import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Clipboard
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_navigator_keys.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';
import '../../../app_features.dart';
import '../../../core/router/app_routes.dart';

class OrderDetailPage extends StatelessWidget {
  final OrderModel order;
  const OrderDetailPage({super.key, required this.order});

  String get _uid => FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

  bool _isBuyer(OrderModel o) => _uid.isNotEmpty && _uid == o.buyerId.trim();
  bool _isSeller(OrderModel o) => _uid.isNotEmpty && _uid == o.sellerId.trim();

  String _normStatus(String s) => s.trim().toUpperCase();

  void _toast(String msg) {
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _safePopAfterFrame(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) Navigator.maybePop(context);
    });
  }

  String _mmStatus(String raw) {
    switch (_normStatus(raw)) {
      case 'PAYMENT_PENDING':
        return 'ငွေစစ်ဆေးနေသည် (Payment Pending)';
      case 'PAYMENT_APPROVED':
        return 'ငွေအတည်ပြုပြီး (Payment Approved)';
      case 'SHIPPED_BY_SELLER':
        return 'Seller က ငွေလက်ခံပြီး ပို့ပြီး';
      case 'PICKUP_OTP_SENT':
        return 'Pickup OTP ထုတ်ပြီး';
      case 'PICKUP_CONFIRMED':
        return 'Pickup အတည်ပြုပြီး';
      case 'DELIVERY_OTP_SENT':
        return 'Drop OTP ထုတ်ပြီး (Delivery stage)';
      case 'DELIVERED':
        return 'Delivered ✅';
      case 'CANCELLED':
        return 'ဖျက်ပြီး';
      default:
        return raw.trim().isEmpty ? '-' : raw;
    }
  }

  bool _canBuyerCancel(OrderModel o) => _normStatus(o.status) == 'PAYMENT_PENDING';

  Future<void> _call(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: p);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMap(String address) async {
    final a = address.trim();
    if (a.isEmpty) return;
    final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a)}",
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Order Detail", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').doc(order.id).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }

          final data = snap.data?.data();
          if (data == null) return const Center(child: Text("Order မတွေ့ပါ"));

          final o = OrderModel.fromMap(order.id, data);
          final status = _normStatus(o.status);

          final showPaymentPending = _isBuyer(o) && status == 'PAYMENT_PENDING';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ---------------- Product Summary ----------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: (o.productImage.trim().isNotEmpty)
                            ? Image.network(
                          o.productImage,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: scheme.surfaceVariant,
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                            : Container(
                          width: 72,
                          height: 72,
                          color: scheme.surfaceVariant,
                          child: const Icon(Icons.image),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.productName, style: AppTextStyles.main(context)),
                            const SizedBox(height: 6),
                            Text(
                              "${o.productPrice} • Qty ${o.quantity}",
                              style: AppTextStyles.small(context),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Status: ${_mmStatus(o.status)}",
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------------- Buyer Payment Pending ----------------
                if (showPaymentPending) ...[
                  const SizedBox(height: 16),
                  const _BuyerPaymentInfoCard(),
                  const SizedBox(height: 12),
                  PaymentTxUploader(
                    orderId: o.id,
                    existingTxId: (data['paymentTxId'] ?? '').toString().trim(),
                  ),
                ],

                const SizedBox(height: 16),

                // ---------------- Address + Seller/Buyer info ----------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on),
                          const SizedBox(width: 8),
                          Expanded(child: Text(o.deliveryAddress)),
                          TextButton(
                            onPressed: () => _openMap(o.deliveryAddress),
                            child: const Text("Map"),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(color: scheme.outlineVariant),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(_isBuyer(o) ? Icons.store : Icons.person),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isBuyer(o) ? "Seller: ${o.sellerName}" : "Buyer: ${o.buyerName}",
                              style: AppTextStyles.small(context),
                            ),
                          ),
                          if (_isSeller(o))
                            TextButton(
                              onPressed: () => _call(o.buyerPhone),
                              child: const Text("ခေါ်မည်"),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ---------------- Buyer Drop OTP (hidden when COD-only) ----------------
                if (AppFeatures.otpDeliveryEnabled &&
                    _uid.isNotEmpty &&
                    _uid == o.buyerId.trim() &&
                    status == 'DELIVERY_OTP_SENT') ...[
                  const SizedBox(height: 16),
                  BuyerDropOtpCard(orderId: o.id, buyerId: o.buyerId),
                ],

                const SizedBox(height: 16),

                // ---------------- Buyer Confirm Received (COD-only) ----------------
                if (_isBuyer(o) && status == 'SHIPPED_BY_SELLER') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Confirm Received"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () async {
                        try {
                          await OrderService.buyerConfirmReceivedR(orderId: o.id);
                          _toast("Delivered ✅");
                          _safePopAfterFrame(context);
                        } catch (e) {
                          _toast("Error: $e");
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ---------------- Buyer Cancel ----------------
                if (_isBuyer(o) && _canBuyerCancel(o))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text("Order ဖျက်မည်"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () async {
                        try {
                          await OrderService.buyerCancelOrder(orderId: o.id);
                          _toast("Order ဖျက်ပြီးပါပြီ");
                          _safePopAfterFrame(context);
                        } catch (e) {
                          _toast("Error: $e");
                        }
                      },
                    ),
                  ),

                // ---------------- Seller OTP (hidden when COD-only) ----------------
                if (AppFeatures.otpDeliveryEnabled && _isSeller(o) && status == 'PICKUP_OTP_SENT') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push(AppRoutes.pickupOtpPath(o.id));
                      },
                      child: const Text("Verify Pickup OTP"),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// =========================================================
// Buyer Payment Info Card
// =========================================================
class _BuyerPaymentInfoCard extends StatelessWidget {
  const _BuyerPaymentInfoCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Payment ကို App escrow ထဲ လွှဲပြီး Transaction ID ကို အောက်မှာ တင်ပေးပါ။",
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// ✅ Transaction ID uploader (NO Storage)
// =========================================================
class PaymentTxUploader extends StatefulWidget {
  final String orderId;
  final String existingTxId;

  const PaymentTxUploader({
    super.key,
    required this.orderId,
    required this.existingTxId,
  });

  @override
  State<PaymentTxUploader> createState() => _PaymentTxUploaderState();
}

class _PaymentTxUploaderState extends State<PaymentTxUploader> {
  final _controller = TextEditingController();
  bool _loading = false;

  // ✅ placeholder (>= 10 chars) because rules require paymentProofUrl.size() >= 10
  static const String _noStorageProofUrl = "NO_STORAGE_OK";

  @override
  void initState() {
    super.initState();
    _controller.text = widget.existingTxId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final txId = _controller.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }

    if (txId.length < 4 || txId.length > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Transaction ID မမှန်ပါ (4~120)")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await OrderService.buyerSubmitPaymentProof(
        orderId: widget.orderId,
        paymentTxId: txId,
        paymentProofUrl: _noStorageProofUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Transaction ID တင်ပြီးပါပြီ ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload error: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: "Transaction ID",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? "Submitting..." : "Submit"),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Note: Screenshot မတင်သေးပါ (Storage upgrade မလုပ်သေးလို့)။",
            style: AppTextStyles.small(context),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// ✅ Buyer-only Drop OTP card
// reads /orders/{orderId}/buyer_secrets/private
// =========================================================
class BuyerDropOtpCard extends StatelessWidget {
  final String orderId;
  final String buyerId;

  const BuyerDropOtpCard({
    super.key,
    required this.orderId,
    required this.buyerId,
  });

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP Copied ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    // ✅ buyer မဟုတ်ရင် Firestore stream မဖွင့်ပါ (permission-denied မလာအောင်)
    if (uid.isEmpty || uid != buyerId.trim()) {
      return const SizedBox.shrink();
    }

    final docRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('buyer_secrets')
        .doc('drop');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(child: Text("Drop OTP loading...")),
              ],
            ),
          );
        }

        if (snap.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text("Drop OTP error: ${snap.error}"),
          );
        }

        final data = snap.data?.data() ?? {};
        final dropOtp = (data['dropOtp'] ?? '').toString().trim();

        if (dropOtp.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: const Text("Drop OTP မထုတ်သေးပါ"),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Drop OTP (Buyer only)",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "ပစ္စည်းရတဲ့အချိန်မှ delivery ကို ဒီ OTP ပေးပါ",
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        dropOtp,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _copy(context, dropOtp),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text("Copy"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
