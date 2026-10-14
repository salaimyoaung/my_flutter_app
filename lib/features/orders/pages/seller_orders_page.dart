import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';
import '../../../core/widgets/expandable_text.dart';
import 'package:timeago/timeago.dart' as timeago;

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  static const String fAll        = 'ALL';
  static const String fAction     = 'ACTION';      // DEPOSIT_APPROVED — ship လုပ်ရမည်
  static const String fInProgress = 'IN_PROGRESS'; // ON_THE_WAY
  static const String fFeePending = 'FEE_PENDING'; // buyer confirm ပြီး — fee ပေးရမည်
  static const String fReturns    = 'RETURNS';
  static const String fCompleted  = 'COMPLETED';
  static const String fTerminal   = 'TERMINAL';    // cancelled / rejected / refunded

  String _filter = fAll;

  @override
  void initState() {
    super.initState();
    _markSellerNotificationsAsRead();
  }

  Future<void> _markSellerNotificationsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('targetRole', isEqualTo: 'seller')
          .where('isRead', isEqualTo: false)
          .where('type', whereNotIn: ['model_request'])
          .get();
      for (final doc in snap.docs) {
        doc.reference.update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SellerOrdersPage markAsRead error: $e');
    }
  }

  int _count(List<OrderModel> orders, String filter) {
    return orders.where((o) => _matchFilter(o, filter)).length;
  }

  bool _matchFilter(OrderModel o, String filter) {
    return switch (filter) {
      fAction     => o.isApproved,
      fInProgress => o.isOnTheWay,
      fFeePending => o.isFeePending,
      fReturns    => o.isReturnPending || o.isReturnRejected || o.isReturnClaimed,
      fCompleted  => o.isCompleted,
      fTerminal   => o.isCancelled || o.isRejected || o.isRefunded,
      _           => true,
    };
  }

  List<OrderModel> _applyFilter(List<OrderModel> orders) {
    if (_filter == fAll) return orders;
    return orders.where((o) => _matchFilter(o, _filter)).toList();
  }

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
                Text(
                  '$count',
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                ),
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

  Widget _orderCard(OrderModel o) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color statusColor = scheme.primary;
    if (o.isApproved)    statusColor = scheme.secondary;
    if (o.isFeePending)  statusColor = scheme.error;
    if (o.isCompleted)   statusColor = scheme.tertiary;
    if (o.isCancelled || o.isRejected || o.isRefunded) statusColor = scheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(AppRoutes.orderDetailPath(o.id), extra: {'orderId': o.id}),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: o.isApproved
                ? scheme.secondary.withValues(alpha: 0.5)
                : o.isFeePending
                    ? scheme.error.withValues(alpha: 0.5)
                    : scheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    '${o.statusEmoji} ${o.statusLabel}',
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
                      Text('${o.formattedPrice}  •  Qty ${o.quantity}', style: textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text('Buyer: ${o.buyerName}', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
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
                              (o.refundedTo == 'seller') ? 'Delivery ခ ရပြီး' : 'Refund လုပ်ပြီး',
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

            if (o.isRejected && o.rejectReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              ExpandableText(
                text: 'Reason: ${o.rejectReason}',
                style: textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
                maxLines: 2,
              ),
            ],

            if (o.isApproved) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 14, color: scheme.secondary),
                  const SizedBox(width: 4),
                  Text('Ship လုပ်ရန် ကျန်နေသည်', style: textTheme.labelSmall?.copyWith(color: scheme.secondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ],

            if (o.isFeePending && o.feeProofUrl.isEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: scheme.error),
                  const SizedBox(width: 4),
                  Text('Service charge လွှဲရန် ကျန်နေသည်', style: textTheme.labelSmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600)),
                ],
              ),
            ],

            if (o.isFeePending && o.feeProofUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('Admin confirm စောင့်နေသည်', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Login Required')));
    }

    return Scaffold(
      appBar: BrandAppBar(title: 'Seller Orders'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: OrderService.sellerOrdersStream(user.uid),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final allOrders = snap.data!.docs
              .map((d) => OrderModel.fromMap(d.id, d.data()))
              .toList();

          final filtered = _applyFilter(allOrders);

          final cAction     = _count(allOrders, fAction);
          final cInProgress = _count(allOrders, fInProgress);
          final cFeePending = _count(allOrders, fFeePending);
          final cReturns    = _count(allOrders, fReturns);
          final cCompleted  = _count(allOrders, fCompleted);
          final cTerminal   = _count(allOrders, fTerminal);

          return MaxWidthBox(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.7,
                    children: [
                      _summaryCard(
                        label: '📦 Action\nRequired',
                        count: cAction,
                        filter: fAction,
                        gradient: [scheme.secondary, scheme.secondaryContainer],
                        urgent: true,
                      ),
                      _summaryCard(
                        label: '🚚 In\nProgress',
                        count: cInProgress,
                        filter: fInProgress,
                        gradient: [
                          const Color(0xFF1565C0),
                          const Color(0xFF42A5F5)
                        ],
                      ),
                      _summaryCard(
                        label: '⏳ Fee\nPending',
                        count: cFeePending,
                        filter: fFeePending,
                        gradient: [
                          scheme.error,
                          scheme.error.withValues(alpha: 0.6)
                        ],
                        urgent: true,
                      ),
                      _summaryCard(
                        label: '🚩 Returns',
                        count: cReturns,
                        filter: fReturns,
                        gradient: [
                          scheme.error,
                          scheme.error.withValues(alpha: 0.6)
                        ],
                        urgent: true,
                      ),
                      _summaryCard(
                        label: '🎉 Completed',
                        count: cCompleted,
                        filter: fCompleted,
                        gradient: [scheme.primary, scheme.primaryContainer],
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
