import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app_features.dart';
import '../../../app_styles.dart';
import '../../../data/repositories/brand_repository.dart';
import '../../../data/models/product_model.dart';
import '../../../core/router/app_routes.dart';

enum BrandSortOption {
  newest,
  priceLowHigh,
  priceHighLow,
}

class BrandCollectionPage extends StatefulWidget {
  final String brand;

  const BrandCollectionPage({
    super.key,
    required this.brand,
  });

  @override
  State<BrandCollectionPage> createState() => _BrandCollectionPageState();
}

class _BrandCollectionPageState extends State<BrandCollectionPage> {
  BrandSortOption _sort = BrandSortOption.newest;
  bool _visible = false;
  late final Future<Map<String, dynamic>?> _brandFuture;

  @override
  void initState() {
    super.initState();
    _brandFuture = BrandRepository().getBrandByName(widget.brand);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  double _priceValue(String input) {
    final match = RegExp(r'[\d.]+').firstMatch(input);
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  Query<Map<String, dynamic>> _queryForSort() {
    return FirebaseFirestore.instance
        .collection('products')
        .where('brand', isEqualTo: widget.brand)
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: "Filter",
            icon: const Icon(Icons.tune),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _queryForSort().snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }

          final docs = snap.data?.docs ?? const [];
          final items = docs.toList();

          if (_sort != BrandSortOption.newest) {
            items.sort((a, b) {
              final pa = _priceValue((a.data()['price'] ?? '').toString());
              final pb = _priceValue((b.data()['price'] ?? '').toString());
              return _sort == BrandSortOption.priceLowHigh
                  ? pa.compareTo(pb)
                  : pb.compareTo(pa);
            });
          }

          final resultsCount = items.length;
          final sortLabel = _sort == BrandSortOption.newest
              ? "Newest"
              : _sort == BrandSortOption.priceLowHigh
                  ? "Price low-high"
                  : "Price high-low";

          return AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
                    child: Row(
                      children: [
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _brandFuture,
                          builder: (context, brandSnap) {
                            final data = brandSnap.data;
                            final logoUrl = (data?['logoUrl'] ?? '').toString().trim();
                            return Hero(
                              tag: "brand-${widget.brand}",
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: logoUrl.isNotEmpty
                                      ? Image.network(
                                          logoUrl,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (context, child, progress) {
                                            if (progress == null) return child;
                                            return const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            );
                                          },
                                          errorBuilder: (_, __, ___) => Text(
                                            widget.brand.substring(0, 1),
                                            style: AppTextStyles.main(context).copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 22,
                                              letterSpacing: 1.2,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          widget.brand.substring(0, 1),
                                          style: AppTextStyles.main(context).copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 22,
                                            letterSpacing: 1.2,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.brand,
                                style: AppTextStyles.heading(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "$resultsCount models",
                                style: AppTextStyles.small(context).copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<BrandSortOption>(
                          onSelected: (v) => setState(() => _sort = v),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: BrandSortOption.newest,
                              child: Text("Newest"),
                            ),
                            PopupMenuItem(
                              value: BrandSortOption.priceLowHigh,
                              child: Text("Price low-high"),
                            ),
                            PopupMenuItem(
                              value: BrandSortOption.priceHighLow,
                              child: Text("Price high-low"),
                            ),
                          ],
                          child: Text(
                            "Sort",
                            style: AppTextStyles.small(context).copyWith(
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 64,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "No models yet",
                              style: AppTextStyles.main(context).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 20,
                        childAspectRatio: 0.52,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final doc = items[i];
                          final data = doc.data();
                          final product = Product.fromFirestore(doc.id, data);
                          final model = (data['model'] ?? '').toString().trim();
                          final title = model.isNotEmpty ? model : product.name;
                          final sellerName = (data['sellerName'] ?? '').toString().trim();
                          return _BrandProductCard(
                            product: product,
                            title: title,
                            sellerName: sellerName,
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BrandCard extends StatefulWidget {
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
  State<BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<BrandCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = widget.brand.isNotEmpty ? widget.brand.substring(0, 1) : "";
    final logoUrl = widget.logoUrl.trim();
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outline.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Hero(
                  tag: "brand-${widget.brand}",
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: logoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                logoUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Text(
                                  initial,
                                  style: AppTextStyles.main(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    letterSpacing: 1.0,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              initial,
                              style: AppTextStyles.main(context).copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                letterSpacing: 1.0,
                                color: scheme.onSurface,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.main(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.modelCount} models",
                  style: AppTextStyles.small(context).copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandProductCard extends StatefulWidget {
  final Product product;
  final String title;
  final String sellerName;

  const _BrandProductCard({
    required this.product,
    required this.title,
    required this.sellerName,
  });

  @override
  State<_BrandProductCard> createState() => _BrandProductCardState();
}

class _BrandProductCardState extends State<_BrandProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          context.push(
            AppRoutes.productPath(widget.product.id),
            extra: {
              'product': widget.product,
              'sellerName': widget.sellerName,
            },
          );
        },
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: widget.product.image.trim().isNotEmpty
                        ? Image.network(
                            widget.product.image,
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
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: scheme.surfaceVariant,
                              child: const Center(child: Icon(Icons.broken_image)),
                            ),
                          )
                        : Container(
                            color: scheme.surfaceVariant,
                            child: const Center(child: Icon(Icons.image)),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.main(context).copyWith(
                          fontWeight: FontWeight.w400,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (AppFeatures.productBadgesEnabled &&
                          widget.product.hasEffectiveBadge) ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (widget.product.effectiveBadgeRecommended)
                              _badgePill(
                                context,
                                scheme,
                                label: "Recommended",
                              ),
                            if (widget.product.effectiveBadgeTrusted)
                              _badgePill(
                                context,
                                scheme,
                                label: "Trusted",
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        widget.product.price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.price().copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgePill(
    BuildContext context,
    ColorScheme scheme, {
    required String label,
  }) {
    return Text(
      label,
      style: AppTextStyles.small(context).copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
