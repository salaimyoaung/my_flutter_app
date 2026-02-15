import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../app_features.dart';
import '../../../data/models/product_model.dart';
import '../../../core/router/app_routes.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  Future<bool> _confirmRemove(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text("Remove favorite?", style: AppTextStyles.heading(context)),
        content: Text(
          "ဒီ item ကို Favorites ကနေ ဖယ်ချင်တာ သေချာလား?",
          style: AppTextStyles.main(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return res ?? false;
  }

  Future<void> _removeFavorite(BuildContext context, String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login ဝင်ပြီးမှ Favorites ကို ပြင်နိုင်ပါတယ်")),
      );
      return;
    }

    final ok = await _confirmRemove(context);
    if (!ok) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(productId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Favorites ကနေ ဖယ်ပြီးပါပြီ")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Remove မရပါ: $e")),
        );
      }
    }
  }

  String _sellerNameFromProductData(Map<String, dynamic> data) {
    final s = (data['sellerName'] ?? '').toString().trim();
    return s.isEmpty ? "Seller" : s;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text("Favorites", style: AppTextStyles.heading(context)),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 0.5,
        ),
        body: const Center(child: Text("Favorites ကြည့်ရန် Login ဝင်ပါ")),
      );
    }

    final favStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Favorites", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: favStream,
        builder: (context, favSnap) {
          if (favSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (favSnap.hasError) {
            return Center(child: Text("Error: ${favSnap.error}"));
          }

          final favDocs = favSnap.data?.docs ?? [];
          if (favDocs.isEmpty) {
            return const Center(child: Text("Favorite မရှိသေးပါ"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: favDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final favDoc = favDocs[i];
              final productId = favDoc.id;

              // ✅ BEST: join products/{productId}
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .doc(productId)
                    .snapshots(),
                builder: (context, pSnap) {
                  if (pSnap.connectionState == ConnectionState.waiting) {
                    return _loadingTile(scheme);
                  }
                  if (pSnap.hasError) {
                    return _errorTile(
                      scheme,
                      "Product load error: ${pSnap.error}",
                      onRemove: () => _removeFavorite(context, productId),
                    );
                  }

                  // product deleted => orphan favorite
                  if (!pSnap.hasData || pSnap.data == null || !pSnap.data!.exists) {
                    return _errorTile(
                      scheme,
                      "Product မရှိတော့ပါ",
                      onRemove: () => _removeFavorite(context, productId),
                    );
                  }

                  final pdata = pSnap.data!.data()!;
                  final product = Product.fromFirestore(productId, pdata);

                  final sellerName = _sellerNameFromProductData(pdata);
                  final brand = (pdata['brand'] ?? '').toString().trim();
                  final model = (pdata['model'] ?? '').toString().trim();

                  return Material(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        context.push(
                          AppRoutes.productPath(product.id),
                          extra: {
                            'product': product,
                            'sellerName': sellerName,
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: product.image.trim().isNotEmpty
                                  ? Image.network(
                                      product.image,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 72,
                                        height: 72,
                                        color: scheme.surfaceVariant,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    )
                                  : Container(
                                      width: 72,
                                      height: 72,
                                      color: scheme.surfaceVariant,
                                      child: const Icon(Icons.image),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ⭐ Title = model if exists, else product.name
                                  Text(
                                    model.isNotEmpty ? model : product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.main(context).copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (AppFeatures.productBadgesEnabled &&
                                      product.hasEffectiveBadge) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _badgePills(product, scheme, context),
                                    ),
                                  ],
                                  if (brand.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      brand,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.small(context).copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(product.price, style: AppTextStyles.price()),
                                  const SizedBox(height: 4),
                                  Text(
                                    sellerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.small(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: "Remove",
                              onPressed: () => _removeFavorite(context, productId),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _loadingTile(ColorScheme scheme) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 80, child: LinearProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _badgePills(Product product, ColorScheme scheme, BuildContext context) {
    final out = <Widget>[];
    if (product.effectiveBadgeRecommended) {
      out.add(_badgePill(
        scheme,
        context: context,
        icon: Icons.check_circle,
        label: "Recommended",
        bg: scheme.primaryContainer,
        fg: scheme.onPrimaryContainer,
      ));
    }
    if (product.effectiveBadgeTrusted) {
      out.add(_badgePill(
        scheme,
        context: context,
        icon: Icons.verified_user,
        label: "Trusted Seller",
        bg: scheme.secondaryContainer,
        fg: scheme.onSecondaryContainer,
      ));
    }
    return out;
  }

  Widget _badgePill(
    ColorScheme scheme, {
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.small(context).copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorTile(
      ColorScheme scheme,
      String msg, {
        required VoidCallback onRemove,
      }) {
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.error_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: "Remove",
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}
