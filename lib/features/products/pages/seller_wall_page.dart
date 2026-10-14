import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/admin_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../data/models/review_model.dart';
import '../../../data/services/review_service.dart';
import '../widgets/brand_wall_view.dart';
import 'widgets/seller_header.dart';

class SellerWallPage extends StatelessWidget {
  final String sellerId;
  final String sellerName;

  const SellerWallPage({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = myId != null && myId == sellerId;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(sellerId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snap.data!.exists) {
          return Scaffold(
            appBar: BrandAppBar(title: 'Profile'),
            body: const Center(child: Text('User not found')),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        
        final rawFee = data['pendingFee'];
        int pendingFee = 0;
        if (rawFee is int) {
          pendingFee = rawFee;
        } else if (rawFee is num) {
          pendingFee = rawFee.toInt();
        } else if (rawFee is String) {
          pendingFee = int.tryParse(rawFee) ?? 0;
        }

        final feeDeadline = data['feeDeadline'] as Timestamp?;
        final hasFee = pendingFee > 0;

        final role = (data['role'] ?? '').toString().toLowerCase().trim();
        final isAdmin = role == 'admin';

        return Scaffold(
          appBar: BrandAppBar(
            title: 'Profile',
            titleSpacing: isOwner ? 16 : 0,
            leading: isOwner ? const SizedBox.shrink() : null,
            leadingWidth: isOwner ? 0 : null,
            actions: isOwner 
                ? [
                    _AppBarChatIcon(myId: myId, scheme: scheme),
                    _AppBarNotifIcon(myId: myId, scheme: scheme),
                    _AppBarRequestIcon(myId: myId),
                    if (!isAdmin) _AppBarAdminContact(myId: myId),
                  ] 
                : [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (val) => val == 'report' ? context.push(AppRoutes.reportPage, extra: {'otherUserId': sellerId, 'otherUserName': sellerName}) : null,
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, size: 18, color: Theme.of(ctx).colorScheme.error), const SizedBox(width: 8), const Text('Report User', style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ],
          ),
          body: MaxWidthBox(
            child: Column(
              children: [
                // ── ✅ PERSISTENT PERSISTENT WARNING BANNER ──
                // Scroll ဆွဲစရာမလိုဘဲ အပေါ်မှာ အမြဲကပ်နေမည့် Banner
                if (isOwner && hasFee)
                  _PersistentCountdownBanner(
                    pendingFee: pendingFee,
                    feeDeadline: feeDeadline,
                    scheme: scheme,
                  ),

                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: SellerHeader(sellerId: sellerId)),
                      if (isOwner) SliverToBoxAdapter(child: _CityWarning(sellerId: sellerId)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _ReviewsSection(sellerId: sellerId),
                        ),
                      ),
                      if (!isOwner) SliverToBoxAdapter(child: _VisitorActions(sellerId: sellerId, createChat: (id) async {
                        final myId = FirebaseAuth.instance.currentUser?.uid;
                        if (myId == null) throw Exception('Login required');
                        final chatId = [myId, sellerId]..sort();
                        final chatDocId = chatId.join('_');
                        final ref = FirebaseFirestore.instance.collection('chats').doc(chatDocId);
                        if (!(await ref.get()).exists) {
                          await ref.set({'participants': [myId, sellerId], 'lastMessage': '', 'updatedAt': FieldValue.serverTimestamp(), 'unreadCount': {myId: 0, sellerId: 0}});
                        }
                        return chatDocId;
                      })),
                      SliverToBoxAdapter(child: BrandWallView(sellerId: sellerId, shrinkWrap: true)),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}

// ─── Sticky Countdown Banner Widget ──────────────────────────────────────────

class _PersistentCountdownBanner extends StatelessWidget {
  final int pendingFee;
  final Timestamp? feeDeadline;
  final ColorScheme scheme;

  const _PersistentCountdownBanner({
    required this.pendingFee,
    this.feeDeadline,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    String countdownText = 'သတ်မှတ်ရက် ကျော်လွန်နေပါပြီ';
    bool isOverdue = true;

    if (feeDeadline != null) {
      final remaining = feeDeadline!.toDate().difference(DateTime.now());
      if (!remaining.isNegative) {
        isOverdue = false;
        final d = remaining.inDays;
        final h = remaining.inHours % 24;
        final m = remaining.inMinutes % 60;
        if (d > 0) {
          countdownText = '$d ရက် $h နာရီ ကျန်ပါသည်';
        } else if (h > 0) {
          countdownText = '$h နာရီ $m မိနစ် ကျန်ပါသည်';
        } else {
          countdownText = '$m မိနစ်သာ ကျန်ပါသည်';
        }
      }
    } else {
      // Deadline မရှိသေးသော old data များအတွက်
      isOverdue = false;
      countdownText = 'မကြာမီ ပိတ်သိမ်းခံရနိုင်သည်';
    }

    final feeStr = pendingFee.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ဝန်ဆောင်ခ ပေးချေရန်'),
            content: Text('စုစုပေါင်း ကျန်ငွေ $feeStr Ks ကို သတ်မှတ်ချိန်အတွင်း ပေးသွင်းပေးပါ။ မဟုတ်ပါက ပစ္စည်းများအားလုံး ခေတ္တ ပိတ်သိမ်းခံရပါမည်။ Admin ဆီသို့ ဆက်သွယ်ပေးချေနိုင်ပါသည်။'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('သိပါပြီ'))],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isOverdue ? scheme.error : Colors.orange.shade900,
          border: const Border(bottom: BorderSide(color: Colors.black26, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOverdue ? '⚠️ ဝန်ဆောင်ခ ပေးရန် သတ်မှတ်ရက် ကျော်လွန်နေပါသည်' : '⏳ ဝန်ဆောင်ခ ပေးရန် ကျန်ရှိချိန်',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'ကျန်ငွေ $feeStr Ks | $countdownText',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets (Internal) ───────────────────────────────────────────────

class _CityWarning extends StatelessWidget {
  final String sellerId;
  const _CityWarning({required this.sellerId});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(sellerId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        if ((data['shopCity'] ?? '').toString().isNotEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.location_city_outlined),
            const SizedBox(width: 10),
            const Expanded(child: Text('Profile မှာ မြို့ မထည့်ရသေးပါ။', style: TextStyle(fontSize: 13))),
            TextButton(onPressed: () => context.push(AppRoutes.editProfile, extra: {'currentName': data['name'] ?? '', 'currentPhone': data['phone'] ?? '', 'currentCoverImage': data['coverImage'] ?? '', 'currentProfileImage': data['profileImage'] ?? ''}), child: const Text('ထည့်မည်')),
          ]),
        );
      },
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final String sellerId;
  const _ReviewsSection({required this.sellerId});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewModel>>(
      stream: ReviewService.sellerReviewsStream(sellerId),
      builder: (context, snap) {
        final reviews = snap.data ?? [];
        if (reviews.isEmpty) return const SizedBox.shrink();
        final avg = reviews.fold<double>(0, (s, r) => s + r.rating) / reviews.length;
        
        // Fetch seller name for the reviews page title
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(sellerId).get(),
          builder: (context, userSnap) {
            final sellerName = (userSnap.data?.data() as Map?)?['name'] ?? 'Seller';
            
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: () => context.push(
                  AppRoutes.sellerReviews.replaceFirst(':sellerId', sellerId),
                  extra: {'sellerName': sellerName},
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(Icons.star_rounded, color: Theme.of(context).colorScheme.tertiary, size: 20),
                    const SizedBox(width: 6),
                    Text('${avg.toStringAsFixed(1)}  (${reviews.length} reviews)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('View all', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                  ]),
                ),
              ),
            ]);
          }
        );
      },
    );
  }
}

class _VisitorActions extends StatelessWidget {
  final String sellerId;
  final Future<String> Function(String) createChat;
  const _VisitorActions({required this.sellerId, required this.createChat});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(sellerId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final phone = (snap.data!.data() as Map?)?['phone'] ?? '';
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final id = await createChat(sellerId);
                  if (context.mounted) {
                    context.push('/chat', extra: {'chatId': id, 'otherUserId': sellerId});
                  }
                },
                icon: const Icon(Icons.chat, size: 16),
                label: const Text('Chat'),
              ),
            ),
            if (phone.isNotEmpty) ...[const SizedBox(width: 10), Expanded(child: ElevatedButton.icon(onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone.toString())), icon: const Icon(Icons.call, size: 16), label: const Text('Call'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.white)))],
          ]),
        );
      },
    );
  }
}

