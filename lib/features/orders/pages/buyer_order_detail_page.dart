import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';

class BuyerOrderDetailPage extends StatelessWidget {
  final OrderModel order;
  const BuyerOrderDetailPage({super.key, required this.order});

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'DEPOSIT_PENDING':
        return 'Deposit Approval စောင့်နေသည်';
      case 'DEPOSIT_APPROVED':
        return 'Seller ပို့ရန် စောင့်နေသည်';
      case 'ON_THE_WAY':
        return 'ပို့ဆောင်နေသည်';
      case 'COMPLETED':
        return 'Delivered ✅';
      case 'CANCELLED':
        return 'Cancelled ❌';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Order Detail")),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data();
          if (data == null) {
            return const Center(child: Text("Order not found"));
          }

          final o = OrderModel.fromMap(order.id, data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // ================= PRODUCT =================
                _card(
                  scheme,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text("Price: ${o.productPrice} MMK"),
                      Text("Qty: ${o.quantity}"),
                      const SizedBox(height: 8),
                      Text(
                        "Status: ${_statusLabel(o.status)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ================= BUYER INFO =================
                _card(
                  scheme,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "My Information",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text("Name: ${o.buyerName}"),
                      Text("Phone: ${o.buyerPhone}"),
                      Text("City: ${o.depositCity}"),
                      Text("Address: ${o.buyerAddress}"),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ================= ACTION BUTTONS =================
                if (o.status == "DEPOSIT_PENDING")
                  _button(
                    context,
                    text: "Cancel Order",
                    color: Colors.red,
                    onPressed: () async {
                      await OrderService.buyerCancel(orderId: o.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  ),

                if (o.status == "ON_THE_WAY")
                  _button(
                    context,
                    text: "Confirm Received",
                    color: scheme.primary,
                    onPressed: () async {
                      await OrderService.buyerConfirmReceived(orderId: o.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _card(ColorScheme scheme, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _button(
      BuildContext context, {
        required String text,
        required Color color,
        required VoidCallback onPressed,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: onPressed,
          child: Text(text),
        ),
      ),
    );
  }
}