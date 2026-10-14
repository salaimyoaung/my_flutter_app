import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/notification_helper.dart';
import '../../../core/widgets/brand_app_bar.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: const BrandAppBar(title: "Notifications"),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // Bell page — announcement + admin actions only
          final bellTypes = kBellNotifTypes.toSet();
          final docs = (snapshot.data?.docs ?? [])
              .where((d) {
                final t = (d.data() as Map<String, dynamic>)['type'] as String?;
                return t != null && bellTypes.contains(t);
              })
              .toList();

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("Notifications မရှိသေးပါ"),
                ],
              ),
            );
          }

          final grouped = <String, _NotifGroup>{};

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['type'] ?? '').toString();
            final chatId = data['chatId']?.toString();
            final isRead = data['isRead'] == true;

            final groupKey = (type == 'chat' && chatId != null)
                ? 'chat_$chatId'
                : doc.id;

            if (!grouped.containsKey(groupKey)) {
              grouped[groupKey] = _NotifGroup(
                docId: doc.id,
                ref: doc.reference,
                data: data,
                unreadCount: isRead ? 0 : 1,
              );
            } else if (!isRead) {
              grouped[groupKey]!.unreadCount++;
            }
          }

          final items = grouped.values.toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) =>
                _NotifTile(item: items[i], userId: userId),
          );
        },
      ),
    );
  }
}

class _NotifGroup {
  final String docId;
  final DocumentReference ref;
  final Map<String, dynamic> data;
  int unreadCount;

  _NotifGroup({
    required this.docId,
    required this.ref,
    required this.data,
    required this.unreadCount,
  });
}

class _NotifTile extends StatelessWidget {
  final _NotifGroup item;
  final String userId;

  const _NotifTile({required this.item, required this.userId});

  Map<String, dynamic> get d => item.data;
  String get type => (d['type'] ?? '').toString();
  bool get isRead => d['isRead'] == true;
  bool get isUnread => !isRead;

  IconData get _icon {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'new_order':
        return Icons.shopping_bag_outlined;
      case 'order':
        final title = d['title']?.toString() ?? '';
        if (title.contains('Fee') || title.contains('fee')) return Icons.receipt_long_outlined;
        if (title.contains('Ship') || title.contains('🚚')) return Icons.local_shipping_outlined;
        if (title.contains('Complete') || title.contains('🎉')) return Icons.check_circle_outline;
        if (title.contains('Pending') || title.contains('⏳')) return Icons.hourglass_empty_rounded;
        return Icons.swap_horiz_outlined;
      case 'order_completed':
        return Icons.check_circle_outline;
      case 'order_status_changed':
        return Icons.swap_horiz_outlined;
      case 'report':
        return Icons.flag_outlined;
      case 'fee_freeze':
        return Icons.lock_outline;
      case 'product_rejected':
        return Icons.remove_circle_outline;
      case 'account_banned':
        return Icons.block_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(ColorScheme cs) {
    switch (type) {
      case 'chat':
        return cs.primary;
      case 'new_order':
        return cs.secondary;
      case 'order':
        final title = d['title']?.toString() ?? '';
        if (title.contains('Fee') || title.contains('fee')) return cs.error;
        if (title.contains('Complete') || title.contains('🎉')) return cs.tertiary;
        if (title.contains('Pending') || title.contains('⏳')) return cs.secondary;
        return cs.secondary;
      case 'order_completed':
        return cs.tertiary;
      case 'report':
        return cs.error;
      case 'fee_freeze':
        return cs.error;
      case 'product_rejected':
        return Colors.orange;
      case 'account_banned':
        return cs.error;
      case 'announcement':
        return cs.primary;
      default:
        return cs.secondary;
    }
  }

  String get _subtitle {
    final body = d['body']?.toString() ?? '';
    if (body.isNotEmpty) return body;
    return d['lastMessage']?.toString() ?? '';
  }

  Future<void> _markRead() async {
    if (isRead) return;
    try {
      final type_ = type;
      final chatId = d['chatId']?.toString();

      if (type_ == 'chat' && chatId != null) {
        final batch = FirebaseFirestore.instance.batch();
        final snap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('chatId', isEqualTo: chatId)
            .where('isRead', isEqualTo: false)
            .get();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      } else {
        await item.ref.update({'isRead': true});
      }
    } catch (_) {}
  }

  Future<void> _onLinkTap(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildLinkifiedText(String text, ColorScheme scheme) {
    final urlRegExp = RegExp(
      r"((https?|ftp|file)://|www\.)[-A-Z0-9+&@#/%?=~_|!:,.;]*[-A-Z0-9+&@#/%=~_|]",
      caseSensitive: false,
    );

    final matches = urlRegExp.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: scheme.onSurfaceVariant,
          height: 1.5,
        ),
      );
    }

    final List<TextSpan> spans = [];
    int start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ));
      }

      final url = match.group(0)!;
      final fullUrl = url.startsWith('www.') ? 'https://$url' : url;

      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: scheme.primary,
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
        style: TextStyle(color: scheme.onSurfaceVariant),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _iconColor(scheme).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _iconColor(scheme), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    d['title']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_subtitle.isNotEmpty)
              GestureDetector(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: _subtitle));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copy ယူပြီးပါပြီ')),
                  );
                },
                child: _buildLinkifiedText(_subtitle, scheme),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _iconColor(scheme).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon, color: _iconColor(scheme), size: 22),
      ),
      title: Text(
        d['title']?.toString() ?? '',
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _subtitle.isNotEmpty
          ? Text(
              _subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: item.unreadCount > 0
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.unreadCount > 9
                    ? '9+'
                    : '${item.unreadCount}',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : isRead
              ? null
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
      tileColor: isUnread
          ? scheme.primaryContainer.withValues(alpha: 0.18)
          : null,
      onTap: () async {
        await _markRead();
        if (context.mounted) _showDetail(context);
      },
    );
  }
}
