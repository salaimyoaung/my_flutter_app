import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/models/product_model.dart';
import 'product_detail_page.dart';

class ProductDetailRoutePage extends StatelessWidget {
  final String productId;
  final Product? product;
  final String? sellerName;

  const ProductDetailRoutePage({
    super.key,
    required this.productId,
    this.product,
    this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedName = (sellerName ?? '').trim();
    if (product != null && resolvedName.isNotEmpty) {
      return ProductDetailPage(product: product!, sellerName: resolvedName);
    }

    final docFuture = FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .get();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: docFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData || snap.data == null || !snap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Product not found")),
          );
        }
        final data = snap.data!.data() ?? <String, dynamic>{};
        final p = product ?? Product.fromFirestore(snap.data!.id, data);
        final name = resolvedName.isNotEmpty
            ? resolvedName
            : (data['sellerName'] ?? '').toString().trim();
        return ProductDetailPage(product: p, sellerName: name);
      },
    );
  }
}
