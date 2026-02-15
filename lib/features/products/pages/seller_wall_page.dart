import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/product_model.dart';
import 'brand_collection_page.dart';

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

    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final isOwner = currentUid.isNotEmpty && currentUid == sellerId.trim();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          sellerName,
          style: AppTextStyles.heading(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        actions: [
          if (isOwner)
            IconButton(
              tooltip: "Orders",
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                context.push(AppRoutes.sellerOrders);
              },
            ),
          if (isOwner)
            IconButton(
              tooltip: "ပစ္စည်းအသစ်တင်မည်",
              icon: Icon(Icons.add_box_outlined, color: scheme.primary),
              onPressed: () {
                context.push(AppRoutes.addProduct);
              },
            ),
        ],
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
              SliverToBoxAdapter(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(sellerId)
                      .snapshots(),
                  builder: (context, userSnap) {
                    String profileImageUrl = '';
                    String coverImageUrl = '';
                    String displayName = sellerName;
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

              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    if (snap.hasError) {
                      return const SizedBox.shrink();
                    }

                    final allDocs = snap.data?.docs ?? const [];
                    if (allDocs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> byBrand = {};
                    for (final d in allDocs) {
                      final data = d.data();
                      final brand = (data['brand'] ?? '').toString().trim();
                      if (brand.isEmpty) continue;
                      byBrand.putIfAbsent(brand, () => []).add(d);
                    }

                    final brands = byBrand.keys.toList()
                      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                    if (brands.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    Future<Map<String, String>> loadBrandLogos(List<String> brandList) async {
                      final ids = brandList
                          .map((b) => b.trim().toLowerCase())
                          .where((b) => b.isNotEmpty)
                          .toList();
                      final Map<String, String> logos = {};
                      if (ids.isEmpty) return logos;
                      for (var i = 0; i < ids.length; i += 10) {
                        final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
                        final snap = await FirebaseFirestore.instance
                            .collection('brands')
                            .where(FieldPath.documentId, whereIn: chunk)
                            .get();
                        for (final doc in snap.docs) {
                          final data = doc.data();
                          final logoUrl = (data['logoUrl'] ?? '').toString().trim();
                          logos[doc.id] = logoUrl;
                        }
                      }
                      return logos;
                    }

                    final logosFuture = loadBrandLogos(brands);

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Browse by Brand",
                            style: AppTextStyles.heading(context),
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<Map<String, String>>(
                            future: logosFuture,
                            builder: (context, logoSnap) {
                              final logos = logoSnap.data ?? {};
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.1,
                                ),
                                itemCount: brands.length,
                                itemBuilder: (context, i) {
                                  final brand = brands[i];
                                  final brandDocs = byBrand[brand] ?? [];
                                  final Set<String> modelSet = {};
                                  for (final bd in brandDocs) {
                                    final data = bd.data();
                                    final model = (data['model'] ?? '').toString().trim();
                                    final name = (data['name'] ?? '').toString().trim();
                                    final key = model.isNotEmpty ? model : name;
                                    if (key.isNotEmpty) {
                                      modelSet.add(key);
                                    }
                                  }
                                  final count = modelSet.isNotEmpty
                                      ? modelSet.length
                                      : brandDocs.length;
                                  final brandId = brand.trim().toLowerCase();
                                  final logoUrl = logos[brandId] ?? '';
                                  print("BrandId: $brandId  LogoUrl: $logoUrl");
                                  return BrandCard(
                                    brand: brand,
                                    logoUrl: logoUrl,
                                    modelCount: count,
                                    onTap: () {
                                      final b = Uri.encodeComponent(brand);
                                      context.push(AppRoutes.brandCollectionPath(b));
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              if (docs.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("ရောင်းရန်ပစ္စည်း မရှိသေးပါ")),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(10),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final product = Product.fromFirestore(doc.id, data);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              context.push(
                                AppRoutes.productPath(product.id),
                                extra: {
                                  'product': product,
                                  'sellerName':
                                      displaySellerNameFromData(data, sellerName),
                                },
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(10),
                                      ),
                                      child: product.image.trim().isNotEmpty
                                          ? Image.network(
                                              product.image,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              loadingBuilder: (context, child, progress) {
                                                if (progress == null) return child;
                                                return Container(
                                                  color: scheme.surfaceVariant,
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (_, __, ___) => Container(
                                                color: scheme.surfaceVariant,
                                                child: const Center(
                                                  child: Icon(Icons.broken_image),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: scheme.surfaceVariant,
                                              child: const Center(child: Icon(Icons.image)),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.main(context)
                                              .copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                          Text(product.price, style: AppTextStyles.price()),
                                          const SizedBox(height: 4),
                                          Builder(builder: (context) {
                                            final cond = product.condition.trim();
                                            final b = product.batteryPercent;
                                            final hasSpecs = cond.isNotEmpty && b != null;
                                            final text = hasSpecs
                                                ? "$cond • Battery ${b}%"
                                                : "Not specified";
                                            return Text(
                                              text,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.small(context)
                                                  .copyWith(color: scheme.onSurfaceVariant),
                                            );
                                          }),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                            height: 30,
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                context.push(
                                                  AppRoutes.editProductPath(product.id),
                                                );
                                              },
                                              icon: const Icon(Icons.edit, size: 16),
                                              label: const Text("Edit"),
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: docs.length,
                    ),
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
