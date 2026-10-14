import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class AdminRefundPage extends StatelessWidget {
  const AdminRefundPage({super.key});

  Future<void> _markRefunded(String orderId) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'status': 'REFUNDED',
      'refundReady': false,
      'refundedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(title: "Admin Refund Panel"),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('refundReady', isEqualTo: true)
            .orderBy('receivedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No Refund Requests"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final deposit = data['depositAmount'] ?? 0;
              final buyer = data['buyerName'] ?? '';
              final txId = data['paymentTxId'] ?? '';
              final product = data['productName'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        product,
                        style: textTheme.titleMedium,
                      ),

                      const SizedBox(height: 8),

                      Text("Buyer: $buyer"),
                      Text("Deposit: $deposit MMK"),
                      Text("TxID: $txId"),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _markRefunded(doc.id);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Refund Marked as Completed ✅"),
                                ),
                              );
                            }
                          },
                          child: const Text("Mark as Refunded"),
                        ),
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
