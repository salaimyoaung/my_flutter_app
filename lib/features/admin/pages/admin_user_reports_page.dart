import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class AdminUserReportsPage extends StatefulWidget {
  const AdminUserReportsPage({super.key});

  @override
  State<AdminUserReportsPage> createState() => _AdminUserReportsPageState();
}

class _AdminUserReportsPageState extends State<AdminUserReportsPage> {
  @override
  void initState() {
    super.initState();
    _markReportNotifsAsRead();
  }

  Future<void> _markReportNotifsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .where('type', isEqualTo: 'report')
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('markReportNotifsAsRead error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: BrandAppBar(title: "User Reports"),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('status', isEqualTo: 'PENDING')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No pending reports"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;

              final reportedUserId =
              (d['reportedUserId'] ?? '').toString().trim();
              final reportedById =
              (d['reportedBy'] ?? '').toString().trim();
              final reason = (d['reason'] ?? '').toString();
              final description = (d['description'] ?? '').toString();
              final status = (d['status'] ?? 'PENDING').toString();
              final imageUrl = (d['imageUrl'] ?? '').toString();

              if (reportedUserId.isEmpty || reportedById.isEmpty) {
                return const SizedBox();
              }

              return FutureBuilder(
                future: Future.wait([
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(reportedUserId)
                      .get(),
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(reportedById)
                      .get(),
                ]),
                builder:
                    (context, AsyncSnapshot<List<DocumentSnapshot>> snap) {
                  String reportedUserName = reportedUserId;
                  String reportedByName = reportedById;
                  String reportedUserImage = "";
                  String reportedByImage = "";

                  if (snap.hasData) {
                    final userData =
                    snap.data![0].data() as Map<String, dynamic>?;
                    final reporterData =
                    snap.data![1].data() as Map<String, dynamic>?;

                    reportedUserName =
                        (userData?['name'] ?? reportedUserId).toString();
                    reportedByName =
                        (reporterData?['name'] ?? reportedById).toString();

                    reportedUserImage =
                        (userData?['profileImage'] ?? "").toString();
                    reportedByImage =
                        (reporterData?['profileImage'] ?? "").toString();
                  }

                  bool isBanned = false;
                  if (snap.hasData) {
                    final ud = snap.data![0].data() as Map<String, dynamic>?;
                    isBanned = ud?['isBanned'] == true;
                  }

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          /// 🔴 REPORTED USER (OFFENDER)
                          Text(
                            "Reported User",
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              context.push(
                                AppRoutes.sellerWallPath(reportedUserId),
                                extra: {
                                  "sellerId": reportedUserId,
                                  "sellerName": reportedUserName,
                                },
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                  reportedUserImage.isNotEmpty
                                      ? NetworkImage(reportedUserImage)
                                      : null,
                                  child: reportedUserImage.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    reportedUserName,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          /// 🟢 REPORTED BY (REPORTER)
                          Text(
                            "Reported By",
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              context.push(
                                AppRoutes.sellerWallPath(reportedById),
                                extra: {
                                  "sellerId": reportedById,
                                  "sellerName": reportedByName,
                                },
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                  reportedByImage.isNotEmpty
                                      ? NetworkImage(reportedByImage)
                                      : null,
                                  child: reportedByImage.isEmpty
                                      ? const Icon(Icons.person, size: 18)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    reportedByName,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.tertiary, // ✅ reporter
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// 🚨 Reason
                          Text("Reason: $reason"),

                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text("Details: $description"),
                          ],

                          if (imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              "Screenshot Evidence:",
                              style: textTheme.labelSmall?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Text("Image load failed"),
                              ),
                            ),
                          ],

                          const SizedBox(height: 10),

                          /// 📌 STATUS
                          Row(
                            children: [
                              const Text("Status: "),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == "PENDING"
                                      ? Theme.of(context).colorScheme.secondary
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          /// 🔥 ACTIONS
                          Row(
                            children: [
                              /// 🔴 BAN / 🟢 UNBAN
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isBanned ? Colors.grey.shade700 : Colors.red,
                                  ),
                                  onPressed: () async {
                                    if (isBanned) {
                                      // ── UNBAN ──────────────────────────
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Unban user?"),
                                          content: Text("$reportedUserName ကို unban လုပ်မည်။"),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text("Unban"),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm != true) return;

                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(reportedUserId)
                                          .update({'isBanned': false});

                                      // Reactivate their products
                                      final productSnap = await FirebaseFirestore
                                          .instance
                                          .collection('products')
                                          .where('sellerId', isEqualTo: reportedUserId)
                                          .get();
                                      final batch = FirebaseFirestore.instance.batch();
                                      for (final p in productSnap.docs) {
                                        batch.update(p.reference, {'active': true});
                                      }
                                      await batch.commit();

                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("$reportedUserName unbanned")),
                                      );
                                    } else {
                                      // ── BAN ────────────────────────────
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Ban user?"),
                                          content: Text("Ban $reportedUserName permanently?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text("Ban"),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm != true) return;

                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(reportedUserId)
                                          .update({'isBanned': true});

                                      final productSnap = await FirebaseFirestore
                                          .instance
                                          .collection('products')
                                          .where('sellerId', isEqualTo: reportedUserId)
                                          .where('active', isEqualTo: true)
                                          .get();
                                      final batch = FirebaseFirestore.instance.batch();
                                      for (final p in productSnap.docs) {
                                        batch.update(p.reference, {'active': false});
                                      }
                                      await batch.commit();

                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "$reportedUserName banned (${productSnap.docs.length} products hidden)"),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(isBanned ? "Unban" : "Ban"),
                                ),
                              ),

                              const SizedBox(width: 8),

                              /// ✅ RESOLVE
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    scheme.secondaryContainer,
                                  ),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('reports')
                                        .doc(doc.id)
                                        .update({'status': 'RESOLVED'});

                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                        Text("Marked as resolved"),
                                      ),
                                    );
                                  },
                                  child: const Text("Resolve"),
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
          );
        },
      ),
    );
  }
}