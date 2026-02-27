import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';

class SellerOrderDetailPage extends StatelessWidget {
  final OrderModel order;
  const SellerOrderDetailPage({super.key, required this.order});

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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                _card(scheme, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("Qty: ${o.quantity}"),
                    Text("Buyer: ${o.buyerName}"),
                    Text("Phone: ${o.buyerPhone}"),
                    Text("City: ${o.depositCity}"),
                    Text("Address: ${o.buyerAddress}"),
                    const SizedBox(height: 8),
                    Text("Status: ${o.status}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary)),
                  ],
                )),

                const SizedBox(height: 20),

                if (o.status == "DEPOSIT_APPROVED")
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await OrderService.sellerMarkShipped(
                          orderId: o.id,
                        );
                      },
                      child: const Text("Mark as Shipped"),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

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
}