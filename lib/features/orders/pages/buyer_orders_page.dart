// buyer_orders_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_navigator_keys.dart';
import '../../../data/models/order_model.dart';
import '../../../core/router/app_routes.dart';

class BuyerOrdersPage extends StatefulWidget {
  const BuyerOrdersPage({super.key});

  @override
  State<BuyerOrdersPage> createState() => _BuyerOrdersPageState();
}

class _BuyerOrdersPageState extends State<BuyerOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // -------------------------
  // ✅ Flow B statuses
  // -------------------------
  static const String sPaymentPending = "PAYMENT_PENDING";
  static const String sPaymentApproved = "PAYMENT_APPROVED";

  static const String sPickupOtpSent = "PICKUP_OTP_SENT";
  static const String sPickupConfirmed = "PICKUP_CONFIRMED";

  static const String sDeliveryOtpSent = "DELIVERY_OTP_SENT";
  static const String sPaymentHeld = "PAYMENT_HELD";
  static const String sDelivered = "DELIVERED";
  static const String sSettled = "SETTLED";

  static const String sCancelled = "CANCELLED";
  static const String sReturning = "RETURNING";
  static const String sReturned = "RETURNED";
  static const String sRefunded = "REFUNDED";
  static const String sFlagged = "FLAGGED";

  final _ordersRef = FirebaseFirestore.instance.collection('orders');

  // ---- Helpers ----
  String _getStr(Map<String, dynamic> d, String k) => (d[k] ?? "").toString();

  void _toast(String msg) {
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ show nicer label in UI
  String _labelForStatus(String s) {
    final x = s.trim().toUpperCase();
    switch (x) {
      case sPaymentPending:
        return "PAYMENT_PENDING";
      case sPaymentApproved:
        return "PAYMENT_APPROVED";
      case sPickupOtpSent:
        return "PICKUP_OTP_SENT";
      case sPickupConfirmed:
        return "PICKUP_CONFIRMED";
      case sDeliveryOtpSent:
        return "DELIVERY_OTP_SENT";
      case sPaymentHeld:
        return "PAYMENT_HELD";
      case sDelivered:
        return "DELIVERED";
      case sSettled:
        return "SETTLED";
      case sCancelled:
        return "CANCELLED";
      case sReturning:
        return "RETURNING";
      case sReturned:
        return "RETURNED";
      case sRefunded:
        return "REFUNDED";
      case sFlagged:
        return "FLAGGED";
      default:
        return x.isEmpty ? "-" : x;
    }
  }

  Color _badgeColor(ColorScheme scheme, String statusRaw) {
    final status = statusRaw.trim().toUpperCase();

    switch (status) {
      case sPaymentPending:
        return Colors.amber.withOpacity(0.18);

      case sPaymentApproved:
        return Colors.blue.withOpacity(0.18);

      case sPickupOtpSent:
      case sDeliveryOtpSent:
        return Colors.orange.withOpacity(0.18);

      case sPickupConfirmed:
      case sPaymentHeld:
        return Colors.teal.withOpacity(0.18);

      case sDelivered:
      case sSettled:
        return Colors.green.withOpacity(0.18);

      case sFlagged:
        return Colors.red.withOpacity(0.18);

      case sCancelled:
      case sReturned:
      case sRefunded:
        return Colors.grey.withOpacity(0.18);

      case sReturning:
        return Colors.purple.withOpacity(0.18);

      default:
        return scheme.surfaceVariant;
    }
  }

  String _storyLine(String statusRaw) {
    final status = _norm(statusRaw);
    switch (status) {
      case sDeliveryOtpSent:
        return "Give OTP to delivery person to receive item.";
      case sPaymentApproved:
        return "Seller preparing your item.";
      case sPaymentHeld:
        return "Item in transit. Payment secured in escrow.";
      case sDelivered:
        return "Item delivered successfully.";
      case sSettled:
        return "Funds released safely.";
      case sFlagged:
        return "Order under review for safety.";
      case sPickupOtpSent:
        return "Pickup in progress. Seller preparing handoff.";
      case sPickupConfirmed:
        return "Pickup confirmed. Delivery underway.";
      case sCancelled:
        return "Order cancelled.";
      case sReturned:
        return "Item returned.";
      case sRefunded:
        return "Refund issued.";
      case sReturning:
        return "Return in progress.";
      default:
        return "Order is being processed.";
    }
  }

  String _norm(String s) => s.trim().toUpperCase();

  bool _isActionRequired(Map<String, dynamic> d) {
    final status = _norm(_getStr(d, 'status'));
    if (status == sDeliveryOtpSent) return true;
    if (status == sFlagged) return true;
    if (status == sReturning) return true;
    return false;
  }

  bool _isInProgress(Map<String, dynamic> d) {
    final status = _norm(_getStr(d, 'status'));
    return status == sPaymentApproved ||
        status == sPickupOtpSent ||
        status == sPickupConfirmed ||
        status == sPaymentHeld;
  }

  bool _isCompleted(Map<String, dynamic> d) {
    final status = _norm(_getStr(d, 'status'));
    return status == sDelivered ||
        status == sSettled ||
        status == sCancelled ||
        status == sReturned ||
        status == sRefunded;
  }

  String _actionCtaLabel(String statusRaw) {
    final status = _norm(statusRaw);
    if (status == sDeliveryOtpSent) return "Show OTP";
    if (status == sFlagged || status == sReturning) return "Respond to issue";
    return "View details";
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
    bool Function(Map<String, dynamic>) test,
  ) {
    final out = all.where((doc) => test(doc.data())).toList();
    out.sort((a, b) {
      final da = _createdAtOf(a.data());
      final db = _createdAtOf(b.data());
      return db.compareTo(da);
    });
    return out;
  }

  Query<Map<String, dynamic>> _buyerQueryVisible(String buyerId) {
    return _ordersRef
        .where('buyerId', isEqualTo: buyerId)
        .where('buyerVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _buyerQueryAll(String buyerId) {
    return _ordersRef.where('buyerId', isEqualTo: buyerId).orderBy('createdAt', descending: true);
  }

  DateTime _createdAtOf(Map<String, dynamic> d) {
    final v = d['createdAt'];
    if (v is Timestamp) return v.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _openDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final id = doc.id.trim();
    if (id.isEmpty) {
      _toast("Order ID မရှိပါ (id empty)");
      return;
    }

    final o = OrderModel.fromMap(id, doc.data());

    context.push(
      AppRoutes.orderDetailPath(o.id),
      extra: {
        'order': o,
      },
    );
  }

  Widget _orderCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool showAction,
    required String indicatorText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final d = doc.data();
    final o = OrderModel.fromMap(doc.id, d);
    final statusRaw = _getStr(d, 'status');

    final title = o.productName.isNotEmpty ? o.productName : "Product";
    final isDone = indicatorText == "Completed";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone ? scheme.primaryContainer.withOpacity(0.35) : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: showAction ? scheme.primary : scheme.outlineVariant,
            width: showAction ? 4 : 1,
          ),
          top: BorderSide(color: scheme.outlineVariant),
          right: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.main(context).copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _badgeColor(scheme, statusRaw),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _labelForStatus(statusRaw),
              style: AppTextStyles.small(context).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _storyLine(statusRaw),
            style: AppTextStyles.main(context).copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showAction) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openDetails(doc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(_actionCtaLabel(statusRaw)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openDetails(doc),
                child: const Text("View details"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> list, {
    required bool showAction,
    required String indicatorText,
    required String emptyText,
  }) {
    if (list.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _orderCard(
        context,
        list[i],
        showAction: showAction,
        indicatorText: indicatorText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text("My Orders", style: AppTextStyles.heading(context)),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 0.5,
        ),
        body: const Center(child: Text("Login ဝင်ပြီးမှ Orders ကြည့်လို့ရမယ်")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("My Orders", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buyerQueryVisible(uid).snapshots(),
        builder: (context, snapVisible) {
          if (snapVisible.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapVisible.hasError) {
            return Center(child: Text("Error: ${snapVisible.error}"));
          }

          final visibleDocs = snapVisible.data?.docs ?? const [];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _buyerQueryAll(uid).snapshots(),
            builder: (context, snapAll) {
              if (snapAll.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapAll.hasError) {
                return Center(child: Text("Error: ${snapAll.error}"));
              }

              final allDocs = snapAll.data?.docs ?? const [];

              // ✅ Merge visible + old docs
              final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byId = {};

              for (final d in visibleDocs) {
                byId[d.id] = d;
              }

              for (final d in allDocs) {
                final data = d.data();
                final hasBuyerVisible = data.containsKey('buyerVisible');
                final buyerVisible = data['buyerVisible'];

                if (!hasBuyerVisible) {
                  byId[d.id] = d;
                  continue;
                }
                if (buyerVisible == true) {
                  byId[d.id] = d;
                }
              }

              final mergedDocs = byId.values.toList();

              mergedDocs.sort((a, b) {
                final da = _createdAtOf(a.data());
                final db = _createdAtOf(b.data());
                return db.compareTo(da);
              });

              if (mergedDocs.isEmpty) {
                return const Center(child: Text("Orders မရှိသေးပါ"));
              }

              final actionDocs = _filterDocs(mergedDocs, _isActionRequired);
              final inProgDocs = _filterDocs(mergedDocs, _isInProgress);
              final doneDocs = _filterDocs(mergedDocs, _isCompleted);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "🛡 Escrow Protection Active",
                            style: AppTextStyles.main(context).copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Funds are only released after confirmed delivery.",
                            style: AppTextStyles.small(context).copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: "🔔 Needs Your Action"),
                      Tab(text: "🚚 On The Way"),
                      Tab(text: "✅ Completed"),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _list(
                          actionDocs,
                          showAction: true,
                          indicatorText: "Action required",
                          emptyText: "No actions needed right now",
                        ),
                        _list(
                          inProgDocs,
                          showAction: false,
                          indicatorText: "On the way",
                          emptyText: "No orders on the way",
                        ),
                        _list(
                          doneDocs,
                          showAction: false,
                          indicatorText: "Completed",
                          emptyText: "No completed orders yet",
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
