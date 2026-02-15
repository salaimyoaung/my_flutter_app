// order_form_page.dart (NO Screenshot / NO Firebase Storage)
// - Only Transaction ID required
// - Save TxID into order at create time (paymentProofUrl = NO_STORAGE_OK placeholder)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/services/order_service.dart';
import '../../../data/models/product_model.dart';

class OrderFormPage extends StatefulWidget {
  final Product product;
  final String sellerName;

  const OrderFormPage({
    super.key,
    required this.product,
    required this.sellerName,
  });

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _addressController = TextEditingController();

  // ✅ Payment proof (Tx only for now)
  final _txController = TextEditingController();

  int _qty = 1;
  bool _loading = false;

  // ✅ placeholder (>= 10 chars) for rules compatibility (no storage yet)
  static const String _noStorageProofUrl = "NO_STORAGE_OK";

  @override
  void dispose() {
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _addressController.dispose();
    _txController.dispose();
    super.dispose();
  }

  // =========================================================
  // ✅ Payment/Escrow accounts (static for now)
  // TODO: later load from Firestore app_config/payment_accounts
  // =========================================================
  Map<String, String> _paymentAccounts() {
    return const {
      "KBZPay": "09xxxxxxxx",
      "WavePay": "09xxxxxxxx",
      "Bank (AYA)": "AYA xxxxxxxx",
    };
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snack("Copied ✅");
  }

