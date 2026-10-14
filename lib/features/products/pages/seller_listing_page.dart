import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class SellerListingPage extends StatefulWidget {
  final String brand;
  final String model;

  const SellerListingPage({
    super.key,
    required this.brand,
    required this.model,
  });

  @override
  State<SellerListingPage> createState() => _SellerListingPageState();
}

class _SellerListingPageState extends State<SellerListingPage> {
  // ✅ Each listing keeps its own selectedVariantId (docId -> variantId)
  final Map<String, String?> _selectedVariantByDoc = {};

  // ✅ Filters
  final Set<String> _colors = {};
  final Set<String> _rams = {};
  final Set<String> _storages = {};
  final Set<String> _conditions = {}; // New / Second New / Second

  bool _matchesVariant(Map<String, dynamic> v) {
    final color = (v['color'] ?? '').toString();
    final ram = (v['ram'] ?? '').toString();
    final storage = (v['storage'] ?? '').toString();

    final okColor = _colors.isEmpty || _colors.contains(color);
    final okRam = _rams.isEmpty || _rams.contains(ram);
    final okStorage = _storages.isEmpty || _storages.contains(storage);

    return okColor && okRam && okStorage;
  }

  bool _matchesCondition(String condition) {
    return _conditions.isEmpty || _conditions.contains(condition);
  }

  int get _activeFilterCount =>
      _colors.length + _rams.length + _storages.length + _conditions.length;

  void _clearFilters() {
    setState(() {
      _colors.clear();
      _rams.clear();
      _storages.clear();
      _conditions.clear();
      _selectedVariantByDoc.clear();
    });
  }

  Future<void> _openFilters({
    required BuildContext context,
    required Set<String> allColors,
    required Set<String> allRams,
    required Set<String> allStorages,
    required Set<String> allConditions,
  }) async {
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final textTheme = Theme.of(context).textTheme;
            Widget sectionTitle(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Text(t, style: textTheme.labelLarge),
            );

            Widget chips(Set<String> all, Set<String> selected) {
              if (all.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    "No options",
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: all.map((x) {
                    final isOn = selected.contains(x);
                    return GestureDetector(
                      onTap: () {
                        setSheet(() {
                          if (isOn) {
                            selected.remove(x);
                          } else {
                            selected.add(x);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isOn ? scheme.primary : scheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isOn
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          x,
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isOn ? scheme.onPrimary : scheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 10, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Filters",
                                style: textTheme.titleMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setSheet(() {
                                  _colors.clear();
                                  _rams.clear();
                                  _storages.clear();
                                  _conditions.clear();
                                });
                              },
                              child: const Text("Clear"),
                            ),
                          ],
                        ),
                      ),

                      sectionTitle("Condition"),
                      chips(allConditions, _conditions),

                      sectionTitle("Color"),
                      chips(allColors, _colors),

                      sectionTitle("RAM"),
                      chips(allRams, _rams),

                      sectionTitle("Storage"),
                      chips(allStorages, _storages),

                      const SizedBox(height: 22),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                // ✅ if filters changed, reset selected variants
                                _selectedVariantByDoc.clear();
                              });
                            },
                            child: Text("Apply", style: textTheme.labelLarge),
                          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(title: widget.model),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('brand', isEqualTo: widget.brand)
            .where('model', isEqualTo: widget.model)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "No listings yet",
                style: textTheme.bodyMedium,
              ),
            );
          }

          // ✅ collect all filter options from data
          final allColors = <String>{};
          final allRams = <String>{};
          final allStorages = <String>{};
          final allConditions = <String>{};

          for (final doc in docs) {
            final d = doc.data();
            final condition = (d['condition'] ?? '').toString();
            if (condition.isNotEmpty) allConditions.add(condition);

            final variants = (d['variants'] ?? []) as List<dynamic>;
            for (final vv in variants) {
              final v = (vv as Map).cast<String, dynamic>();
              final c = (v['color'] ?? '').toString();
              final r = (v['ram'] ?? '').toString();
              final s = (v['storage'] ?? '').toString();
              if (c.isNotEmpty) allColors.add(c);
              if (r.isNotEmpty) allRams.add(r);
              if (s.isNotEmpty) allStorages.add(s);
            }
          }

          // ✅ apply filters (hide listings that don't match)
          final filteredDocs = docs.where((doc) {
            final d = doc.data();
            final condition = (d['condition'] ?? '').toString();
            if (!_matchesCondition(condition)) return false;

            final variants = (d['variants'] ?? []) as List<dynamic>;
            final hasVariant = variants.any((vv) {
              final v = (vv as Map).cast<String, dynamic>();
              return _matchesVariant(v);
            });

            return hasVariant;
          }).toList();

          return Column(
            children: [
              // ✅ Filter bar (premium / minimal)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune,
                              size: 18,
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _activeFilterCount == 0
                                  ? "Filters"
                                  : "Filters • $_activeFilterCount",
                              style: textTheme.labelLarge?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${filteredDocs.length} results",
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _openFilters(
                          context: context,
                          allColors: allColors,
                          allRams: allRams,
                          allStorages: allStorages,
                          allConditions: allConditions,
                        ),
                        child: const Text("Edit"),
                      ),
                    ),
                    if (_activeFilterCount > 0) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: _clearFilters,
                          child: const Text("Clear"),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();

                    final sellerName = (data['sellerName'] ?? '').toString();
                    final condition = (data['condition'] ?? '').toString();
                    final variantsRaw =
                        (data['variants'] ?? []) as List<dynamic>;

                    // filter variants
                    final variants = variantsRaw
                        .map((e) => (e as Map).cast<String, dynamic>())
                        .where(_matchesVariant)
                        .toList();

                    // ensure we have a selected variant for this doc
                    final currentSelectedId = _selectedVariantByDoc[doc.id];
                    Map<String, dynamic>? selectedVariant;

                    if (currentSelectedId != null) {
                      selectedVariant = variants.firstWhere(
                        (v) => (v['id'] ?? '').toString() == currentSelectedId,
                        orElse: () => {},
                      );
                      if (selectedVariant.isEmpty) {
                        selectedVariant = null;
                      }
                    }

                    // if not selected, default to first variant
                    selectedVariant ??= variants.isNotEmpty
                        ? variants.first
                        : null;

                    if (selectedVariant != null) {
                      _selectedVariantByDoc[doc.id] =
                          (selectedVariant['id'] ?? '').toString();
                    }

                    final selectedPrice = selectedVariant == null
                        ? null
                        : (selectedVariant['price'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // header
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sellerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  condition,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // variants
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: variants.map((v) {
                              final vid = (v['id'] ?? '').toString();
                              final label =
                                  "${v['color']} • ${v['ram']} • ${v['storage']}";
                              final isSelected =
                                  (_selectedVariantByDoc[doc.id] == vid);

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedVariantByDoc[doc.id] = vid;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.surface,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isSelected
                                          ? scheme.primary
                                          : scheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 18),

                          // price (selected)
                          if (selectedPrice == null)
                            Text(
                              "Select variant",
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Text(
                              "$selectedPrice MMK",
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
