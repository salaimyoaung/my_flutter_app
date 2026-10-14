import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/notification_helper.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../shared/pages/full_screen_image_page.dart';

class AdminVerifySellersPage extends StatefulWidget {
  const AdminVerifySellersPage({super.key});

  @override
  State<AdminVerifySellersPage> createState() => _AdminVerifySellersPageState();
}

class _AdminVerifySellersPageState extends State<AdminVerifySellersPage> {
  String _filter = 'all'; // 'all' | 'verified' | 'unverified'
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _markAllVerifyNotiRead();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Admin က Verify Sellers page ဖွင့်ချိန်မှာ
  /// verify_request notifications အားလုံးကို read mark လုပ်သည်
  Future<void> _markAllVerifyNotiRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      final toMark = snap.docs.where((doc) {
        final data = doc.data();
        return data['type'] == 'verify_request';
      }).toList();

      if (toMark.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in toMark) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  /// သီးခြား seller တစ်ယောက်အတွက် notification ကို read mark လုပ်သည်
  Future<void> _markNotiReadForUser(String sellerId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('sellerId', isEqualTo: sellerId)
          .where('isRead', isEqualTo: false)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _toggleVerify(String uid, bool currentStatus) async {
    final action = currentStatus ? 'Unverify' : 'Verify';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Seller?'),
        content: Text(
          currentStatus
              ? 'ဒီ seller ရဲ့ verified badge ကို ဖယ်မလား?'
              : 'ဒီ seller ကို verified အဖြစ် သတ်မှတ်မလား?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // ✅ If verifying (not unverifying), check for duplicate verified names first
      if (!currentStatus) {
        // Get the current user's name
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final name = (userDoc.data()?['name'] ?? '').toString();

        if (name.isNotEmpty) {
          final nameCheck = await FirebaseFirestore.instance
              .collection('users')
              .where('name', isEqualTo: name)
              .where('isVerified', isEqualTo: true)
              .limit(1)
              .get();

          if (nameCheck.docs.isNotEmpty) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Duplicate Name Detected'),
                  content: Text('"$name" ဆိုတဲ့အမည်နဲ့ Verified ဖြစ်ပြီးသား Seller တစ်ယောက် ရှိနေပါတယ်။ အတည်ပြုပေး၍ မရပါ။'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                  ],
                ),
              );
            }
            return;
          }
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isVerified': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ Send notification to seller on verification success
      if (!currentStatus) {
        createNotification(
          userId: uid,
          type: 'account_verified',
          title: 'အကောင့် အတည်ပြုပြီးပါပြီ ✅',
          body: 'သင့်ဆိုင်အား Sigma Moby မှ အောင်မြင်စွာ အတည်ပြုပေးလိုက်ပါပြီ။',
          targetRole: 'seller',
        ).catchError((_) {});
      }

      // ✅ Mark notifications as read for this seller
      await _markNotiReadForUser(uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus
                ? 'Verified badge ဖယ်ပြီးပါပြီ'
                : 'Verified badge ထည့်ပြီးပါပြီ'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ── Navigate to seller's wall (profile) page ─────────────────────────────
  void _openSellerWall(String uid, String name) {
    context.push(
      AppRoutes.profile,
      extra: {'userId': uid, 'sellerName': name},
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(title: 'Verify Sellers'),
      body: Column(
        children: [
          // ── Search + Filter bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Name သို့မဟုတ် Email ရှာမည်',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
                const SizedBox(height: 10),
                // Filter chips
                Row(
                  children: [
                    _chip('All', 'all', scheme),
                    const SizedBox(width: 8),
                    _chip('Pending', 'pending', scheme),
                    const SizedBox(width: 8),
                    _chip('Verified', 'verified', scheme),
                    const SizedBox(width: 8),
                    _chip('Unverified', 'unverified', scheme),
                  ],
                ),
              ],
            ),
          ),

          // ── User list ───────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data!.docs.toList();

                // Sort: Pending users first, then by updatedAt or createdAt
                docs.sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();
                  
                  final aPending = (aData['verificationDocUrl'] ?? '').toString().isNotEmpty && aData['isVerified'] != true;
                  final bPending = (bData['verificationDocUrl'] ?? '').toString().isNotEmpty && bData['isVerified'] != true;
                  
                  if (aPending && !bPending) return -1;
                  if (!aPending && bPending) return 1;
                  
                  final aTime = aData['updatedAt'] ?? aData['createdAt'] ?? Timestamp.now();
                  final bTime = bData['updatedAt'] ?? bData['createdAt'] ?? Timestamp.now();
                  return bTime.compareTo(aTime);
                });

                // Filter by verified status
                if (_filter == 'verified') {
                  docs = docs
                      .where((d) => d.data()['isVerified'] == true)
                      .toList();
                } else if (_filter == 'unverified') {
                  docs = docs
                      .where((d) => d.data()['isVerified'] != true)
                      .toList();
                } else if (_filter == 'pending') {
                  docs = docs
                      .where((d) => 
                        (d.data()['verificationDocUrl'] ?? '').toString().isNotEmpty && 
                        d.data()['isVerified'] != true
                      )
                      .toList();
                }

                // Filter by search query
                if (_search.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data();
                    final name =
                    (data['name'] ?? '').toString().toLowerCase();
                    final email =
                    (data['email'] ?? '').toString().toLowerCase();
                    return name.contains(_search) || email.contains(_search);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _search.isNotEmpty ? 'No results found' : 'No users',
                      style: textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final uid = doc.id;
                    final name = (data['name'] ?? '').toString();
                    final email = (data['email'] ?? '').toString();
                    final profile = (data['profileImage'] ?? '').toString();
                    final isVerified = data['isVerified'] == true;
                    final role = (data['role'] ?? 'user').toString();
                    final totalSales = data['totalSales'] ?? 0;
                    final licenseUrl = (data['verificationDocUrl'] ?? '').toString();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: isVerified
                            ? Border.all(color: scheme.primary.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Avatar — tap to open seller's wall
                          GestureDetector(
                            onTap: () => _openSellerWall(uid, name),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                  scheme.surfaceContainerHighest,
                                  backgroundImage: profile.isNotEmpty
                                      ? NetworkImage(profile)
                                      : null,
                                  child: profile.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                if (isVerified)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: scheme.surface,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(1),
                                      child: Icon(
                                        Icons.verified,
                                        color: scheme.primary,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Info
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openSellerWall(uid, name),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name.isNotEmpty ? name : '(no name)',
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isVerified) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.verified,
                                            color: scheme.primary, size: 14),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      // Role chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: role == 'admin'
                                              ? scheme.primaryContainer
                                              : scheme.surfaceContainerHighest,
                                          borderRadius:
                                          BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          role,
                                          style: textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: role == 'admin'
                                                ? scheme.onPrimaryContainer
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$totalSales sales',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // ── License Doc Thumbnail ──
                                  if (licenseUrl.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: () => FullScreenImagePage.show(context, licenseUrl),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: scheme.secondaryContainer.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: scheme.secondary.withValues(alpha: 0.2)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.description_outlined, size: 14),
                                            const SizedBox(width: 6),
                                            const Text('View License', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Verify toggle button
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: isVerified
                                  ? scheme.errorContainer
                                  : scheme.primaryContainer,
                              foregroundColor:
                              isVerified ? scheme.error : scheme.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _toggleVerify(uid, isVerified),
                            child: Text(
                              isVerified ? 'Unverify' : 'Verify',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, ColorScheme scheme) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}