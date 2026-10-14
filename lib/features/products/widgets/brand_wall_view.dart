import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';

class BrandWallView extends StatefulWidget {
  final String? sellerId;
  final String searchQuery;
  final double? minPrice;
  final double? maxPrice;
  final bool shrinkWrap;

  const BrandWallView({
    super.key,
    this.sellerId,
    this.searchQuery = "",
    this.minPrice,
    this.maxPrice,
    this.shrinkWrap = false,
  });

  @override
  State<BrandWallView> createState() => _BrandWallViewState();
}

class _BrandWallViewState extends State<BrandWallView> {
  String _selectedType = "phones";
  late Stream<QuerySnapshot<Map<String, dynamic>>> _brandsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _brandsStream = FirebaseFirestore.instance
        .collection('phone_brands')
        .snapshots();
    _initProductsStream();
  }

  void _initProductsStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('products')
        .where('active', isEqualTo: true);

    if (widget.sellerId != null) {
      query = query.where('sellerId', isEqualTo: widget.sellerId);
    }

    if (_selectedType == "phones") {
      query = query.where(
        'deviceType',
        whereIn: ["android_phone", "iphone"],
      );
    } else {
      query = query.where(
        'deviceType',
        whereIn: ["android_tablet", "ipad"],
      );
    }
    _productsStream = query.snapshots();
  }

  @override
  void didUpdateWidget(BrandWallView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sellerId != widget.sellerId) {
      setState(() {
        _initProductsStream();
      });
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getProcessedData(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final q = widget.searchQuery.toLowerCase().trim();
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = [];

    for (final d in docs) {
      final data = d.data();
      final model = (data['model'] ?? "").toString().toLowerCase();
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;

      // Filter by Search Query
      if (q.isNotEmpty && !model.contains(q)) continue;

      // Filter by Price Range
      if (widget.minPrice != null && price < widget.minPrice!) continue;
      if (widget.maxPrice != null && price > widget.maxPrice!) continue;

      filtered.add(d);
    }

    // Sort by price if price filter is active (Low to High)
    if (widget.minPrice != null || widget.maxPrice != null) {
      filtered.sort((a, b) {
        final pA = (a.data()['price'] as num?)?.toDouble() ?? 0.0;
        final pB = (b.data()['price'] as num?)?.toDouble() ?? 0.0;
        return pA.compareTo(pB);
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productsStream,
        builder: (context, productSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _brandsStream,
            builder: (context, brandSnap) {
              if (widget.shrinkWrap) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 5),
                    _SegmentedControl(
                      selected: _selectedType,
                      onChanged: (v) {
                        if (_selectedType != v) {
                          setState(() {
                            _selectedType = v;
                            _initProductsStream();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    ..._buildPlainContent(context, productSnap, brandSnap),
                  ],
                );
              }

              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 5)),
                  SliverToBoxAdapter(
                    child: _SegmentedControl(
                      selected: _selectedType,
                      onChanged: (v) {
                        if (_selectedType != v) {
                          setState(() {
                            _selectedType = v;
                            _initProductsStream();
                          });
                        }
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  ..._buildSliverContent(context, productSnap, brandSnap),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildPlainContent(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> productSnap,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> brandSnap,
  ) {
    if (productSnap.hasError || brandSnap.hasError) {
      return [Center(child: Text('Error: ${productSnap.error ?? brandSnap.error}'))];
    }
    if (!productSnap.hasData || !brandSnap.hasData) {
      return [const Center(child: CircularProgressIndicator())];
    }

    final docs = productSnap.data!.docs;
    if (docs.isEmpty) return [const Center(child: Text("No models"))];

    final processedDocs = _getProcessedData(docs);
    if (processedDocs.isEmpty) return [const Center(child: Text("No result"))];

    final scheme = Theme.of(context).colorScheme;

    // ── LISTING VIEW (When Price Filter is active) ──────────────────────────
    if (widget.minPrice != null || widget.maxPrice != null) {
      return [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: processedDocs.length,
          itemBuilder: (context, index) {
            final doc = processedDocs[index];
            final data = doc.data();
            final isExpanded = _expanded.contains(doc.id);
            return _ListingRow(
              rank: index + 1,
              doc: doc,
              data: data,
              isExpanded: isExpanded,
              onTap: () => setState(() {
                if (isExpanded) {
                  _expanded.remove(doc.id);
                } else {
                  _expanded.add(doc.id);
                }
              }),
              onNavigate: () {
                final p = Product.fromFirestore(doc.id, data);
                context.push(AppRoutes.productPath(doc.id), extra: {'product': p, 'sellerName': p.sellerName});
              },
              scheme: scheme,
              textTheme: Theme.of(context).textTheme,
            );
          },
        )
      ];
    }

    // ── SEARCH VIEW ──────────────────────────────────────────────────────────
    if (widget.searchQuery.trim().isNotEmpty) {
      final Map<String, Map<String, dynamic>> uniqueModels = {};
      for (final d in processedDocs) {
        final data = d.data();
        final brand = (data['brand'] ?? "").toString().trim();
        final modelName = (data['model'] ?? "").toString().trim();
        final key = "${brand}_$modelName".toLowerCase();
        if (!uniqueModels.containsKey(key)) {
          uniqueModels[key] = {"model": modelName, "brand": brand};
        }
      }
      final results = uniqueModels.values.toList();
      return [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            return ListTile(
              leading: const Icon(Icons.search),
              title: Text(item['model'].toString()),
              subtitle: Text(item['brand'].toString()),
              onTap: () => context.push(AppRoutes.modelListings, extra: {'brand': item['brand'], 'model': item['model'], 'sellerId': widget.sellerId}),
            );
          },
        )
      ];
    }

    // ── GRID VIEW ────────────────────────────────────────────────────────────
    final Map<String, int> brandCounts = {};
    for (final d in processedDocs) {
      final brand = (d.data()['brand'] ?? "").toString().trim();
      if (brand.isNotEmpty) {
        brandCounts[brand] = (brandCounts[brand] ?? 0) + 1;
      }
    }

    final Map<String, String> brandLogos = {};
    for (final b in brandSnap.data!.docs) {
      final name = (b.data()['name'] ?? "").toString().trim().toLowerCase();
      final logo = (b.data()['logoUrl'] ?? "").toString();
      if (name.isNotEmpty) brandLogos[name] = logo;
    }

    final brands = brandCounts.keys.toList()..sort();
    final cols = context.brandGridColumns;
    return [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: context.hPadding, vertical: 8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: brands.length,
          itemBuilder: (context, i) {
            final brand = brands[i];
            return _BrandCard(
              brand: brand,
              count: brandCounts[brand] ?? 0,
              logoUrl: brandLogos[brand.toLowerCase()] ?? "",
              colorIndex: i,
              onTap: () => context.push(AppRoutes.seriesList, extra: {"brand": brand, "deviceType": _selectedType, "sellerId": widget.sellerId}),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildSliverContent(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> productSnap,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> brandSnap,
  ) {
    if (productSnap.hasError || brandSnap.hasError) {
      return [
        SliverToBoxAdapter(
          child: Center(
              child: Text('Error: ${productSnap.error ?? brandSnap.error}')),
        )
      ];
    }
    if (!productSnap.hasData || !brandSnap.hasData) {
      return [
        const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()),
        )
      ];
    }

    final docs = productSnap.data!.docs;
    if (docs.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Center(child: Text("No models")),
        )
      ];
    }

    final processedDocs = _getProcessedData(docs);
    if (processedDocs.isEmpty) {
      return [const SliverToBoxAdapter(child: Center(child: Text("No result")))];
    }

    final scheme = Theme.of(context).colorScheme;

    // ── LISTING VIEW (When Price Filter is active) ──────────────────────────
    if (widget.minPrice != null || widget.maxPrice != null) {
      final textTheme = Theme.of(context).textTheme;
      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = processedDocs[index];
              final data = doc.data();
              final isExpanded = _expanded.contains(doc.id);
              return _ListingRow(
                rank: index + 1,
                doc: doc,
                data: data,
                isExpanded: isExpanded,
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expanded.remove(doc.id);
                  } else {
                    _expanded.add(doc.id);
                  }
                }),
                onNavigate: () {
                  final p = Product.fromFirestore(doc.id, data);
                  context.push(
                    AppRoutes.productPath(doc.id),
                    extra: {
                      'product': p,
                      'sellerName': p.sellerName,
                      'sellerId': p.sellerId, // Pass sellerId for owner check
                    },
                  );
                },
                scheme: scheme,
                textTheme: textTheme,
              );
            },
            childCount: processedDocs.length,
          ),
        ),
      ];
    }

    // ── SEARCH VIEW ──────────────────────────────────────────────────────────
    if (widget.searchQuery.trim().isNotEmpty) {
      final Map<String, Map<String, dynamic>> uniqueModels = {};
      for (final d in processedDocs) {
        final data = d.data();
        final brand = (data['brand'] ?? "").toString().trim();
        final modelName = (data['model'] ?? "").toString().trim();
        final key = "${brand}_$modelName".toLowerCase();
        if (!uniqueModels.containsKey(key)) {
          uniqueModels[key] = {
            "model": modelName,
            "brand": brand,
          };
        }
      }
      final results = uniqueModels.values.toList();
      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = results[index];
              return ListTile(
                leading: const Icon(Icons.search),
                title: Text(item['model'].toString()),
                subtitle: Text(item['brand'].toString()),
                onTap: () {
                  context.push(
                    AppRoutes.modelListings,
                    extra: {
                      'brand': item['brand'],
                      'model': item['model'],
                      'sellerId': widget.sellerId,
                    },
                  );
                },
              );
            },
            childCount: results.length,
          ),
        ),
      ];
    }

    // ── GRID VIEW ────────────────────────────────────────────────────────────
    final Map<String, int> brandCounts = {};
    for (final d in processedDocs) {
      final brand = (d.data()['brand'] ?? "").toString().trim();
      if (brand.isNotEmpty) {
        brandCounts[brand] = (brandCounts[brand] ?? 0) + 1;
      }
    }

    final Map<String, String> brandLogos = {};
    for (final b in brandSnap.data!.docs) {
      final name = (b.data()['name'] ?? "").toString().trim().toLowerCase();
      final logo = (b.data()['logoUrl'] ?? "").toString();
      if (name.isNotEmpty) brandLogos[name] = logo;
    }

    final brands = brandCounts.keys.toList()..sort();
    final cols = context.brandGridColumns;
    final hPad = context.hPadding;

    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final brand = brands[i];
              return _BrandCard(
                brand: brand,
                count: brandCounts[brand] ?? 0,
                logoUrl: brandLogos[brand.toLowerCase()] ?? "",
                colorIndex: i,
                onTap: () {
                  context.push(
                    AppRoutes.seriesList,
                    extra: {
                      "brand": brand,
                      "deviceType": _selectedType,
                      "sellerId": widget.sellerId,
                    },
                  );
                },
              );
            },
            childCount: brands.length,
          ),
        ),
      ),
    ];
  }
}