  void _showPaymentHowToSheet() {
    final scheme = Theme.of(context).colorScheme;
    final accts = _paymentAccounts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ငွေလွှဲစနစ် (Escrow)", style: AppTextStyles.heading(context)),
                const SizedBox(height: 10),
                Text(
                  "Buyer ပေးတဲ့ငွေကို App escrow အဖြစ် admin က ထိန်းထားပြီး\n"
                      "Delivery အတည်ပြုပြီးမှ Seller ကို payout ထုတ်ပေးမယ်။",
                  style: AppTextStyles.main(context),
                ),
                const SizedBox(height: 12),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 10),
                Text(
                  "အဆင့်လိုက် (Buyer ကြိုသိရန်)",
                  style: AppTextStyles.main(context).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  "1) Buyer က Order Confirm လုပ်မယ် (PAYMENT_PENDING)\n"
                      "2) Buyer က အောက်ပါ account တွေထဲကို ငွေလွှဲမယ်\n"
                      "3) Buyer က Transaction ID ကို Order ထဲမှာ တင်မယ်\n"
                      "4) Admin က စစ်ပြီး PAYMENT_APPROVED ပြောင်းမယ်\n"
                      "5) Seller က Accept လုပ်ပြီး Pickup OTP flow စမယ်\n"
                      "6) Delivery အတည်ပြုပြီးမှ Seller ကို payout (SETTLED)",
                  style: AppTextStyles.main(context),
                ),
                const SizedBox(height: 12),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 10),
                Text(
                  "ငွေလွှဲရမည့်နေရာများ (App Escrow)",
                  style: AppTextStyles.main(context).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ...accts.entries.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.key,
                                style: AppTextStyles.main(context).copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(e.value, style: AppTextStyles.main(context)),
                              const SizedBox(height: 4),
                              Text("(App Escrow)", style: AppTextStyles.small(context)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _copy(e.value),
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: "Copy",
                        ),
                      ],
                    ),
                  );
                }).toList(),
                Text(
                  "မှတ်ချက်: Storage upgrade မလုပ်သေးလို့ Screenshot မတင်ခိုင်းပါဘူး။ Transaction ID ပဲတင်ပေးပါ။",
                  style: AppTextStyles.small(context),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text("နားလည်ပါပြီ"),
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmEscrowBeforeOrder() async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text("Escrow စနစ် သဘောတူလား?", style: AppTextStyles.heading(context)),
        content: Text(
          "Order Confirm လုပ်ပြီးနောက် payment ကို App escrow (admin) ထဲ လွှဲရမယ်။\n"
              "Admin စစ်ဆေးအတည်ပြုပြီးမှ Seller က accept လုပ်နိုင်မယ်။\n"
              "Delivery အတည်ပြုပြီးမှ Seller ကို payout ထုတ်ပေးမယ်။\n\n"
              "အဲ့တာ သဘောတူလား?",
          style: AppTextStyles.main(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text("မလုပ်တော့ပါ"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text("သဘောတူပါတယ်"),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _prefillFromProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    if (!mounted) return;

    setState(() {
      _buyerNameController.text = (data['name'] ?? data['displayName'] ?? '').toString();
      _buyerPhoneController.text = (data['phone'] ?? '').toString();
    });
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go(AppRoutes.signup);
      return;
    }

    // ✅ own product guard
    if (widget.product.sellerId.trim() == user.uid.trim()) {
      _snack("ကိုယ့်ပစ္စည်းကို ကိုယ် Order မတင်နိုင်ပါ");
      return;
    }

    final buyerName = _buyerNameController.text.trim();
    final buyerPhone = _buyerPhoneController.text.trim();
    final address = _addressController.text.trim();

    if (buyerName.isEmpty || buyerPhone.isEmpty || address.isEmpty) {
      _snack("နာမည် / ဖုန်း / လိပ်စာ ပြည့်စုံအောင် ဖြည့်ပါ");
      return;
    }

    // ✅ TxID validate (required)
    final txId = _txController.text.trim();
    if (txId.length < 4 || txId.length > 120) {
      _snack("Transaction ID မမှန်ပါ (4~120)");
      return;
    }

    // ✅ Confirm escrow rules
    final ok = await _confirmEscrowBeforeOrder();
    if (!ok) return;

    setState(() => _loading = true);

    try {
      await OrderService.createOrder(
        productId: widget.product.id,
        productName: widget.product.name,
        productPrice: widget.product.price,
        productImage: widget.product.image,
        sellerId: widget.product.sellerId,
        sellerName: widget.sellerName,
        buyerId: user.uid,
        buyerName: buyerName,
        buyerPhone: buyerPhone,
        deliveryAddress: address,
        quantity: _qty,
        paymentMethod: 'ESCROW',

        // ✅ Save Tx only (no screenshot)
        paymentTxId: txId,
        paymentProofUrl: _noStorageProofUrl,
        paymentProofStatus: 'SUBMITTED',
      );

      if (!mounted) return;
      Navigator.pop(context);
      _snack("Order တင်ပြီးပါပြီ ✅ (PAYMENT_PENDING)");
    } catch (e) {
      if (!mounted) return;
      _snack("Order မအောင်မြင်ပါ: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Order တင်မည်", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: "Profile မှ auto-fill",
            onPressed: _prefillFromProfile,
            icon: const Icon(Icons.person_search),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Product summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.product.image.trim().isNotEmpty
                        ? Image.network(
                      widget.product.image,
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
                        Text(widget.product.name, style: AppTextStyles.main(context)),
                        const SizedBox(height: 6),
                        Text(widget.product.price, style: AppTextStyles.price()),
                        const SizedBox(height: 6),
                        Text("Seller: ${widget.sellerName}", style: AppTextStyles.small(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Escrow info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Payment: Escrow (Admin approve) — Order မတင်ခင် သိထားရန်",
                          style: AppTextStyles.main(context).copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Order တင်ပြီးနောက် payment ကို App escrow ထဲ လွှဲရမယ်။\n"
                              "Admin စစ်ဆေးအတည်ပြုပြီးမှ Seller က accept လုပ်နိုင်မယ်။",
                          style: AppTextStyles.main(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _showPaymentHowToSheet,
                            icon: const Icon(Icons.receipt_long),
                            label: const Text("ငွေလွှဲနည်း / လွှဲရမည့်နေရာ ကြည့်မယ်"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _buyerNameController,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: "ဝယ်သူအမည်",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _buyerPhoneController,
              enabled: !_loading,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "ဖုန်းနံပါတ်",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _addressController,
              enabled: !_loading,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "ပို့ဆောင်မည့် လိပ်စာ",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),

            // qty
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text("အရေအတွက်"),
                  const Spacer(),
                  IconButton(
                    onPressed: (_qty > 1 && !_loading) ? () => setState(() => _qty--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text("$_qty", style: AppTextStyles.main(context)),
                  IconButton(
                    onPressed: !_loading ? () => setState(() => _qty++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Transaction ID UI (ONLY)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Transaction ID တင်ရန်",
                    style: AppTextStyles.main(context).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _txController,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: "Transaction ID",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "မှတ်ချက်: Storage upgrade မလုပ်သေးလို့ Screenshot မတင်ခိုင်းပါဘူး။ Transaction ID ပဲတင်ပါ။",
                    style: AppTextStyles.small(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payment summary row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(width: 10),
                  const Expanded(child: Text("Payment: Escrow (Admin approve)")),
                  TextButton(
                    onPressed: _showPaymentHowToSheet,
                    child: const Text("Details"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _loading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Order Confirm"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
