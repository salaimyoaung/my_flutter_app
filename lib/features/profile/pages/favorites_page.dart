import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_features.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../data/models/product_model.dart';
import '../../products/pages/widgets/product_price_section.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FavoritesPage — auth-aware entry point
// Wraps in StreamBuilder so IndexedStack sees uid updates on login/logout
// without needing hot restart.
// ─────────────────────────────────────────────────────────────────────────────
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final uid = snapshot.data?.uid;
        if (uid == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: const BrandAppBar(title: 'Favorites', leading: SizedBox.shrink()),
            body: const Center(child: Text('Favorites ကြည့်ရန် Login ဝင်ပါ')),
          );
        }
        return _FavoritesBody(uid: uid);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FavoritesBody — actual UI; receives a guaranteed non-null uid
// ─────────────────────────────────────────────────────────────────────────────
class _FavoritesBody extends StatelessWidget {
  final String uid;
  const _FavoritesBody({required this.uid});

  // ─── Confirm Remove Dialog ──────────────────────────────────────────────

  Future<bool> _confirmRemove(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('Remove favorite?', style: textTheme.titleLarge),
        content: Text(
          'ဒီ item ကို Favorites ကနေ ဖယ်ချင်တာ သေချာလား?',
          style: textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Remove',
              style: textTheme.labelLarge?.copyWith(color: scheme.error),
            ),
          ),
        ],
      ),
    );

    return res ?? false;
  }

  // ─── Remove Favorite ────────────────────────────────────────────────────

  Future<void> _removeFavorite(BuildContext context, String productId) async {
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
          const SnackBar(content: Text('Favorites ကနေ ဖယ်ပြီးပါပြီ')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remove မရပါ: $e')),
        );
      }
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final favStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const BrandAppBar(title: 'Favorites', leading: SizedBox.shrink()),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: favStream,
        builder: (context, favSnap) {
          if (favSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (favSnap.hasError) {
            return Center(child: Text('Error: ${favSnap.error}'));
          }

          final favDocs = favSnap.data?.docs ?? [];
          if (favDocs.isEmpty) {
            return const Center(child: Text('Favorite မရှိသေးပါ'));
          }

          return MaxWidthBox(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: context.hPadding,
                vertical: 12,
              ),
              itemCount: favDocs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final favDoc = favDocs[i];
                final productId = favDoc.id;

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
                        'Product load error: ${pSnap.error}',
                        onRemove: () => _removeFavorite(context, productId),
                      );
                    }
                    if (!pSnap.hasData ||
                        pSnap.data == null ||
                        !pSnap.data!.exists) {
                      return _errorTile(
                        scheme,
                        'Product မရှိတော့ပါ',
                        onRemove: () => _removeFavorite(context, productId),
                      );
                    }

                    final pdata = pSnap.data!.data()!;
                    final product = Product.fromFirestore(productId, pdata);
                    final sellerName = product.sellerName.isNotEmpty
                        ? product.sellerName
                        : 'Seller';
                    final brand = product.brand;
                    final model = product.model;

                    return Material(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => context.push(
                          AppRoutes.productPath(product.id),
                          extra: {
                            'product': product,
                            'sellerName': sellerName,
                          },
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // ── Thumbnail ────────────────────────────
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: product.image.trim().isNotEmpty
                                    ? AppNetworkImage(
                                        product.image,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stack) =>
                                                Container(
                                          width: 72,
                                          height: 72,
                                          color:
                                              scheme.surfaceContainerHighest,
                                          child:
                                              const Icon(Icons.broken_image),
                                        ),
                                      )
                                    : Container(
                                        width: 72,
                                        height: 72,
                                        color: scheme.surfaceContainerHighest,
                                        child: const Icon(Icons.image),
                                      ),
                              ),
                              const SizedBox(width: 12),

                              // ── Info ─────────────────────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model.isNotEmpty ? model : product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),

                                    if (AppFeatures.productBadgesEnabled &&
                                        product.hasEffectiveBadge) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: _badgePills(
                                            product, scheme, context),
                                      ),
                                    ],

                                    if (brand.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        brand,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 4),
                                    Text(
                                      ProductPriceSection.formatPrice(
                                          product.priceDouble),
                                      style: textTheme.titleSmall?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),

                                    const SizedBox(height: 4),
                                    Text(
                                      sellerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),

                              // ── Remove Button ─────────────────────────
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: () =>
                                    _removeFavorite(context, productId),
                                icon: Icon(Icons.delete_outline,
                                    color: scheme.error),
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
          );
        },
      ),
    );
  }

  // ─── Helper Widgets ──────────────────────────────────────────────────────

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
              color: scheme.surfaceContainerHighest,
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
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.error_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline, color: scheme.error),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _badgePills(
    Product product,
    ColorScheme scheme,
    BuildContext context,
  ) {
    final out = <Widget>[];
    if (product.effectiveBadgeRecommended) {
      out.add(_badgePill(
        scheme,
        context: context,
        icon: Icons.check_circle,
        label: 'Recommended',
        bg: scheme.primaryContainer,
        fg: scheme.onPrimaryContainer,
      ));
    }
    if (product.effectiveBadgeTrusted) {
      out.add(_badgePill(
        scheme,
        context: context,
        icon: Icons.verified_user,
        label: 'Trusted Seller',
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
    final textTheme = Theme.of(context).textTheme;
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
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