class _AppBarChatIcon extends StatelessWidget {
  final String myId; final ColorScheme scheme;
  const _AppBarChatIcon({required this.myId, required this.scheme});
  @override Widget build(BuildContext context) => IconButton(icon: const Icon(Icons.chat_outlined, size: 22), onPressed: () => context.push('/chats'));
}
class _AppBarNotifIcon extends ConsumerWidget {
  final String myId; final ColorScheme scheme;
  const _AppBarNotifIcon({required this.myId, required this.scheme});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(bellUnreadProvider).value ?? 0;
    return Stack(
      children: [
        IconButton(icon: const Icon(Icons.notifications_outlined, size: 22), onPressed: () => context.push(AppRoutes.notifications)),
        if (count > 0)
          Positioned(
            right: 8, top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(count > 9 ? '9+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}
class _AppBarRequestIcon extends ConsumerWidget {
  final String myId;
  const _AppBarRequestIcon({required this.myId});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(sellerModelRequestUnseenProvider).value ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        IconButton(icon: const Icon(Icons.list_alt_outlined, size: 22), onPressed: () => context.push(AppRoutes.myModelRequests)),
        if (count > 0)
          Positioned(
            right: 8, top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(count > 9 ? '9+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}
class _AppBarAdminContact extends StatelessWidget {
  final String? myId;
  const _AppBarAdminContact({required this.myId});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.headset_mic_outlined, size: 22),
    onPressed: () async {
      if (myId == null) return;
      
      try {
        // ── Find first available admin ─────────────────────────────────────
        final adminSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .limit(1)
            .get();

        if (adminSnap.docs.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Admin ဆက်သွယ်ရန် ခေတ္တ အဆင်မပြေပါ')),
            );
          }
          return;
        }

        final adminId = adminSnap.docs.first.id;
        
        // ── Create or get chat ─────────────────────────────────────────────
        final participants = [myId, adminId]..sort();
        final chatId = participants.join('_');
        
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
        final chatDoc = await chatRef.get();
        
        if (!chatDoc.exists) {
          await chatRef.set({
            'participants': participants,
            'lastMessage': '',
            'updatedAt': FieldValue.serverTimestamp(),
            'unreadCount': {myId: 0, adminId: 0},
            'deletedFor': {myId: false, adminId: false},
          });
        }

        if (context.mounted) {
          context.push('/chat', extra: {
            'chatId': chatId,
            'otherUserId': adminId,
          });
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    },
  ); 
}

class _ReviewCard extends StatefulWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});
  @override State<_ReviewCard> createState() => _ReviewCardState();
}
class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;
  @override Widget build(BuildContext context) {
    final r = widget.review;
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => context.push(
              AppRoutes.sellerWall,
              extra: {'sellerId': r.buyerId, 'sellerName': r.buyerName},
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 18, backgroundImage: r.buyerProfileImage.isNotEmpty ? NetworkImage(r.buyerProfileImage) : null, child: r.buyerProfileImage.isEmpty ? const Icon(Icons.person, size: 18) : null), 
                const SizedBox(width: 10),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(
                AppRoutes.sellerWall,
                extra: {'sellerId': r.buyerId, 'sellerName': r.buyerName},
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.buyerName, style: const TextStyle(fontWeight: FontWeight.bold)), 
                Text(r.productName, style: const TextStyle(fontSize: 12, color: Colors.grey))
              ]),
            ),
          ), 
          Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 14)))
        ]),
        if (r.comment.isNotEmpty) ...[const SizedBox(height: 6), Text(r.comment, maxLines: _expanded ? null : 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)), if (r.comment.length > 40) GestureDetector(onTap: () => setState(() => _expanded = !_expanded), child: Text(_expanded ? 'See less' : 'See more', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)))],
      ]),
    );
  }
}
