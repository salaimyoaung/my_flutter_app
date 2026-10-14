import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';
import '../../../core/widgets/expandable_text.dart';
import '../../orders/pages/admin_order_detail_page.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  // ✅ Reuse constants from OrderService — no duplication
  static const String fAll = 'ALL';
  String _filter = fAll;

  @override
  void initState() {
    super.initState();
    _markAdminNotificationsAsRead();
  }

  Future<void> _markAdminNotificationsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .where('type', whereIn: ['order', 'new_order'])
          .get();
      await Future.wait(snap.docs.map((doc) =>
          doc.reference.update({'isRead': true, 'readAt': FieldValue.serverTimestamp()})));
    } catch (e) {
      if (kDebugMode) debugPrint('markAsRead error: $e');
    }
  }

  // ✅ Revenue formatter
  final _currencyFmt = NumberFormat('#,###', 'en_US');

  // ─── Helpers ──────────────────────────────────────────────────────────────

  int _countBy(List<QueryDocumentSnapshot> docs, String status) {
    if (status == OrderService.sFeePending) {
      // ✅ Fee Pending logic: must have returned deposit first
      return docs.where((x) {
        final data = x.data() as Map<String, dynamic>;
        return data['status'] == OrderService.sFeePending && data['depositReturned'] == true;
      }).length;
    }
    if (status == OrderService.sReturnPending) {
      // ✅ Returns category logic: pending + rejected + claimed
      return docs.where((x) {
        final data = x.data() as Map<String, dynamic>;
        final s = data['status'] as String?;
        return s == OrderService.sReturnPending ||
               s == OrderService.sReturnRejected ||
               s == OrderService.sReturnClaimed;
      }).length;
    }
    if (status == OrderService.sRejected) {
       return docs.where((x) {
        final data = x.data() as Map<String, dynamic>;
        final s = data['status'] as String?;
        return s == OrderService.sRejected || s == OrderService.sSellerRejected || s == OrderService.sRefunded;
      }).length;
    }
    return docs
        .where((x) =>
    (x.data() as Map<String, dynamic>)['status'] == status)
        .length;
  }

  // Seller လွှဲထားတဲ့ service charges စုစုပေါင်း (feeConfirmed == true orders သာ)
  double _totalRevenue(List<QueryDocumentSnapshot> docs) {
    double total = 0;
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['feeConfirmed'] == true) {
        total += (data['feeTransferAmount'] as num? ?? 0).toDouble();
      }
    }
    return total;
  }

  static const String fDepositReturnPending = 'DEPOSIT_RETURN_PENDING';

  // ✅ Deposit Return Pending: Status is FEE_PENDING or COMPLETED, but deposit not yet returned
  int _countDepositReturnPending(List<QueryDocumentSnapshot> docs) {
    return docs.where((x) {
      final data = x.data() as Map<String, dynamic>;
      final status = data['status'] as String?;
      final isReturnable = status == OrderService.sFeePending || status == OrderService.sCompleted;
      return isReturnable && data['depositReturned'] != true;
    }).length;
  }

  // ✅ Client-side filter — acceptable for admin panel (limited volume)
  List<QueryDocumentSnapshot> _applyFilter(
      List<QueryDocumentSnapshot> docs) {
    if (_filter == fAll) return docs;
    
    if (_filter == fDepositReturnPending) {
      return docs.where((x) {
        final data = x.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final isReturnable = status == OrderService.sFeePending || status == OrderService.sCompleted;
        return isReturnable && data['depositReturned'] != true;
      }).toList();
    }

    if (_filter == OrderService.sFeePending) {
      return docs.where((x) {
        final data = x.data() as Map<String, dynamic>;
        return data['status'] == OrderService.sFeePending && data['depositReturned'] == true;
      }).toList();
    }

    if (_filter == OrderService.sReturnPending) {
      return docs.where((x) {
        final data = x.data() as Map<String, dynamic>;
        final s = data['status'] as String?;
        return s == OrderService.sReturnPending ||
               s == OrderService.sReturnRejected ||
               s == OrderService.sReturnClaimed;
      }).toList();
    }

    if (_filter == OrderService.sRejected) {
      return docs.where((x) {
        final data = x.data() as Map<String, dynamic>;
        final s = data['status'] as String?;
        return s == OrderService.sRejected || 
               s == OrderService.sSellerRejected || 
               s == OrderService.sRefunded;
      }).toList();
    }

    return docs
        .where((x) =>
    (x.data() as Map<String, dynamic>)['status'] == _filter)
        .toList();
  }

  // ─── Confirm Dialog ───────────────────────────────────────────────────────

  // ✅ Confirmation before irreversible admin actions
  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('အတည်ပြုရန်'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('မလုပ်ပါ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('အတည်ပြုမည်'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Summary Card ─────────────────────────────────────────────────────────

  Widget _summaryCard({
    required BuildContext context,
    required String label,
    required int count,
    required String status,
    required List<Color> gradient,
  }) {
    final selected = _filter == status;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.6),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Order Card ───────────────────────────────────────────────────────────

  Widget _orderCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final status = (d['status'] ?? '').toString();
    final rejectReason = (d['rejectReason'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminOrderDetailPage(
              order: OrderModel.fromMap(doc.id, d),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d['productName'] ?? 'Product',
                    style: textTheme.titleMedium,
                  ),
                ),
                if (d['depositReturned'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          (d['refundedTo'] == 'seller') ? 'Delivery ခ လွှဲပြီး' : 'Deposit ပြန်ရပြီး',
                          style: textTheme.labelSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Buyer: ${d['buyerName'] ?? '-'}', style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status: $status', style: textTheme.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
                if (d['createdAt'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Ordered: ${timeago.format((d['createdAt'] as Timestamp).toDate())}',
                        style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9),
                      ),
                      if (d['updatedAt'] != null && 
                          (d['updatedAt'] as Timestamp).seconds > (d['createdAt'] as Timestamp).seconds + 60)
                        Text(
                          'Updated: ${timeago.format((d['updatedAt'] as Timestamp).toDate())}',
                          style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
              ],
            ),

            if (d['status'] == OrderService.sReturnClaimed)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Seller မှ Delivery ခ Claim တောင်းထားသည်', 
                          style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
              ),

            if (d['status'] == OrderService.sReturnRejected)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('⚠️ Return ပယ်ချထားသည် (Seller claim စောင့်ဆိုင်းဆဲ)', 
                     style: textTheme.labelSmall?.copyWith(color: scheme.error, fontSize: 10)),
              ),

            if (rejectReason.isNotEmpty && (status == OrderService.sRejected || status == OrderService.sSellerRejected || status == OrderService.sRefunded))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ExpandableText(
                  text: 'Reason: $rejectReason',
                  style: textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w500),
                  maxLines: 2,
                ),
              ),

            if (status == OrderService.sDepositPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve'),
                      onPressed: () async {
                        final ok = await _confirm('Deposit ကို approve လုပ်မှာသေချာပါသလား?');
                        if (!ok) return;
                        try {
                          await OrderService.adminApproveDeposit(orderId: doc.id);
                          if (!mounted) return;
                          _showSnack('Approved ✅');
                        } catch (e) {
                          if (!mounted) return;
                          _showSnack(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      onPressed: () async {
                        final ok = await _confirm('ဤ Order ကို reject လုပ်မှာသေချာပါသလား?');
                        if (!ok) return;
                        try {
                          await OrderService.adminRejectDeposit(orderId: doc.id);
                          if (!mounted) return;
                          _showSnack('Rejected ❌');
                        } catch (e) {
                          if (!mounted) return;
                          _showSnack(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Login required')));
    }

    return Scaffold(
      appBar: BrandAppBar(title: 'Admin Orders'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          final filtered = _applyFilter(docs);

          final pending    = _countBy(docs, OrderService.sDepositPending);
          final approved   = _countBy(docs, OrderService.sDepositApproved);
          final onTheWay   = _countBy(docs, OrderService.sOnTheWay);
          final feePending = _countBy(docs, OrderService.sFeePending);
          final completed  = _countBy(docs, OrderService.sCompleted);
          final cancelled  = _countBy(docs, OrderService.sCancelled);
          final rejected   = _countBy(docs, OrderService.sRejected);
          final refunded   = _countBy(docs, OrderService.sRefunded);
          final returns    = _countBy(docs, OrderService.sReturnPending);
          final depositReturnPending = _countDepositReturnPending(docs);
          final totalRevenue = _totalRevenue(docs);

          return CustomScrollView(
            slivers: [
              // ── Summary Cards ──────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.7,
                  children: [
                    _summaryCard(
                      context: context,
                      label: '💰 Pending',
                      count: pending,
                      status: OrderService.sDepositPending,
                      gradient: [scheme.tertiary, scheme.tertiaryContainer],
                    ),
                    _summaryCard(
                      context: context,
                      label: '✅ Approved',
                      count: approved,
                      status: OrderService.sDepositApproved,
                      gradient: [scheme.secondary, scheme.secondaryContainer],
                    ),
                    _summaryCard(
                      context: context,
                      label: '🚚 On The Way',
                      count: onTheWay,
                      status: OrderService.sOnTheWay,
                      gradient: const [
                        Color(0xFF1565C0),
                        Color(0xFF42A5F5),
                      ],
                    ),
                    _summaryCard(
                      context: context,
                      label: '⏳ Fee Pending',
                      count: feePending,
                      status: OrderService.sFeePending,
                      gradient: const [
                        Color(0xFFE65100),
                        Color(0xFFFF9800),
                      ],
                    ),
                    _summaryCard(
                      context: context,
                      label: '🎉 Completed',
                      count: completed,
                      status: OrderService.sCompleted,
                      gradient: [scheme.primary, scheme.primaryContainer],
                    ),
                    _summaryCard(
                      context: context,
                      label: '❌ Cancelled',
                      count: cancelled,
                      status: OrderService.sCancelled,
                      gradient: [scheme.error, scheme.errorContainer],
                    ),
                    _summaryCard(
                      context: context,
                      label: '↩️ Rejected/Refund',
                      count: rejected + refunded,
                      status: OrderService.sRejected,
                      gradient: [Colors.grey.shade700, Colors.grey.shade500],
                    ),
                    _summaryCard(
                      context: context,
                      label: '🔄 Deposit Return Pending',
                      count: depositReturnPending,
                      status: fDepositReturnPending,
                      gradient: [
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                    ),
                    _summaryCard(
                      context: context,
                      label: '🚩 Returns',
                      count: returns,
                      status: OrderService.sReturnPending,
                      gradient: [
                        scheme.error,
                        scheme.errorContainer,
                      ],
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      // Revenue Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.surfaceTint,
                              scheme.primary.withValues(alpha: 0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('စုစုပေါင်း Service Charges လက်ခံရရှိ',
                                style: textTheme.labelSmall?.copyWith(
                                    color: Colors.white70)),
                            const SizedBox(height: 6),
                            Text(
                              '${_currencyFmt.format(totalRevenue)} MMK',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Filter chip ────────────────────────────────────────────
              if (_filter != fAll)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text('Filter: $_filter',
                            style: textTheme.labelMedium),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              setState(() => _filter = fAll),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Order List ─────────────────────────────────────────────
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Order မရှိပါ')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _orderCard(filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}