import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  String get _myId => FirebaseAuth.instance.currentUser?.uid ?? '';

  void _showChatOptions(
    BuildContext context,
    String chatId,
    String otherUserId,
    bool isBlocked,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete conversation'),
              onTap: () async {
                Navigator.pop(sheetContext);

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete conversation?'),
                    content: const Text('This will remove chat only for you.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;
                if (!context.mounted) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .update({'deletedFor.$_myId': true});

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete failed')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(isBlocked ? Icons.lock_open : Icons.block),
              title: Text(isBlocked ? 'Unblock user' : 'Block user'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_myId)
                      .update({
                    'blockedUsers': isBlocked
                        ? FieldValue.arrayRemove([otherUserId])
                        : FieldValue.arrayUnion([otherUserId]),
                  });
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isBlocked ? 'Unblocked' : 'Blocked')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Action failed')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Report to admin'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(AppRoutes.reportPage, extra: {
                  'chatId': chatId,
                  'otherUserId': otherUserId,
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (!authSnap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final myId = authSnap.data!.uid;
        return _buildContent(context, scheme, myId);
      },
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme scheme, String myId) {
    return Scaffold(
      appBar: const BrandAppBar(title: 'Messages'),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(myId).snapshots(),
        builder: (context, mySnap) {
          if (mySnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final myData = mySnap.data?.data() as Map<String, dynamic>? ?? {};
          final rawBlocked = myData['blockedUsers'];
          List<String> myBlocked = [];
          if (rawBlocked is List) {
            myBlocked = List<String>.from(rawBlocked);
          } else if (rawBlocked is Map) {
            myBlocked = List<String>.from(rawBlocked.keys);
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: myId)
                .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final chats = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final deletedForMap = data['deletedFor'] as Map<String, dynamic>? ?? {};
                return deletedForMap[myId] != true;
              }).toList();

              if (chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 50, color: scheme.outline),
                      const SizedBox(height: 10),
                      Text('No conversations yet',
                          style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }

              return MaxWidthBox(
                child: ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final data = chat.data() as Map<String, dynamic>;
                    final participants = List<String>.from(data['participants'] ?? []);
                    final others = participants.where((id) => id != myId && id.isNotEmpty).toList();

                    if (others.isEmpty) return const SizedBox.shrink();

                    final otherId = others.first;
                    final lastMessage = (data['lastMessage'] ?? '').toString().trim().isEmpty
                        ? 'No messages yet'
                        : data['lastMessage'].toString();

                    final unread = data['unreadCount'] is Map
                        ? (data['unreadCount'][myId] as num?)?.toInt() ?? 0
                        : 0;

                    return _ChatTile(
                      key: ValueKey(chat.id),
                      chatId: chat.id,
                      otherId: otherId,
                      myId: myId,
                      lastMessage: lastMessage,
                      unreadCount: unread,
                      updatedAt: data['updatedAt'] as Timestamp?,
                      isBlockedByMe: myBlocked.contains(otherId),
                      onLongPress: (cid, oid, block) =>
                          _showChatOptions(context, cid, oid, block),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String chatId;
  final String otherId;
  final String myId;
  final String lastMessage;
  final int unreadCount;
  final Timestamp? updatedAt;
  final bool isBlockedByMe;
  final Function(String chatId, String otherId, bool isBlocked) onLongPress;

  const _ChatTile({
    super.key,
    required this.chatId,
    required this.otherId,
    required this.myId,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
    required this.isBlockedByMe,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherId).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const ListTile(title: Text('Loading...'));
        }

        if (!userSnap.data!.exists) {
          return ListTile(
            title: const Text('Unknown user'),
            subtitle: Text(isBlockedByMe ? 'Blocked user' : lastMessage),
            onTap: isBlockedByMe
                ? null
                : () => context.push('/chat', extra: {
                      'chatId': chatId,
                      'otherUserId': otherId,
                    }),
            onLongPress: () => onLongPress(chatId, otherId, isBlockedByMe),
          );
        }

        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        final rawBlocked = userData['blockedUsers'];
        List<String> otherBlocked = [];
        if (rawBlocked is List) {
          otherBlocked = List<String>.from(rawBlocked);
        } else if (rawBlocked is Map) {
          otherBlocked = List<String>.from(rawBlocked.keys);
        }

        final name = (userData['name'] ?? 'User').toString();
        final profile = (userData['profileImage'] ?? '').toString();

        final isOnline = () {
          if (userData['isOnline'] != true) return false;
          final ls = userData['lastSeen'];
          if (ls == null || ls is! Timestamp) return true;
          return DateTime.now().difference(ls.toDate()).inMinutes < 10;
        }();

        final isBlocked = isBlockedByMe || otherBlocked.contains(myId);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: Stack(
            children: [
              Hero(
                tag: chatId,
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: profile.isNotEmpty ? NetworkImage(profile) : null,
                  child: profile.isEmpty ? const Icon(Icons.person) : null,
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: scheme.tertiary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            isBlocked ? 'Blocked user' : lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_formatTime(updatedAt),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: TextStyle(
                      color: scheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: isBlocked
              ? null
              : () => context.push('/chat', extra: {
                    'chatId': chatId,
                    'otherUserId': otherId,
                  }),
          onLongPress: () => onLongPress(chatId, otherId, isBlockedByMe),
        );
      },
    );
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
}
