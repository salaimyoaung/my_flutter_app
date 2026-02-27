import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

class AdminImeiReportsPage extends StatelessWidget {
  const AdminImeiReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Login required")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("IMEI Reports (Admin)"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, adminSnap) {
          if (!adminSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final role =
          (adminSnap.data!.get('role') ?? '').toString().toLowerCase();

          if (role != 'admin') {
            return const Center(child: Text("Admin only"));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('imei_reports')
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Index required or permission issue"));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final reports = snapshot.data!.docs;

              if (reports.isEmpty) {
                return const Center(child: Text("No pending reports"));
              }

              return ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final doc = reports[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final imei = data['imei'] ?? "";
                  final reason = data['reason'] ?? "";
                  final reportId = doc.id;

                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("IMEI: $imei",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text("Reason: $reason"),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  onPressed: () => _approveReport(
                                      context, reportId, imei, reason),
                                  child: const Text("Approve"),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _rejectReport(context, reportId),
                                  child: const Text("Reject"),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approveReport(
      BuildContext context,
      String reportId,
      String imei,
      String reason,
      ) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;

    final batch = FirebaseFirestore.instance.batch();

    final reportRef =
    FirebaseFirestore.instance.collection('imei_reports').doc(reportId);

    final blacklistRef =
    FirebaseFirestore.instance.collection('blacklisted_imeis').doc(imei);

    batch.update(reportRef, {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    batch.set(blacklistRef, {
      'imei': imei,
      'reason': reason,
      'approvedBy': admin.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("IMEI Approved & Blacklisted")),
    );
  }

  Future<void> _rejectReport(
      BuildContext context,
      String reportId,
      ) async {
    await FirebaseFirestore.instance
        .collection('imei_reports')
        .doc(reportId)
        .update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Report Rejected")),
    );
  }
}