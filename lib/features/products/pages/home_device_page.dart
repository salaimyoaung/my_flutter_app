import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';

class HomeDevicePage extends StatelessWidget {
  const HomeDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Devices")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _deviceTile(
            context,
            title: "Phones",
            deviceType: "phone",
          ),
          const SizedBox(height: 20),
          _deviceTile(
            context,
            title: "Tablets",
            deviceType: "tablet",
          ),
        ],
      ),
    );
  }

  Widget _deviceTile(BuildContext context,
      {required String title, required String deviceType}) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        context.push(
          AppRoutes.brandCollection,
          extra: {"deviceType": deviceType},
        );
      },
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}