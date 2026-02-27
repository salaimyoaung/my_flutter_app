import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';

class ModelListPage extends StatefulWidget {
  final String brand;
  final String deviceType;

  const ModelListPage({
    super.key,
    required this.brand,
    required this.deviceType,
  });

  @override
  State<ModelListPage> createState() => _ModelListPageState();
}

class _ModelListPageState extends State<ModelListPage> {
  String _selectedSeries = "All";

  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('phone_models')
        .where('brand', isEqualTo: widget.brand)
        .where('active', isEqualTo: true);

    if (widget.deviceType == "phones") {
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

    return query;
  }

  Query<Map<String, dynamic>> _filteredQuery() {
    Query<Map<String, dynamic>> query = _baseQuery();

    if (_selectedSeries != "All") {
      query = query.where('series', isEqualTo: _selectedSeries);
    }

    return query.orderBy('model');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.brand),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _baseQuery().snapshots(),
        builder: (context, baseSnapshot) {
          if (!baseSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = baseSnapshot.data!.docs;

          /// 🔥 Extract dynamic series + count
          final Map<String, int> seriesCount = {};

          for (final d in allDocs) {
            final s = (d.data()['series'] ?? '').toString().trim();
            if (s.isEmpty) continue;

            seriesCount[s] = (seriesCount[s] ?? 0) + 1;
          }

          final sortedSeries = seriesCount.keys.toList()..sort();

          final seriesList = ["All", ...sortedSeries];

          return Column(
            children: [

              /// PREMIUM SEGMENTED PILLS
              if (seriesList.length > 1)
                Container(
                  height: 44,
                  alignment: Alignment.centerLeft,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: seriesList.length,
                    itemBuilder: (context, index) {
                      final series = seriesList[index];
                      final isSelected = _selectedSeries == series;

                      final count = series == "All"
                          ? allDocs.length
                          : (seriesCount[series] ?? 0);

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSeries = series;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  series,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),

                                /// Smaller Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.25)
                                        : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(context)
                                          .colorScheme
                                          .primary,
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
              /// MODEL LIST
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<
                        Map<String, dynamic>>>(
                  stream: _filteredQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child:
                          CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding:
                          const EdgeInsets.all(24),
                          child: Text(
                            "Something went wrong.\nPlease try again.",
                            textAlign:
                            TextAlign.center,
                            style: theme
                                .textTheme.bodyLarge,
                          ),
                        ),
                      );
                    }

                    final docs =
                        snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No models available",
                          style: theme
                              .textTheme.bodyLarge,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding:
                      const EdgeInsets.all(20),
                      itemCount: docs.length,
                      separatorBuilder:
                          (_, __) => Divider(
                        color: scheme.outlineVariant,
                      ),
                      itemBuilder:
                          (context, index) {
                        final data =
                        docs[index].data();
                        final modelName =
                        (data['model'] ?? '')
                            .toString()
                            .trim();

                        return ListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          title: Text(
                            modelName,
                            style: theme
                                .textTheme.titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                              Icons
                                  .chevron_right),
                          onTap: () {
                            context.push(
                              AppRoutes
                                  .modelListings,
                              extra: {
                                "brand":
                                widget.brand,
                                "model":
                                modelName,
                              },
                            );
                          },
                        );
                      },
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