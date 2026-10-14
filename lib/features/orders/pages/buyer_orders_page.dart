import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../core/widgets/expandable_text.dart';
import '../../../data/models/order_model.dart';
import 'package:timeago/timeago.dart' as timeago;

class BuyerOrdersPage extends StatefulWidget {
  const BuyerOrdersPage({super.key});

  @override
  State<BuyerOrdersPage> createState() => _BuyerOrdersPageState();
}

class _BuyerOrdersPageState extends State<BuyerOrdersPage> {
  static const String fAll           = 'ALL';
  static const String fPending       = 'PENDING';       // DEPOSIT_PENDING — approval စောင့်
  static const String fApproved      = 'APPROVED';      // DEPOSIT_APPROVED — seller ship စောင့်
  static const String fOnTheWay      = 'ON_THE_WAY';    // ပစ္စည်း လာနေဆဲ — confirm ရန်
  static const String fDepositPending= 'DEP_PENDING';   // FEE_PENDING — deposit ပြန်ရရန် စောင့်
  static const String fCompleted     = 'COMPLETED';
  static const String fReturns       = 'RETURNS';
  static const String fTerminal      = 'TERMINAL';      // cancelled / rejected / refunded

  String _filter = fAll;

  @override
  void initState() {
    super.initState();
    _markBuyerNotificationsAsRead();
  }

