import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/fee_service.dart';
import '../../../core/widgets/brand_app_bar.dart';

/// Admin page — lists sellers who have outstanding platform fees.
///
/// Each row shows seller name, pending fee amount, and freeze/unfreeze toggle.
/// Freeze sets `listingsFrozen: true` on the user doc, which product queries
/// respect to hide that seller's listings.
///
/// Admin can also mark a fee as paid (resets pendingFee to 0).
class AdminPendingFeesPage extends StatelessWidget {
  const AdminPendingFeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandAppBar(title: 'Pending Fees'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('pendingFee', isGreaterThan: 0)
            .orderBy('pendingFee', descending: true)
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
                  Icon(Icons.check_circle_outline, size: 56, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(height: 12),
                  const Text('Pending fee မရှိပါ', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _SellerFeeCard(
                sellerId: doc.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Seller Fee Card ──────────────────────────────────────────────────────────

class _SellerFeeCard extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic> data;

  const _SellerFeeCard({required this.sellerId, required this.data});

  @override
  State<_SellerFeeCard> createState() => _SellerFeeCardState();
}

class _SellerFeeCardState extends State<_SellerFeeCard> {
  bool _busy = false;

  int get _pendingFee {
    final v = widget.data['pendingFee'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  bool get _frozen => widget.data['listingsFrozen'] == true;

  String get _name => (widget.data['name'] ?? '').toString();
  String get _profileImage => (widget.data['profileImage'] ?? '').toString();
  String get _phone => (widget.data['phone'] ?? '').toString();

  // ── Toggle freeze ────────────────────────────────────────────────────────
  // Freeze: sets listingsFrozen on user doc AND sets active=false on all
  //   seller products (hidden from BrandWallView's active==true query).
  // Unfreeze: reverses both.

  Future<void> _toggleFreeze() async {
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final willFreeze = !_frozen;

      // 1. Update user doc
      final batch = db.batch();
      batch.set(
        db.collection('users').doc(widget.sellerId),
        {'listingsFrozen': willFreeze},
        SetOptions(merge: true),
      );

      // 2. Batch-update ALL seller's products (No skipping during freeze)
      final productsSnap = await db
          .collection('products')
          .where('sellerId', isEqualTo: widget.sellerId)
          .get();

      for (final doc in productsSnap.docs) {
        final data = doc.data();
        
        if (willFreeze) {
          // 🔒 Freeze လုပ်ရင် အကုန်ပိတ်မယ်
          batch.update(doc.reference, {'active': false});
        } else {
          // 🔓 Unfreeze logic: ပေါ်သင့်တာ အကုန် ပြန်ဖော်မယ်
          
          final imeiStatus = (data['imeiStatus'] ?? '').toString().toUpperCase();
          final isSold = data['soldAt'] != null;
          final isRejected = imeiStatus == 'REJECTED' || imeiStatus == 'BLACKLISTED';
          final hasOrder = data['hasActiveOrder'] == true;

          // ✅ ရောင်းပြီးသား မဟုတ်ရဘူး၊ admin ပယ်ထားတာ မဟုတ်ရဘူး၊ လက်ရှိ order တက်နေတာ မဟုတ်ရဘူး
          if (!isSold && !isRejected && !hasOrder) {
            batch.update(doc.reference, {'active': true});
          }
        }
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willFreeze
                ? '$_name ၏ listing ${productsSnap.docs.length} ခု freeze လုပ်ပြီးပါပြီ'
                : '$_name ၏ listing များ ပြန်ဖွင့်ပြီးပါပြီ',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Mark fee paid ────────────────────────────────────────────────────────

  Future<void> _markPaid() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fee ပေးချေပြီးကြောင်း အတည်ပြုရန်'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_name ၏ စုစုပေါင်း pending fee မှာ ${FeeService.formatFee(_pendingFee)} ဖြစ်ပါသည်။'),
            const SizedBox(height: 12),
            const Text('ပေးချေမည့် ပမာဏကို ရိုက်ထည့်ပါ (ပစ္စည်းတစ်ခုစာဆိုလျှင် ၅,၀၀၀ သို့မဟုတ် ၁၀,၀၀၀)'),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actions: [
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'ဥပမာ - ၅၀၀၀'),
            onSubmitted: (val) => Navigator.pop(ctx, true),
            autofocus: true,
            onChanged: (val) => _inputAmount = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('မလုပ်ဘူး')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('အတည်ပြုမည်')),
            ],
          ),
        ],
      ),
    );

    if (confirm != true || _inputAmount <= 0) return;

    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. စုစုပေါင်းထဲကနေ အခုပေးတဲ့ ပမာဏကိုပဲ နှုတ်မယ်
      final newFee = (_pendingFee - _inputAmount).clamp(0, 9999999);
      
      batch.set(
        db.collection('users').doc(widget.sellerId),
        {
          'pendingFee': newFee,
          // ✅ Clear deadline if balance is fully paid
          if (newFee <= 0) 'feeDeadline': null,
          // အကုန်လုံး ပေးပြီးသွားမှသာ unfreeze လုပ်မယ်
          'listingsFrozen': newFee > 0 ? widget.data['listingsFrozen'] : false,
          'lastFeePaidAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2. အကုန်လုံး ပေးပြီးသွားမှ product တွေကို ပြန်ဖွင့်မယ်
      // 2. Re-activate products that are available for sale
      if (newFee <= 0 && _frozen) {
        final productsSnap = await db
            .collection('products')
            .where('sellerId', isEqualTo: widget.sellerId)
            .get();
        for (final doc in productsSnap.docs) {
          final data = doc.data();
          final imeiStatus = (data['imeiStatus'] ?? '').toString().toUpperCase();
          final isSold = data['soldAt'] != null;
          final isRejected = imeiStatus == 'REJECTED' || imeiStatus == 'BLACKLISTED';
          final hasOrder = data['hasActiveOrder'] == true;

          // ✅ ရောင်းပြီးသား၊ admin ပယ်ထားတာနဲ့ လက်ရှိ deal ရှိနေတာတွေကို ချန်လှပ်ပြီးမှ ပြန်ဖွင့်ပေးမယ်
          if (!isSold && !isRejected && !hasOrder) {
            batch.update(doc.reference, {'active': true});
          }
        }
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_name — ${_inputAmount}Ks ပေးချေပြီးကြောင်း မှတ်သားပြီးပါပြီ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _inputAmount = 0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: _frozen ? scheme.error : scheme.outlineVariant,
          width: _frozen ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Row(
              children: [
                // Profile image
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primaryContainer,
                  backgroundImage: _profileImage.isNotEmpty
                      ? NetworkImage(_profileImage)
                      : null,
                  child: _profileImage.isEmpty
                      ? Icon(Icons.person, color: scheme.primary)
                      : null,
                ),
                const SizedBox(width: 12),

                // Name + phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.isNotEmpty ? _name : widget.sellerId,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_phone.isNotEmpty)
                        Text(
                          _phone,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),

                // Freeze badge
                if (_frozen)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🔒 Frozen',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Fee amount ────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pending Fee:',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Text(
                  FeeService.formatFee(_pendingFee),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.error,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Actions ───────────────────────────────────────────────
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  // Freeze / Unfreeze
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleFreeze,
                      icon: Icon(
                        _frozen ? Icons.lock_open_outlined : Icons.lock_outline,
                        size: 18,
                      ),
                      label: Text(_frozen ? 'Unfreeze' : 'Freeze'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _frozen ? scheme.primary : scheme.error,
                        side: BorderSide(
                          color: _frozen ? scheme.primary : scheme.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Mark paid
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _markPaid,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Paid ✓'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Theme.of(context).colorScheme.onTertiary,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
