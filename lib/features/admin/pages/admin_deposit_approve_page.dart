import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_styles.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class AdminDepositApprovePage extends StatelessWidget {
  const AdminDepositApprovePage({super.key});

  Future<void> _updateStatus({
    required String orderId,
    required String depositStatus,
    required String status,
  }) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'depositStatus': depositStatus,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openImage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: BrandAppBar(title: "Deposit Approval"),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('depositStatus', isEqualTo: 'PENDING')
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text("No Pending Deposits"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {

              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;

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
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),

                      Text("Buyer: ${data['buyerName']}"),
                      Text("Phone: ${data['buyerPhone']}"),
                      Text("Seller: ${data['sellerName']}"),

                      const SizedBox(height: 8),

                      Text(
                        "Deposit: ${data['depositAmount']} MMK",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),

                      Text("TxID: ${data['depositTxId']}"),

                      const SizedBox(height: 10),

                      if ((data['depositScreenshotUrl'] ?? '').toString().isNotEmpty)
                        TextButton.icon(
                          onPressed: () =>
                              _openImage(data['depositScreenshotUrl']),
                          icon: const Icon(Icons.image),
                          label: const Text("View Screenshot"),
                        ),

                      const SizedBox(height: 12),

                      Row(
                        children: [

                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.tertiary,
                                foregroundColor: Theme.of(context).colorScheme.onTertiary,
                              ),
                              onPressed: () async {
                                await _updateStatus(
                                  orderId: doc.id,
                                  depositStatus: "APPROVED",
                                  status: "DEPOSIT_APPROVED",
                                );
                              },
                              child: const Text("Approve"),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                                foregroundColor: Theme.of(context).colorScheme.onError,
                              ),
                              onPressed: () async {
                                await _updateStatus(
                                  orderId: doc.id,
                                  depositStatus: "REJECTED",
                                  status: "DEPOSIT_REJECTED",
                                );
                              },
                              child: const Text("Reject"),
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