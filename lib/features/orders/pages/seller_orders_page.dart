import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../app_features.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ---- Flow B statuses ----
  static const String sPayPending = 'PAYMENT_PENDING';
  static const String sPayApproved = 'PAYMENT_APPROVED';

  // ---- Status groups ----
  static const List<String> inProgressStatuses = [
    'PICKUP_OTP_SENT',
    'PICKUP_CONFIRMED',
    'DELIVERY_OTP_SENT',
    'PAYMENT_HELD',
  ];

  static const List<String> doneStatuses = [
    'DELIVERED',
    'SETTLED',
    'CANCELLED',
    'RETURNED',
    'REFUNDED',
  ];

  static const List<String> flaggedStatuses = ['FLAGGED'];

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

  // ---------- basic helpers ----------
  String _norm(String s) => s.trim().toUpperCase();

  String _getStr(Map<String, dynamic> d, String k) => (d[k] ?? '').toString().trim();

  bool _getBool(Map<String, dynamic> d, String k, {bool fallback = false}) {
    final v = d[k];
    if (v is bool) return v;
    return fallback;
  }

  bool _sellerVisible(Map<String, dynamic> d) => _getBool(d, 'sellerVisible', fallback: true);

  bool _sellerAccepted(Map<String, dynamic> d) => _getBool(d, 'sellerAccepted', fallback: false);

  bool _sellerRejected(Map<String, dynamic> d) => _getBool(d, 'sellerRejected', fallback: false);

  DateTime _createdAtOf(Map<String, dynamic> d) {
    final v = d['createdAt'];
    if (v is Timestamp) return v.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ---------- status label ----------
  String _mmStatus(String raw) {
    switch (_norm(raw)) {
      case sPayPending:
        return 'Payment စောင့် (Pending)';
      case sPayApproved:
        return 'Payment OK (Approved)';

      case 'NEW':
        return 'အသစ် (New)';

      case 'PICKUP_OTP_SENT':
        return 'Pickup OTP ပို့ပြီး';
      case 'PICKUP_CONFIRMED':
        return 'Pickup အတည်ပြုပြီး';
      case 'DELIVERY_OTP_SENT':
        return 'Drop OTP ပို့ပြီး';
      case 'PAYMENT_HELD':
        return 'Escrow ထိန်းထား';
      case 'DELIVERED':
        return 'ပို့ပြီး';
      case 'SETTLED':
        return 'ငွေလွှဲပြီး';
      case 'CANCELLED':
        return 'ဖျက်ပြီး';
      case 'RETURNED':
        return 'ပြန်ရောက်';
      case 'REFUNDED':
        return 'Refund ပြန်';
      case 'FLAGGED':
        return '⚠️ Flagged';
      default:
        return raw.trim().isEmpty ? '-' : raw.trim();
    }
  }

  // ---------- Reject reason dialog (safe dispose AFTER pop animation) ----------
  Future<String?> _askRejectReason(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text("Reject Order", style: AppTextStyles.heading(context)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Buyer ဘက်မှာ Reject reason ကို မြင်ရပါမယ်။",
                  style: AppTextStyles.small(context),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: controller,
                  maxLines: 3,
                  maxLength: 200,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: "Reject reason (ဥပမာ - Stock မရှိတော့ပါ)",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final r = (v ?? '').trim();
                    if (r.length < 3) return "Reject reason အနည်းဆုံး 3 လုံး ထည့်ပါ";
                    if (r.length > 200) return "Reject reason (max 200) ကျော်နေပါတယ်";
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogCtx, controller.text.trim());
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      controller.dispose();
    });

    return res;
  }

  // ---------- Classification (Flow B) ----------
  bool _isActionRequired(Map<String, dynamic> d) {
    final status = _norm(_getStr(d, 'status'));
    if (_sellerAccepted(d)) return false;
    if (_sellerRejected(d)) return false;
    if (status == sPayApproved) return true;
    if (flaggedStatuses.contains(status)) return true;
    return false;
  }

  bool _isInProgress(Map<String, dynamic> d) {
    final status = _norm(_getStr(d, 'status'));
    if (_sellerRejected(d)) return false;
    if (!_sellerAccepted(d)) return false;
    return inProgressStatuses.contains(status);
  }

  bool _isDone(Map<String, dynamic> d) {
    final status = _norm(_getStr(d, 'status'));
    if (_sellerRejected(d)) return true;
    return doneStatuses.contains(status);
  }

  // ---------- filter + sort ----------
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
      bool Function(Map<String, dynamic>) test,
      ) {
    final out = all.where((doc) {
      final d = doc.data();
      if (!_sellerVisible(d)) return false;
      return test(d);
    }).toList();

    out.sort((a, b) {
      final da = _createdAtOf(a.data());
      final db = _createdAtOf(b.data());
      return db.compareTo(da);
    });

    return out;
  }

  Widget _buildSegmentedControl(int index, int actionCount, int progressCount, int doneCount) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          height: 46,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: scheme.outlineVariant.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = constraints.maxWidth / 3;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      left: segmentWidth * index,
                      top: 0,
                      bottom: 0,
                      width: segmentWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _segmentItem("Action Required", actionCount, index == 0, () {
                          if (_tabController.index != 0) {
                            _tabController.animateTo(0);
                          }
                        }),
                        _segmentItem("In Progress", progressCount, index == 1, () {
                          if (_tabController.index != 1) {
                            _tabController.animateTo(1);
                          }
                        }),
                        _segmentItem("Completed", doneCount, index == 2, () {
                          if (_tabController.index != 2) {
                            _tabController.animateTo(2);
                          }
                        }),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _segmentItem(String title, int count, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final fontWeight = selected ? FontWeight.w800 : FontWeight.w600;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: fontWeight,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, OrderModel o) {
    final s = _norm(o.status);
    if (AppFeatures.otpDeliveryEnabled && s == 'PICKUP_OTP_SENT') {
      context.push(AppRoutes.pickupOtpPath(o.id));
      return;
    }

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
    required bool showActions,
    required String indicatorText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final d = doc.data();

    final o = OrderModel.fromMap(doc.id, d);

    final statusRaw = _getStr(d, 'status');
    final statusN = _norm(statusRaw);

    final accepted = _sellerAccepted(d);
    final rejected = _sellerRejected(d);
    final isFlagged = flaggedStatuses.contains(statusN);

    // ✅ FIX: accepted badge should show regardless of status (since status changes to PICKUP_OTP_SENT)
    final badgeText =
        rejected ? 'Rejected' : (accepted ? 'Accepted' : _mmStatus(statusRaw));

    return Container(
      padding: const EdgeInsets.all(12),
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
                  o.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.main(context).copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFlagged) ...[
                    const Icon(Icons.warning_amber_rounded, size: 18),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    indicatorText,
                    style: AppTextStyles.small(context).copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              badgeText,
              style: AppTextStyles.small(context).copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),

          Text(
            "${o.productPrice} • Qty: ${o.quantity}",
            style: AppTextStyles.main(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),

          Text(
            "Buyer: ${o.buyerName}",
            style: AppTextStyles.small(context).copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Address: ${o.deliveryAddress}",
                style: AppTextStyles.small(context)
                    .copyWith(color: scheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                "Phone: ${o.buyerPhone}",
                style: AppTextStyles.small(context)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),

          if (showActions) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _norm(statusRaw) == 'PAYMENT_APPROVED'
                    ? () async {
                        try {
                          await OrderService.sellerMarkShippedR(
                            orderId: o.id,
                            deliveryService: "Seller Delivery",
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Marked Shipped ✅")),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 44),
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text("Accept / Mark as Shipped"),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _norm(statusRaw) == 'PAYMENT_APPROVED'
                    ? () async {
                        final r = await _askRejectReason(context);
                        if (r == null) return;
                        try {
                          await OrderService.sellerReject(orderId: o.id, reason: r);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Rejected ❌")),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text("Reject"),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openDetails(context, o),
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
        required bool showActions,
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
      itemBuilder: (c, i) => _orderCard(
        c,
        list[i],
        showActions: showActions,
        indicatorText: indicatorText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text("Seller Orders", style: AppTextStyles.heading(context)),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(AppRoutes.signup),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Login / Signup လုပ်ပါ"),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Seller Orders", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: OrderService.sellerOrdersStream(user.uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 58);
              }
              if (snap.hasError) {
                return const SizedBox(height: 58);
              }

              final docs = snap.data?.docs ?? const [];

              final actionDocs = _filterDocs(docs, _isActionRequired);
              final inProgDocs = _filterDocs(docs, _isInProgress);
              final doneDocs = _filterDocs(docs, _isDone);

              return AnimatedBuilder(
                animation: _tabController.animation!,
                builder: (context, _) {
                  final index = _tabController.index;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: _buildSegmentedControl(
                      index,
                      actionDocs.length,
                      inProgDocs.length,
                      doneDocs.length,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: OrderService.sellerOrdersStream(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }

          final docs = snap.data?.docs ?? const [];

          final actionDocs = _filterDocs(docs, _isActionRequired);
          final inProgDocs = _filterDocs(docs, _isInProgress);
          final doneDocs = _filterDocs(docs, _isDone);

          return TabBarView(
            controller: _tabController,
            children: [
              _list(
                actionDocs,
                showActions: true,
                indicatorText: "Action required",
                emptyText: "No orders need your action",
              ),
              _list(
                inProgDocs,
                showActions: false,
                indicatorText: "In progress",
                emptyText: "No orders in progress",
              ),
              _list(
                doneDocs,
                showActions: false,
                indicatorText: "Completed",
                emptyText: "No completed orders yet",
              ),
            ],
          );
        },
      ),
    );
  }
}
