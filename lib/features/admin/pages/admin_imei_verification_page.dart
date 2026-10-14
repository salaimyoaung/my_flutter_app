import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/imei_service.dart';
import '../../../core/widgets/brand_app_bar.dart';
import 'admin_imei_verification_detail_page.dart';

class AdminImeiVerificationPage extends StatefulWidget {
  const AdminImeiVerificationPage({super.key});

  @override
  State<AdminImeiVerificationPage> createState() =>
      _AdminImeiVerificationPageState();
}

class _AdminImeiVerificationPageState
    extends State<AdminImeiVerificationPage> {
  @override
  void initState() {
    super.initState();
    _markAllImeiNotiRead();
  }

  /// Admin က IMEI Verification page ဖွင့်ချိန်မှာ
  /// new_imei_submission notifications အားလုံးကို read mark လုပ်သည်
  Future<void> _markAllImeiNotiRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Single-field query only — composite index မလိုဘဲ အလုပ်လုပ်
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      final toMark = snap.docs.where((doc) {
        final data = doc.data();
        return data['type'] == 'new_imei_submission' &&
               data['isRead'] != true;
      }).toList();
      if (toMark.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in toMark) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(title: "IMEI Verification"),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ImeiService.pendingImeiStream(),
        builder: (context, snap) {
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
                      size: 56, color: Colors.green.shade400),
                  const SizedBox(height: 12),
                  const Text('Pending IMEI မရှိပါ',
                      style: TextStyle(fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              final doc = docs[i];
              return _ImeiListItem(doc: doc);
            },
          );
        },
      ),
    );
  }
}

class _ImeiListItem extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _ImeiListItem({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final scheme = Theme.of(context).colorScheme;

    final brand = (d['brand'] ?? '').toString();
    final model = (d['model'] ?? '').toString();
    final imeiFull = (d['imeiFull'] ?? '').toString();
    final productId = (d['productId'] ?? '').toString();
    final createdAt = d['createdAt'] as Timestamp?;
    final sellerName = (d['sellerName'] ?? '').toString();

    // Avoid "Samsung Samsung Galaxy S22"
    final displayTitle = model.toLowerCase().startsWith(brand.toLowerCase())
        ? model
        : '$brand $model';

    // Short product ID — first 8 chars
    final shortId = productId.length > 8
        ? '#${productId.substring(0, 8).toUpperCase()}'
        : '#${productId.toUpperCase()}';

    // Last 4 digits of IMEI shown
    final imeiHint = imeiFull.length >= 4
        ? '••• ${imeiFull.substring(imeiFull.length - 4)}'
        : imeiFull;

    // Date formatting
    String dateStr = '';
    if (createdAt != null) {
      final dt = createdAt.toDate().toLocal();
      dateStr =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AdminImeiVerificationDetailPage(imeiDocId: doc.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status dot — always pending here
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        shortId,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (sellerName.isNotEmpty) ...[
                        Text(
                          '  ·  ',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 11),
                        ),
                        Flexible(
                          child: Text(
                            sellerName,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side: IMEI hint + date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  imeiHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
