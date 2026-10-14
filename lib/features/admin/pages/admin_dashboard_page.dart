import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/brand_app_bar.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const BrandAppBar(title: 'Admin Dashboard'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── KPI Section ──────────────────────────────────────────────────
            Text(
              'Key Performance Indicators (Last 24h)',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const _KpiGrid(),

            const SizedBox(height: 32),

            // ─── Admin Tools ──────────────────────────────────────────────────
            Text(
              'Admin Tools',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _AdminToolsGrid(scheme: scheme),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _KpiCard(
          label: 'Total Users',
          valueFuture: FirebaseFirestore.instance.collection('users').count().get().then((s) => s.count ?? 0),
          icon: Icons.people_alt_outlined,
          color: Colors.blue,
        ),
        _KpiCard(
          label: 'New Users',
          valueFuture: FirebaseFirestore.instance
              .collection('users')
              .where('createdAt', isGreaterThan: Timestamp.fromDate(last24h))
              .count()
              .get()
              .then((s) => s.count ?? 0),
          icon: Icons.person_add_alt_1_outlined,
          color: Colors.green,
        ),
        _KpiCard(
          label: 'Total Listings',
          valueFuture: FirebaseFirestore.instance.collection('products').count().get().then((s) => s.count ?? 0),
          icon: Icons.inventory_2_outlined,
          color: Colors.orange,
        ),
        _KpiCard(
          label: 'New Listings',
          valueFuture: FirebaseFirestore.instance
              .collection('products')
              .where('createdAt', isGreaterThan: Timestamp.fromDate(last24h))
              .count()
              .get()
              .then((s) => s.count ?? 0),
          icon: Icons.add_business_outlined,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final Future<int> valueFuture;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.valueFuture,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<int>(
      future: valueFuture,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminToolsGrid extends StatelessWidget {
  final ColorScheme scheme;
  const _AdminToolsGrid({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ToolItem(Icons.receipt_long_outlined, 'Admin Orders', AppRoutes.adminOrders),
      _ToolItem(Icons.verified_user_outlined, 'Verify Sellers', AppRoutes.adminVerifySellers),
      _ToolItem(Icons.branding_watermark_outlined, 'Manage Brands', AppRoutes.manageBrands),
      _ToolItem(Icons.phone_android_outlined, 'Manage Models', AppRoutes.manageModels),
      _ToolItem(Icons.add_to_photos_outlined, 'Add Model', AppRoutes.adminAddModel),
      _ToolItem(Icons.pending_actions_outlined, 'Model Requests', AppRoutes.adminModelRequests),
      _ToolItem(Icons.fact_check_outlined, 'IMEI Verification', AppRoutes.adminImeiVerification),
      _ToolItem(Icons.report_problem_outlined, 'IMEI Reports', AppRoutes.adminImeiReports),
      _ToolItem(Icons.warning_amber_outlined, 'User Reports', AppRoutes.adminUserReports),
      _ToolItem(Icons.block_outlined, 'Banned Users', AppRoutes.adminBannedUsers),
      _ToolItem(Icons.payments_outlined, 'Pending Fees', AppRoutes.adminPendingFees),
      _ToolItem(Icons.settings_suggest_outlined, 'Fee Settings', AppRoutes.adminFeeSettings),
      _ToolItem(Icons.campaign_outlined, 'Announcement', AppRoutes.adminAnnounce),
      _ToolItem(Icons.payment_outlined, 'Payment Settings', AppRoutes.adminPaymentSettings),
      _ToolItem(Icons.local_shipping_outlined, 'Shipping Settings', AppRoutes.adminShippingSettings),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return InkWell(
          onTap: () => context.push(tool.route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.icon, size: 24, color: scheme.primary),
                const SizedBox(height: 8),
                Text(
                  tool.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  final String route;
  _ToolItem(this.icon, this.label, this.route);
}
