import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

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
      appBar: BrandAppBar(title: brand),
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

          // ── Deduplicate series ──────────────────────────────────────
          final Map<String, String> seriesDeviceType = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final series = (data['series'] ?? '').toString().trim();
            final dt = (data['deviceType'] ?? 'android_phone').toString();
            if (series.isNotEmpty && !seriesDeviceType.containsKey(series)) {
              seriesDeviceType[series] = dt;
            }
          }

          final seriesList = seriesDeviceType.keys.toList()..sort();

          if (seriesList.isEmpty) {
            return const Center(child: Text('No series available'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: seriesList.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final series = seriesList[i];
              final dt = seriesDeviceType[series] ?? 'android_phone';

              return ListTile(
                title: Text(
                  series,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push(
                    AppRoutes.modelList,
                    extra: {
                      'brand': brand,
                      'deviceType': dt,       // ✅ actual deviceType, not "phones"
                      'initialSeries': series, // ✅ pre-selects series filter
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