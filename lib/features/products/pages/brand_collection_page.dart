import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';

class BrandCollectionPage extends StatelessWidget {
  final String brand;

  const BrandCollectionPage({
    super.key,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    final modelsRef = FirebaseFirestore.instance
        .collection('phone_models')
        .where('brand', isEqualTo: brand)
        .where('active', isEqualTo: true)
        .orderBy('order');

    return Scaffold(
      appBar: AppBar(title: Text(brand)),
      body: StreamBuilder<QuerySnapshot>(
        stream: modelsRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No models"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final modelName = data['name'];

              return ListTile(
                title: Text(modelName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push(
                    AppRoutes.modelList,
                    extra: {
                      "brand": brand,
                      "model": modelName,
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}