import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class SeriesListPage extends StatelessWidget {
  final String brand;
  final String deviceType;
  final String? sellerId;

  const SeriesListPage({
    super.key,
    required this.brand,
    required this.deviceType,
    this.sellerId,
  });

  @override
  Widget build(BuildContext context) {

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('products')
        .where('brand', isEqualTo: brand)
        .where('active', isEqualTo: true);

    if (sellerId != null) {
      query = query.where('sellerId', isEqualTo: sellerId);
    }

    if (deviceType == "phones") {
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

    return Scaffold(
      appBar: BrandAppBar(title: brand),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final Map<String,int> seriesCount = {};

          for (final d in docs) {
            final data = d.data();
            final series = (data['series'] ?? "").toString().trim();

            if (series.isEmpty) continue;

            seriesCount[series] = (seriesCount[series] ?? 0) + 1;
          }

          final seriesList = seriesCount.keys.toList()..sort();

          if(seriesList.isEmpty){
            return const Center(child: Text("No series available"));
          }

          return MaxWidthBox(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: context.hPadding,
                vertical: 20,
              ),
              itemCount: seriesList.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final series = seriesList[index];
                final count = seriesCount[series] ?? 0;

                return ListTile(
                  title: Text(
                    series,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "$count ${count == 1 ? 'model' : 'models'}",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push(
                      AppRoutes.modelList,
                      extra: {
                        "brand": brand,
                        "initialSeries": series,
                        "deviceType": deviceType,
                        "sellerId": sellerId,
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}