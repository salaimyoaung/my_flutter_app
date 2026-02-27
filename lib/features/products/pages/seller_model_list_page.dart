import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SellerModelListPage extends StatefulWidget {
  final String sellerId;
  final String brand;

  const SellerModelListPage({
    super.key,
    required this.sellerId,
    required this.brand,
  });

  @override
  State<SellerModelListPage> createState() =>
      _SellerModelListPageState();
}

class _SellerModelListPageState
    extends State<SellerModelListPage> {
  String selectedModel = "All";

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: widget.sellerId)
        .where('brand', isEqualTo: widget.brand);

    return Scaffold(
      appBar: AppBar(title: Text(widget.brand)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          final Map<String, int> modelCounts = {};

          for (final d in docs) {
            final model =
            (d.data()['model'] ?? '').toString().trim();
            if (model.isEmpty) continue;

            modelCounts[model] =
                (modelCounts[model] ?? 0) + 1;
          }

          final models = modelCounts.keys.toList()..sort();

          return Column(
            children: [
              const SizedBox(height: 12),

              // 🔥 FILTER CHIPS
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip("All", docs.length),

                    for (final m in models)
                      _chip(m, modelCounts[m]!),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 🔥 MODEL LIST
              Expanded(
                child: ListView.builder(
                  itemCount: selectedModel == "All"
                      ? models.length
                      : 1,
                  itemBuilder: (context, i) {
                    final model = selectedModel == "All"
                        ? models[i]
                        : selectedModel;

                    return ListTile(
                      title: Text(model),
                      trailing:
                      const Icon(Icons.chevron_right),
                      onTap: () {
                        context.push(
                          "/seller-products",
                          extra: {
                            "sellerId": widget.sellerId,
                            "brand": widget.brand,
                            "model": model,
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

  Widget _chip(String label, int count) {
    final isSelected = selectedModel == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text("$label ($count)"),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            selectedModel = label;
          });
        },
      ),
    );
  }
}