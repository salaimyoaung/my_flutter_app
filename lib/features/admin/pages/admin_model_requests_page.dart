import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../data/services/model_request_service.dart';
import 'admin_add_model_page.dart';

class AdminModelRequestsPage extends StatefulWidget {
  const AdminModelRequestsPage({super.key});

  @override
  State<AdminModelRequestsPage> createState() => _AdminModelRequestsPageState();
}

class _AdminModelRequestsPageState extends State<AdminModelRequestsPage> {
  final _service = ModelRequestService();

  @override
  void initState() {
    super.initState();
    _markModelRequestNotifsAsRead();
  }

  Future<void> _markModelRequestNotifsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .where('type', isEqualTo: 'model_request')
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('markModelRequestNotifsAsRead error: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String get _adminUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Edit Dialog ──────────────────────────────────────────────────────────

  void _showEditDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final brandCtrl = TextEditingController(text: data['brand'] ?? '');
    final modelCtrl = TextEditingController(text: data['model'] ?? '');
    final seriesCtrl = TextEditingController(text: data['series'] ?? '');

    showDialog(
      context: context,
      // ✅ barrierDismissible false — prevent accidental dismiss while saving
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Model Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: brandCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: seriesCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Series (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: modelCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),

                // ── Save only ──────────────────────────────────────────────
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    // ✅ Validation before save
                    if (modelCtrl.text.trim().isEmpty ||
                        brandCtrl.text.trim().isEmpty) {
                      _showSnack('Brand နဲ့ Model ထည့်ပါ');
                      return;
                    }
                    setDialogState(() => isLoading = true);
                    try {
                      await _service.editRequest(
                        requestId: doc.id,
                        brand: brandCtrl.text,
                        model: modelCtrl.text,
                        series: seriesCtrl.text,
                        deviceType:
                        (data['deviceType'] ?? '').toString(),
                      );
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      _showSnack('Saved ✅');
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (!context.mounted) return;
                      _showSnack(
                          e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Save'),
                ),

                // ── Edit + Approve ─────────────────────────────────────────
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (modelCtrl.text.trim().isEmpty ||
                        brandCtrl.text.trim().isEmpty) {
                      _showSnack('Brand နဲ့ Model ထည့်ပါ');
                      return;
                    }
                    setDialogState(() => isLoading = true);
                    try {
                      await _service.editAndApprove(
                        requestId: doc.id,
                        adminUid: _adminUid,
                        brand: brandCtrl.text,
                        model: modelCtrl.text,
                        series: seriesCtrl.text,
                        deviceType:
                        (data['deviceType'] ?? '').toString(),
                      );
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      _showSnack('Approved ✅');
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (!context.mounted) return;
                      _showSnack(
                          e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Approve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Reject Dialog ────────────────────────────────────────────────────────

  Future<void> _rejectDialog(String requestId) async {
    final ctrl = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reject Request'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Reason (လိုအပ်သည်)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                // ✅ Reason required
                if (ctrl.text.trim().isEmpty) {
                  _showSnack('Reason ထည့်ပါ');
                  return;
                }
                setDialogState(() => isLoading = true);
                try {
                  await _service.rejectRequest(
                    requestId: requestId,
                    adminUid: _adminUid,
                    note: ctrl.text.trim(),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  _showSnack('Rejected ❌');
                } catch (e) {
                  setDialogState(() => isLoading = false);
                  if (!context.mounted) return;
                  _showSnack(
                      e.toString().replaceAll('Exception: ', ''));
                }
              },
              child: isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: 'Model Requests',
        actions: [
          // ✅ Admin can add model directly from this page
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Model အသစ်ထည့်မည်',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminAddModelPage(),
                ),
              );
            },
          ),
        ],
      ),
      // ✅ FAB — quick access to add model
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAddModelPage()),
          );
        },
        icon: const Icon(Icons.phone_android),
        label: const Text('Model ထည့်မည်'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.pendingRequestsStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(height: 12),
                  const Text('Pending requests မရှိပါ'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminAddModelPage()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Model အသစ်ထည့်မည်'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            // ✅ __ not _ — Dart 3 fix
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();

              final createdAt = data['createdAt'];
              final timeStr = createdAt is Timestamp
                  ? timeago.format(createdAt.toDate())
                  : '-';

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Brand / Model ──────────────────────────────────
                      Text(
                        '${data['brand'] ?? '-'} / ${data['model'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      if ((data['series'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Series: ${data['series']}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                      ],

                      const SizedBox(height: 6),

                      // ── Seller ─────────────────────────────────────────
                      GestureDetector(
                        onTap: () => context.push(
                          AppRoutes.sellerWallPath(
                              (data['sellerId'] ?? '').toString()),
                        ),
                        child: Text(
                          'Seller: ${data['sellerName'] ?? '-'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Device: ${data['deviceType'] ?? '-'}',
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Requested: $timeStr',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),

                      const SizedBox(height: 10),

                      // ── Actions ────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // ✏️ Edit + optional approve
                          IconButton(
                            icon: Icon(Icons.edit,
                                color: Theme.of(context).colorScheme.secondary),
                            tooltip: 'Edit',
                            onPressed: () => _showEditDialog(doc),
                          ),

                          // ❌ Reject
                          IconButton(
                            icon: Icon(Icons.close,
                                color: Theme.of(context).colorScheme.error),
                            tooltip: 'Reject',
                            onPressed: () => _rejectDialog(doc.id),
                          ),

                          // ✅ Quick approve (no edit)
                          IconButton(
                            icon: Icon(Icons.check,
                                color: Theme.of(context).colorScheme.tertiary),
                            tooltip: 'Approve',
                            onPressed: () async {
                              try {
                                await _service.approveRequest(
                                  requestId: doc.id,
                                  adminUid: _adminUid,
                                );
                                if (!context.mounted) return;
                                _showSnack('Approved ✅');
                              } catch (e) {
                                if (!context.mounted) return;
                                _showSnack(e
                                    .toString()
                                    .replaceAll('Exception: ', ''));
                              }
                            },
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