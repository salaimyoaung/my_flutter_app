import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/widgets/copy_text_row.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/order_service.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';
import 'package:sigmamoby/shared/pages/full_screen_image_page.dart';

class SellerOrderDetailPage extends StatefulWidget {
  final OrderModel order;

  const SellerOrderDetailPage({super.key, required this.order});

  @override
  State<SellerOrderDetailPage> createState() => _SellerOrderDetailPageState();
}

class _SellerOrderDetailPageState extends State<SellerOrderDetailPage> {
  // ── Delivery form state (page-level — always visible when approved) ──────
  final _serviceCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  File? _voucherFile;
  File? _productFile;
  bool _uploading = false;

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Pick voucher photo ────────────────────────────────────────────────────
  Future<void> _pickVoucher() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _voucherFile = File(picked.path));
    }
  }

  Future<void> _pickProduct() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _productFile = File(picked.path));
    }
  }

  // ── Submit — Mark as Shipped ──────────────────────────────────────────────
  Future<void> _submitShipped(String orderId) async {
    if (_serviceCtrl.text.trim().isEmpty) {
      _snack('Delivery service name ထည့်ပါ');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _snack('Phone number ထည့်ပါ');
      return;
    }
    if (_voucherFile == null) {
      _snack('ဘောင်ချာပုံ upload လုပ်ပါ');
      return;
    }
    if (_productFile == null) {
      _snack('ပစ္စည်းပုံ upload လုပ်ပါ');
      return;
    }

    setState(() => _uploading = true);
    try {
      final sellerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final ts = DateTime.now().millisecondsSinceEpoch;
      
      // Upload voucher
      final vRef = FirebaseStorage.instance
          .ref()
          .child('delivery_vouchers')
          .child(sellerUid)
          .child('${orderId}_v_$ts.jpg');
      await vRef.putFile(
          _voucherFile!, SettableMetadata(contentType: 'image/jpeg'));
      final vUrl = await vRef.getDownloadURL();

      // Upload product photo
      final pRef = FirebaseStorage.instance
          .ref()
          .child('delivery_vouchers') // reusing the same category folder
          .child(sellerUid)
          .child('${orderId}_p_$ts.jpg');
      await pRef.putFile(
          _productFile!, SettableMetadata(contentType: 'image/jpeg'));
      final pUrl = await pRef.getDownloadURL();

      await OrderService.sellerMarkShipped(
        orderId: orderId,
        deliveryServiceName: _serviceCtrl.text.trim(),
        deliveryPhone: _phoneCtrl.text.trim(),
        deliveryVoucherUrl: vUrl,
        deliveryProductUrl: pUrl,
      );

      if (!mounted) return;
      _snack('Marked as Shipped ✅');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showDeliveryFailedSheet(BuildContext context, String orderId) {
    final reasonCtrl = TextEditingController();
    File? proofFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.only(left: 16, right: 16, top: 20, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.report_gmailerrorred_rounded, color: Theme.of(sheetCtx).colorScheme.error),
                const SizedBox(width: 8),
                Text('Report Delivery Failed', style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              const Text('ဝယ်သူကို ဆက်သွယ်မရခြင်း သို့မဟုတ် အခြားအကြောင်းများကြောင့် ပစ္စည်းပြန်ရောက်လာကြောင်း အထောက်အထား တင်ပြပါရန်။', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'အကြောင်းပြချက် (ဥပမာ - ဝယ်သူ ဖုန်းမကိုင်ပါ)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('အထောက်အထားပုံ (ဥပမာ - Delivery app screenshot)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (picked != null) setSheet(() => proofFile = File(picked.path));
                },
                child: Container(
                  height: 120, width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(color: proofFile != null ? Theme.of(sheetCtx).colorScheme.primary : Theme.of(sheetCtx).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
                  child: proofFile != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(proofFile!, fit: BoxFit.cover))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined), Text('ပုံတင်ရန် နှိပ်ပါ', style: TextStyle(fontSize: 12))]),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (reasonCtrl.text.trim().isEmpty) { _snack('အကြောင်းပြချက် ထည့်ပါ'); return; }
                    if (proofFile == null) { _snack('အထောက်အထားပုံ တင်ပါ'); return; }

                    setSheet(() => _uploading = true);
                    try {
                      final ts = DateTime.now().millisecondsSinceEpoch;
                      final ref = FirebaseStorage.instance.ref().child('delivery_vouchers').child(FirebaseAuth.instance.currentUser!.uid).child('${orderId}_failed_$ts.jpg');
                      await ref.putFile(proofFile!);
                      final url = await ref.getDownloadURL();

                      await OrderService.sellerReportDeliveryFailed(orderId: orderId, reason: reasonCtrl.text.trim(), proofUrl: url);
                      if (!sheetCtx.mounted) return;
                      Navigator.pop(sheetCtx);
                      _snack('Reported Successfully ✅');
                    } catch (e) {
                      _snack(e.toString());
                    } finally {
                      setSheet(() => _uploading = false);
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Confirm & Report'),
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(sheetCtx).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(title: 'Order Detail'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.order.id)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data();
          if (data == null) {
            return const Center(child: Text('Order not found'));
          }

          final o = OrderModel.fromMap(widget.order.id, data);

          return MaxWidthBox(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.hPadding,
                vertical: 16,
              ),
              child: Column(
                children: [

                  // ── Order Info ───────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.push(
                        AppRoutes.productPath(o.productId)),
                    child: _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.productName,
                                style: textTheme.titleMedium,
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Price: ${o.formattedPrice}'),
                        Text('Qty: ${o.quantity}'),
                        const SizedBox(height: 8),
                        Text(
                          'Status: ${o.statusEmoji} ${o.statusLabel}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    )),
                  ),

                  const SizedBox(height: 16),

                  // ── imei.org Verification (Only after admin runs API check) ─
                  if (!o.isCancelled && !o.isRejected) ...[
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .doc(o.productId)
                          .snapshots(),
                      builder: (context, pSnap) {
                        if (!pSnap.hasData) return const SizedBox.shrink();
                        final pData = pSnap.data?.data();
                        if (pData == null) return const SizedBox.shrink();
                        
                        final product = Product.fromFirestore(o.productId, pData);
                        final parsed = product.imeiCheckParsed;

                        final specValues = [
                          parsed['modelName'],
                          parsed['fullName'],
                          parsed['manufacturer'],
                          parsed['modelNumber'],
                          parsed['Model'],
                          parsed['Model Desc'],
                          parsed['Full Name'],
                          parsed['Brand'],
                        ];

                        final hasSpecs = specValues.any((v) {
                          if (v == null) return false;
                          final str = v.toString().trim();
                          return str.isNotEmpty && str.toLowerCase() != 'null';
                        });

                        final statusVal = (parsed['status'] ?? parsed['Status'] ?? parsed['result'] ?? '').toString().toUpperCase();
                        final errVal = (parsed['error'] ?? parsed['errorMessage'] ?? parsed['message'] ?? parsed['failReason'] ?? parsed['reason'] ?? '').toString().trim();
                        final hasErrorText = errVal.isNotEmpty && errVal.toLowerCase() != 'null';

                        final isRejectedOrFailed = !hasSpecs && (statusVal.contains('REJECT') ||
                            statusVal.contains('FAIL') ||
                            statusVal.contains('ERROR') ||
                            statusVal.contains('CANCEL') ||
                            statusVal.contains('UNSUCCESSFUL') ||
                            hasErrorText ||
                            product.imeiStatus.toUpperCase() == 'REJECTED' ||
                            product.imeiStatus.toUpperCase() == 'BLACKLISTED');

                        // ✅ Admin က API check လုပ်ပြီး Valid ဖြစ်လျှင် သို့မဟုတ် Order Approve ဖြစ်ပြီးလျှင် seller & buyer order တွင် ပြပါမည်
                        final isValidated = product.imeiStatus.toUpperCase() == 'VALID' ||
                            o.depositStatus.toUpperCase() == 'APPROVED' ||
                            o.isApproved;
                        final showImeiOrg = isValidated && parsed.isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _card(scheme, Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 1. Seller-Listed Specs ───────────────────────
                              Text('Seller-Listed Specs',
                                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: scheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    _specRow('Model', product.name.isNotEmpty ? product.name : '—', scheme, textTheme, isFirst: true),
                                    _specRow('Condition', product.condition.isNotEmpty ? product.condition : '—', scheme, textTheme),
                                    _specRow('RAM', product.ram != null ? '${product.ram} GB' : '—', scheme, textTheme),
                                    _specRow('Storage', product.storage != null ? '${product.storage} GB' : '—', scheme, textTheme),
                                    _specRow('Color', product.color.isNotEmpty ? product.color : '—', scheme, textTheme),
                                    _specRow('Model No.', product.modelNumber ?? '—', scheme, textTheme),
                                  ],
                                ),
                              ),

                              if (showImeiOrg) ...[
                                const SizedBox(height: 20),

                                // ── 2. IMEI.org Verification Result ──────────────
                                Row(
                                  children: [
                                    Icon(Icons.verified_user_outlined,
                                        size: 16, color: isRejectedOrFailed ? scheme.error : scheme.primary),
                                    const SizedBox(width: 6),
                                    Text('IMEI.org Verification',
                                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                if (isRejectedOrFailed) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.cancel_rounded, color: Colors.red.shade800, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'API စစ်ဆေးမှု မအောင်မြင်ပါ / ငြင်းပယ်ခံရသည် (API Check Rejected)',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.red.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '• imei.org API မှ စစ်ဆေးမှုကို Reject ပြုလုပ်ထားပါသည် (Server အဆင်မပြေခြင်း သို့မဟုတ် IMEI အချက်အလက် မရှိခြင်း ဖြစ်နိုင်ပါသည်)။',
                                          style: TextStyle(fontSize: 11, color: Colors.red.shade800, height: 1.3),
                                        ),
                                        if ((parsed['error'] ?? parsed['errorMessage'] ?? parsed['message'] ?? '').toString().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'အသေးစိတ် Error: ${parsed['error'] ?? parsed['errorMessage'] ?? parsed['message']}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red.shade700,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ] else if (!hasSpecs) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: scheme.outlineVariant),
                                    ),
                                    child: Text(
                                      'IMEI.org စစ်ဆေးပြီး (အချက်အလက်များ သိမ်းဆည်းပြီးပါပြီ)',
                                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ] else ...[
                                  _ImeiOrgOrderResultTable(parsed: parsed),
                                  const SizedBox(height: 8),
                                  Text('Admin မှ အသေးစိတ် စစ်ဆေးပေးထားသော အချက်အလက်များ ဖြစ်ပါသည်။',
                                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10)),
                                ],
                              ],
                            ],
                          )),
                        );
                      },
                    ),
                  ],

                  // ── Return Request Info (Seller view) ──────────────────
                  if (o.isReturnPending || o.isRefunded || o.isReturnRejected || o.isReturnClaimed) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            o.isRefunded ? Icons.assignment_returned_rounded : Icons.warning_amber_rounded,
                            color: o.isRefunded ? scheme.primary : scheme.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              o.isRefunded 
                                  ? (o.refundedTo == 'seller' 
                                      ? 'Order အား Seller ထံ Refund ပေးလိုက်ပါပြီ' 
                                      : (o.returnReason.isNotEmpty 
                                          ? 'ဝယ်သူ၏ Return Request ကို အတည်ပြု၍ Refund ပေးလိုက်ပါပြီ' 
                                          : 'Order အား Buyer ထံ Refund ပေးလိုက်ပါပြီ'))
                                  : (o.isReturnRejected || o.isReturnClaimed)
                                      ? 'Buyer ၏ Return Request ကို ပယ်ချထားသည်'
                                      : 'Buyer မှ ပစ္စည်းပြန်ပေးရန် Request တင်ထားသည်',
                              style: textTheme.titleSmall?.copyWith(
                                color: o.isRefunded ? scheme.primary : scheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Text('ဝယ်သူ၏ အကြောင်းပြချက်: ${o.returnReason}', style: textTheme.bodyMedium),
                        if (o.isRefunded && o.refundedTo != 'seller' && o.returnReason.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Admin ၏ ဆုံးဖြတ်ချက်: Buyer တင်ပြသော အချက်အလက်များ မှန်ကန်သဖြင့် ဝယ်သူ့ထံ Deposit ပြန်လွှဲပေးလိုက်ခြင်း ဖြစ်ပါသည်။',
                              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 12),
                        if (o.returnPhotos.isNotEmpty)
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: o.returnPhotos.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (ctx, i) => GestureDetector(
                                onTap: () => FullScreenImagePage.show(context, o.returnPhotos[i]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AppNetworkImage(o.returnPhotos[i], width: 120, height: 120, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        
                        if (o.isReturnRejected || o.isReturnClaimed || (o.isRefunded && o.refundedTo == 'seller')) ...[
                          const SizedBox(height: 16),
                          Divider(height: 1, color: scheme.outlineVariant),
                          const SizedBox(height: 16),
                          Text('Admin ၏ ဆုံးဖြတ်ချက်:', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(o.returnRejectReason, style: textTheme.bodySmall),
                          
                          const SizedBox(height: 16),
                          if (o.isReturnRejected)
                            _SellerClaimForm(order: o),
                          
                          if (o.isReturnClaimed || (o.isRefunded && o.refundedTo == 'seller')) ...[
                            Text('သင့်ဘက်မှ တောင်းဆိုထားသော Delivery ခ', style: textTheme.labelSmall),
                            const SizedBox(height: 4),
                            Text('${o.sellerReturnClaimAmount} MMK', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
                            const SizedBox(height: 8),
                            if (o.sellerReturnClaimProofUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppNetworkImage(o.sellerReturnClaimProofUrl, height: 120, width: double.infinity, fit: BoxFit.cover,
                                    onTap: () => FullScreenImagePage.show(context, o.sellerReturnClaimProofUrl)),
                              ),
                          ],
                          
                          if (o.isRefunded && o.refundedTo == 'seller' && o.depositReturnProofUrl.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('Admin မှ သင့်ထံ Delivery ခ လွှဲထားသော ပြေစာ', style: textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkImage(o.depositReturnProofUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                                  onTap: () => FullScreenImagePage.show(context, o.depositReturnProofUrl)),
                            ),
                          ],
                        ] else if (o.isReturnPending) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Admin မှ အချက်အလက်များကို စစ်ဆေးနေပါသည်။ စစ်ဆေးပြီးပါက သင့်ထံ အကြောင်းကြားပေးပါမည်။',
                              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ],
                    )),
                  ],

                  // ── Buyer Info ───────────────────────────────────────
                  const SizedBox(height: 16),
                  _card(scheme, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buyer', style: textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text('Name: ${o.buyerName}'),
                      CopyTextRow(label: 'Phone', value: o.buyerPhone),
                      Text('City: ${o.depositCity}'),
                      Text('Address: ${o.buyerAddress}'),
                    ],
                  )),

                  // ── Seller Rejected Alert ───────────────────────────
                  if (o.isSellerRejected || (o.isRefunded && o.rejectedBy == 'seller')) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.report_problem_rounded, color: scheme.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('သင့်ဘက်မှ Order ကို ပယ်ဖျက်ထားသည်', 
                                style: textTheme.titleSmall?.copyWith(color: scheme.error, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Text('သင့်၏ အကြောင်းပြချက်: ${o.rejectReason}', style: textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        Text('ပို့ဆောင်ရန် အဆင်မပြေပါသဖြင့် ပယ်ဖျက်လိုက်ခြင်း ဖြစ်ပါသည်။ Admin မှ ဝယ်သူ့ထံ Deposit ငွေများ ပြန်လွှဲပေးရန် ဆောင်ရွက်နေပြီ ဖြစ်ပါသည်။',
                            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                      ],
                    )),
                  ],

                  // ── Delivery Form — ကြိုပြ (isApproved အခြေအနေမှာ) ──
                  if (o.isApproved) ...[
                    const SizedBox(height: 16),
                    _card(
                      scheme,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header + hint
                          Row(
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  size: 16, color: scheme.primary),
                              const SizedBox(width: 6),
                              Text('Delivery အချက်အလက်',
                                  style: textTheme.titleSmall),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 14,
                                    color: scheme.onTertiaryContainer),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Delivery ဘောင်ချာပုံ ရိုက်ထားပါ',
                                    style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onTertiaryContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Service name
                          TextField(
                            controller: _serviceCtrl,
                            enabled: !_uploading,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Service အမည်',
                              hintText: 'ဥပမာ — JT Express, Kerry',
                              border: OutlineInputBorder(),
                              prefixIcon:
                                  Icon(Icons.business_outlined),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Phone
                          TextField(
                            controller: _phoneCtrl,
                            enabled: !_uploading,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Phone',
                              hintText: '09xxxxxxxxx',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone_outlined),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ① Voucher photo picker
                          Text('① Delivery ဘောင်ချာပုံ', style: textTheme.labelMedium),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _uploading ? null : _pickVoucher,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _voucherFile != null
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _voucherFile == null
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 12),
                                      child: Row(
                                        children: [
                                          Icon(Icons.receipt_long_outlined,
                                              color: scheme.onSurfaceVariant),
                                          const SizedBox(width: 10),
                                          Text(
                                            'ဘောင်ချာပုံ upload လုပ်ပါ',
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                    color: scheme
                                                        .onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.file(
                                            _voucherFile!,
                                            height: 140,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: scheme.surface,
                                            child: Icon(Icons.edit_outlined,
                                                size: 16,
                                                color: scheme.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ② Product photo picker
                          Text('② ပစ္စည်းပုံ (Product Photo)', style: textTheme.labelMedium),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _uploading ? null : _pickProduct,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _productFile != null
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _productFile == null
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 12),
                                      child: Row(
                                        children: [
                                          Icon(Icons.inventory_2_outlined,
                                              color: scheme.onSurfaceVariant),
                                          const SizedBox(width: 10),
                                          Text(
                                            'ပို့ဆောင်မည့် ပစ္စည်းပုံ upload လုပ်ပါ',
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                    color: scheme
                                                        .onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.file(
                                            _productFile!,
                                            height: 140,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: scheme.surface,
                                            child: Icon(Icons.edit_outlined,
                                                size: 16,
                                                color: scheme.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Mark as Shipped button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: _uploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(
                                      Icons.local_shipping_outlined),
                              label: Text(_uploading
                                  ? 'Uploading...'
                                  : 'Mark as Shipped'),
                              onPressed:
                                  _uploading ? null : () => _submitShipped(o.id),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ✅ Reject Order Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Order ကို ပယ်ဖျက်မည် (Reject)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.error,
                                side: BorderSide(color: scheme.error),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final ctrl = TextEditingController();
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Reject Order'),
                                    content: TextField(
                                      controller: ctrl,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        hintText: 'ဘာကြောင့် ပယ်ဖျက်ရသလဲ ရေးပါ (ဥပမာ - ဝယ်သူရှိသည့်မြို့ကို ပို့မရပါ)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('မလုပ်ပါ')),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ပယ်ဖျက်မည်')),
                                    ],
                                  ),
                                );
                                if (ok != true || ctrl.text.trim().isEmpty) return;
                                try {
                                  await OrderService.sellerRejectOrder(orderId: o.id, reason: ctrl.text.trim());
                                  _snack('Order ကို ပယ်ဖျက်လိုက်ပါပြီ ⚠️');
                                } catch (e) {
                                  _snack(e.toString());
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Delivery Failed Action (When status is ON_THE_WAY) ─────
                  if (o.isOnTheWay) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.report_gmailerrorred_rounded, size: 16, color: scheme.error),
                          const SizedBox(width: 8),
                          Text('ပို့ဆောင်မှု မအောင်မြင်ပါသလား?', style: textTheme.titleSmall?.copyWith(color: scheme.error)),
                        ]),
                        const SizedBox(height: 8),
                        Text('ဝယ်သူကို ဆက်သွယ်မရခြင်း သို့မဟုတ် အခြားအကြောင်းများကြောင့် ပစ္စည်းပြန်ရောက်လာပါက အောက်ပါခလုတ်ကို နှိပ်ပါ။',
                            style: textTheme.bodySmall),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.assignment_return_outlined, size: 18),
                            label: const Text('Report Delivery Failed (Returned to Seller)'),
                            style: OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error)),
                            onPressed: () => _showDeliveryFailedSheet(context, o.id),
                          ),
                        ),
                      ],
                    )),
                  ],

                  // ── Delivery Info (shipped ပြီးပြီ) ──────────────────
                  if (o.isOnTheWay || o.isFeePending || o.isCompleted) ...[
                    if (o.deliveryServiceName.isNotEmpty ||
                        o.deliveryVoucherUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _card(scheme, Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  size: 16, color: scheme.primary),
                              const SizedBox(width: 6),
                              Text('Delivery အချက်အလက်',
                                  style: textTheme.titleSmall),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (o.deliveryServiceName.isNotEmpty)
                            Text('Service: ${o.deliveryServiceName}'),
                          if (o.deliveryPhone.isNotEmpty)
                            CopyTextRow(
                                label: 'Phone', value: o.deliveryPhone),
                          if (o.deliveryVoucherUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('① Delivery ဘောင်ချာပုံ', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkImage(
                                o.deliveryVoucherUrl,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                onTap: () => FullScreenImagePage.show(
                                    context, o.deliveryVoucherUrl),
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                          ],
                          if (o.deliveryProductUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('② ပစ္စည်းပုံ', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkImage(
                                o.deliveryProductUrl,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                onTap: () => FullScreenImagePage.show(
                                    context, o.deliveryProductUrl),
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                          ],
                        ],
                      )),
                    ],
                  ],

                  // ── Buyer Received Proof ─────────────────────────────────
                  if ((o.isFeePending || o.isCompleted) &&
                      (o.receivedReceiptUrl.isNotEmpty ||
                          o.receivedProductUrl.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.verified_outlined,
                              size: 16, color: scheme.tertiary),
                          const SizedBox(width: 6),
                          Text('Buyer လက်ခံကြောင်း အထောက်အထား',
                              style: textTheme.titleSmall?.copyWith(
                                  color: scheme.tertiary)),
                        ]),
                        const SizedBox(height: 12),

                        if (o.receivedReceiptUrl.isNotEmpty) ...[
                          Text('① Delivery ဘောင်ချာပုံ',
                              style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => FullScreenImagePage.show(
                                context, o.receivedReceiptUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkImage(
                                o.receivedReceiptUrl,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (o.receivedProductUrl.isNotEmpty) ...[
                          Text('② ရရှိတဲ့ ပစ္စည်းပုံ',
                              style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => FullScreenImagePage.show(
                                context, o.receivedProductUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkImage(
                                o.receivedProductUrl,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )),
                  ],

                  // ── Platform Fee Card (feePending or completed + fee > 0) ──────────
                  if ((o.isFeePending || o.isCompleted) && o.platformFee > 0) ...[
                    const SizedBox(height: 16),
                    _PlatformFeeCard(
                      orderId: o.id,
                      platformFee: o.platformFee,
                      sellerId: o.sellerId,
                      existingPayerName: o.feePayerName,
                      existingProofUrl: o.feeProofUrl,
                      existingTransferAmount: o.feeTransferAmount,
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(ColorScheme scheme, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

// ─── Seller Claim Form ──────────────────────────────────────────────────────

class _SellerClaimForm extends StatefulWidget {
  final OrderModel order;
  const _SellerClaimForm({required this.order});

  @override
  State<_SellerClaimForm> createState() => _SellerClaimFormState();
}

class _SellerClaimFormState extends State<_SellerClaimForm> {
  final _amountCtrl = TextEditingController();
  final _bankCtrl   = TextEditingController();
  final _accNameCtrl= TextEditingController();
  final _accNoCtrl  = TextEditingController();
  File? _claimProof;
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bankCtrl.dispose();
    _accNameCtrl.dispose();
    _accNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Camera'), onTap: () => Navigator.pop(c, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Gallery'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) setState(() => _claimProof = File(picked.path));
  }

  Future<void> _submit() async {
    final amt = int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final bank = _bankCtrl.text.trim();
    final name = _accNameCtrl.text.trim();
    final no = _accNoCtrl.text.trim();

    if (amt <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery ခ ထည့်ပေးပါ'))); return; }
    if (bank.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ဘဏ်အမည် ထည့်ပေးပါ'))); return; }
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('အကောင့်အမည် ထည့်ပေးပါ'))); return; }
    if (no.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('အကောင့်နံပါတ် ထည့်ပေးပါ'))); return; }
    if (_claimProof == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shipping ဘောင်ချာပုံ တင်ပေးပါ'))); return; }

    setState(() => _submitting = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child('delivery_vouchers').child(widget.order.sellerId).child('${widget.order.id}_claim_$ts.jpg');
      await ref.putFile(_claimProof!);
      final url = await ref.getDownloadURL();

      await OrderService.sellerClaimReturnDelivery(
        orderId: widget.order.id,
        amount: amt,
        proofUrl: url,
        bankName: bank,
        accountName: name,
        accountNo: no,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery ခ Claim တင်ပြီးပါပြီ ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery ခ ကုန်ကျစရိတ် Claim လုပ်ရန်', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Delivery ခ ပမာဏ (MMK)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bankCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'ဘဏ်အမည် (ဥပမာ - Kpay)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _accNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'အကောင့်အမည်', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _accNoCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'အကောင့်နံပါတ်', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _submitting ? null : _pickProof,
          child: Container(
            height: 100, width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: _claimProof != null ? scheme.primary : scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
            child: _claimProof != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_claimProof!, fit: BoxFit.cover))
                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined), Text('ဘောင်ချာပုံ တင်ရန်', style: TextStyle(fontSize: 12))]),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
            label: const Text('Claim တင်မည်'),
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMEI.org Result Table for Orders
// ─────────────────────────────────────────────────────────────────────────────

class _ImeiOrgOrderResultTable extends StatelessWidget {
  final Map<String, dynamic> parsed;
  const _ImeiOrgOrderResultTable({required this.parsed});

  static const _labels = <String, String>{
    'modelName':         'Model',
    'modelNumber':       'Model Number',
    'fullName':          'Full Name',
    'storage':           'Storage',
    'color':             'Color',
    'manufacturer':      'Manufacturer',
    'productionDate':    'Production Date',
    'purchaseDate':      'Date of Purchase',
    'warrantyUntil':     'Warranty Until',
    'warrantyStatus':    'Warranty Status',
    'carrier':           'Carrier',
    'country':           'Country',
    'activated':         'Activated',
    'simlock':           'Network Lock',
    'blacklist':         'Blacklist',
    'fmi':               'iCloud Lock (FMI)',
    'icloud':            'iCloud Status',
    'knoxGuard':         'KnoxGuard',
    'soldDate':          'Sold Date',
    'shipDate':          'Ship Date',
    'soldToCountry':     'Sold-to Country',
    'shipToCountry':     'Ship-to Country',
    'doNumber':          'DO Number',
    'IMEI':              'IMEI',
    'imei2':             'IMEI 2',
    'serialNumber':      'Serial Number',
    'Model Description': 'Model Description',
    'Replaced':          'Replaced',
    'Estimated Purchase Date': 'Estimated Purchase Date',
  };

  Color _statusColor(BuildContext ctx, String key, String val) {
    final scheme = Theme.of(ctx).colorScheme;
    final up = val.toUpperCase().trim();
    
    switch (key) {
      case 'fmi':
      case 'icloud':
      case 'simlock':
      case 'carrier':
      case 'blacklist':
      case 'knoxGuard':
      case 'warrantyStatus':
        if (['OFF', 'UNLOCKED', 'CLEAN', 'OK', 'NOT BLACKLISTED', 'IN WARRANTY', 'UNLOCK'].contains(up)) return Colors.green;
        if (up.contains('CLEAN') || up.contains('UNLOCKED') || up == 'OFF') return Colors.green;

        if (['ON', 'LOCKED', 'LOST', 'ERASED', 'EXPIRED', 'BLACKLISTED', 'OUT OF WARRANTY'].contains(up)) return scheme.error;
        if (up.contains('LOCKED') || up.contains('BLACKLISTED') || up.contains('LOST') || up == 'ON') return scheme.error;
        break;
    }
    
    return scheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hasSpecs = (parsed['modelName'] ??
            parsed['fullName'] ??
            parsed['manufacturer'] ??
            parsed['modelNumber'] ??
            parsed['Model'] ??
            parsed['Model Desc'] ??
            parsed['Full Name'] ??
            parsed['Brand'])
        .toString()
        .trim()
        .isNotEmpty;

    final statusVal = (parsed['status'] ?? parsed['Status'] ?? parsed['result'] ?? parsed['error'] ?? '').toString().toUpperCase();
    final isRejectedOrFailed = !hasSpecs && (statusVal.contains('REJECT') ||
        statusVal.contains('FAIL') ||
        statusVal.contains('ERROR') ||
        statusVal.contains('CANCEL') ||
        parsed.containsKey('error') ||
        parsed.containsKey('errorMessage'));

    if (isRejectedOrFailed) {
      return const SizedBox.shrink();
    }

    final rows = parsed.entries
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        // ✅ IMEI, Serial Number စတဲ့ identifier များကို ဖျောက်ထားပါမယ်
        .where((e) => !['IMEI', 'imei2', 'serialNumber', 'sn', 'IMEI 2', 'status', 'Status', 'error', 'errorMessage', 'id', 'service_id', 'input', 'order_id', 'orderId'].contains(e.key))
        .toList();

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          final label = _labels[entry.key] ?? entry.key;
          final val = entry.value.toString();
          final color = _statusColor(context, entry.key, val);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(label, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        val, 
                        textAlign: TextAlign.end, 
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        )
                      ),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1) Divider(height: 1, color: scheme.outlineVariant),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _specRow(
  String label,
  String value,
  ColorScheme scheme,
  TextTheme textTheme, {
  bool isFirst = false,
}) {
  return Column(
    children: [
      if (!isFirst)
        Divider(height: 1, color: scheme.outlineVariant),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ─── Platform Fee Card ────────────────────────────────────────────────────────

class _PlatformFeeCard extends StatefulWidget {
  final String orderId;
  final int platformFee;
  final String sellerId;
  final String existingPayerName;
  final String existingProofUrl;
  final int existingTransferAmount;

  const _PlatformFeeCard({
    required this.orderId,
    required this.platformFee,
    required this.sellerId,
    required this.existingPayerName,
    required this.existingProofUrl,
    required this.existingTransferAmount,
  });

  @override
  State<_PlatformFeeCard> createState() => _PlatformFeeCardState();
}

class _PlatformFeeCardState extends State<_PlatformFeeCard> {
  List<Map<String, dynamic>> _bankAccounts = [];
  String _deadlineStr = '';

  // ── Fee proof upload state ──────────────────────────────────────────────
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  File?   _proofFile;
  bool    _uploading = false;
  String  _proofUrl  = '';
  String  _payerName = '';
  int     _transferAmount = 0;

  @override
  void initState() {
    super.initState();
    _proofUrl       = widget.existingProofUrl;
    _payerName      = widget.existingPayerName;
    _transferAmount = widget.existingTransferAmount;
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery မှ ရွေးရန်'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera နှင့် ရိုက်ရန်'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;
    setState(() => _proofFile = File(xfile.path));
  }

  Future<void> _submitProof() async {
    final name = _nameCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('နာမည် ထည့်ပေးပါ')));
      return;
    }
    if (amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('လွှဲသည့်ပမာဏ ထည့်ပေးပါ')));
      return;
    }
    final amount = int.tryParse(amountStr.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ပမာဏ မှန်ကန်အောင် ထည့်ပေးပါ')));
      return;
    }
    if (_proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot ရွေးပေးပါ')));
      return;
    }
    setState(() => _uploading = true);
    try {
      final feeUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final ref = FirebaseStorage.instance
          .ref()
          .child('fee_proofs')
          .child(feeUid)
          .child('${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_proofFile!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'feePayerName':      name,
        'feeProofUrl':       url,
        'feeTransferAmount': amount,
        'updatedAt':         FieldValue.serverTimestamp(),
      });

      // NOTE: onFeeProofSubmitted Cloud Function က admin notification ပို့ပေးသောကြောင့်
      // client-side ထပ်ခေါ်မလို

      if (mounted) {
        setState(() {
          _proofUrl       = url;
          _payerName      = name;
          _transferAmount = amount;
          _uploading      = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('လွှဲကြောင်း အောင်မြင်စွာ တင်ပြီးပါပြီ')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _loadData() async {
    // Load bank accounts
    final paySnap = await FirebaseFirestore.instance
        .collection('settings')
        .doc('payment')
        .get();
    final raw = paySnap.data()?['bankAccounts'] as List<dynamic>? ?? [];
    final accounts = raw
        .map((e) => {
              'name':        (e['name']        ?? '').toString(),
              'number':      (e['number']      ?? '').toString(),
              'accountName': (e['accountName'] ?? '').toString(),
            })
        .toList();

    // Load seller fee deadline
    final sellerSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sellerId)
        .get();
    final feeDeadline = sellerSnap.data()?['feeDeadline'];
    String deadline = '';
    if (feeDeadline is Timestamp) {
      final d = feeDeadline.toDate();
      deadline = '${d.day}/${d.month}/${d.year} အတွင်း လွှဲရမည်';
    }

    if (mounted) {
      setState(() {
        _bankAccounts = accounts;
        _deadlineStr = deadline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────
          Text(
            'Service Charge လွှဲပေးရန်',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),

          // ── Deadline ───────────────────────────────────────────────
          if (_deadlineStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _deadlineStr,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Fee amount ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ကျသင့်ငွေ', style: textTheme.bodyMedium),
                Text(
                  '${widget.platformFee} MMK',
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // ── Bank accounts ──────────────────────────────────────────
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.error.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(
            'လွှဲရမည့် အကောင့်',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          if (_bankAccounts.isEmpty)
            Text(
              'Admin ဆက်သွယ်ပြီး လွှဲပေးပါ',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ..._bankAccounts.map((acc) {
              final name        = acc['name']        ?? '';
              final number      = acc['number']      ?? '';
              final accountName = acc['accountName'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (name.isNotEmpty)
                            Text(name,
                                style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600)),
                          if (accountName.isNotEmpty)
                            Text(accountName,
                                style: textTheme.bodySmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w500)),
                          if (number.isNotEmpty)
                            Text(number,
                                style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (number.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.copy_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: number));
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'ကူးယူရန်',
                      ),
                  ],
                ),
              );
            }),

          // ── Fee Proof Upload / Display ──────────────────────────────
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.error.withValues(alpha: 0.3)),
          const SizedBox(height: 10),

          if (_proofUrl.isNotEmpty) ...[
            // ── Already submitted ────────────────────────────────────
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 16, color: scheme.tertiary),
                const SizedBox(width: 6),
                Text(
                  'လွှဲပြီးကြောင်း တင်ပြီးပြီ',
                  style: textTheme.labelMedium?.copyWith(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (_payerName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('လွှဲသူ: $_payerName',
                  style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
            ],
            if (_transferAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'လွှဲသည့်ပမာဏ: ${_transferAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} MMK',
                style: textTheme.bodySmall?.copyWith(
                    color: scheme.primary, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => FullScreenImagePage.show(context, _proofUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppNetworkImage(
                  _proofUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                ),
              ),
            ),
          ] else ...[
            // ── Upload form ──────────────────────────────────────────
            Text(
              'လွှဲပြီးကြောင်း တင်ပေးပါ',
              style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),

            // Name field
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'သင့်နာမည် (လွှဲသူ)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: scheme.surface,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),

            // Amount field
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'လွှဲသည့်ပမာဏ (MMK)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: scheme.surface,
                suffixText: 'MMK',
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),

            // Screenshot picker
            GestureDetector(
              onTap: _pickProofImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: scheme.outlineVariant,
                      style: BorderStyle.solid),
                ),
                child: _proofFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_proofFile!,
                            fit: BoxFit.cover,
                            width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 32,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(height: 4),
                          Text('Screenshot ရွေးရန်',
                              style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _uploading ? null : _submitProof,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(_uploading ? 'တင်နေသည်...' : 'လွှဲပြီးကြောင်း တင်မည်'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
