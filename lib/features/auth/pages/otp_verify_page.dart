// otp_verify_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../app_styles.dart';
import '../../../data/services/order_service.dart';

class PickupOtpVerifyPage extends StatefulWidget {
  final String orderId;
  const PickupOtpVerifyPage({super.key, required this.orderId});

  @override
  State<PickupOtpVerifyPage> createState() => _PickupOtpVerifyPageState();
}

class _PickupOtpVerifyPageState extends State<PickupOtpVerifyPage> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  String _norm(String s) => s.trim().toUpperCase();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _verifyPickupOtp({
    required String orderId,
    required String inputOtp,
  }) async {
    final ordersRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ordersRef);
      if (!snap.exists) {
        throw Exception("Order မတွေ့ပါ");
      }

      final data = snap.data() as Map<String, dynamic>;
      final status = _norm(_s(data['status']));
      final currentOtp = _s(data['pickupOtp']);

      // ✅ Only allow at correct step
      if (status != 'PICKUP_OTP_SENT') {
        // already confirmed / wrong step
        throw Exception("Pickup OTP verify လုပ်လို့မရတဲ့ အခြေအနေပါ (status=$status)");
      }

      if (currentOtp.isEmpty) {
        throw Exception("pickupOtp မရှိပါ (Seller Accept ပြီး OTP generate မဖြစ်သေး)");
      }

      if (currentOtp != inputOtp) {
        throw Exception("OTP မမှန်ပါ");
      }

      // ✅ OK: mark pickup confirmed
      tx.update(ordersRef, {
        'status': 'PICKUP_CONFIRMED',
        'pickupConfirmedAt': FieldValue.serverTimestamp(),

        // audit fields
        'pickupOtpVerified': true,
        'pickupOtpVerifiedAt': FieldValue.serverTimestamp(),

        // optional: keep OTP but mark used
        'pickupOtpUsed': true,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final docStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Pickup OTP Verify", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }
          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text("Order မတွေ့ပါ"));
          }

          final productName = _s(data['productName'] ?? data['name']);
          final buyerName = _s(data['buyerName']);
          final buyerPhone = _s(data['buyerPhone']);
          final address = _s(data['deliveryAddress']);
          final status = _norm(_s(data['status']));

          final canVerify = status == 'PICKUP_OTP_SENT';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ---- Order summary card ----
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName.isEmpty ? "Product" : productName,
                        style: AppTextStyles.main(context).copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Buyer: ${buyerName.isEmpty ? '-' : buyerName}  (${buyerPhone.isEmpty ? '-' : buyerPhone})",
                        style: AppTextStyles.small(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Address: ${address.isEmpty ? '-' : address}",
                        style: AppTextStyles.small(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: canVerify
                                  ? Colors.orange.withOpacity(0.14)
                                  : scheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "Status: $status",
                              style: AppTextStyles.small(context).copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ---- OTP input ----
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Seller ပေးတဲ့ Pickup OTP ကို ထည့်ပါ",
                        style: AppTextStyles.main(context).copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            hintText: "6-digit OTP",
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.length != 6) return "OTP 6 လုံး ထည့်ပါ";
                            if (int.tryParse(s) == null) return "OTP မှာ နံပါတ်ပဲရမယ်";
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (!canVerify || _submitting)
                              ? null
                              : () async {
                            if (_formKey.currentState?.validate() != true) return;

                            final otp = _otpController.text.trim();

                            setState(() => _submitting = true);
                            try {
                              await OrderService.verifyPickupOtp(
                                orderId: widget.orderId,
                                inputOtp: _otpController.text.trim(),
                              );
                              if (!mounted) return;
                              _toast("Pickup Confirmed ✅");
                              Navigator.pop(context, true);
                            } catch (e) {
                              _toast(e.toString().replaceFirst("Exception: ", ""));
                            } finally {
                              if (mounted) setState(() => _submitting = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _submitting
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.verified),
                          label: Text(_submitting ? "Verifying..." : "Verify Pickup OTP"),
                        ),
                      ),

                      if (!canVerify) ...[
                        const SizedBox(height: 10),
                        Text(
                          "ဒီ Order က pickup OTP verify လုပ်လို့မရတဲ့ status ဖြစ်နေပါတယ်။",
                          style: AppTextStyles.small(context).copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
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
