import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _norm(String s) => s.trim().toUpperCase();

  bool _isActionRequired(String status) =>
      status == OrderService.sDepositApproved;

  bool _isInProgress(String status) =>
      status == OrderService.sOnTheWay;

  bool _isCompleted(String status) =>
      status == OrderService.sCompleted ||
          status == OrderService.sCancelled ||
          status == OrderService.sRefunded;

  String _statusLabel(String s) {
    switch (_norm(s)) {
      case "DEPOSIT_PENDING":
        return "Deposit Pending";
      case "DEPOSIT_APPROVED":
        return "Ready to Ship";
      case "ON_THE_WAY":
        return "On the way";
      case "COMPLETED":
        return "Completed";
      case "REFUNDED":
        return "Refunded";
      case "CANCELLED":
        return "Cancelled";
      default:
        return s;
    }
  }

  Widget _orderCard(OrderModel o, bool showAction) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.push(
          AppRoutes.orderDetailPath(o.id),
          extra: {
            'order': o,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              o.productName,
              style: AppTextStyles.main(context)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text("${o.productPrice} • Qty ${o.quantity}"),
            const SizedBox(height: 6),
            Text("Buyer: ${o.buyerName}"),
            const SizedBox(height: 6),
            Text(
              "Status: ${_statusLabel(o.status)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),

            if (showAction) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text("Mark as Shipped"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await OrderService.sellerMarkShipped(orderId: o.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Marked Shipped ✅")),
                    );
                  },
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      bool Function(String) filter,
      bool showAction,
      String emptyText,
      ) {
    final list = docs
        .where((d) => filter(_norm(d['status'] ?? '')))
        .toList();

    if (list.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (c, i) {
        final o = OrderModel.fromMap(list[i].id, list[i].data());
        return _orderCard(o, showAction);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Login Required")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Seller Orders",
            style: AppTextStyles.heading(context)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Action"),
            Tab(text: "In Progress"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: OrderService.sellerOrdersStream(user.uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(
                docs,
                _isActionRequired,
                true,
                "No orders to ship",
              ),
              _buildList(
                docs,
                _isInProgress,
                false,
                "No orders in progress",
              ),
              _buildList(
                docs,
                _isCompleted,
                false,
                "No completed orders",
              ),
            ],
          );
        },
      ),
    );
  }
}