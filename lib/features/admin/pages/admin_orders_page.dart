// admin_orders_page.dart (Flow B + Prepare Drop)
// ✅ Admin does:
// 1) PAYMENT_PENDING -> PAYMENT_APPROVED
// 2) PICKUP_CONFIRMED -> (prepare drop) -> DELIVERY_OTP_SENT
//    (hash-only fields on order doc) + returns RAW token
//
// Requires: OrderService.adminPrepareDrop(orderId: ...) -> returns token string

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Clipboard
import 'package:cloud_functions/cloud_functions.dart';
import '../../../app_styles.dart';
import '../../../data/services/order_service.dart';
import '../../../app_features.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {

  Future<void> callAdminPrepareDrop(BuildContext context, String orderId) async {
    try {
      final callable =
      FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('adminPrepareDrop');

      final res = await callable.call({"orderId": orderId});

      final data = Map<String, dynamic>.from(res.data as Map);
      final link = (data["deliveryLink"] ?? "").toString();
      final otp = (data["dropOtp"] ?? "").toString();

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Drop Prepared ✅"),
          content: SelectableText(
            "Order: $orderId\n\nDelivery Link:\n$link\n\nDrop OTP:\n$otp",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("adminPrepareDrop error: $e")),
      );
    }
  }
  // ---- Status constants (Flow B) ----
  static const String sPaymentPending = "PAYMENT_PENDING";
  static const String sPaymentApproved = "PAYMENT_APPROVED";

  static const String sPickupOtpSent = "PICKUP_OTP_SENT";
  static const String sPickupConfirmed = "PICKUP_CONFIRMED";

  // ✅ Drop stage
  static const String sDeliveryOtpSent = "DELIVERY_OTP_SENT";

  static const String sCancelled = "CANCELLED";
  static const String sFlagged = "FLAGGED";

  static const String fAll = "ALL";
  String _filter = fAll;

  final CollectionReference<Map<String, dynamic>> _ordersRef =
  FirebaseFirestore.instance.collection('orders');

  /// ✅ Busy lock PER-ORDER
  final ValueNotifier<Set<String>> _busyIds =
  ValueNotifier<Set<String>>(<String>{});

  // ✅ Change this later to your real hosted URL
  // Example:
  // static const String kDeliveryVerifyBaseUrl = "https://yourapp.web.app/verify";
  static const String kDeliveryVerifyBaseUrl = "https://YOUR_DOMAIN/verify";

  // ---------------- Helpers ----------------
  String _maskPhone(String? p) {
    final s = (p ?? "").trim();
    if (s.length <= 4) return s;
    return "${s.substring(0, 2)}******${s.substring(s.length - 2)}";
  }

  String _getStr(Map<String, dynamic> d, String k) =>
      (d[k] ?? "").toString().trim();

  int _countBy(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      String status,
      ) {
    return docs.where((x) => _getStr(x.data(), 'status') == status).length;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilter(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    if (_filter == fAll) return docs;
    return docs.where((x) => _getStr(x.data(), 'status') == _filter).toList();
  }

  Color _badgeColor(ColorScheme scheme, String status) {
    switch (status) {
      case sPaymentPending:
        return Colors.orange.withOpacity(0.18);
      case sPaymentApproved:
        return Colors.blue.withOpacity(0.18);
      case sPickupOtpSent:
        return Colors.orange.withOpacity(0.18);
      case sPickupConfirmed:
        return Colors.teal.withOpacity(0.18);
      case sDeliveryOtpSent:
        return Colors.deepPurple.withOpacity(0.18);
      case sFlagged:
        return Colors.red.withOpacity(0.18);
      case sCancelled:
        return Colors.grey.withOpacity(0.18);
      default:
        return scheme.surfaceVariant;
    }
  }

  // ✅ Reserve height so card doesn't jump when actions change
  double _actionsReservedHeight(String status) {
    if (status == sPaymentPending) return 56; // approve only
    if (status == sPickupConfirmed) return 56; // prepare drop
    return 0;
  }

  Future<void> fixMissingPhoneModels() async {
    try {
      final productsSnap =
          await FirebaseFirestore.instance.collection('products').get();
      final processed = <String>{};

      for (final doc in productsSnap.docs) {
        final data = doc.data();
        final brand = (data['brand'] ?? '').toString().trim();
        final model = (data['model'] ?? '').toString().trim();
        if (brand.isEmpty || model.isEmpty) continue;

        final brandId = brand.toLowerCase();
        final modelId = model.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final docId = "${brandId}__${modelId}";
        if (processed.contains(docId)) continue;
        processed.add(docId);

        final ref = FirebaseFirestore.instance.collection('phone_models').doc(docId);
        final snap = await ref.get();
        if (snap.exists) continue;

        await ref.set({
          'brand': brand,
          'model': model,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("Created phone_models: $docId");
      }
    } catch (e) {
      print("fixMissingPhoneModels error: $e");
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied ✅")),
    );
  }

  // =========================================================
  // ✅ ACTION 1: Approve Payment
  // =========================================================
  Future<void> _approvePayment(String orderId) async {
    final currentBusy = Set<String>.from(_busyIds.value);
    if (currentBusy.contains(orderId)) return;
    _busyIds.value = {...currentBusy, orderId};

    try {
      await OrderService.adminApproveDepositR(orderId: orderId, approved: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PAYMENT_APPROVED ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Approve error: $e")),
      );
    } finally {
      final after = Set<String>.from(_busyIds.value);
      after.remove(orderId);
      _busyIds.value = after;
    }
  }

  Future<void> _confirmApprove({required String orderId}) async {
    final scheme = Theme.of(context).colorScheme;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text("Approve payment?", style: AppTextStyles.heading(context)),
        content: Text(
          "Buyer ငွေဝင်ပြီးသားဆိုတာ အတည်ပြုပြီး\n"
              "status ကို PAYMENT_APPROVED သို့ ပြောင်းမယ်။",
          style: AppTextStyles.main(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Approve"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _approvePayment(orderId);
    }
  }

  Future<void> _rejectPayment(String orderId) async {
    final currentBusy = Set<String>.from(_busyIds.value);
    if (currentBusy.contains(orderId)) return;
    _busyIds.value = {...currentBusy, orderId};

    try {
      await OrderService.adminApproveDepositR(orderId: orderId, approved: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Deposit Rejected ❌")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reject error: $e")),
      );
    } finally {
      final after = Set<String>.from(_busyIds.value);
      after.remove(orderId);
      _busyIds.value = after;
    }
  }
  // =========================================================
  // ✅ ACTION 2: Prepare Drop (Admin)
  // - calls OrderService.adminPrepareDrop(orderId)
  // - gets raw token back, show dialog with token+link+copy
  // =========================================================
  Future<void> _prepareDrop(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }

    final currentBusy = Set<String>.from(_busyIds.value);
    if (currentBusy.contains(orderId)) return;
    _busyIds.value = {...currentBusy, orderId};

    try {
      // ✅ returns RAW token (admin will send to delivery)
      final token = await OrderService.adminPrepareDrop(orderId: orderId);

      // build link
      final link = Uri.parse(kDeliveryVerifyBaseUrl)
          .replace(queryParameters: {'orderId': orderId, 'token': token})
          .toString();

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) {
          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: scheme.surface,
            title: Text("Prepare Drop ✅", style: AppTextStyles.heading(context)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Delivery သို့ ပို့မယ့် one-time link ကို copy လုပ်ပြီး SMS/Chat နဲ့ပို့ပါ။",
                    style: AppTextStyles.main(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Token:",
                    style: AppTextStyles.small(context)
                        .copyWith(fontWeight: FontWeight.w900),
                  ),
                  SelectableText(token, style: AppTextStyles.small(context)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _copy(token),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text("Copy Token"),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Link:",
                    style: AppTextStyles.small(context)
                        .copyWith(fontWeight: FontWeight.w900),
                  ),
                  SelectableText(link, style: AppTextStyles.small(context)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _copy(link),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text("Copy Link"),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "မှတ်ချက်: buyer ရဲ့ drop OTP ကို buyer တစ်ယောက်ပဲ သိမယ်။\n"
                        "Delivery က link ထဲ OTP ထည့်မှ Delivered confirm ဖြစ်မယ်။",
                    style: AppTextStyles.small(context),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("DELIVERY_OTP_SENT ✅ (prepared)")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Prepare drop error: $e")),
      );
    } finally {
      final after = Set<String>.from(_busyIds.value);
      after.remove(orderId);
      _busyIds.value = after;
    }
  }

  Future<void> _confirmPrepareDrop({required String orderId}) async {
    final scheme = Theme.of(context).colorScheme;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text("Prepare Drop?", style: AppTextStyles.heading(context)),
        content: Text(
          "Pickup Confirmed ဖြစ်ပြီးသား order ကို\n"
              "Drop stage အတွက် token + OTP (hash) ပြင်ဆင်မယ်။\n\n"
              "လုပ်မလား?",
          style: AppTextStyles.main(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Prepare"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _prepareDrop(orderId);
    }
  }

  // ---------------- Summary Card ----------------
  Widget _summaryCard({
    required ColorScheme scheme,
    required String title,
    required int count,
    required String filterStatus,
    required Color tint,
    required IconData icon,
  }) {
    final selected = _filter == filterStatus;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _filter = filterStatus),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? tint.withOpacity(0.35) : tint.withOpacity(0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onSurface),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.small(context)
                    .copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "$count",
              style: AppTextStyles.main(context)
                  .copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _busyIds.dispose();
    super.dispose();
  }

  // ---------------- Main UI ----------------
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text("Admin Orders", style: AppTextStyles.heading(context)),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 0.5,
        ),
        body: const Center(child: Text("Login ဝင်ပြီးမှ Admin Orders ကြည့်လို့ရမယ်")),
      );
    }

    // ✅ Admin role guard (nice UX; rules will still protect)
    final adminDocStream =
    FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: adminDocStream,
      builder: (context, adminSnap) {
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final role = (adminSnap.data?.data()?['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final isAdmin = role == 'admin';

        if (!isAdmin) {
          return Scaffold(
            backgroundColor: AppColors.background(context),
            appBar: AppBar(
              title: Text("Admin Orders", style: AppTextStyles.heading(context)),
              backgroundColor: scheme.surface,
              foregroundColor: scheme.onSurface,
              elevation: 0.5,
            ),
            body: const Center(child: Text("Admin မဟုတ်ပါ")),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background(context),
          appBar: AppBar(
            title: Text("Admin Orders", style: AppTextStyles.heading(context)),
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            elevation: 0.5,
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ordersRef
                .where('createdAt', isGreaterThan: Timestamp(0, 0))
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text("Error: ${snap.error}"));
              }

              final docs = snap.data?.docs ?? [];
              final filtered = _applyFilter(docs);

              final cPending = _countBy(docs, sPaymentPending);
              final cApproved = _countBy(docs, sPaymentApproved);
              final cPickupSent = _countBy(docs, sPickupOtpSent);
              final cPickupConfirmed = _countBy(docs, sPickupConfirmed);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: fixMissingPhoneModels,
                            child: const Text("Fix Missing Phone Models"),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _summaryCard(
                          scheme: scheme,
                          title: "Payment Pending",
                          count: cPending,
                          filterStatus: sPaymentPending,
                          tint: Colors.orange,
                          icon: Icons.pending_actions,
                        ),
                        const SizedBox(height: 10),
                        _summaryCard(
                          scheme: scheme,
                          title: "Payment Approved",
                          count: cApproved,
                          filterStatus: sPaymentApproved,
                          tint: Colors.blue,
                          icon: Icons.verified_outlined,
                        ),
                        const SizedBox(height: 10),
                        AppFeatures.otpDeliveryEnabled ? Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                scheme: scheme,
                                title: "Pickup OTP Sent",
                                count: cPickupSent,
                                filterStatus: sPickupOtpSent,
                                tint: Colors.orange,
                                icon: Icons.qr_code_2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _summaryCard(
                                scheme: scheme,
                                title: "Pickup Confirmed",
                                count: cPickupConfirmed,
                                filterStatus: sPickupConfirmed,
                                tint: Colors.teal,
                                icon: Icons.check_circle_outline,
                              ),
                            ),
                          ],
                        ) : const SizedBox.shrink(),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text("Filter:", style: AppTextStyles.small(context)),
                              ChoiceChip(
                                label: const Text("ALL"),
                                selected: _filter == fAll,
                                onSelected: (_) => setState(() => _filter = fAll),
                                showCheckmark: false,
                              ),
                              Text(
                                _filter == fAll ? "Showing all" : "Status: $_filter",
                                style: AppTextStyles.small(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text("No orders"))
                        : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final doc = filtered[i];
                        final d = doc.data();

                        final status = _getStr(d, 'status');
                        final productName = _getStr(d, 'productName');
                        final productPrice = _getStr(d, 'productPrice');
                        final sellerName = _getStr(d, 'sellerName');
                        final buyerName = _getStr(d, 'buyerName');
                        final buyerPhone = _maskPhone(_getStr(d, 'buyerPhone'));

                        final txId = _getStr(d, 'paymentTxId');
                        final proofUrl = _getStr(d, 'paymentProofUrl');
                        final proofStatus = _getStr(d, 'paymentProofStatus');

                        final reservedH = _actionsReservedHeight(status);

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
                                      productName.isEmpty ? "Product" : productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.main(context)
                                          .copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _badgeColor(scheme, status),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      status,
                                      style: AppTextStyles.small(context)
                                          .copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Seller: $sellerName",
                                      style: AppTextStyles.small(context),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    productPrice.isEmpty ? "" : productPrice,
                                    style: AppTextStyles.price(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Buyer: $buyerName ($buyerPhone)",
                                style: AppTextStyles.small(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // ✅ Payment proof info
                              if (status == sPaymentPending &&
                                  (txId.isNotEmpty ||
                                      proofUrl.isNotEmpty ||
                                      proofStatus.isNotEmpty)) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: scheme.outlineVariant),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Buyer Payment Proof",
                                        style: AppTextStyles.small(context)
                                            .copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 6),
                                      if (proofStatus.isNotEmpty)
                                        Text("Status: $proofStatus",
                                            style: AppTextStyles.small(context)),
                                      if (txId.isNotEmpty)
                                        Text("TxID: $txId",
                                            style: AppTextStyles.small(context)),
                                      if (proofUrl.isNotEmpty)
                                        Text("ProofUrl: $proofUrl",
                                            style: AppTextStyles.small(context)),
                                    ],
                                  ),
                                ),
                              ],

                              if (reservedH > 0) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: reservedH,
                                  child: ValueListenableBuilder<Set<String>>(
                                    valueListenable: _busyIds,
                                    builder: (_, busySet, __) {
                                      final isBusyThis = busySet.contains(doc.id);
                                      if (isBusyThis) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                              SizedBox(width: 10),
                                              Text("Updating..."),
                                            ],
                                          ),
                                        );
                                      }

                                      if (status == sPaymentPending) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => _confirmApprove(orderId: doc.id),
                                              icon: const Icon(Icons.verified_outlined, size: 18),
                                              label: const Text("Approve Deposit"),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: scheme.outlineVariant),
                                                foregroundColor: scheme.onSurface,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: () => _rejectPayment(doc.id),
                                              icon: const Icon(Icons.cancel_outlined, size: 18),
                                              label: const Text("Reject Deposit"),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: scheme.outlineVariant),
                                                foregroundColor: Colors.red,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      if (status == sPickupConfirmed && AppFeatures.otpDeliveryEnabled) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: OutlinedButton.icon(
                                            onPressed: () => _confirmPrepareDrop(orderId: doc.id),
                                            icon: const Icon(Icons.local_shipping_outlined, size: 18),
                                            label: const Text("Prepare Drop Link"),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: scheme.outlineVariant),
                                              foregroundColor: scheme.onSurface,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                        );
                                      }

                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    );
  }
}
