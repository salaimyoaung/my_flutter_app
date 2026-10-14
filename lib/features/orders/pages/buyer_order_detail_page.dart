import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/widgets/copy_text_row.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/order_service.dart';
import '../../../data/services/review_service.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';
import 'package:sigmamoby/shared/pages/full_screen_image_page.dart';

class BuyerOrderDetailPage extends StatefulWidget {
  final OrderModel order;

  const BuyerOrderDetailPage({super.key, required this.order});

  @override
  State<BuyerOrderDetailPage> createState() => _BuyerOrderDetailPageState();
}

class _BuyerOrderDetailPageState extends State<BuyerOrderDetailPage> {
  // ── Review bottom sheet ───────────────────────────────────────────────────
  Future<void> _showReviewSheet(OrderModel o) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final scheme    = Theme.of(ctx).colorScheme;
        final textTheme = Theme.of(ctx).textTheme;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.star_rounded, color: scheme.tertiary, size: 22),
                  const SizedBox(width: 8),
                  Text('ရောင်းသူဆီ Review ရေးမည်',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text(o.sellerName,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 16),

                // ── Star rating ───────────────────────────────────────
                Row(
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setSheet(() => rating = star),
                      child: Icon(
                        star <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: scheme.tertiary,
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // ── Comment ───────────────────────────────────────────
                TextField(
                  controller: commentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'သင်၏ အတွေ့အကြုံကို ရေးပါ...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: scheme.surface,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Submit ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: submitting
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(submitting ? 'တင်နေသည်...' : 'Review တင်မည်'),
                    onPressed: submitting
                        ? null
                        : () async {
                            setSheet(() => submitting = true);
                            try {
                              await ReviewService.submitReview(
                                sellerId:    o.sellerId,
                                orderId:     o.id,
                                productName: o.productName,
                                rating:      rating,
                                comment:     commentCtrl.text.trim(),
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _invalidateReviewCache();
                              });
                              _snack('Review တင်ပြီးပါပြီ ⭐');
                            } catch (e) {
                              setSheet(() => submitting = false);
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())));
                            }
                          },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => commentCtrl.dispose());
  }

  // ── Confirm Received inline state ─────────────────────────────────────────
  File? _receiptFile;
  File? _productFile;
  bool  _uploading = false;

  // imei.org API check

  // ✅ Cache hasReviewed future — StreamBuilder ထဲ FutureBuilder ထည့်ထားသောကြောင့်
  // stream emit တိုင်း Firestore read ထပ်ဖတ်မနေအောင် state မှာ cache လုပ်သည်
  // Review တင်ပြီးနောက် _invalidateReviewCache() ခေါ်မှသာ ပြန် fetch လုပ်မည်
  Future<bool>? _hasReviewedFuture;

  void _invalidateReviewCache() {
    setState(() => _hasReviewedFuture = null);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<File?> _pickImage() async {
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
    if (source == null) return null;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<void> _submitConfirm(String orderId) async {
    if (_receiptFile == null) {
      _snack('Delivery ဘောင်ချာပုံ upload လုပ်ပါ'); return;
    }
    if (_productFile == null) {
      _snack('ရရှိတဲ့ ပစ္စည်းပုံ upload လုပ်ပါ'); return;
    }
    setState(() => _uploading = true);
    try {
      final buyerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('received_photos')
          .child(buyerUid);

      final receiptRef = storageRef.child('${orderId}_receipt_$ts.jpg');
      await receiptRef.putFile(_receiptFile!, SettableMetadata(contentType: 'image/jpeg'));
      final receiptUrl = await receiptRef.getDownloadURL();

      final productRef = storageRef.child('${orderId}_product_$ts.jpg');
      await productRef.putFile(_productFile!, SettableMetadata(contentType: 'image/jpeg'));
      final productUrl = await productRef.getDownloadURL();

      await OrderService.buyerConfirmReceived(
        orderId: orderId,
        receivedReceiptUrl: receiptUrl,
        receivedProductUrl: productUrl,
      );

      if (!mounted) return;
      _snack('ပစ္စည်းလက်ခံကြောင်း confirm ပြုလုပ်ပြီး — Admin မှ deposit ပြန်လွှဲပေးပါမည်');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showReturnSheet(String orderId) async {
    final reasonCtrl = TextEditingController();
    final List<File> localPhotos = [];
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final scheme = Theme.of(ctx).colorScheme;
        final textTheme = Theme.of(ctx).textTheme;

        return SingleChildScrollView(
          padding: EdgeInsets.only(left: 16, right: 16, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.assignment_return_outlined, color: scheme.error, size: 22),
                const SizedBox(width: 8),
                Text('ပစ္စည်းပြန်ပေးမည် (Return Product)', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text('ပစ္စည်းသည် ဖော်ပြချက်နှင့် မကိုက်ညီပါက ဤနေရာတွင် အထောက်အထားများနှင့်အတူ တင်ပြနိုင်ပါသည်။',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),

              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                onChanged: (v) => setSheet(() {}),
                decoration: InputDecoration(
                  hintText: 'မကိုက်ညီသည့် အချက်များကို ရေးသားပါ...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              Text('သက်သေပြ ဓာတ်ပုံများ (အများဆုံး ၅ ပုံ)', style: textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...localPhotos.map((f) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(f, width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => setSheet(() => localPhotos.remove(f)),
                          child: CircleAvatar(radius: 10, backgroundColor: scheme.error, child: const Icon(Icons.close, size: 12, color: Colors.white)),
                        ),
                      ),
                    ],
                  )),
                  if (localPhotos.length < 5)
                    GestureDetector(
                      onTap: () async {
                        final f = await _pickImage();
                        if (f != null) setSheet(() => localPhotos.add(f));
                      },
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: scheme.error),
                  onPressed: submitting || reasonCtrl.text.trim().isEmpty || localPhotos.isEmpty ? null : () async {
                    setSheet(() => submitting = true);
                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                      final List<String> urls = [];
                      for (var f in localPhotos) {
                        final ts = DateTime.now().millisecondsSinceEpoch;
                        final ref = FirebaseStorage.instance.ref()
                            .child('return_photos')
                            .child(uid)
                            .child('$orderId' '_$ts.jpg');
                        await ref.putFile(f, SettableMetadata(contentType: 'image/jpeg'));
                        urls.add(await ref.getDownloadURL());
                      }
                      await OrderService.buyerRequestReturn(orderId: orderId, reason: reasonCtrl.text.trim(), returnPhotos: urls);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _snack('Return Request တင်ပြီးပါပြီ။ Admin စစ်ဆေးပေးပါမည်။');
                    } catch (e) {
                      setSheet(() => submitting = false);
                      _snack(e.toString());
                    }
                  },
                  child: submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Return Request တင်မည်'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _photoTile({
    required ColorScheme scheme,
    required String label,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _uploading ? null : onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
              color: file != null ? scheme.primary : scheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: file == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: Row(children: [
                  Icon(icon, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label,
                      style: TextStyle(color: scheme.onSurfaceVariant))),
                ]),
              )
            : Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file,
                      height: 130, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 6, right: 6,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.surface,
                    child: Icon(Icons.edit_outlined, size: 16, color: scheme.primary),
                  ),
                ),
              ]),
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

                  // ── Product ────────────────────────────────────────────
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
                          o.isFeePending && o.depositReturned
                              ? 'Status: 🎉 Completed'
                              : o.isFeePending
                                  ? 'Status: 🕐 Deposit ပြန်ရရန် စောင့်ဆိုင်းပါ'
                                  : 'Status: ${o.statusEmoji} ${o.statusLabel}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    )),
                  ),

                  // ── imei.org Verification (Only after admin runs API check) ─
                  if (!o.isCancelled && !o.isRejected) ...[
                    const SizedBox(height: 16),
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

                        return _card(scheme, Column(
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
                        ));
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Refund proof (rejected ဖြစ်ပြီး admin ပြန်လွှဲပေးတဲ့ ပုံ) ─
                  if (o.isRejected && o.rejectRefundProofUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Deposit ပြန်လွှဲပြေစာ',
                              style: textTheme.labelMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AppNetworkImage(
                            o.rejectRefundProofUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            onTap: () => FullScreenImagePage.show(
                                context, o.rejectRefundProofUrl),
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ],
                    )),
                  ],

                  // ── Delivery Info ──────────────────────────────────────
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
                          CopyTextRow(label: 'Phone', value: o.deliveryPhone),
                        if (o.deliveryVoucherUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('ဘောင်ချာပုံ', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppNetworkImage(
                              o.deliveryVoucherUrl,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              onTap: () => FullScreenImagePage.show(context, o.deliveryVoucherUrl),
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                        ],
                        if (o.deliveryProductUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('ပစ္စည်းပုံ', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppNetworkImage(
                              o.deliveryProductUrl,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              onTap: () => FullScreenImagePage.show(context, o.deliveryProductUrl),
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                        ],
                      ],
                    )),
                  ],

                  // ── Received Proof (completed ဖြစ်ပြီးမှ ပြ) ──────────
                  if (o.isCompleted &&
                      (o.receivedReceiptUrl.isNotEmpty ||
                          o.receivedProductUrl.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_outlined,
                                size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text('လက်ခံကြောင်း အထောက်အထား',
                                style: textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (o.receivedReceiptUrl.isNotEmpty) ...[
                          Text('ဘောင်ချာပုံ',
                              style: textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppNetworkImage(
                              o.receivedReceiptUrl,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              onTap: () => FullScreenImagePage.show(context, o.receivedReceiptUrl),
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (o.receivedProductUrl.isNotEmpty) ...[
                          Text('ပစ္စည်းပုံ',
                              style: textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppNetworkImage(
                              o.receivedProductUrl,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              onTap: () => FullScreenImagePage.show(context, o.receivedProductUrl),
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                        ],
                      ],
                    )),
                  ],

                  // ── Deposit Return Status (Refund / Return Deposit) ──
                  if (o.isFeePending || o.isCompleted || o.isRefunded || o.isCancelled) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              o.depositReturned
                                  ? Icons.check_circle_rounded
                                  : Icons.account_balance_wallet_outlined,
                              size: 16,
                              color: o.depositReturned
                                  ? scheme.tertiary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              (o.isRefunded || o.isCancelled) ? 'Refund ပြန်အမ်းငွေ' : 'Deposit ပြန်အမ်းကြေး',
                              style: textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ပမာဏ', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                            Text(
                              '${o.depositAmount} MMK',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (o.depositReturned) ...[
                          Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 15, color: scheme.tertiary),
                              const SizedBox(width: 6),
                              Text(
                                'Deposit ပြန်ရပြီ ✅',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (o.depositReturnProofUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => FullScreenImagePage.show(context, o.depositReturnProofUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppNetworkImage(
                                  o.depositReturnProofUrl,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.hourglass_empty_rounded, size: 15, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                'Admin မှ ပြန်လွှဲရန် စောင့်ဆိုင်းနေသည်',
                                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ],
                    )),
                  ],

                  // ── Write Review (completed orders only) ──────────────
                  if (o.isCompleted) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<bool>(
                      future: () {
                        // ✅ Cache — stream emit တိုင်း Firestore read မထပ်ဖတ်အောင်
                        _hasReviewedFuture ??= ReviewService.hasReviewed(o.id);
                        return _hasReviewedFuture!;
                      }(),
                      builder: (context, snap) {
                        final reviewed = snap.data ?? false;
                        if (reviewed) {
                          return _card(scheme, Row(
                            children: [
                              Icon(Icons.star_rounded,
                                  color: scheme.tertiary, size: 18),
                              const SizedBox(width: 8),
                              Text('Review တင်ပြီးပြီ ✅',
                                  style: textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ));
                        }
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.star_outline_rounded),
                            label: const Text('ရောင်းသူဆီ Review ရေးမည်'),
                            onPressed: () => _showReviewSheet(o),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Action Buttons ─────────────────────────────────────
                  if (o.isPending)
                    _actionButton(
                      context,
                      text: 'Cancel Order',
                      background: scheme.error,
                      foreground: scheme.onError,
                      onPressed: () async {
                        try {
                          await OrderService.buyerCancel(orderId: o.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            _snack(e.toString().replaceAll('Exception: ', ''));
                          }
                        }
                      },
                    ),

                  // ── Confirm Received inline section ───────────────────
                  if (o.isOnTheWay) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.verified_outlined,
                              color: scheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text('လက်ခံကြောင်း အတည်ပြုရန်',
                              style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 4),
                        Text('ပုံ ၂ ခုမဖြစ်မနေ upload လုပ်မှ complete လုပ်နိုင်သည်',
                            style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 14),

                        // ① Delivery receipt
                        Text('① Delivery ဘောင်ချာပုံ',
                            style: textTheme.labelMedium),
                        const SizedBox(height: 6),
                        _photoTile(
                          scheme: scheme,
                          label: 'Delivery service ဘောင်ချာပုံ upload လုပ်ပါ',
                          icon: Icons.receipt_long_outlined,
                          file: _receiptFile,
                          onTap: () async {
                            final f = await _pickImage();
                            if (f != null) setState(() => _receiptFile = f);
                          },
                        ),
                        const SizedBox(height: 12),

                        // ② Product photo
                        Text('② ရရှိတဲ့ ပစ္စည်းပုံ',
                            style: textTheme.labelMedium),
                        const SizedBox(height: 6),
                        _photoTile(
                          scheme: scheme,
                          label: 'ရရှိတဲ့ ပစ္စည်းပုံ upload လုပ်ပါ',
                          icon: Icons.inventory_2_outlined,
                          file: _productFile,
                          onTap: () async {
                            final f = await _pickImage();
                            if (f != null) setState(() => _productFile = f);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: _uploading
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_outline),
                            label: Text(_uploading
                                ? 'Uploading...'
                                : 'Confirm Received'),
                            onPressed: _uploading
                                ? null
                                : () => _submitConfirm(o.id),
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 🚩 Return Product Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.assignment_return_outlined),
                            label: const Text('ပစ္စည်းမကိုက်ညီ၍ ပြန်ပေးမည် (Return)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.error,
                              side: BorderSide(color: scheme.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _uploading ? null : () => _showReturnSheet(o.id),
                          ),
                        ),
                      ],
                    )),
                  ],
                  
                  // ── Return Info (if requested or already refunded) ──────
                  if (o.isReturnPending || o.isReturnRejected || o.isReturnClaimed || (o.isRefunded && o.returnReason.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    _card(scheme, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            (o.isReturnRejected || o.isReturnClaimed || (o.isRefunded && o.refundedTo == 'seller')) 
                                ? Icons.report_problem_rounded 
                                : o.isRefunded ? Icons.assignment_returned_rounded : Icons.assignment_return_rounded, 
                            color: (o.isReturnRejected || o.isReturnClaimed || (o.isRefunded && o.refundedTo == 'seller')) 
                                ? scheme.error 
                                : o.isRefunded ? scheme.primary : scheme.error, 
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (o.isReturnRejected || o.isReturnClaimed)
                                  ? 'Return Request ကို ပယ်ချထားသည်'
                                  : (o.isRefunded && o.refundedTo == 'seller')
                                      ? 'Return ကို ငြင်းပယ်၍ Seller ထံ Refund ပေးလိုက်ပါပြီ'
                                      : o.isRefunded ? 'Order အား Refund ပေးလိုက်ပါပြီ' : 'Return Request တင်ထားသည်', 
                              style: textTheme.titleSmall?.copyWith(
                                color: (o.isReturnRejected || o.isReturnClaimed || (o.isRefunded && o.refundedTo == 'seller')) 
                                    ? scheme.error 
                                    : o.isRefunded ? scheme.primary : scheme.error, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text('Reason: ${o.returnReason}', style: textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        if (o.returnPhotos.isNotEmpty)
                          SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: o.returnPhotos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (ctx, i) => GestureDetector(
                                onTap: () => FullScreenImagePage.show(context, o.returnPhotos[i]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AppNetworkImage(o.returnPhotos[i], width: 100, height: 100, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        
                        if (o.isReturnRejected || o.isReturnClaimed || (o.isRefunded && o.refundedTo == 'seller')) ...[
                          const SizedBox(height: 12),
                          Divider(height: 1, color: scheme.outlineVariant),
                          const SizedBox(height: 12),
                          Text('Admin ၏ ဆုံးဖြတ်ချက်:', style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(o.returnRejectReason, style: textTheme.bodySmall),
                          if (o.undeliverableProofUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkImage(o.undeliverableProofUrl, height: 140, width: double.infinity, fit: BoxFit.cover,
                                  onTap: () => FullScreenImagePage.show(context, o.undeliverableProofUrl)),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text('ဝယ်သူ၏ အကြောင်းပြချက် မခိုင်လုံဟု ယူဆသဖြင့် Deposit ငွေကို Seller ၏ Delivery ခ အဖြစ် လွှဲပေးလိုက်မည် ဖြစ်ပါသည်။',
                              style: textTheme.bodySmall?.copyWith(color: scheme.error, fontStyle: FontStyle.italic)),
                        ] else if (o.isReturnPending) ...[
                          const SizedBox(height: 12),
                          Text('Admin မှ စစ်ဆေးပြီးနောက် deposit ပြန်အမ်းခြင်း သို့မဟုတ် seller ထံ ပစ္စည်းပြန်ပို့ခြင်းများကို လုပ်ဆောင်ပေးပါမည်။',
                              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
                        ],
                      ],
                    )),
                  ],

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
                            child: Text('Seller မှ Order ကို ပယ်ဖျက်လိုက်ပါသည်', 
                                style: textTheme.titleSmall?.copyWith(color: scheme.error, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Text('ရောင်းသူ၏ အကြောင်းပြချက်: ${o.rejectReason}', style: textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        Text('ပို့ဆောင်ရန် အဆင်မပြေပါသဖြင့် Seller မှ ပယ်ဖျက်လိုက်ခြင်း ဖြစ်ပါသည်။ Admin မှ သင့်ထံ Deposit ငွေများ ပြန်လွှဲပေးရန် ဆောင်ရွက်နေပြီ ဖြစ်ပါသည်။',
                            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                      ],
                    )),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── UI Helpers ───────────────────────────────────────────────────────────

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

  Widget _actionButton(
    BuildContext context, {
    required String text,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: onPressed,
          child: Text(text),
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// IMEI.org Result Table for Orders
// ─────────────────────────────────────────────────────────────────────────────

class _ImeiOrgOrderResultTable extends StatelessWidget {
  final Map<String, dynamic> parsed;
  const _ImeiOrgOrderResultTable({required this.parsed});

  static const _labels = <String, String>{
    'modelName':      'Model',
    'modelNumber':    'Model Number',
    'fullName':       'Full Name',
    'storage':        'Storage',
    'color':          'Color',
    'manufacturer':   'Manufacturer',
    'productionDate': 'Production Date',
    'purchaseDate':   'Date of Purchase',
    'warrantyUntil':  'Warranty Until',
    'warrantyStatus': 'Warranty Status',
    'carrier':        'Carrier',
    'country':        'Country',
    'activated':      'Activated',
    'simlock':        'Network Lock',
    'blacklist':      'Blacklist',
    'fmi':            'iCloud Lock (FMI)',
    'icloud':         'iCloud Status',
    'knoxGuard':      'KnoxGuard',
    'soldDate':       'Sold Date',
    'shipDate':       'Ship Date',
    'soldToCountry':  'Sold-to Country',
    'shipToCountry':  'Ship-to Country',
    'doNumber':       'DO Number',
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
