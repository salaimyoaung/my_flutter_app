// order_form_page.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/order_service.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';
import 'package:sigmamoby/core/widgets/city_picker_sheet.dart';

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
  final _buyerNameCtrl = TextEditingController();
  final _buyerPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _txCtrl = TextEditingController();
  final _refundBankNameCtrl = TextEditingController();
  final _refundAccountNoCtrl = TextEditingController();
  final _refundAccountNameCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _screenshotFile;
  String? _buyerCity;
  String? _sellerCity;
  int _depositAmount = 0;
  bool _loading = false;
  bool _sellerCityLoaded = false;

  // ✅ Fees loaded from Firestore settings/shipping — no longer hardcoded
  int _sameCityFee = 10000;   // fallback default
  int _diffCityFee = 20000;   // fallback default

  static const int _qty = 1;

  @override
  void initState() {
    super.initState();
    _loadSellerCity();
    _loadShippingSettings();
  }

  @override
  void dispose() {
    _buyerNameCtrl.dispose();
    _buyerPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _txCtrl.dispose();
    _refundBankNameCtrl.dispose();
    _refundAccountNoCtrl.dispose();
    _refundAccountNameCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadSellerCity() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.product.sellerId)
          .get();
      final city = (doc.data()?['shopCity'] ?? '').toString().trim();
      _sellerCity = city.isEmpty ? null : city;
    } catch (_) {
      _sellerCity = null;
    } finally {
      if (mounted) setState(() => _sellerCityLoaded = true);
      _calculateDeposit();
    }
  }

  // ── Load delivery fees from Firestore ────────────────────────────────────
  Future<void> _loadShippingSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('shipping')
          .get();
      final data = doc.data() ?? {};
      if (mounted) {
        setState(() {
          _sameCityFee = (data['sameCityFee'] as int?) ?? 10000;
          _diffCityFee = (data['differentCityFee'] as int?) ?? 20000;
        });
        // ✅ Race condition fix — seller city ကြိုတင် load ပြီးနေနိုင်သောကြောင့်
        // shipping fee load ပြီးမှ deposit ပြန်တွက်မည်
        _calculateDeposit();
      }
    } catch (_) {
    }
  }

  void _calculateDeposit() {
    if (_buyerCity == null) return;
    setState(() {
      _depositAmount =
          (_buyerCity == _sellerCity) ? _sameCityFee : _diffCityFee;
    });
  }

  // ── Searchable city picker (shared widget) ────────────────────────────────
  Future<void> _showCityPicker() async {
    final result = await CityPickerSheet.show(context);
    if (result != null && mounted) {
      setState(() => _buyerCity = result);
      _calculateDeposit();
    }
  }

  Future<void> _pickScreenshot() async {
    // ✅ Bottom sheet — let user choose Gallery or Camera
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera နဲ့ ရိုက်မည်'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery မှ ရွေးမည်'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _screenshotFile = File(picked.path));
    } catch (e) {
      _snack('Image error: $e');
    }
  }

  Future<String> _uploadScreenshot(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Login required');

    final ref = FirebaseStorage.instance
        .ref()
        .child('deposit_screenshots')
        .child(user.uid)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go(AppRoutes.signup);
      return;
    }

    // ✅ Validation
    if (_buyerNameCtrl.text.trim().isEmpty ||
        _buyerPhoneCtrl.text.trim().isEmpty ||
        _addressCtrl.text.trim().isEmpty) {
      _snack('အချက်အလက်ပြည့်စုံအောင်ဖြည့်ပါ');
      return;
    }

    if (_buyerCity == null) {
      _snack('မြို့ရွေးပါ');
      return;
    }

    if (_depositAmount == 0) {
      _snack('Deposit မတွက်ရသေးပါ');
      return;
    }

    if (_txCtrl.text.trim().isEmpty) {
      _snack('လွှဲသူ အကောင့်နာမည် ထည့်ပါ');
      return;
    }

    if (_refundBankNameCtrl.text.trim().isEmpty ||
        _refundAccountNoCtrl.text.trim().isEmpty ||
        _refundAccountNameCtrl.text.trim().isEmpty) {
      _snack('Deposit ပြန်လွှဲမည့် အကောင့် အချက်အလက် ဖြည့်ပါ');
      return;
    }

    if (_screenshotFile == null) {
      _snack('Screenshot ထည့်ပါ');
      return;
    }

    setState(() => _loading = true);

    try {
      final screenshotUrl = await _uploadScreenshot(_screenshotFile!);

      await OrderService.createOrder(
        productId: widget.product.id,
        productName: widget.product.model,
        productBrand: widget.product.brand,
        productSeries: widget.product.series,
        productPrice: widget.product.priceDouble,
        productImage: widget.product.image,
        sellerId: widget.product.sellerId,
        sellerName: widget.sellerName,
        buyerId: user.uid,
        buyerName: _buyerNameCtrl.text.trim(),
        buyerPhone: _buyerPhoneCtrl.text.trim(),
        buyerAddress: _addressCtrl.text.trim(),
        quantity: _qty,
        depositAmount: _depositAmount,
        depositCity: _buyerCity!,
        depositTxId: _txCtrl.text.trim(),
        depositScreenshotUrl: screenshotUrl,
        refundBankName: _refundBankNameCtrl.text.trim(),
        refundAccountNo: _refundAccountNoCtrl.text.trim(),
        refundAccountName: _refundAccountNameCtrl.text.trim(),
        imeiFull: widget.product.imeiFull,
        imeiPhoto: widget.product.imeiPhoto,
      );

      // Notifications are handled by onNewOrder Cloud Function
      // to avoid duplicate pushes.

      if (!mounted) return;
      Navigator.pop(context);
      _snack('Order တင်ပြီးပါပြီ (Admin Approval စောင့်ပါ)');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(title: 'Order + Deposit'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Product Summary ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (widget.product.image.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppNetworkImage(
                        widget.product.image,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                        const Icon(Icons.phone_android, size: 40),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.product.name,
                            style: textTheme.titleSmall),
                        const SizedBox(height: 4),
                        // ✅ formattedPrice getter
                        Text(widget.product.formattedPrice,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── City-not-yet-selected hint ───────────────────────────────
            if (_buyerCity == null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: scheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'မြို့အမည် ရွေးပြီးမှသာ ကျသင့်သည့် deposit ပမာဏကို သိရှိနိုင်မည်',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Buyer Info ───────────────────────────────────────────────
            TextField(
              controller: _buyerNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'ဝယ်သူ အမည်',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _buyerPhoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'ဖုန်း နံပါတ်',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // ── City (searchable picker — Firestore-driven) ───────────
            GestureDetector(
              onTap: _showCityPicker,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'မြို့',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city_outlined),
                  suffixIcon: Icon(Icons.search),
                ),
                child: Text(
                  _buyerCity ?? 'မြို့ရွေးပါ',
                  style: TextStyle(
                    color: _buyerCity != null
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Address (ရပ်ကွက် / မြို့နယ် ရေးရုံဆိုသည်) ─────────────────
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'လိပ်စာ / ရပ်ကွက်',
                hintText: 'ဥပမာ — သာကေတ ၇ ရပ်ကွက်၊ မင်းဘူး Delivery ရုံး',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),



            // ── Deposit Info ─────────────────────────────────────────────
            if (!_sellerCityLoaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Calculating shipping fees...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (_depositAmount > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // ✅ Show same/different city label
                    if (_buyerCity != null)
                      Text(
                        _buyerCity == _sellerCity
                            ? '📍 Same City — Delivery fee သက်သာသည်'
                            : '🚚 Different City — Delivery fee',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (_buyerCity != null) const SizedBox(height: 4),
                    Text(
                      'Deposit: ${_depositAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} MMK',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Depositသည် ပစ္စည်း ပို့ပြီးချိန်တွင် ရောင်းသူ၏ ပစ္စည်း ချို့ယွင်းမှုကြောင့်မဟုတ်ဘဲ ဝယ်သူ၏ ပျက်ကွက်မှုအကြောင်းအမျိုးမျိုးကြောင့် ပစ္စည်းမယူဖြစ်ပါက ရောင်းသူထံ ပစ္စည်းပြန်ပို့ရန်အတွက် ခန့်မှန်းခြေ deliveryခ ဖြစ်ပါသည်။ '
                      'သို့ဖြစ်ပါ၍ ပစ္စည်းရရှိချိန်တွင် အမှန်တတယ် ကုန်ကျသော delivery ခသာ ပစ္စည်းတန်ဖိုးနှင့်အတူ delivery ကို ပေးရမည် ဖြစ်ပါသည်။ '
                      'ပစ္စည်းရရှိကြောင်း Received နှိပ်ပါက Admin မှ ဝယ်သူဆီ Deposit အကုန် ပြန်လွှဲပေးပါမည်။ ',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Bank Accounts (live from Firestore) ──────────────────────
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('settings')
                  .doc('payment')
                  .snapshots(),
              builder: (context, settingSnap) {
                if (settingSnap.hasError) {
                  return const SizedBox.shrink();
                }
                final accounts = settingSnap.hasData
                    ? List<Map<String, dynamic>>.from(
                        settingSnap.data!.data()?['bankAccounts'] ?? [],
                      )
                    : <Map<String, dynamic>>[];

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deposit Bank Accounts',
                          style: textTheme.labelLarge),
                      const SizedBox(height: 8),
                      if (!settingSnap.hasData)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (accounts.isEmpty)
                        Text(
                          'Bank account မရှိသေးပါ',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ...accounts.map((a) {
                          final name        = (a['name']        ?? '').toString();
                          final number      = (a['number']      ?? '').toString();
                          final accountName = (a['accountName'] ?? '').toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                      if (accountName.isNotEmpty)
                                        Text(accountName,
                                            style: textTheme.bodySmall?.copyWith(
                                                color: scheme.primary,
                                                fontWeight: FontWeight.w500)),
                                      Text(number,
                                          style: textTheme.bodySmall?.copyWith(
                                              color: scheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                // ✅ Copy account number to clipboard
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    size: 16,
                                  ),
                                  tooltip: 'Copy',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: number),
                                    );
                                    ScaffoldMessenger.of(context)
                                        .clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$name — $number copied!',
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Sender Name ──────────────────────────────────────────────
            TextField(
              controller: _txCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'လွှဲသူ အကောင့်နာမည် ထည့်ပါ',
                hintText: 'e.g. Mg Mg / May Thu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // ── Screenshot ───────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _pickScreenshot,
              icon: const Icon(Icons.image_outlined),
              label: Text(_screenshotFile == null
                  ? 'Screenshot Upload လုပ်ပါ'
                  : 'Screenshot ပြောင်းမည်'),
            ),

            if (_screenshotFile != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _screenshotFile!,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Refund Account ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_outlined,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Deposit ပြန်လွှဲရမည့် အကောင့်',
                        style: textTheme.labelLarge?.copyWith(
                            color: scheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order ပြီးဆုံးသောအခါ သို့မဟုတ် Reject ဖြစ်သောအခါ '
                    'Deposit ကို သင့်အကောင့်ထဲသို့ ပြန်လွှဲပေးပါမည်။',
                    style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _refundBankNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bank / Wallet (ဘဏ်အမည်)',
                      hintText: 'ဥပမာ — KBZ Pay, Wave Money, AYA Bank',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _refundAccountNoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'အကောင့် နံပါတ်',
                      hintText: 'ဥပမာ — 09xxxxxxxxx',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _refundAccountNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'အကောင့် နာမည်',
                      hintText: 'ဥပမာ — Mg Mg',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ],
              ),
            ),


            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Submit Order'),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ✅ _CityPickerSheet removed — replaced by shared CityPickerSheet widget
// See: lib/core/widgets/city_picker_sheet.dart

