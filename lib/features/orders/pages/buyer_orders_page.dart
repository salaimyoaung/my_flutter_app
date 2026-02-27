// buyer_orders_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/order_model.dart';

class BuyerOrdersPage extends StatelessWidget {
  const BuyerOrdersPage({super.key});

  String _statusLabel(String status) {
    switch (status) {
      case "DEPOSIT_PENDING":
        return "🟡 Deposit Pending";

      case "DEPOSIT_APPROVED":
        return "🔵 Approved";

      case "ON_THE_WAY":
        return "🚚 On The Way";

      case "COMPLETED":
        return "✅ Delivered";

      case "CANCELLED":
        return "❌ Cancelled";

      default:
        return status;
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case "DEPOSIT_PENDING":
        return "Admin approval စောင့်နေသည်။";

      case "DEPOSIT_APPROVED":
        return "Seller မှ ပို့ရန် ပြင်ဆင်နေသည်။";

      case "ON_THE_WAY":
        return "ပစ္စည်း ပို့ဆောင်နေသည်။";

      case "COMPLETED":
        return "ပစ္စည်းလက်ခံပြီးပါပြီ။";

      case "CANCELLED":
        return "Order ပယ်ဖျက်ထားသည်။";

      default:
        return "";
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "DEPOSIT_PENDING":
        return Colors.amber;

      case "DEPOSIT_APPROVED":
        return Colors.blue;

      case "ON_THE_WAY":
        return Colors.orange;

      case "COMPLETED":
        return Colors.green;

      case "CANCELLED":
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ordersRef = FirebaseFirestore.instance.collection('orders');

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Login ဝင်ပြီးမှ Orders ကြည့်လို့ရမယ်")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("My Orders", style: AppTextStyles.heading(context)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersRef
            .where('buyerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("Orders မရှိသေးပါ"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final status = (data['status'] ?? '').toString();
              final productName = (data['productName'] ?? '').toString();
              final price = (data['productPrice'] ?? '').toString();

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  context.push(
                    AppRoutes.orderDetail,
                    extra: {
                      "order": OrderModel.fromMap(doc.id, data),
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
                        productName,
                        style: AppTextStyles.main(context).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Price: $price MMK",
                        style: AppTextStyles.small(context),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusMessage(status),
                        style: AppTextStyles.small(context),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}