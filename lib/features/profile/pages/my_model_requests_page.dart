import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/brand_app_bar.dart';
import '../../../data/models/model_request_model.dart';

class MyModelRequestsPage extends StatefulWidget {
  const MyModelRequestsPage({super.key});

  @override
  State<MyModelRequestsPage> createState() => _MyModelRequestsPageState();
}

class _MyModelRequestsPageState extends State<MyModelRequestsPage> {
  @override
  void initState() {
    super.initState();
    _markAllSeen();
  }

  /// Mark all approved/rejected requests as seen when page opens
  Future<void> _markAllSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('model_requests')
          .where('sellerId', isEqualTo: uid)
          .where('isSeenBySeller', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isSeenBySeller': true});
      }
      if (snap.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_markAllSeen ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BrandAppBar(title: 'My Model Requests'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('model_requests')
            .where('sellerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Model request မရှိသေးပါ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          final requests =
              docs.map((d) => ModelRequestModel.fromDoc(d)).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _RequestCard(request: requests[i]),
          );
        },
      ),
    );
  }
}

// ─── Badge count stream ───────────────────────────────────────────────────────
/// Returns count of approved/rejected requests not yet seen by seller.
Stream<int> unseenModelRequestCountStream(String sellerId) {
  if (sellerId.isEmpty) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('model_requests')
      .where('sellerId', isEqualTo: sellerId)
      .where('isSeenBySeller', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
}

// ─── Request card ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final ModelRequestModel request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final status = request.status;

    final (Color bgColor, Color fgColor, IconData icon, String label) =
        switch (status) {
      'APPROVED' => (
          scheme.tertiary.withValues(alpha: 0.12),
          scheme.tertiary,
          Icons.check_circle_outline,
          'Approved',
        ),
      'REJECTED' => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.cancel_outlined,
          'Rejected',
        ),
      _ => (
          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          scheme.onSurfaceVariant,
          Icons.hourglass_empty_rounded,
          'Pending',
        ),
    };

    String dateStr = '';
    if (request.createdAt != null) {
      final d = request.createdAt!.toDate();
      dateStr = '${d.day}/${d.month}/${d.year}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.brand} ${request.model}',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: fgColor),
                    const SizedBox(width: 4),
                    Text(label,
                        style: textTheme.labelSmall?.copyWith(
                            color: fgColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (request.series.isNotEmpty)
            Text('Series: ${request.series}',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          Text('Type: ${request.deviceType}',
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(dateStr,
                style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant, fontSize: 11)),
          ],
          if (status == 'REJECTED' && request.adminNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Admin မှတ်ချက်: ${request.adminNote}',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
          ],
          if (status == 'APPROVED') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: scheme.tertiary),
                const SizedBox(width: 6),
                Text(
                  'Product တင်ရန် အသင့်ဖြစ်ပြီ',
                  style: textTheme.bodySmall?.copyWith(
                      color: scheme.tertiary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
