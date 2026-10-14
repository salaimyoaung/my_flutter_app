import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/copy_text_row.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/order_service.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';
import 'package:sigmamoby/shared/pages/full_screen_image_page.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final OrderModel order;

  const AdminOrderDetailPage({super.key, required this.order});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  // imei.org API check
  bool _imeiOrgLoading = false;
  String _imeiOrgError = '';

  void _snack(BuildContext context, String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('အတည်ပြုရန်'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('မလုပ်ပါ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('အတည်ပြုမည်'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static const _rejectPresets = [
    'Deposit ငွေ မရရှိပါသောကြောင့် Reject လုပ်ပါသည်။ deposit ငွေလွှဲပြီး order အသစ် ပြန်တင်ပေးပါ',
    'အကောင့် နာမည် လွဲမှားနေပါသဖြင့် Reject လုပ်ပါသည်။ မှန်ကန်သော နာမည်ဖြင့် order အသစ် ပြန်တင်ပေးပါ။',
    'Screenshot လွဲမှားနေပါသဖြင့် Reject လုပ်ပါသည်။ မှန်ကန်သော Screenshotဖြင့် order အသစ် ပြန်တင်ပေးပါ။',
    'သတ်မှတ်ထားသော deposit မပြည့်ပါသဖြင့် Reject လုပ်ပါသည်။ လွှဲထားသော deposit ငွေ ပြန်လွှဲပေးပါမည်။ Deposit အပြည့်ပြန်လွှဲပြီး order အသစ် ပြန်တင်ပေးပါ။',
    'ရောင်းသူနှင့် ဝယ်သူ မြို့ချင်း အလွန်ဝေးပါသောကြောင့် Delivery လက်မခံ၍ Reject လုပ်ရခြင်း ဖြစ်ပါသည်။ Deposit ငွေ ပြန်လွှဲပေးပါမည်။',
  ];

  Future<void> _runImeiOrgCheck({
    required String? imei,
    required String productId,
    required String brand,
  }) async {
    if (productId.isEmpty) {
      _snack(context, 'Product ID မရှိပါ');
      return;
    }

    if (_imeiOrgLoading) return;

    setState(() {
      _imeiOrgLoading = true;
      _imeiOrgError = '';
    });

    String targetImei = imei ?? '';

    // ✅ If imei is missing (not copied to order yet), fetch from imei_registry
    if (targetImei.isEmpty) {
      try {
        final registrySnap = await FirebaseFirestore.instance
            .collection('imei_registry')
            .where('productId', isEqualTo: productId)
            .limit(1)
            .get();

        if (registrySnap.docs.isNotEmpty) {
          // doc ID in imei_registry is the full IMEI
          targetImei = registrySnap.docs.first.id;
        }
      } catch (e) {
        debugPrint('[IMEI_DEBUG] Registry fetch error: $e');
      }
    }

    if (targetImei.isEmpty) {
      if (mounted) setState(() => _imeiOrgLoading = false);
      if (context.mounted) {
        _snack(context, 'IMEI အချက်အလက် ရှာမတွေ့ပါ (Seller မှ IMEI မထည့်ထားခြင်း ဖြစ်နိုင်သည်)');
      }
      return;
    }

    final deviceType = (brand.toLowerCase() == 'apple') ? 'iphone' : brand.toLowerCase();
    
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable(
            'runImeiCheck',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 4)),
          )
          .call({
        'imei':       targetImei,
        'productId':  productId,
        'brand':      brand,
        'deviceType': deviceType,
      });
      if (!mounted) return;
      setState(() => _imeiOrgError = '');
      _snack(context, 'IMEI စစ်ဆေးပြီးပါပြီ ✅');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final isTimeout = e.code == 'deadline-exceeded' || e.code == 'unavailable';
      final errText = isTimeout
          ? 'imei.org API စစ်ဆေးမှု ကြာမြင့်နေပါသည် (Timeout/Server Busy)။ imei.org တွင် စစ်ဆေးနေဆဲ ဖြစ်နိုင်သောကြောင့် ခဏကြာလျှင် Run API Check ကို ပြန်လည်နှိပ်ပါ။'
          : '${e.code}: ${e.message}';
      setState(() => _imeiOrgError = errText);

      try {
        await FirebaseFirestore.instance.collection('products').doc(productId).set({
          'imeiCheckParsed': {
            'status': e.code.contains('reject') ? 'REJECTED' : 'TIMEOUT',
            'error': errText,
            'errorMessage': errText,
          },
          'imeiCheckedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (saveErr) {
        debugPrint('[IMEI_DEBUG] Failed to save imei error to product: $saveErr');
      }
    } catch (e) {
      if (!mounted) return;
      final errText = 'API စစ်ဆေးမှု ချိတ်ဆက်မရပါ: ${e.toString()}';
      setState(() => _imeiOrgError = errText);
    } finally {
      if (mounted) setState(() => _imeiOrgLoading = false);
    }
  }

  void _showDepositReturnSheet(BuildContext context, OrderModel o) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DepositReturnCard(order: o),
    );
  }

  Future<void> _showRejectDialog(BuildContext context, OrderModel o) async {
    final orderId = o.id;
    final ctrl    = TextEditingController();
    final scheme  = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        File? refundProofFile;
        bool uploading = false;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            // ── Image picker helper ──────────────────────────────────────
            Future<void> pickRefundProof() async {
              final source = await showModalBottomSheet<ImageSource>(
                context: ctx,
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
              final picked = await ImagePicker()
                  .pickImage(source: source, imageQuality: 85);
              if (picked != null) {
                setSheet(() => refundProofFile = File(picked.path));
              }
            }

            // ── Submit handler ───────────────────────────────────────────
            Future<void> submit() async {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) return;

              setSheet(() => uploading = true);
              String? photoUrl;

              // Upload refund proof photo if provided
              if (refundProofFile != null) {
                try {
                  final ts  = DateTime.now().millisecondsSinceEpoch;
                  final ref = FirebaseStorage.instance
                      .ref()
                      .child('reject_proofs')
                      .child('${orderId}_$ts.jpg');
                  await ref.putFile(
                      refundProofFile!,
                      SettableMetadata(contentType: 'image/jpeg'));
                  photoUrl = await ref.getDownloadURL();
                } catch (_) {
                  // Non-fatal — proceed without photo
                }
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx, {'reason': reason, 'photoUrl': photoUrl});
            }

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────
                  Row(
                    children: [
                      Icon(Icons.cancel_outlined,
                          color: scheme.error, size: 20),
                      const SizedBox(width: 8),
                      Text('Reject Reason',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Buyer Refund Account ─────────────────────────────
                  if (o.refundBankName.isNotEmpty || o.refundAccountNo.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Buyer ၏ ပြန်လွှဲရမည့် အကောင့်', 
                              style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (o.refundBankName.isNotEmpty)
                            Text('Bank/Wallet: ${o.refundBankName}', style: textTheme.bodySmall),
                          if (o.refundAccountNo.isNotEmpty)
                            Row(
                              children: [
                                Expanded(child: Text('နံပါတ်: ${o.refundAccountNo}', style: textTheme.bodySmall)),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: o.refundAccountNo));
                                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          if (o.refundAccountName.isNotEmpty)
                            Text('နာမည်: ${o.refundAccountName}', style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Preset chips ─────────────────────────────────────
                  Text('အသင့်သုံး reason များ',
                      style: textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  ...List.generate(_rejectPresets.length, (i) {
                    return GestureDetector(
                      onTap: uploading ? null : () {
                        ctrl.text = _rejectPresets[i];
                        ctrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: ctrl.text.length),
                        );
                        setSheet(() {});
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: ctrl.text == _rejectPresets[i]
                              ? scheme.errorContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ctrl.text == _rejectPresets[i]
                                ? scheme.error
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          _rejectPresets[i],
                          style: textTheme.bodySmall?.copyWith(
                            color: ctrl.text == _rejectPresets[i]
                                ? scheme.onErrorContainer
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 4),

                  // ── Custom text field ────────────────────────────────
                  Text('သို့မဟုတ် ကိုယ်တိုင် ရေးပါ',
                      style: textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    maxLines: 2,
                    enabled: !uploading,
                    onChanged: (_) => setSheet(() {}),
                    decoration: InputDecoration(
                      hintText: 'Reason ရေးပါ...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Optional refund proof photo ──────────────────────
                  Text('Deposit ပြန်လွှဲ ပုံ (မဖြစ်မနေ မဟုတ်)',
                      style: textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: uploading ? null : pickRefundProof,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: refundProofFile != null
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: refundProofFile == null
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      color: scheme.onSurfaceVariant, size: 20),
                                  const SizedBox(width: 8),
                                  Text('ငွေလွှဲပုံ ထည့်မည် (optional)',
                                      style: textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            )
                          : Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    refundProofFile!,
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: uploading
                                        ? null
                                        : () => setSheet(
                                            () => refundProofFile = null),
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: scheme.error,
                                      child: Icon(Icons.close,
                                          size: 14, color: scheme.onError),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Actions ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              uploading ? null : () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                          ),
                          icon: uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cancel_outlined, size: 18),
                          label: Text(uploading ? 'Uploading...' : 'Reject'),
                          onPressed: (ctrl.text.trim().isEmpty || uploading)
                              ? null
                              : submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    final reason    = (result['reason'] as String?) ?? '';
    final photoUrl  = result['photoUrl'] as String?;
    if (reason.isEmpty) return;

    try {
      await OrderService.adminRejectDeposit(
        orderId: orderId,
        reason: reason,
        refundProofUrl: photoUrl,
      );
      if (!context.mounted) return;
      _snack(context, 'Rejected ❌');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(title: 'Admin Order Detail'),
      // ✅ Stream — live updates as admin acts on order
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // ── Product ──────────────────────────────────────────
                _card(scheme, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.productName, style: textTheme.titleMedium),
                    const SizedBox(height: 6),
                    // ✅ formattedPrice
                    Text('Price: ${o.formattedPrice}'),
                    Text('Qty: ${o.quantity}'),
                    const SizedBox(height: 8),
                    // ✅ statusEmoji + statusLabel
                    Text(
                      'Status: ${o.statusEmoji} ${o.statusLabel}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                )),

                const SizedBox(height: 16),

                // ── Buyer ────────────────────────────────────────────
                _card(scheme, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buyer', style: textTheme.titleSmall),
                    const SizedBox(height: 10),
                    _UserProfileTile(
                      userId: o.buyerId,
                      name: o.buyerName,
                      subtitle: '${o.buyerPhone}  •  ${o.depositCity}',
                      onTap: o.buyerId.isNotEmpty
                          ? () => context.push(
                                AppRoutes.sellerWallPath(o.buyerId))
                          : null,
                    ),
                    const SizedBox(height: 6),
                    if (o.buyerAddress.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'လိပ်စာ: ${o.buyerAddress}',
                          style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                )),

                const SizedBox(height: 16),

                // ── Seller ───────────────────────────────────────────
                _card(scheme, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seller', style: textTheme.titleSmall),
                    const SizedBox(height: 10),
                    _UserProfileTile(
                      userId: o.sellerId,
                      name: o.sellerName,
                      onTap: o.sellerId.isNotEmpty
                          ? () => context.push(
                                AppRoutes.sellerWallPath(o.sellerId))
                          : null,
                    ),
                    // ── Seller address from Firestore (phone/city shown inside tile) ──
                    if (o.sellerId.isNotEmpty)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(o.sellerId)
                            .snapshots(),
                        builder: (context, snap) {
                          final addr = (snap.data?.data()?['address'] ?? '').toString();
                          if (addr.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            child: Text(
                              'လိပ်စာ: $addr',
                              style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                  ],
                )),

                const SizedBox(height: 16),

                // ── Shipping Route ────────────────────────────────────
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: o.sellerId.isNotEmpty
                      ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(o.sellerId)
                          .snapshots()
                      : null,
                  builder: (context, snap) {
                    final sellerCity =
                        (snap.data?.data()?['shopCity'] ?? '').toString();
                    final buyerCity = o.depositCity;
                    return _card(
                      scheme,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── From → To row ─────────────────────────
                          Row(
                            children: [
                              // From (seller city)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From',
                                      style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      sellerCity.isNotEmpty
                                          ? sellerCity
                                          : '—',
                                      style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),

                              // Arrow
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward_rounded,
                                    size: 22, color: scheme.primary),
                              ),

                              // To (buyer city)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'To',
                                      style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      buyerCity.isNotEmpty ? buyerCity : '—',
                                      style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700),
                                      textAlign: TextAlign.end,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          Divider(height: 1, color: scheme.outlineVariant),
                          const SizedBox(height: 10),

                          // ── Deposit amount row ─────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Deposit',
                                style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant),
                              ),
                              Text(
                                '${o.depositAmount} MMK',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ── Deposit ──────────────────────────────────────────
                _card(scheme, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deposit', style: textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text('Amount: ${o.depositAmount} MMK'),
                    Text('Status: ${o.depositStatus}'),
                    if (o.depositTxId.isNotEmpty)
                      CopyTextRow(label: 'လွှဲသူ', value: o.depositTxId),
                    // ── Refund account ────────────────────────────────
                    if (o.refundBankName.isNotEmpty ||
                        o.refundAccountNo.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 10),
                      Text(
                        'Deposit ပြန်လွှဲရမည့် အကောင့်',
                        style: textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      if (o.refundBankName.isNotEmpty)
                        Text('Bank/Wallet: ${o.refundBankName}'),
                      if (o.refundAccountNo.isNotEmpty)
                        CopyTextRow(label: 'နံပါတ်', value: o.refundAccountNo),
                      if (o.refundAccountName.isNotEmpty)
                        Text('နာမည်: ${o.refundAccountName}'),
                    ],
                    // ✅ Screenshot for admin to verify
                    if (o.depositScreenshotUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AppNetworkImage(
                          o.depositScreenshotUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          onTap: () => FullScreenImagePage.show(context, o.depositScreenshotUrl),
                          errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image),
                        ),
                      ),
                    ],

                    // ── Refund proof photo (shown when rejected + photo exists) ──
                    if (o.isRejected && o.rejectRefundProofUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 12),
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
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          onTap: () => FullScreenImagePage.show(context, o.rejectRefundProofUrl),
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    ],
                  ],
                )),

                // ── IMEI Info ─────────────────────────────────────────
                // Always show if productId exists, so we can fetch IMEI from product 
                // even if it's missing in the order (for older orders).
                if (o.productId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .doc(o.productId)
                        .snapshots(),
                    builder: (context, pSnap) {
                      final pData = pSnap.data?.data();
                      if (pData == null) return const SizedBox.shrink();
                      final product = Product.fromFirestore(o.productId, pData);
                      
                      // Use product's IMEI if order's IMEI is missing
                      final displayImei = o.imeiFull.isNotEmpty ? o.imeiFull : product.imeiFull;
                      final displayImeiPhoto = o.imeiPhoto.isNotEmpty ? o.imeiPhoto : product.imeiPhoto;

                      if (displayImei.isEmpty && displayImeiPhoto.isEmpty) return const SizedBox.shrink();

                      return _card(scheme, Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Seller-Listed Specs (Moved from IMEI Verification Page) ──
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

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Text('IMEI Verification', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              const Spacer(),
                              // 🔍 Run IMEI Check Button for Admin
                              if (!o.isCancelled && !o.isRejected)
                                FilledButton.tonal(
                                  onPressed: _imeiOrgLoading ? null : () => _runImeiOrgCheck(
                                    imei: displayImei,
                                    productId: o.productId,
                                    brand: o.productBrand,
                                  ),
                                  style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      visualDensity: VisualDensity.compact),
                                  child: _imeiOrgLoading
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('🔍 Run API Check'),
                                ),
                            ],
                          ),
                          
                          if (_imeiOrgError.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_imeiOrgError, style: TextStyle(color: scheme.error, fontSize: 11)),
                          ],

                          // ── Display IMEI API Result if exists or error ──────────────────
                          if (product.imeiCheckParsed.isNotEmpty || _imeiOrgError.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Divider(height: 1, color: scheme.outlineVariant),
                            const SizedBox(height: 10),
                            Text('imei.org API Result',
                                style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _ImeiOrgAdminResultTable(
                              parsed: product.imeiCheckParsed,
                              apiError: _imeiOrgError,
                            ),
                            const SizedBox(height: 10),
                            _ImeiOrgVerificationSummaryCard(
                              product: product,
                              parsed: product.imeiCheckParsed,
                              apiError: _imeiOrgError,
                            ),
                          ],
                        ],
                      ));
                    },
                  ),
                ],


                // ── Delivery Info ─────────────────────────────────────
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
                            errorBuilder: (_, _, _) =>
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
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ],
                    ],
                  )),
                ],

                // ── Buyer Received Proof ──────────────────────────────
                if ((o.isFeePending || o.isCompleted || o.isReturnPending) &&
                    (o.receivedReceiptUrl.isNotEmpty ||
                        o.receivedProductUrl.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  _card(scheme, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 16, color: scheme.tertiary),
                          const SizedBox(width: 6),
                          Text('Buyer လက်ခံကြောင်း အထောက်အထား',
                              style: textTheme.titleSmall?.copyWith(
                                  color: scheme.tertiary)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ① Delivery ဘောင်ချာပုံ
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

                      // ② ရရှိတဲ့ ပစ္စည်းပုံ
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

                // ── Return Request Info (Admin only) ───────────────────
                if (o.isReturnPending) ...[
                  const SizedBox(height: 16),
                  _card(scheme, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.warning_amber_rounded, color: scheme.error, size: 18),
                        const SizedBox(width: 8),
                        Text('Buyer Return Request တင်ထားသည်', style: textTheme.titleSmall?.copyWith(color: scheme.error, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 10),
                      Text('Reason: ${o.returnReason}', style: textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      if (o.returnPhotos.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: o.returnPhotos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, i) => GestureDetector(
                              onTap: () => FullScreenImagePage.show(context, o.returnPhotos[i]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppNetworkImage(o.returnPhotos[i], width: 120, height: 120, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text('Admin Action:', style: textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Accept & Refund'),
                              style: FilledButton.styleFrom(backgroundColor: scheme.secondary),
                              onPressed: () async {
                                final ok = await _confirm('Return Request ကို အတည်ပြုပြီး ဝယ်သူကို Refund ပေးမှာ သေချာပါသလား?');
                                if (!ok) return;
                                // This will use the unified _DepositReturnCard below
                                // We'll scroll down or just hint
                                _snack(context, 'အောက်ပါ "Deposit ပြန်လွှဲမည်" ကတ်တွင် ပုံတင်ပေးပါ။');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Reject Refund'),
                              style: FilledButton.styleFrom(backgroundColor: scheme.error),
                              onPressed: () async {
                                final ctrl = TextEditingController();
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Reject Return Request'),
                                    content: TextField(
                                      controller: ctrl,
                                      maxLines: 3,
                                      decoration: const InputDecoration(hintText: 'Reject လုပ်ရသည့် အကြောင်းပြချက်...'),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
                                    ],
                                  ),
                                );
                                if (ok != true || ctrl.text.trim().isEmpty) return;
                                try {
                                  await OrderService.adminRejectReturnForBuyer(orderId: o.id, reason: ctrl.text.trim());
                                  if (!context.mounted) return;
                                  _snack(context, 'Return Rejected (Seller can now claim fee) ⚠️');
                                } catch (e) {
                                  if (!context.mounted) return;
                                  _snack(context, e.toString());
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  )),
                ],

                // ── Seller Rejected Info ─────────────────────────────
                if (o.isSellerRejected || (o.isRefunded && o.rejectedBy == 'seller')) ...[
                  const SizedBox(height: 16),
                  _card(scheme, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.report_problem_rounded, color: scheme.error, size: 18),
                        const SizedBox(width: 8),
                        Text('Seller မှ Order ကို ပယ်ဖျက်လိုက်ပါသည်', 
                            style: textTheme.titleSmall?.copyWith(color: scheme.error, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 10),
                      Text('ရောင်းသူ၏ အကြောင်းပြချက်: ${o.rejectReason}', style: textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      Text('Admin Action:', style: textTheme.labelMedium),
                      const SizedBox(height: 8),
                      const Text('ဝယ်သူ့ထံ deposit ပြန်အမ်းရန် အောက်ပါ "Deposit ပြန်လွှဲမည်" ကတ်တွင် ပုံတင်ပေးပါ။',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  )),
                ],

                // ── Return Rejected / Claimed Info ────────────────────
                if (o.isReturnRejected || o.isReturnClaimed || (o.isRefunded && o.refundedTo == 'seller')) ...[
                  const SizedBox(height: 16),
                  _card(scheme, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.report_problem_rounded, color: scheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Return Request ကို ပယ်ချထားသည်', style: textTheme.titleSmall?.copyWith(color: scheme.error, fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 6),
                      Text('Reason: ${o.returnRejectReason}', style: textTheme.bodySmall),
                      if (o.undeliverableProofUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Delivery Failure Proof:', style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AppNetworkImage(o.undeliverableProofUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                              onTap: () => FullScreenImagePage.show(context, o.undeliverableProofUrl)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (o.isReturnClaimed || (o.isRefunded && o.refundedTo == 'seller')) ...[
                        Divider(height: 1, color: scheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text('Seller တောင်းဆိုထားသော Delivery ခ', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Amount: ${o.sellerReturnClaimAmount} MMK', style: textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (o.sellerReturnClaimProofUrl.isNotEmpty) ...[
                          Text('Shipping Voucher:', style: textTheme.labelSmall),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppNetworkImage(o.sellerReturnClaimProofUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                                onTap: () => FullScreenImagePage.show(context, o.sellerReturnClaimProofUrl)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text('Seller ၏ ပြန်လွှဲရမည့် အကောင့်', style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (o.sellerClaimBankName.isNotEmpty)
                                Text('Bank: ${o.sellerClaimBankName}', style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                              if (o.sellerClaimAccountName.isNotEmpty)
                                Text('Name: ${o.sellerClaimAccountName}', style: textTheme.bodySmall),
                              if (o.sellerClaimAccountNo.isNotEmpty)
                                Row(
                                  children: [
                                    Expanded(child: Text('A/C: ${o.sellerClaimAccountNo}', style: textTheme.bodySmall)),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: o.sellerClaimAccountNo));
                                        _snack(context, 'Copied');
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!o.isRefunded) ...[
                          Text('Admin Action:', style: textTheme.labelMedium),
                          const SizedBox(height: 8),
                          const Text('Seller ထံ delivery ခ လွှဲရန် အောက်ပါ "Deposit ပြန်လွှဲမည်" ကတ်တွင် ပုံတင်ပေးပါ။',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ] else ...[
                          Divider(height: 1, color: scheme.outlineVariant),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: scheme.tertiary),
                              const SizedBox(width: 6),
                              Text(
                                'Admin မှ Seller ထံ Delivery ခ လွှဲပြီးပါပြီ ✅',
                                style: textTheme.labelMedium?.copyWith(color: scheme.tertiary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppNetworkImage(o.depositReturnProofUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
                                onTap: () => FullScreenImagePage.show(context, o.depositReturnProofUrl)),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 8),
                        const Text('Seller ဘက်မှ delivery ခ claim လုပ်ရန် စောင့်ဆိုင်းနေပါသည်။',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                      ],
                    ],
                  )),
                ],

                // ── Deposit Return Button (Decluttered UI)
                if (o.isFeePending || o.isCompleted || o.isReturnPending || o.isCancelled || o.isReturnClaimed || o.isRefunded || o.isSellerRejected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Icon(o.depositReturned ? Icons.receipt_long_outlined : Icons.account_balance_wallet_outlined),
                      label: Text(o.depositReturned 
                          ? 'Deposit ပြန်လွှဲထားသော ပြေစာ ကြည့်မည်' 
                          : (o.isReturnClaimed ? 'Seller ဆီ Delivery ခ လွှဲမည်' : 'Deposit ပြန်လွှဲမည်')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: o.depositReturned ? scheme.tertiary : scheme.primary),
                        foregroundColor: o.depositReturned ? scheme.tertiary : scheme.primary,
                      ),
                      onPressed: () => _showDepositReturnSheet(context, o),
                    ),
                  ),
                ],

                // ── Fee Payment Proof (နောက်ဆုံး — seller fee ပေးပြီးမှ admin confirm)
                if ((o.isFeePending || o.isCompleted) && o.platformFee > 0) ...[
                  const SizedBox(height: 16),
                  _card(scheme, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 16, color: scheme.error),
                          const SizedBox(width: 6),
                          Text('Service Charge လွှဲကြောင်း',
                              style: textTheme.titleSmall?.copyWith(
                                  color: scheme.error)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Fee amount row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ကျသင့်ငွေ', style: textTheme.bodyMedium),
                          Text('${o.platformFee} MMK',
                              style: textTheme.titleMedium?.copyWith(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 10),

                      if (o.feeProofUrl.isEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.hourglass_empty_rounded,
                                size: 15, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('လွှဲကြောင်း မတင်ရသေး',
                                style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 15, color: scheme.tertiary),
                            const SizedBox(width: 6),
                            Text('လွှဲပြီးကြောင်း တင်ထားသည်',
                                style: textTheme.bodySmall?.copyWith(
                                    color: scheme.tertiary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (o.feePayerName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('လွှဲသူ: ${o.feePayerName}',
                              style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant)),
                        ],
                        if (o.feeTransferAmount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('လွှဲသည့်ပမာဏ',
                                  style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                              Text(
                                '${o.feeTransferAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} MMK',
                                style: textTheme.bodyMedium?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => FullScreenImagePage.show(
                              context, o.feeProofUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppNetworkImage(
                              o.feeProofUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.check_circle_rounded,
                                size: 18),
                            label: const Text('လက်ခံပြီး ✅ (Fee Received)'),
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.tertiary,
                              foregroundColor: scheme.onTertiary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: o.feeConfirmed ? null : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('အတည်ပြုရန်'),
                                  content: Text(
                                    'Seller ${o.sellerName} ၏ fee လက်ခံပြီး order ကို COMPLETED သတ်မှာ သေချာပါသလား?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('မလုပ်ပါ'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('အတည်ပြုမည်'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              try {
                                await OrderService.adminConfirmFeeReceived(
                                  orderId: o.id,
                                  sellerId: o.sellerId,
                                );
                                if (!context.mounted) return;
                                _snack(context, 'Fee လက်ခံပြီး — Order COMPLETED ✅');
                              } catch (e) {
                                if (!context.mounted) return;
                                _snack(context, e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  )),
                ],

                const SizedBox(height: 24),

                // ── Admin Actions ─────────────────────────────────────
                // ✅ o.isPending getter — no hardcoded strings
                if (o.isPending) ...[
                  _actionButton(
                    context,
                    label: 'Approve Deposit',
                    icon: Icons.check_circle_outline,
                    color: scheme.primary,
                    onColor: scheme.onPrimary,
                    onPressed: () async {
                      try {
                        final errPayload = _imeiOrgError.isNotEmpty
                            ? {
                                'status': 'REJECTED',
                                'error': _imeiOrgError,
                                'errorMessage': _imeiOrgError,
                              }
                            : null;

                        if (errPayload != null && o.productId.isNotEmpty) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('products')
                                .doc(o.productId)
                                .set({
                              'imeiCheckParsed': errPayload,
                              'imeiCheckedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                          } catch (e) {
                            debugPrint('[IMEI_DEBUG] Direct save error: $e');
                          }
                        }

                        await OrderService.adminApproveDeposit(
                          orderId: o.id,
                          imeiCheckParsed: errPayload,
                        );
                        if (!context.mounted) return;
                        _snack(context, 'Approved ✅');
                      } catch (e) {
                        if (!context.mounted) return;
                        _snack(context,
                            e.toString().replaceAll('Exception: ', ''));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _actionButton(
                    context,
                    label: 'Reject Deposit',
                    icon: Icons.cancel_outlined,
                    color: scheme.error,
                    onColor: scheme.onError,
                    onPressed: () => _showRejectDialog(context, o),
                  ),
                ],

                // ✅ Refund button removed — now consolidated into _DepositReturnCard above
              ],
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

  Widget _actionButton(BuildContext context, {
        required String label,
        required IconData icon,
        required Color color,
        required Color onColor,
        required VoidCallback onPressed,
      }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: onColor,
          minimumSize: const Size(double.infinity, 48),
        ),
        onPressed: onPressed,
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
// IMEI.org Result Table for Admin Order Detail
// ─────────────────────────────────────────────────────────────────────────────

class _ImeiOrgAdminResultTable extends StatelessWidget {
  final Map<String, dynamic> parsed;
  final String? apiError;

  const _ImeiOrgAdminResultTable({
    required this.parsed,
    this.apiError,
  });

  static const _labels = <String, String>{
    'modelName':      'Model',
    'modelNumber':    'Model Number',
    'fullName':       'Full Name',
    'storage':        'Storage',
    'ram':            'RAM',
    'color':          'Color',
    'manufacturer':   'Manufacturer',
    'serialNumber':   'Serial Number',
    'imei2':          'IMEI 2',
    'productionDate': 'Production Date',
    'purchaseDate':   'Date of Purchase',
    'warrantyUntil':  'Warranty Until',
    'warrantyStatus': 'Warranty Status',
    'carrier':        'Carrier',
    'country':        'Country',
    'activated':      'Activated',
    'activationDate': 'Activation Date',
    'simlock':        'Network Lock',
    'blacklist':      'Blacklist',
    'blacklistedBy':  'Blacklisted By',
    'fmi':            'iCloud Lock (FMI)',
    'icloud':         'iCloud Status',
    'knoxGuard':      'KnoxGuard',
  };

  static const _preferredOrder = <String>[
    'modelName',
    'fullName',
    'Model',
    'Full Name',
    'Model Desc',
    'condition',
    'Condition',
    'ram',
    'RAM',
    'storage',
    'Capacity',
    'Storage',
    'color',
    'Color',
    'modelNumber',
    'Model Number',
    'Model No',
    'serialNumber',
    'Serial Number',
    'Serial',
    'imei2',
    'IMEI 2',
    'IMEI2',
    'fmi',
    'FMI',
    'icloud',
    'iCloud',
    'miLock',
    'miActivationLock',
    'Mi Activation Lock',
    'simlock',
    'Simlock',
    'blacklist',
    'Blacklist Status',
    'knoxGuard',
    'KnoxGuard',
    'warrantyStatus',
    'Warranty Status',
    'activated',
    'Activated',
    'activationDate',
    'Activation Date',
    'warrantyStart',
    'Warranty Start Date',
    'purchaseDate',
    'Date of Purchase',
    'warrantyUntil',
    'Warranty Until',
    'productionDate',
    'Production Date',
    'deliveryDate',
    'Delivery Date',
    'manufacturer',
    'Manufacturer',
    'carrier',
    'Carrier',
    'country',
    'Country',
    'unlockCode',
    'Unlock Code',
    'warrantyDescription',
    'Warranty Description',
  ];

  static int _orderIndex(String key) {
    final idx = _preferredOrder.indexWhere((k) => k.toLowerCase() == key.toLowerCase());
    return idx != -1 ? idx : 999;
  }

  Color _statusColor(BuildContext ctx, String key, String val) {
    final scheme = Theme.of(ctx).colorScheme;
    final up = val.toUpperCase().trim();
    
    // အရေးကြီးတဲ့ Status field တွေကိုပဲ အရောင်ခြယ်ပါမယ် (နာမည်တွေကို အရောင်မခြယ်တော့ပါ)
    switch (key.toLowerCase()) {
      case 'fmi':
      case 'icloud':
      case 'milock':
      case 'miactivationlock':
      case 'mi activation lock':
      case 'simlock':
      case 'carrier':
      case 'blacklist':
      case 'knoxguard':
      case 'warrantystatus':
        // Good statuses (Green)
        if (['OFF', 'UNLOCKED', 'CLEAN', 'OK', 'NOT BLACKLISTED', 'IN WARRANTY', 'UNLOCK'].contains(up)) return Colors.green;
        if (up.contains('CLEAN') || up.contains('UNLOCKED') || up == 'OFF') return Colors.green;

        // Bad statuses (Red)
        if (['ON', 'LOCKED', 'LOST', 'ERASED', 'EXPIRED', 'BLACKLISTED', 'OUT OF WARRANTY'].contains(up)) return scheme.error;
        if (up.contains('LOCKED') || up.contains('BLACKLISTED') || up.contains('LOST') || up == 'ON') return scheme.error;
        break;
    }
    
    return scheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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

    final errStr = (apiError ?? '').trim();
    final statusVal = (parsed['status'] ?? parsed['Status'] ?? parsed['result'] ?? parsed['error'] ?? '').toString().toUpperCase();
    final isRejectedOrFailed = !hasSpecs && (errStr.isNotEmpty ||
        statusVal.contains('REJECT') ||
        statusVal.contains('FAIL') ||
        statusVal.contains('ERROR') ||
        statusVal.contains('CANCEL') ||
        parsed.containsKey('error') ||
        parsed.containsKey('errorMessage'));

    if (isRejectedOrFailed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.error.withOpacity(0.5)),
        ),
        child: Text(
          'API စစ်ဆေးမှု မအောင်မြင်ပါ / Rejected ဖြစ်သွားပါသည်',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.error,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Use defined labels for specific keys, others show raw key
    final rows = parsed.entries
        .where((e) => e.value != null && 
                     e.value.toString().trim().isNotEmpty &&
                     e.key != 'error' &&
                     e.key != 'errorMessage' &&
                     !['id', 'status', 'Status', 'service_id', 'input', 'order_id', 'orderId'].contains(e.key))
        .toList();

    rows.sort((a, b) => _orderIndex(a.key).compareTo(_orderIndex(b.key)));

    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          'IMEI.org စစ်ဆေးပြီးပါပြီ (အသေးစိတ် fields များ မရှိပါ)',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
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
          var val = entry.value.toString().trim();
          if (entry.key.toLowerCase().contains('date') && val.contains(' ')) {
            val = val.split(' ')[0];
          }
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

// ─────────────────────────────────────────────────────────────────────────────
// IMEI Verification Summary Card (Auto-detect Mismatch / Warnings)
// ─────────────────────────────────────────────────────────────────────────────

class _ImeiOrgVerificationSummaryCard extends StatelessWidget {
  final Product product;
  final Map<String, dynamic> parsed;
  final String? apiError;

  const _ImeiOrgVerificationSummaryCard({
    required this.product,
    required this.parsed,
    this.apiError,
  });

  @override
  Widget build(BuildContext context) {
    // ── 0. Check if device specs exist ──────────────────────────────────────
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

    final errStr = (apiError ?? '').trim();
    final statusVal = (parsed['status'] ?? parsed['Status'] ?? parsed['result'] ?? parsed['error'] ?? '').toString().toUpperCase();

    // Only show Error/Rejection/Timeout card if we do NOT have device specs
    if (!hasSpecs) {
      final isTimeout = statusVal.contains('TIMEOUT') || errStr.contains('Timeout') || errStr.contains('unavailable');
      final isRejectedOrFailed = errStr.isNotEmpty ||
          statusVal.contains('REJECT') ||
          statusVal.contains('FAIL') ||
          statusVal.contains('ERROR') ||
          statusVal.contains('CANCEL') ||
          parsed.containsKey('error') ||
          parsed.containsKey('errorMessage');

      if (isTimeout) {
        final displayError = errStr.isNotEmpty ? errStr : (parsed['error'] ?? parsed['errorMessage'] ?? 'API စစ်ဆေးမှု ကြာမြင့်နေပါသည် (Timeout)။').toString();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'API စစ်ဆေးမှု ကြာမြင့်နေပါသည် (Timeout / Pending)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• imei.org တွင် စစ်ဆေးမှု လုပ်ဆောင်နေဆဲ ဖြစ်နိုင်ပါသည်။ ခဏကြာလျှင် "Run API Check" ကို ပြန်လည်နှိပ်ပြီး စစ်ဆေးပေးပါ၊ သို့မဟုတ် imei.org တွင် တိုက်ရိုက် ကြည့်ရှုပါ။',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.3),
              ),
              if (displayError.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'အသေးစိတ်: $displayError',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      }

      if (isRejectedOrFailed) {
        final displayError = errStr.isNotEmpty
            ? errStr
            : (parsed['error'] ?? parsed['errorMessage'] ?? parsed['message'] ?? parsed['status'] ?? parsed['Status'] ?? 'API Check Rejected or Failed').toString();

        return Container(
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
                  Icon(Icons.cancel_rounded, color: Colors.red.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'API စစ်ဆေးမှု ငြင်းပယ်ခံရသည် / မအောင်မြင်ပါ (API Error / Rejected)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• imei.org API မှ စစ်ဆေးမှုကို Reject ပြုလုပ်လိုက်ပါသည် (Server ခေတ္တ အဆင်မပြေခြင်း သို့မဟုတ် IMEI မှားယွင်းနေခြင်း ဖြစ်နိုင်ပါသည်)။',
                style: TextStyle(fontSize: 12, color: Colors.red.shade800, height: 1.3),
              ),
              if (displayError.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'အသေးစိတ် Error: $displayError',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      }

      if (parsed.isEmpty) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'API စစ်ဆေးပြီး - အသေးစိတ် specs များ မရှိပါ (IMEI ကို မူရင်းဘူး/ဖုန်းနှင့် တိုက်ဆိုင် စစ်ဆေးပေးပါ)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── 2. Condition Check (Brand New vs Activation Date) ──────────────────
    final isBrandNewClaimed = product.condition.toLowerCase().contains('brand new') ||
        product.condition.toLowerCase().contains('sealed');

    final activationDate = parsed['activationDate'] ??
        parsed['activated'] ??
        parsed['warrantyStart'] ??
        parsed['warrantyStartDate'] ??
        parsed['purchaseDate'] ??
        parsed['Activation Date'];

    String cleanActivationDate = '';
    if (activationDate != null) {
      final s = activationDate.toString().trim();
      cleanActivationDate = s.split('T')[0].split(' ')[0].trim();
    }

    final hasActivationMismatch = isBrandNewClaimed &&
        activationDate != null &&
        activationDate.toString().trim().isNotEmpty;

    // ── 3. Lock & Blacklist Check ─────────────────────────────────────────
    final fmi = (parsed['fmi'] ??
            parsed['icloud'] ??
            parsed['miLock'] ??
            parsed['miActivationLock'] ??
            parsed['Mi Activation Lock'] ??
            parsed['knoxGuard'] ??
            '')
        .toString()
        .toUpperCase();

    final blacklist = (parsed['blacklist'] ?? parsed['simlock'] ?? '')
        .toString()
        .toUpperCase();

    final isLocked = fmi == 'ON' ||
        fmi.contains('LOCKED') ||
        blacklist.contains('BLACKLISTED') ||
        blacklist.contains('LOCKED');

    final hasWarnings = hasActivationMismatch || isLocked;

    final bgBorderColor = hasWarnings ? Colors.orange : Colors.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgBorderColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bgBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasWarnings ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                color: bgBorderColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasWarnings
                      ? 'စစ်ဆေးတွေ့ရှိချက်များ (Verification Warnings)'
                      : 'API တိုက်ဆိုင်စစ်ဆေးမှု အဆင်ပြေပါသည် (Genuine Device)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: hasWarnings ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (hasActivationMismatch) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.4),
                children: [
                  const TextSpan(text: '⚠️ Condition Mismatch: Seller မှ Original Brand New (Sealed) ဟု တင်ထားသော်လည်း API စစ်ဆေးချက်အရ '),
                  TextSpan(
                    text: cleanActivationDate.isNotEmpty ? cleanActivationDate : activationDate.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0),
                  ),
                  const TextSpan(text: ' တွင် Activation ပြုလုပ်ပြီးသား ဖြစ်နေပါသည်။'),
                ],
              ),
            ),
          ],
          if (isLocked) ...[
            const SizedBox(height: 6),
            Text(
              '⛔ Lock Alert: ဖုန်းတွင် Activation Lock (ON) သို့မဟုတ် Network Lock/Blacklist အခြေအနေ တွေ့ရှိရပါသည်။',
              style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ],
          if (!hasWarnings) ...[
            const SizedBox(height: 4),
            Text(
              '• IMEI မူရင်း Database တွင် အချက်အလက်များ မှန်ကန်စွာ တည်ရှိပြီး Lock မရှိပါ။',
              style: TextStyle(fontSize: 12, color: Colors.green.shade900),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── User Profile Tile — profile pic + name + verified badge + tap ────────────

class _UserProfileTile extends StatelessWidget {
  final String userId;
  final String name;
  final String? subtitle;
  final VoidCallback? onTap;

  const _UserProfileTile({
    required this.userId,
    required this.name,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userId.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots()
          : null,
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final profileImage = (data['profileImage'] ?? '').toString();
        final isVerified = data['isVerified'] == true;
        final totalSales = ((data['totalSales'] ?? 0) as num).toInt();
        final phone = (data['phone'] ?? '').toString();
        final shopCity = (data['shopCity'] ?? '').toString();
        final contactLine = [phone, shopCity]
            .where((s) => s.isNotEmpty)
            .join('  •  ');

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              // ── Avatar ─────────────────────────────────────────────
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: profileImage.isNotEmpty
                    ? NetworkImage(profileImage)
                    : null,
                child: profileImage.isEmpty
                    ? Icon(Icons.person,
                        size: 20, color: scheme.onPrimaryContainer)
                    : null,
              ),

              const SizedBox(width: 12),

              // ── Name + subtitle ────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified,
                              color: scheme.primary, size: 15),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else ...[
                      if (contactLine.isNotEmpty)
                        Text(
                          contactLine,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      if (totalSales > 0)
                        Text(
                          '$totalSales sales completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              // ── Chevron (tappable hint) ────────────────────────────
              if (onTap != null)
                Icon(Icons.chevron_right,
                    size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }
}

// ─── Deposit Return Card ──────────────────────────────────────────────────────

class _DepositReturnCard extends StatefulWidget {
  final OrderModel order;
  const _DepositReturnCard({required this.order});

  @override
  State<_DepositReturnCard> createState() => _DepositReturnCardState();
}

class _DepositReturnCardState extends State<_DepositReturnCard> {
  File? _proofFile;
  bool _uploading = false;

  Future<void> _pickProof() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _proofFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ငွေလွှဲပုံ ရွေးပေးပါ')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('အတည်ပြုရန်'),
        content: Text(
          'Buyer ${widget.order.buyerName} ကို deposit ${widget.order.depositAmount} MMK ပြန်လွှဲပြီးကြောင်း အတည်ပြုမှာသေချာပါသလား?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('မလုပ်ပါ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('အတည်ပြုမည်')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _uploading = true);
    try {
      final ts  = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('deposit_return_proofs/${widget.order.id}_$ts.jpg');
      await ref.putFile(_proofFile!, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      final status = widget.order.status;
      final isRefund = [
        OrderStatus.depositPending,
        OrderStatus.depositApproved,
        OrderStatus.cancelled,
        OrderStatus.returnPending,
        OrderStatus.returnClaimed, // ✅ Also a refund (to seller)
        OrderStatus.sellerRejected, // ✅ Also a refund (to buyer)
      ].contains(status);

      if (isRefund) {
        // ✅ For refunds, issue a full refund
        // refundedTo: 'seller' if it's a return claim
        await OrderService.adminRefundDeposit(
          orderId: widget.order.id,
          depositReturnProofUrl: url,
          refundedTo: status == OrderStatus.returnClaimed ? 'seller' : 'buyer',
        );
      } else {
        // ✅ For normal successful orders, just mark as returned
        await OrderService.adminMarkDepositReturned(
          orderId: widget.order.id,
          depositReturnProofUrl: url,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isRefund 
            ? 'Refunded ↩️' 
            : 'Deposit ပြန်လွှဲပြီး မှတ်တမ်းတင်ပြီးပါပြီ ✅')));
      
      // ✅ Auto-close bottom sheet on success
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // ✅ Switch to Seller view if it was a return claim (even if now REFUNDED)
    final isSellerView = o.isReturnClaimed || o.refundedTo == 'seller';

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                o.depositReturned
                    ? Icons.check_circle_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 20,
                color: o.depositReturned ? scheme.tertiary : scheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isSellerView ? 'Seller ဆီ Delivery ခ လွှဲမည်' : 'Deposit ပြန်လွှဲမည်',
                style: textTheme.titleMedium?.copyWith(
                  color: o.depositReturned ? scheme.tertiary : scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Deposit amount ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isSellerView ? 'လွှဲပေးရမည့် Delivery ခ' : 'ပြန်လွှဲရမည့် Deposit', style: textTheme.bodyLarge),
                Text(
                  isSellerView ? '${o.sellerReturnClaimAmount} MMK' : '${o.depositAmount} MMK',
                  style: textTheme.titleLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 20),

          // ── Account Info ─────────────────────────────────────
          Text(
            isSellerView ? 'Seller ၏ ပြန်လွှဲရမည့် အကောင့်' : 'Buyer ၏ ပြန်လွှဲရမည့် အကောင့်',
            style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSellerView) ...[
                   if (o.sellerClaimBankName.isNotEmpty)
                    Row(children: [
                      Icon(Icons.account_balance_outlined, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(o.sellerClaimBankName, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  const SizedBox(height: 6),
                  Text('နာမည်: ${o.sellerClaimAccountName}', style: textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  CopyTextRow(label: 'အကောင့်', value: o.sellerClaimAccountNo),
                ] else ...[
                  if (o.refundBankName.isNotEmpty)
                    Row(children: [
                      Icon(Icons.account_balance_outlined, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(o.refundBankName, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  const SizedBox(height: 6),
                  Text('နာမည်: ${o.refundAccountName}', style: textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  CopyTextRow(label: 'အကောင့်', value: o.refundAccountNo),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 20),

          // ── Already returned ─────────────────────────────────────────
          if (o.depositReturned) ...[
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: scheme.tertiary),
                const SizedBox(width: 8),
                Text(
                  'လွှဲပြီးကြောင်း မှတ်တမ်းတင်ပြီးပါပြီ ✅',
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (o.depositReturnProofUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppNetworkImage(
                  o.depositReturnProofUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  onTap: () => FullScreenImagePage.show(context, o.depositReturnProofUrl),
                ),
              ),
            ],
          ] else ...[
            // ── Upload proof form ────────────────────────────────────
            Text(
              'ငွေလွှဲပြေစာ ပုံ upload လုပ်ပါ',
              style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _uploading ? null : _pickProof,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _proofFile != null ? scheme.primary : scheme.outlineVariant,
                    width: _proofFile != null ? 2 : 1,
                  ),
                ),
                child: _proofFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_proofFile!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                          const SizedBox(height: 8),
                          Text('ငွေလွှဲပုံ ရွေးရန်', style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _uploading ? null : _submit,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(_uploading ? 'တင်နေသည်...' : 'ငွေလွှဲပြီးကြောင်း အတည်ပြုမည်'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}