class _SegmentedControl extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _SegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPhones = selected == "phones";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Selection Indicator
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: isPhones ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Labels
            Row(
              children: [
                _item(context, "phones", "Phones"),
                _item(context, "tablets", "Tablets"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String value,
    String label,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selected == value;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: Container(
          alignment: Alignment.center,
          // Ensuring vertical centering
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.1, // Adjusted for Noto Sans Myanmar / Google Fonts baseline
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final String brand;
  final int count;
  final String logoUrl;
  final VoidCallback onTap;
  final int colorIndex;

  const _BrandCard({
    required this.brand,
    required this.count,
    required this.logoUrl,
    required this.onTap,
    this.colorIndex = 0,
  });

  static const _bookColors = [Color(0xFF2D2F39)];

  @override
  Widget build(BuildContext context) {
    final bookColor = _bookColors[colorIndex % _bookColors.length];
    final highlightColor = Color.lerp(bookColor, Colors.white, 0.10)!;
    final shadowColor = Color.lerp(bookColor, Colors.black, 0.20)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // All sizes relative to cell — never overflow
        final spineW = (w * 0.09).clamp(5.0, 10.0);
        final logoH = (h * 0.38).clamp(28.0, 64.0);
        final iconSz = (logoH * 0.75).clamp(20.0, 48.0);
        final fontSize = (w * 0.115).clamp(9.0, 13.0);
        final subSize = (w * 0.095).clamp(8.0, 11.0);
        final gap = (h * 0.03).clamp(2.0, 8.0);
        final hPad = (w * 0.06).clamp(4.0, 10.0);

        Widget logoWidget;
        if (logoUrl.isEmpty) {
          logoWidget = Icon(Icons.phone_android, color: Colors.white54, size: iconSz);
        } else if (logoUrl.toLowerCase().endsWith('.svg')) {
          logoWidget = SvgPicture.network(
            logoUrl,
            height: logoH,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            placeholderBuilder: (_) => const SizedBox.shrink(),
          );
        } else {
          logoWidget = AppNetworkImage(
            logoUrl,
            height: logoH,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
          );
        }

        return GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              // book spine / shadow (right edge)
              Positioned(
                right: 0,
                top: 4,
                child: Container(
                  width: spineW,
                  height: h - 4,
                  decoration: BoxDecoration(
                    color: shadowColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              // main book body
              Positioned(
                left: 0,
                right: spineW - 2,
                top: 0,
                bottom: 4,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [highlightColor, bookColor, shadowColor],
                      stops: const [0.0, 0.15, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(-2, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // logo — constrained to logoH, never overflows
                      SizedBox(
                        height: logoH,
                        child: Center(child: logoWidget),
                      ),
                      SizedBox(height: gap),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: Text(
                          brand,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(height: gap * 0.6),
                      Text(
                        '$count ${count == 1 ? 'model' : 'models'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: subSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Listing Row (accordion) ───────────────────────────────────────────────

class _ListingRow extends StatelessWidget {
  final int rank;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic> data;
  final bool isExpanded;
  final VoidCallback onTap, onNavigate;
  final ColorScheme scheme;
  final TextTheme textTheme;

  const _ListingRow({
    required this.rank,
    required this.doc,
    required this.data,
    required this.isExpanded,
    required this.onTap,
    required this.onNavigate,
    required this.scheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final price = (data['price'] ?? '').toString();
    final imageUrl = (data['image'] ?? '').toString();
    final specs = data['specs'] as Map<String, dynamic>? ?? {};

    // Denormalized seller data
    final sellerName = data['sellerName'] ?? data['seller']?['name'] ?? '';
    final profileImage = data['sellerProfileImage'] ?? data['seller']?['profileImage'] ?? '';
    final isVerified = data['sellerIsVerified'] == true || data['seller']?['isVerified'] == true;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank == 1 ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: rank == 1 ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${data['model'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: doc.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Listing ID copied')),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(Icons.copy_rounded, size: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _SellerRowInline(
                        sellerName: sellerName,
                        profileImage: profileImage,
                        isVerified: isVerified,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(double.tryParse(price) ?? 0).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} MMK',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: scheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Container(
            color: scheme.surfaceContainerLowest,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Hero(
                        tag: 'product-${doc.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppNetworkImage(imageUrl, width: 90, height: 110, fit: BoxFit.contain),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (specs['warrantyDays'] != null) _specRow(_warranty(specs['warrantyDays']), scheme, textTheme),
                          if (specs['batteryPercent'] != null) _specRow('🔋 ${specs['batteryPercent']}%', scheme, textTheme, isGood: true),
                          if (data['imeiStatus'] == 'valid') _specRow('✅ IMEI Verified', scheme, textTheme, isGood: true),

                          // Additional specs
                          if ((specs['condition'] ?? data['condition'] ?? '').toString().isNotEmpty)
                            _specRow('Condition: ${specs['condition'] ?? data['condition']}', scheme, textTheme),
                          if (specs['ram'] != null || specs['storage'] != null)
                            _specRow('RAM/Storage: ${specs['ram'] ?? '-'}GB / ${specs['storage'] ?? '-'}GB', scheme, textTheme),
                          if ((specs['color'] ?? '').toString().isNotEmpty)
                            _specRow('Color: ${specs['color']}', scheme, textTheme),
                          if ((data['icloudStatus'] ?? '').toString().isNotEmpty)
                            _specRow('iCloud: ${data['icloudStatus']}', scheme, textTheme, isGood: data['icloudStatus'] == 'clean'),
                          if ((specs['modelNumber'] ?? '').toString().isNotEmpty)
                            _specRow('Model No: ${specs['modelNumber']}', scheme, textTheme),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onNavigate,
                    child: Text('View more details →', style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }

  String _warranty(dynamic days) {
    final d = int.tryParse(days.toString()) ?? 0;
    if (d == 0) return 'No warranty';
    if (d >= 30) return '${d ~/ 30}-Month Warranty';
    return '$d-Day Warranty';
  }

  Widget _specRow(String label, ColorScheme scheme, TextTheme textTheme, {bool isGood = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(
          color: isGood ? AppColors.success : scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SellerRowInline extends StatelessWidget {
  final String? sellerName;
  final String? profileImage;
  final bool isVerified;
  final ColorScheme scheme;
  final TextTheme textTheme;

  const _SellerRowInline({
    required this.sellerName,
    required this.profileImage,
    required this.isVerified,
    required this.scheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (sellerName == null || sellerName!.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundImage: (profileImage != null && profileImage!.isNotEmpty) ? NetworkImage(profileImage!) : null,
          child: (profileImage == null || profileImage!.isEmpty) ? const Icon(Icons.person, size: 10) : null,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(sellerName!, style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (isVerified) ...[
          const SizedBox(width: 3),
          const Icon(Icons.verified, color: Color(0xFF1DA1F2), size: 11),
        ],
      ],
    );
  }
}
