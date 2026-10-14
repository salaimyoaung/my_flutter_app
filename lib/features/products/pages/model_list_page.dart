import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class ModelListPage extends StatefulWidget {
  final String brand;
  final String deviceType;
  final String? sellerId;
  /// Optional — pre-selects a series filter pill on open
  final String? initialSeries;

  const ModelListPage({
    super.key,
    required this.brand,
    required this.deviceType,
    this.sellerId,
    this.initialSeries,
  });

  @override
  State<ModelListPage> createState() => _ModelListPageState();
}

class _ModelListPageState extends State<ModelListPage> {
  late String _selectedSeries;

  @override
  void initState() {
    super.initState();
    // Pre-select series if passed (e.g. from BrandCollectionPage)
    _selectedSeries = widget.initialSeries?.trim().isNotEmpty == true
        ? widget.initialSeries!.trim().toLowerCase()
        : 'All';
  }

  // ✅ Correct deviceType values — matches AddProductPage constants
  // Phone types: android_phone, iphone
  // Tablet types: android_tablet, ipad
  static const _phoneTypes = ['android_phone', 'iphone'];
  static const _tabletTypes = ['android_tablet', 'ipad'];

  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('products')
        .where('brand', isEqualTo: widget.brand)
        .where('active', isEqualTo: true);

    if (widget.sellerId != null) {
      query = query.where('sellerId', isEqualTo: widget.sellerId);
    }

    // ✅ Handle both keyword ("phones"/"tablets") and actual deviceType values
    // BrandCollectionPage passes "phones"/"tablets" as keyword
    // SeriesListPage may pass actual values like "android_phone"
    if (widget.deviceType == 'phones' ||
        _phoneTypes.contains(widget.deviceType)) {
      query = query.where('deviceType', whereIn: _phoneTypes);
    } else if (widget.deviceType == 'tablets' ||
        _tabletTypes.contains(widget.deviceType)) {
      query = query.where('deviceType', whereIn: _tabletTypes);
    } else {
      // Specific deviceType passed — filter exactly
      query = query.where('deviceType', isEqualTo: widget.deviceType);
    }

    return query;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ print() removed — was logging sellerId: null on every build
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: BrandAppBar(
        title: widget.initialSeries?.trim().isNotEmpty == true
            ? widget.initialSeries!
            : widget.brand,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _baseQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // ── Build unique model map ─────────────────────────────────
          final Map<String, Map<String, dynamic>> uniqueModels = {};
          final Map<String, int> seriesCount = {};
          final Map<String, int> productCount = {};

          for (final d in docs) {
            final data = d.data();
            final rawModel = (data['model'] ?? '').toString().trim();
            final seriesRaw = (data['series'] ?? '').toString().trim();
            final series = seriesRaw.toLowerCase();

            if (rawModel.isEmpty) continue;

            final key = rawModel.toLowerCase();

            // Count products per model
            productCount[key] = (productCount[key] ?? 0) + 1;

            if (!uniqueModels.containsKey(key)) {
              uniqueModels[key] = {
                'model': rawModel,
                'series': series,
              };
            } else {
              // Fill in missing series if we find one later
              if (uniqueModels[key]!['series'].toString().isEmpty &&
                  series.isNotEmpty) {
                uniqueModels[key]!['series'] = series;
              }
            }
          }

          // Count models per series
          for (final m in uniqueModels.values) {
            final s = (m['series'] ?? '').toString();
            if (s.isNotEmpty) {
              seriesCount[s] = (seriesCount[s] ?? 0) + 1;
            }
          }

          final sortedSeries = seriesCount.keys.toList()..sort();
          final seriesList =
          seriesCount.isEmpty ? <String>[] : ['All', ...sortedSeries];

          // ── Filter + sort model list ───────────────────────────────
          List<Map<String, dynamic>> modelList = uniqueModels.values.toList();

          if (_selectedSeries != 'All') {
            modelList = modelList
                .where((m) => m['series'] == _selectedSeries)
                .toList();
          }

          modelList.sort((a, b) =>
              (a['model'] as String)
                  .toLowerCase()
                  .compareTo((b['model'] as String).toLowerCase()));

          if (modelList.isEmpty) {
            return const Center(child: Text('Model မရှိသေးပါ'));
          }

          return MaxWidthBox(
            child: Column(
            children: [
              // ── Series Filter Pills ──────────────────────────────
              if (seriesList.length > 1 && widget.initialSeries == null)
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: seriesList.length,
                    itemBuilder: (context, index) {
                      final series = seriesList[index];
                      final isSelected = _selectedSeries == series;
                      final count = series == 'All'
                          ? uniqueModels.length
                          : (seriesCount[series] ?? 0);

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedSeries = series),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  series,
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? scheme.onPrimary
                                        : scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? scheme.onPrimary
                                        .withValues(alpha: 0.25)
                                        : scheme.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? scheme.onPrimary
                                          : scheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ── Model List ───────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: modelList.length,
                  // ✅ __ not _ — Dart 3 fix
                  separatorBuilder: (_, _) =>
                      Divider(color: scheme.outlineVariant),
                  itemBuilder: (context, index) {
                    final modelName =
                    (modelList[index]['model'] as String).trim();

                    final count = productCount[modelName.toLowerCase()] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        modelName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$count model${count == 1 ? '' : 's'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.push(
                          AppRoutes.modelListings,
                          extra: {
                            'brand': widget.brand,
                            'model': modelName,
                            'sellerId': widget.sellerId,
                          },
                        );
                      },
                    );
                  },
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