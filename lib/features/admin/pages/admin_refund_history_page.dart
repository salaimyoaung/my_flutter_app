import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../app_styles.dart';

class AdminRefundHistoryPage extends StatelessWidget {
  const AdminRefundHistoryPage({super.key});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return "-";
    final d = ts.toDate();
    return "${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text("Refund History"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', isEqualTo: 'REFUNDED')
            .orderBy('refundedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No Refund History"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final product = data['productName'] ?? '';
              final buyer = data['buyerName'] ?? '';
              final phone = data['buyerPhone'] ?? '';
              final deposit = data['depositAmount'] ?? 0;
              final txId = data['paymentTxId'] ?? '';
              final refundedAt = data['refundedAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Product
                      Text(
                        product,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text("Buyer: $buyer"),
                      Text("Phone: $phone"),
                      Text("Deposit Refunded: $deposit MMK"),
                      Text("TxID: $txId"),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 18, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            "Refunded on: ${_formatDate(refundedAt)}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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