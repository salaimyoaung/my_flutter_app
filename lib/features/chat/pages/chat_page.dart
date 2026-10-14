import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/presence_service.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/widgets/brand_app_bar.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  String? _lastMessageId;
  bool _isMarking = false;
  bool _isUploading = false;
  List<XFile> _selectedImages = [];

  String get _myId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _markAsReadAndSeen();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isActuallyOnline(bool flag, dynamic lastSeenRaw, {Timestamp? lastMessageAt}) {
    // ── 1) Explicit flag ───────────────────────────────────────────────────
    if (flag) {
      if (lastSeenRaw == null || lastSeenRaw is! Timestamp) return true;
      final diff = DateTime.now().difference(lastSeenRaw.toDate());
      if (diff.inMinutes < 10) return true; // Online if flag is true AND fresh
    }

    // ── 2) Implicit presence (Activity fallback) ───────────────────────────
    // အကယ်၍ user က offline လို့ ပြနေသော်လည်း လွန်ခဲ့သော ၅ မိနစ်အတွင်း message ပို့ထားလျှင်
    // သူ့ကို online ဟု ယာယီသတ်မှတ်မည် (Network lag ကြောင့် status မတက်တာမျိုးအတွက်)
    if (lastMessageAt != null) {
      final diff = DateTime.now().difference(lastMessageAt.toDate());
      if (diff.inMinutes < 5) return true;
    }

    return false;
  }

  String _lastSeenText(dynamic lastSeenRaw) {
    if (lastSeenRaw == null || lastSeenRaw is! Timestamp) return 'Offline';
    final dt = lastSeenRaw.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } else if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _markAsReadAndSeen() async {
    if (_myId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'unreadCount.$_myId': FieldValue.delete(),
        'lastSeen.$_myId': FieldValue.serverTimestamp(),
        'deletedFor.$_myId': false,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('markAsRead error: $e');
    }
  }

  void _markMessagesAsSeen(List<QueryDocumentSnapshot> docs) async {
    if (_isMarking || _myId.isEmpty) return;
    _isMarking = true;

    const int batchLimit = 400;
    WriteBatch batch = FirebaseFirestore.instance.batch();
    int count = 0;
    bool hasUpdate = false;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final seenBy = List<String>.from(data['seenBy'] ?? []);
      if (data['senderId'] != _myId && !seenBy.contains(_myId)) {
        hasUpdate = true;
        batch.update(doc.reference, {
          'seenBy': FieldValue.arrayUnion([_myId]),
        });
        count++;

        if (count >= batchLimit) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          count = 0;
        }
      }
    }

    if (hasUpdate) {
      if (count > 0) await batch.commit();
      try {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({'unreadCount.$_myId': FieldValue.delete()});
      } catch (_) {}
    } else if (count > 0) {
      await batch.commit();
    }
    _isMarking = false;
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;
    setState(() => _selectedImages = files);
  }

  Future<void> _sendMessage() async {
    if (_isUploading || _myId.isEmpty) return;

    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_myId)
        .get();
    final myData = myDoc.data() ?? {};

    if (myData['isBanned'] == true) {
      _snack('Your account is banned');
      return;
    }

    final myBlocked = List<String>.from(myData['blockedUsers'] ?? []);
    if (myBlocked.contains(widget.otherUserId)) {
      _snack('You blocked this user');
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty) return;

    setState(() => _isUploading = true);

    final chatRef =
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      const int maxChatImageBytes = 10 * 1024 * 1024;
      for (int i = 0; i < _selectedImages.length; i++) {
        final file = File(_selectedImages[i].path);
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_images')
            .child(_myId)
            .child('${now}_$i.jpg');

        try {
          final bytes = await file.length();
          if (bytes > maxChatImageBytes) {
            _snack('ပုံ ${i + 1} သည် 10MB ကျော်နေသောကြောင့် skip လုပ်သည်');
            continue;
          }

          await ref.putFile(file);
          final imageUrl = await ref.getDownloadURL();

          await chatRef.collection('messages').add({
            'senderId': _myId,
            'imageUrl': imageUrl,
            'text': i == 0 ? text : '',
            'createdAt': FieldValue.serverTimestamp(),
            'seenBy': [_myId],
            'deletedFor': {_myId: false, widget.otherUserId: false},
          });
        } catch (_) {
          _snack('Upload failed for image ${i + 1}');
        }
      }

      if (_selectedImages.isEmpty) {
        await chatRef.collection('messages').add({
          'senderId': _myId,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'seenBy': [_myId],
          'deletedFor': {_myId: false, widget.otherUserId: false},
        });
      }

      final lastMsg = text.isNotEmpty
          ? text
          : _selectedImages.length > 1
          ? '📷 ${_selectedImages.length} Photos'
          : '📷 Photo';

      await chatRef.update({
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': lastMsg,
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
        'deletedFor.$_myId': false,
        'deletedFor.${widget.otherUserId}': false,
      });

      _textController.clear();
      // ✅ Bump self presence on message send
      PresenceService.setOnline();
    } catch (e) {
      _snack('Send failed');
    } finally {
      if (mounted) {
        setState(() {
          _selectedImages = [];
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteMessageForMe(String messageId) async {
    if (_myId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({'deletedFor.$_myId': true});
  }

  Future<void> _onLinkTap(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Could not launch $url: $e');
    }
  }

  Widget _buildLinkifiedText(String text, bool isMe, ColorScheme scheme) {
    final textColor = isMe ? scheme.onPrimary : scheme.onSurface;
    final linkColor = isMe ? Colors.white : scheme.primary;

    final urlRegExp = RegExp(
      r"((https?|ftp|file)://|www\.)[-A-Z0-9+&@#/%?=~_|!:,.;]*[-A-Z0-9+&@#/%=~_|]",
      caseSensitive: false,
    );

    final matches = urlRegExp.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: TextStyle(color: textColor));
    }

    final List<TextSpan> spans = [];
    int start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(color: textColor),
        ));
      }

      final url = match.group(0)!;
      final fullUrl = url.startsWith('www.') ? 'https://$url' : url;

      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.bold,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _onLinkTap(fullUrl),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: textColor),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
        ),
      ),
    );
  }

  // ─── UI Components ────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final firestore = FirebaseFirestore.instance;
    return BrandAppBar(
      titleWidget: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('users').doc(widget.otherUserId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final otherData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = (otherData['name'] ?? 'User').toString();
          final profile = (otherData['profileImage'] ?? '').toString();

          final isOnlineFromFlag = otherData['isOnline'] == true;
          final lastSeen = otherData['lastSeen'];

          return StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('chats')
                .doc(widget.chatId)
                .collection('messages')
                .where('senderId', isEqualTo: widget.otherUserId)
                .orderBy('createdAt', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, msgSnap) {
              Timestamp? lastMsgAt;
              if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
                lastMsgAt = msgSnap.data!.docs.first.get('createdAt') as Timestamp?;
              }

              final isOnline = _isActuallyOnline(
                isOnlineFromFlag,
                lastSeen,
                lastMessageAt: lastMsgAt,
              );

              return GestureDetector(
                onTap: () => context.push('/profile', extra: {'userId': widget.otherUserId}),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: widget.chatId,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: profile.isNotEmpty ? NetworkImage(profile) : null,
                            child: profile.isEmpty ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            isOnline ? 'Online' : _lastSeenText(lastSeen),
                            style: TextStyle(
                              fontSize: 11,
                              color: isOnline ? Colors.greenAccent : Colors.white70,
                              fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInputArea(ColorScheme scheme) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_myId).snapshots(),
      builder: (context, mySnap) {
        if (!mySnap.hasData) return const SizedBox.shrink();

        final myData = mySnap.data!.data() as Map<String, dynamic>? ?? {};
        final myBlocked = List<String>.from(myData['blockedUsers'] ?? []);
        final isBlocked = myBlocked.contains(widget.otherUserId);
        final isBanned = myData['isBanned'] == true;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(),
          builder: (context, otherSnap) {
            if (!otherSnap.hasData) return const SizedBox.shrink();
            final otherData = otherSnap.data!.data() as Map<String, dynamic>? ?? {};
            final isOtherBanned = otherData['isBanned'] == true;

            if (isBlocked || isBanned || isOtherBanned) {
              return Container(
                padding: const EdgeInsets.all(12),
                alignment: Alignment.center,
                child: Text(
                  isBanned
                      ? 'Your account is banned'
                      : isBlocked
                      ? 'You blocked this user'
                      : 'This user is banned',
                  style: TextStyle(color: scheme.error),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: _isUploading ? null : _pickImages,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        enabled: !isBanned,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Type message...',
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: _isUploading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.send),
                      onPressed: (_isUploading || (_textController.text.trim().isEmpty && _selectedImages.isEmpty))
                          ? null
                          : _sendMessage,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_myId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Login required')));
    }

    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If gesture is still active, don't force context operations if not mounted.
        if (mounted) {
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: MaxWidthBox(
          maxWidth: 800,
          child: Column(
            children: [
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('sending...'),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;

                    if (docs.isNotEmpty) {
                      final latestId = docs.first.id;
                      if (_lastMessageId != latestId) {
                        _lastMessageId = latestId;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }
                    }

                    if (docs.isNotEmpty && !_isMarking) {
                      Future.microtask(() => _markMessagesAsSeen(docs));
                    }

                    if (docs.isEmpty) return const Center(child: Text('No messages yet'));

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final deletedForMap = (data['deletedFor'] as Map<String, dynamic>?) ?? {};
                        if (deletedForMap[_myId] == true) {
                          return const Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'You deleted this message',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        final isMe = data['senderId'] == _myId;
                        final time = _formatTime(data['createdAt']);
                        final seenBy = List<String>.from(data['seenBy'] ?? []);
                        final isSeen = seenBy.length > 1;
                        final imageUrl = (data['imageUrl'] ?? '').toString();
                        final text = (data['text'] ?? '').toString();

                        return GestureDetector(
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (text.isNotEmpty)
                                      ListTile(
                                        leading: const Icon(Icons.copy),
                                        title: const Text('စာသားကို Copy ယူမည်'),
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: text));
                                          Navigator.pop(ctx);
                                          _snack('Copy ယူပြီးပါပြီ');
                                        },
                                      ),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                                      title: const Text('Message ကို ဖျက်မည်',
                                          style: TextStyle(color: Colors.red)),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogCtx) => AlertDialog(
                                            title: const Text('Delete message?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(dialogCtx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(dialogCtx, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _deleteMessageForMe(docs[i].id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe ? scheme.primary : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Scaffold(
                                              backgroundColor: Colors.black,
                                              body: Center(
                                                child: InteractiveViewer(
                                                  child: Image.network(imageUrl),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: AppNetworkImage(
                                            imageUrl,
                                            width: MediaQuery.of(context).size.width * 0.5,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, progress) {
                                              if (progress == null) return child;
                                              return SizedBox(
                                                width: MediaQuery.of(context).size.width * 0.5,
                                                height: 150,
                                                child: const Center(child: CircularProgressIndicator()),
                                              );
                                            },
                                            errorBuilder: (_, _, _) => const SizedBox(
                                              width: 120,
                                              height: 80,
                                              child: Center(child: Icon(Icons.broken_image_outlined)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (text.isNotEmpty) _buildLinkifiedText(text, isMe, scheme),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isMe)
                                        Text(
                                          isSeen ? '✓✓' : '✓',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: scheme.onPrimary.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      const SizedBox(width: 4),
                                      Text(
                                        time,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe
                                              ? scheme.onPrimary.withValues(alpha: 0.7)
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_selectedImages[i].path),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImages.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              _buildInputArea(scheme),
            ],
          ),
        ),
      ),
    );
  }
}
