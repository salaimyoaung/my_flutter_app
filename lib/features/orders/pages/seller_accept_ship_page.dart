import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app_styles.dart';

class BuyerOrdersPage extends StatelessWidget {
  const BuyerOrdersPage({super.key});

  Future<void> _markAsReceived(String orderId) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'status': 'DELIVERED',
      'receivedAt': FieldValue.serverTimestamp(),
      'refundReady': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final buyerId = FirebaseAuth.instance.currentUser?.uid;

    if (buyerId == null) {
      return const Scaffold(
        body: Center(child: Text("Login Required")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text("My Orders"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('buyerId', isEqualTo: buyerId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text("No Orders"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {

              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        data['productName'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),

                      Text("Seller: ${data['sellerName']}"),
                      Text("Status: $status"),

                      const SizedBox(height: 12),

                      if (status == 'SHIPPED')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () async {
                              await _markAsReceived(doc.id);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Item Received ✅ Deposit refund will be processed by admin.",
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text("Item Received"),
                          ),
                        ),

                      if (status == 'DELIVERED')
                        const Text(
                          "Waiting for admin refund...",
                          style: TextStyle(color: Colors.orange),
                        ),

                      if (status == 'REFUNDED')
                        const Text(
                          "Deposit Refunded ✅",
                          style: TextStyle(color: Colors.green),
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