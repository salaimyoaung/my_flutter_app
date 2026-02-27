import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';

class BrandWallView extends StatefulWidget {
  const BrandWallView({super.key});

  @override
  State<BrandWallView> createState() => _BrandWallViewState();
}

class _BrandWallViewState extends State<BrandWallView> {
  String _selectedType = "phones";

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('phone_models')
        .where('active', isEqualTo: true);

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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF7F8FC),
            Color(0xFFEDEFF5),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 5),
          _SegmentedControl(
            selected: _selectedType,
            onChanged: (v) => setState(() => _selectedType = v),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: query.snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text("No models"));
                    }

                    // Count brands from products
                    final Map<String, int> brandCounts = {};
                    for (final d in docs) {
                      final brand =
                      (d.data()['brand'] ?? '').toString().trim();
                      if (brand.isEmpty) continue;
                      brandCounts[brand] =
                          (brandCounts[brand] ?? 0) + 1;
                    }

                    final brands = brandCounts.keys.toList()..sort();

                    // 🔥 Listen brand collection for logos
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('phone_brands')
                          .snapshots(),
                      builder: (context, brandSnap) {
                        if (!brandSnap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final Map<String, String> brandLogos = {};

                        for (final b in brandSnap.data!.docs) {
                          final name = (b.data()['name'] ?? '')
                              .toString()
                              .trim()
                              .toLowerCase();

                          final logo =
                          (b.data()['logoUrl'] ?? '').toString();

                          if (name.isNotEmpty) {
                            brandLogos[name] = logo;
                          }
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 1,
                          ),
                          itemCount: brands.length,
                          itemBuilder: (context, i) {
                            final brand = brands[i];
                            final count = brandCounts[brand] ?? 0;

                            return _BrandCard(
                              brand: brand,
                              count: count,
                              logoUrl: brandLogos[
                              brand.toLowerCase()] ??
                                  "",
                              onTap: () {
                                context.push(
                                  AppRoutes.modelList,
                                  extra: {
                                    "brand": brand,
                                    "deviceType": _selectedType,
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////
// SEGMENT CONTROL
//////////////////////////////////////////////////////////

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: selected == "phones"
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width / 2 - 40,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
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

  Widget _item(BuildContext context, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selected == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? scheme.onSurface
                  : scheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////
// BRAND CARD (Firestore Logo Version)
//////////////////////////////////////////////////////////

class _BrandCard extends StatelessWidget {
  final String brand;
  final int count;
  final String logoUrl;
  final VoidCallback onTap;

  const _BrandCard({
    required this.brand,
    required this.count,
    required this.logoUrl,
    required this.onTap,
  });

  Widget _buildLogo(ColorScheme scheme) {
    if (logoUrl.isEmpty) {
      return Icon(Icons.phone_android,
          size: 40, color: scheme.primary);
    }

    if (logoUrl.toLowerCase().endsWith(".svg")) {
      return SvgPicture.network(
        logoUrl,
        height: 48,
        key: ValueKey(logoUrl),
      );
    }

    return Image.network(
      logoUrl,
      height: 48,
      fit: BoxFit.contain,
      key: ValueKey(logoUrl),
      errorBuilder: (_, __, ___) => Icon(
        Icons.phone_android,
        size: 40,
        color: scheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(scheme),
            const SizedBox(height: 10),
          Text(
            brand,
            style: Theme.of(context).textTheme.titleMedium,
          ),
            const SizedBox(height: 4),
        Text(
          "$count models",
          style: Theme.of(context).textTheme.bodySmall,
        ),
          ],
        ),
      ),
    );
  }
}