import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/product_model.dart';
import '../../../../widgets/product_card.dart';
import '../../providers/seller_products_provider.dart';

class SellerProducts extends ConsumerWidget {
  final String sellerId;

  const SellerProducts({
    super.key,
    required this.sellerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(sellerProductsProvider(sellerId));

    return productsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),

      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text("Error loading products")),
        ),
      ),

      data: (products) {
        if (products.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text("No products yet")),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final Product product = products[index];

                return ProductCard(
                  productId: product.id,
                  data: product.toMap(),
                );
              },
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }
}