import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {

  static const String sDepositPending = "DEPOSIT_PENDING";
  static const String sDepositApproved = "DEPOSIT_APPROVED";
  static const String sCompleted = "COMPLETED";
  static const String sCancelled = "CANCELLED";

  static const String fAll = "ALL";
  String _filter = fAll;

  final _ordersRef = FirebaseFirestore.instance.collection('orders');

  // ================= HELPERS =================

  String _getStr(Map<String, dynamic> d, String k) =>
      (d[k] ?? "").toString().trim();

  int _countBy(List<QueryDocumentSnapshot> docs, String status) {
    return docs.where((x) => _getStr(x.data() as Map<String, dynamic>, 'status') == status).length;
  }

  double _totalRevenue(List<QueryDocumentSnapshot> docs) {
    double total = 0;
    for (var d in docs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['status'] == sCompleted) {
        total += double.tryParse(data['productPrice']?.toString() ?? "0") ?? 0;
      }
    }
    return total;
  }

  List<QueryDocumentSnapshot> _applyFilter(List<QueryDocumentSnapshot> docs) {
    if (_filter == fAll) return docs;
    return docs.where((x) =>
    _getStr(x.data() as Map<String, dynamic>, 'status') == _filter).toList();
  }

  // ================= MODERN SUMMARY CARD =================

  Widget _summaryCard({
    required String label,
    required int count,
    required String status,
    required List<Color> gradient,
  }) {
    final selected = _filter == status;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filter = status;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
              BoxShadow(
                color: gradient.first.withOpacity(0.6),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ]
                : [],
          ),
          child: Column(
            children: [
              Text(
                "$count",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Login required")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Orders"),
        automaticallyImplyLeading: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ordersRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          final pending = _countBy(docs, sDepositPending);
          final approved = _countBy(docs, sDepositApproved);
          final delivered = _countBy(docs, sCompleted);
          final cancelled = _countBy(docs, sCancelled);
          final totalRevenue = _totalRevenue(docs);

          final filtered = _applyFilter(docs);

          return Column(
            children: [

              // ======= SUMMARY SECTION =======
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text("IMEI Reports"),
                onTap: () {
                  context.push(AppRoutes.adminImeiReports);
                },
              ),


              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _summaryCard(
                          label: "💰 Pending",
                          count: pending,
                          status: sDepositPending,
                          gradient: [Colors.orange, Colors.deepOrange],
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          label: "🚚 Approved",
                          count: approved,
                          status: sDepositApproved,
                          gradient: [Colors.blue, Colors.indigo],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _summaryCard(
                          label: "✅ Delivered",
                          count: delivered,
                          status: sCompleted,
                          gradient: [Colors.green, Colors.teal],
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          label: "❌ Cancelled",
                          count: cancelled,
                          status: sCancelled,
                          gradient: [Colors.red, Colors.redAccent],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ===== Revenue Card =====
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff141E30), Color(0xff243B55)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Revenue",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            "$totalRevenue MMK",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ======= ORDER LIST =======
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final d = doc.data() as Map<String, dynamic>;

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        context.push(
                          AppRoutes.orderDetailPath(doc.id),
                          extra: {
                            'order': OrderModel.fromMap(doc.id, d),
                          },
                        );
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['productName'] ?? "Product",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text("Buyer: ${d['buyerName']}"),
                              const SizedBox(height: 6),
                              Text("Status: ${d['status']}"),
                              const SizedBox(height: 10),

                              if (d['status'] == sDepositPending)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    onPressed: () async {
                                      await OrderService.adminApproveDeposit(
                                        orderId: doc.id,
                                      );

                                      if (!mounted) return;

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("Deposit Approved ✅")),
                                      );
                                    },
                                    child: const Text("Approve Deposit"),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}