import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SellerBrandWallView extends StatelessWidget {
  final String sellerId;

  const SellerBrandWallView({
    super.key,
    required this.sellerId,
  });

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: sellerId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No products"));
        }

        // 🔥 seller ရဲ့ brand တွေတွက်
        final Map<String, int> brandCounts = {};

        for (final d in docs) {
          final brand =
          (d.data()['brand'] ?? '').toString().trim();

          if (brand.isEmpty) continue;

          brandCounts[brand] =
              (brandCounts[brand] ?? 0) + 1;
        }

        final brands = brandCounts.keys.toList()..sort();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: brands.length,
          itemBuilder: (context, i) {
            final brand = brands[i];

            return InkWell(
              onTap: () {
                context.push(
                  "/seller-models",
                  extra: {
                    "sellerId": sellerId,
                    "brand": brand,
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Center(
                  child: Text(
                    "$brand\n${brandCounts[brand]} models",
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}