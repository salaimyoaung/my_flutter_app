import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:realproject/features/products/pages/seller_brand_wall_view.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_routes.dart';

class SellerWallPage extends StatelessWidget {
  final String sellerId;
  final String? sellerName;

  const SellerWallPage({
    super.key,
    required this.sellerId,
    this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final isOwner = currentUid.isNotEmpty && currentUid == sellerId.trim();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(sellerId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasData && snap.data!.exists) {
              final name = (snap.data!.data()?['name'] ?? sellerName ?? 'Shop')
                  .toString();
              return Text(
                name,
                style: AppTextStyles.heading(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
            return Text(
              sellerName ?? "Shop",
              style: AppTextStyles.heading(context),
            );
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: sellerId)
            .snapshots(),
        builder: (context, productSnap) {
          if (productSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (productSnap.hasError) {
            return const Center(child: Text("ပစ္စည်းစာရင်း ဆွဲယူရာတွင် အမှားရှိနေသည်"));
          }

          final docs = productSnap.data?.docs ?? [];

          // ✅ fallback cover = first product image (if any)
          String fallbackCover = "";
          if (docs.isNotEmpty) {
            final firstData = docs.first.data();
            fallbackCover = (firstData['image'] ?? '').toString().trim();
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter  (
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(sellerId)
                      .snapshots(),
                  builder: (context, userSnap) {
                    String profileImageUrl = '';
                    String coverImageUrl = '';
                    String displayName = sellerName ?? '';
                    String phone = '';

                    if (userSnap.hasData && userSnap.data!.exists) {
                      final userData = userSnap.data!.data() ?? {};
                      profileImageUrl =
                          (userData['profileImage'] ?? '').toString().trim();
                      coverImageUrl =
                          (userData['coverImage'] ?? '').toString().trim();
                      displayName = (userData['name'] ?? sellerName).toString();
                      phone = (userData['phone'] ?? '').toString();
                    }

                    // ✅ FACEBOOK STYLE header sizes
                    const double coverHeight = 170;
                    const double avatarRadius = 44;

                    final String coverToUse =
                    coverImageUrl.isNotEmpty ? coverImageUrl : fallbackCover;

                    return Column(
                      children: [
                        Container(
                          color: scheme.surface,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // ---- Cover ----
                              SizedBox(
                                height: coverHeight,
                                width: double.infinity,
                                child: coverToUse.isNotEmpty
                                    ? Image.network(
                                  coverToUse,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: scheme.surfaceVariant,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    color: scheme.surfaceVariant,
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported_outlined),
                                    ),
                                  ),
                                )
                                    : Container(
                                  color: scheme.surfaceVariant,
                                  child: const Center(
                                    child: Icon(Icons.photo, size: 30),
                                  ),
                                ),
                              ),

                              // ---- gradient bottom ----
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.00),
                                          Colors.black.withOpacity(0.12),
                                          Colors.black.withOpacity(0.25),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // ---- Avatar overlap ----
                              Positioned(
                                left: 20,
                                bottom: -avatarRadius,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: avatarRadius,
                                    backgroundColor: scheme.primaryContainer,
                                    backgroundImage: profileImageUrl.isNotEmpty
                                        ? NetworkImage(profileImageUrl)
                                        : null,
                                    child: profileImageUrl.isEmpty
                                        ? Icon(Icons.store, size: 40, color: scheme.primary)
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ✅ space for avatar overlap
                        const SizedBox(height: avatarRadius + 14),

                        // ---- Name + actions ----
                        Container(
                          width: double.infinity,
                          color: scheme.surface,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: AppTextStyles.heading(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              if (userSnap.hasData && userSnap.data!.exists)
                                Builder(
                                  builder: (_) {
                                    final userData = userSnap.data!.data() ?? {};
                                    final address = (userData['shopAddress'] ?? '').toString().trim();
                                    final city = (userData['shopCity'] ?? '').toString().trim();

                                    if (address.isEmpty && city.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Row(
                                      children: [
                                        Icon(Icons.location_on_outlined,
                                            size: 16, color: scheme.primary),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            city.isNotEmpty ? "$address ($city)" : address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.small(context)
                                                .copyWith(color: scheme.onSurfaceVariant),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                              const SizedBox(height: 6),

                              if (isOwner) ...[
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        context.push(
                                          AppRoutes.editProfile,
                                          extra: {
                                            'currentName': displayName,
                                            'currentPhone': phone,
                                            'currentCoverImage': coverImageUrl,
                                            'currentProfileImage': profileImageUrl,
                                          },
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: Icon(Icons.edit, size: 16, color: scheme.primary),
                                      label: Text(
                                        "Profile ပြင်မည်",
                                        style: TextStyle(fontSize: 14, color: scheme.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await FirebaseAuth.instance.signOut();
                                        if (context.mounted) {
                                          context.go(AppRoutes.home);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("အကောင့်ထဲမှ ထွက်ပြီးပါပြီ")),
                                          );
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                                      label: const Text(
                                        "အကောင့်မှ ထွက်မည်",
                                        style: TextStyle(color: Colors.red, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 6),
                              Text(
                                "ပစ္စည်းစုစုပေါင်း - ${docs.length} ခု",
                                style: AppTextStyles.small(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              if (docs.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text("ရောင်းရန်ပစ္စည်း မရှိသေးပါ"),
                    ),
                  ),
                )
              else
                SliverFillRemaining(
                  child: SellerBrandWallView(
                    sellerId: sellerId,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ✅ keep ONLY ONE copy of this function (remove duplicates)
  String displaySellerNameFromData(Map<String, dynamic> data, String fallback) {
    final s = (data['sellerName'] ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }
}
class BrandCard extends StatelessWidget {
  final String brand;
  final String logoUrl;
  final int modelCount;
  final VoidCallback onTap;

  const BrandCard({
    super.key,
    required this.brand,
    required this.logoUrl,
    required this.modelCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            if (logoUrl.isNotEmpty)
              Image.network(logoUrl, width: 40, height: 40)
            else
              const Icon(Icons.phone_android, size: 40),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text("$modelCount models"),
                ],
              ),
            ),

            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}