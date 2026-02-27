import 'package:flutter/material.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';

class AdminOrderDetailPage extends StatelessWidget {
  final OrderModel order;
  const AdminOrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Admin Order Detail")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Text(order.productName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),

            Text("Buyer: ${order.buyerName}"),
            Text("Seller: ${order.sellerName}"),
            Text("Status: ${order.status}"),

            const SizedBox(height: 20),

            if (order.status == "DEPOSIT_PENDING")
              ElevatedButton(
                onPressed: () async {
                  await OrderService.adminApproveDeposit(
                      orderId: order.id);
                },
                child: const Text("Approve Deposit"),
              ),
          ],
        ),
      ),
    );
  }
}