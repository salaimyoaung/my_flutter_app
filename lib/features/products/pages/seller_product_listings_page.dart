import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../widgets/product_card.dart';

class SellerProductListingsPage extends StatelessWidget {
  final String sellerId;
  final String brand;
  final String model;

  const SellerProductListingsPage({
    super.key,
    required this.sellerId,
    required this.brand,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
    FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .where('brand', isEqualTo: brand);

    if (model != "All") {
      query = query.where('model', isEqualTo: model);
    }

    return Scaffold(
      appBar: AppBar(title: Text("$brand - $model")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("ပစ္စည်းမရှိသေးပါ"),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return ProductCard(
                productId: doc.id,
                data: doc.data(),
              );
            },
          );
        },
      ),
    );
  }
}