  Future<void> _markBuyerNotificationsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('targetRole', isEqualTo: 'buyer')
          .where('isRead', isEqualTo: false)
          .get();
      for (final doc in snap.docs) {
        doc.reference.update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BuyerOrdersPage markAsRead error: $e');
    }
  }

  // ─── Filter helpers ───────────────────────────────────────────────────────

  bool _matchFilter(OrderModel o, String filter) {
    return switch (filter) {
      fPending        => o.isPending,
      fApproved       => o.isApproved,
      fOnTheWay       => o.isOnTheWay,
      // deposit မပြန်ရသေးရင်သာ "Deposit Pending" — ပြန်ရပြီဆိုရင် Completed ထဲ ရောက်မည်
      fDepositPending => o.isFeePending && !o.depositReturned,
      fCompleted      => o.isCompleted || (o.isFeePending && o.depositReturned),
      fReturns        => o.isReturnPending || o.isReturnRejected || o.isReturnClaimed,
      fTerminal       => o.isCancelled || o.isRejected || o.isRefunded,
      _               => true,
    };
  }

  int _count(List<OrderModel> orders, String filter) =>
      orders.where((o) => _matchFilter(o, filter)).length;

  List<OrderModel> _applyFilter(List<OrderModel> orders) {
    if (_filter == fAll) return orders;
    return orders.where((o) => _matchFilter(o, _filter)).toList();
  }

  // ─── Status message for buyer ─────────────────────────────────────────────

  String _statusMessage(OrderModel o) {
    if (o.isPending) {
      return 'Admin approval စောင့်နေသည်';
    }
    if (o.isApproved) {
      return 'Seller မှ ပို့ဆောင်ရန် ပြင်ဆင်နေသည်';
    }
    if (o.isOnTheWay) {
      return 'ပစ္စည်း ပို့ဆောင်နေသည် — လက်ခံရရှိပါက confirm လုပ်ပေးပါ';
    }
    if (o.isFeePending) {
      return o.depositReturned
          ? 'Deposit ပြန်ရပြီးပါပြီ ✅'
          : 'ပစ္စည်းလက်ခံပြီးပါပြီ — Deposit ပြန်ရရန် စောင့်ဆိုင်းပါ';
    }
    if (o.isCompleted) {
      return o.depositReturned
          ? 'Deposit ပြန်ရပြီးပါပြီ ✅'
          : 'Deposit ပြန်လွှဲရန် Admin မှ ဆောင်ရွက်နေသည်';
    }
    if (o.isCancelled) {
      return 'Order ပယ်ဖျက်ထားသည်';
    }
    if (o.isRejected) {
      return 'Admin မှ Reject လုပ်ပါသည်';
    }
    if (o.isRefunded) {
      return o.refundedTo == 'seller'
          ? 'Return ပယ်ချ၍ Seller ထံ Delivery ခ လွှဲပေးလိုက်ပါပြီ'
          : 'Deposit ပြန်အမ်းပြီးပါပြီ';
    }
    if (o.isReturnRejected) {
      return 'Return Request ကို ပယ်ချထားသည် (Admin အကြောင်းပြချက် စစ်ဆေးပါ)';
    }
    if (o.isReturnClaimed) {
      return 'Seller မှ Delivery ခ Claim တင်ထားသည် — Admin အတည်ပြုပေးပါမည်';
    }
    return '';
  }

  // ─── Summary Card ─────────────────────────────────────────────────────────

  Widget _summaryCard({
    required String label,
    required int count,
    required String filter,
    required List<Color> gradient,
    bool urgent = false,
  }) {
    final selected = _filter == filter;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
                  )
                ]
              : [],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (urgent && count > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('!',
                        style: textTheme.labelSmall?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                Text('$count',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white,
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

  Widget _orderCard(OrderModel o) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color statusColor = scheme.onSurfaceVariant;
    if (o.isPending)   statusColor = scheme.secondary;
    if (o.isApproved)  statusColor = scheme.primary;
    if (o.isOnTheWay)  statusColor = scheme.primary;
    if (o.isFeePending && !o.depositReturned) statusColor = const Color(0xFFE65100);
    if (o.isFeePending && o.depositReturned)  statusColor = scheme.tertiary;
    if (o.isCompleted)                        statusColor = scheme.tertiary;
    if (o.isCancelled || o.isRejected)   statusColor = scheme.error;
    if (o.isRefunded)  statusColor = scheme.onSurfaceVariant;

    // Highlight border for on-the-way (action needed from buyer)
    final borderColor = o.isOnTheWay
        ? scheme.primary.withValues(alpha: 0.5)
        : scheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(AppRoutes.orderDetail, extra: {'orderId': o.id}),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product name + status badge ──────────────────────────
            Row(
              children: [
                Expanded(child: Text(o.productName, style: textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    o.isFeePending && o.depositReturned
                        ? '🎉 Completed'
                        : o.isFeePending
                            ? '🕐 Deposit ပြန်ရရန် စောင့်ဆိုင်းပါ'
                            : '${o.statusEmoji} ${o.statusLabel}',
                    style: textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Price: ${o.formattedPrice}', style: textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text('Seller: ${o.sellerName}', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (o.depositReturned)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
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
                              (o.refundedTo == 'seller') ? 'Delivery ခ လွှဲပြီး' : 'Deposit ပြန်ရပြီး',
                              style: textTheme.labelSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    if (o.createdAt != null)
                      Text(
                        'Ordered: ${timeago.format(o.createdAt!.toDate())}',
                        style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9),
                      ),
                    if (o.updatedAt != null && 
                        o.updatedAt!.seconds > (o.createdAt?.seconds ?? 0) + 60)
                      Text(
                        'Updated: ${timeago.format(o.updatedAt!.toDate())}',
                        style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(_statusMessage(o), style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),

            // ── Reject reason ────────────────────────────────────────
            if (o.isRejected && o.rejectReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              ExpandableText(
                text: 'Reason: ${o.rejectReason}',
                style: textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
                maxLines: 2,
              ),
            ],

            // ── CTA hint for on-the-way ──────────────────────────────
            if (o.isOnTheWay) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 14, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text('ပစ္စည်းရရင် Confirm လုပ်ပေးပါ', style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
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
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final uid       = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Login ဝင်ပြီးမှ Orders ကြည့်လို့ရမယ်')));
    }

    return Scaffold(
      appBar: BrandAppBar(title: 'My Orders'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('buyerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allOrders = (snapshot.data?.docs ?? [])
              .map((d) => OrderModel.fromMap(d.id, d.data()))
              .toList();

          final filtered = _applyFilter(allOrders);

          final cPending        = _count(allOrders, fPending);
          final cApproved       = _count(allOrders, fApproved);
          final cOnTheWay       = _count(allOrders, fOnTheWay);
          final cDepositPending = _count(allOrders, fDepositPending);
          final cCompleted      = _count(allOrders, fCompleted);
          final cReturns        = _count(allOrders, fReturns);
          final cTerminal       = _count(allOrders, fTerminal);

          return MaxWidthBox(
            child: CustomScrollView(
              slivers: [
                // ── Summary Cards ──────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.7,
                    children: [
                      _summaryCard(
                        label: '💰 Pending',
                        count: cPending,
                        filter: fPending,
                        gradient: [scheme.tertiary, scheme.tertiaryContainer],
                      ),
                      _summaryCard(
                        label: '✅ Approved',
                        count: cApproved,
                        filter: fApproved,
                        gradient: [scheme.secondary, scheme.secondaryContainer],
                      ),
                      _summaryCard(
                        label: '🚚 On The Way',
                        count: cOnTheWay,
                        filter: fOnTheWay,
                        gradient: [
                          const Color(0xFF1565C0),
                          const Color(0xFF42A5F5)
                        ],
                        urgent: true,
                      ),
                      _summaryCard(
                        label: '💰 Deposit\nPending',
                        count: cDepositPending,
                        filter: fDepositPending,
                        gradient: [
                          const Color(0xFFE65100),
                          const Color(0xFFFF8A65)
                        ],
                      ),
                      _summaryCard(
                        label: '🎉 Completed',
                        count: cCompleted,
                        filter: fCompleted,
                        gradient: [scheme.primary, scheme.primaryContainer],
                      ),
                      _summaryCard(
                        label: '🚩 Returns',
                        count: cReturns,
                        filter: fReturns,
                        gradient: [
                          scheme.error,
                          scheme.errorContainer.withValues(alpha: 0.8)
                        ],
                        urgent: true,
                      ),
                      _summaryCard(
                        label: '❌ Cancelled /\nRejected',
                        count: cTerminal,
                        filter: fTerminal,
                        gradient: [Colors.grey.shade700, Colors.grey.shade500],
                      ),
                    ],
                  ),
                ),

                // ── Filter label ───────────────────────────────────────
                if (_filter != fAll)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text('Filter: $_filter', style: textTheme.labelMedium),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _filter = fAll),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Order List ─────────────────────────────────────────
                filtered.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Order မရှိပါ', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.hPadding,
                          vertical: 8,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _orderCard(filtered[i]),
                            ),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
