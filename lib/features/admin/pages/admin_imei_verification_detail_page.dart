import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/imei_service.dart';
import 'package:go_router/go_router.dart';
import 'package:sigmamoby/core/router/app_routes.dart';
import 'package:sigmamoby/core/services/notification_helper.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

/// Opened when admin taps a pending IMEI item from the list page.
/// Streams the imei_registry doc so data is always fresh.
class AdminImeiVerificationDetailPage extends StatelessWidget {
  final String imeiDocId; // full IMEI = doc ID
  const AdminImeiVerificationDetailPage({super.key, required this.imeiDocId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('imei_registry')
          .doc(imeiDocId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.data!.exists) {
          return Scaffold(
            appBar: BrandAppBar(title: 'IMEI Verification'),
            body: const Center(child: Text('Record မတွေ့ပါ')),
          );
        }
        final doc = snap.data!;
        return _DetailBody(doc: doc);
      },
    );
  }
}

// ─── Main body (stateful — holds dropdown/form state) ─────────────────────────

class _DetailBody extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  const _DetailBody({required this.doc});

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  // C.E.I.R.
  String _ceirImeiStatus     = '';
  String _ceirTaxStatus      = '';
  String _ceirBlockingStatus = '';

  // Device/Specs
  String? _specsResult;
  final TextEditingController _mismatchNoteCtrl = TextEditingController();

  // imei.org API
  Map<String, dynamic> _imeiOrgParsed = {};
  // true when _imeiOrgParsed was loaded from imeiCheckParsed or live API
  // false when loaded only from legacy imeiCheck* fields (can still be upgraded)
  bool _imeiOrgFromParsed = false;
  bool _imeiOrgLoading = false;
  String _imeiOrgError = '';

  Future<void> _runImeiOrgCheck() async {
    if (productId.isEmpty || imei.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product ID သို့မဟုတ် IMEI မရှိပါ')),
      );
      return;
    }

    if (_imeiOrgLoading) return;

    setState(() {
      _imeiOrgLoading = true;
      _imeiOrgError = '';
    });

    final deviceType = (brand.toLowerCase() == 'apple') ? 'iphone' : brand.toLowerCase();

    try {
      await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable(
            'runImeiCheck',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 4)),
          )
          .call({
        'imei':       imei,
        'productId':  productId,
        'brand':      brand,
        'deviceType': deviceType,
      });
      if (!mounted) return;
      setState(() => _imeiOrgError = '');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IMEI စစ်ဆေးပြီးပါပြီ ✅')),
      );
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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _productSub;

  // Saving flags
  bool _ceirSaving   = false;
  bool _specsSaving  = false;
  bool _rejectSaving = false;

  Map<String, dynamic> get d => widget.doc.data() ?? {};
  String get imei      => (d['imeiFull']    ?? '').toString();
  String get brand     => (d['brand']       ?? '').toString();
  String get model     => (d['model']       ?? '').toString();
  String get productId => (d['productId']   ?? '').toString();

  String get displayTitle {
    final b = brand.trim().toLowerCase();
    final m = model.trim();
    return m.toLowerCase().startsWith(b) ? m : '$brand $m';
  }

  bool get _ceirFilled =>
      _ceirImeiStatus.isNotEmpty &&
      _ceirTaxStatus.isNotEmpty &&
      _ceirBlockingStatus.isNotEmpty;
  bool get _specsFilled => _specsResult != null;

  // China Refurbished မှာ Device Verification မလိုဘူး — CEIR ပဲ စစ်မယ်
  bool get _isRefurbished =>
      (d['condition'] ?? '').toString().toLowerCase().contains('refurb');

  @override
  void initState() {
    super.initState();
    _loadFromDoc(d);
    _subscribeProductParsed();
  }

  void _subscribeProductParsed() {
    final pid = productId;
    if (pid.isEmpty) return;
    _productSub = FirebaseFirestore.instance
        .collection('products')
        .doc(pid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (!mounted || _imeiOrgFromParsed) return;
      final parsed = data?['imeiCheckParsed'];
      if (parsed is Map) {
        setState(() {
          _imeiOrgParsed     = Map<String, dynamic>.from(parsed);
          _imeiOrgFromParsed = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(_DetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Upgrade from legacy fields to full imeiCheckParsed if not already done
    final newParsed = widget.doc.data()?['imeiCheckParsed'];
    if (newParsed is Map && !_imeiOrgFromParsed) {
      setState(() {
        _imeiOrgParsed      = Map<String, dynamic>.from(newParsed);
        _imeiOrgFromParsed  = true;
      });
    }
  }

  void _loadFromDoc(Map<String, dynamic> d) {
    _ceirImeiStatus     = (d['ceirImeiStatus']     ?? '').toString();
    _ceirTaxStatus      = (d['ceirTaxStatus']      ?? '').toString();
    _ceirBlockingStatus = (d['ceirBlockingStatus'] ?? '').toString();
    final saved = (d['specsVerified'] ?? '').toString();
    _specsResult = saved.isEmpty ? null : saved;
    _mismatchNoteCtrl.text = (d['specsMismatchNote'] ?? '').toString();

    // Pre-load saved imei.org result — avoids re-calling API (wastes credits)
    if (_imeiOrgParsed.isEmpty) {
      final savedParsed = d['imeiCheckParsed'];
      if (savedParsed is Map) {
        _imeiOrgParsed      = Map<String, dynamic>.from(savedParsed);
        _imeiOrgFromParsed  = true;
      }
    }

    if (_imeiOrgParsed.isEmpty) {
      // 2️⃣ Reconstruct from imeiCheckRaw — full data, preferred over legacy fields
      final savedRaw = d['imeiCheckRaw'];
      if (savedRaw is Map) {
        final raw = Map<String, dynamic>.from(savedRaw);
        String r(String k) => (raw[k] ?? '').toString().trim();
        final fromRaw = <String, dynamic>{};
        void addRaw(String parsedKey, List<String> rawKeys) {
          for (final k in rawKeys) {
            final v = r(k);
            if (v.isNotEmpty) { fromRaw[parsedKey] = v; break; }
          }
        }
        addRaw('serialNumber',   ['Serial Number', 'Serial']);
        addRaw('imei2',          ['IMEI2', 'IMEI 2']);
        addRaw('manufacturer',   ['Manufacturer', 'Brand']);
        addRaw('fullName',       ['Full Name', 'Device Name']);
        addRaw('modelNumber',    ['Model Number', 'Model No']);
        addRaw('modelName',      ['Model Desc', 'Model']);
        addRaw('productionDate', ['Production Date']);
        addRaw('purchaseDate',   ['Date of Purchase', 'Purchase Date']);
        addRaw('warrantyUntil',  ['Warranty Until', 'Warranty Date']);
        addRaw('warrantyStatus', ['Warranty Status']);
        addRaw('carrier',        ['Carrier']);
        addRaw('country',        ['Country', 'Purchase Country']);
        addRaw('blacklist',      ['Blacklist Status']);
        addRaw('fmi',            ['FMI']);
        addRaw('icloud',         ['iCloud']);
        addRaw('knoxGuard',      ['KnoxGuard']);
        addRaw('simlock',        ['Simlock']);

        // Apple-specific: parse model field to extract Storage & Color separately
        final dt = (d['deviceType'] ?? '').toString().toLowerCase();
        if ((dt == 'iphone' || dt == 'ipad') && fromRaw.containsKey('modelName')) {
          final mf = fromRaw['modelName'].toString();
          // Storage: "256GB", "1TB" etc.
          final storageMatcher = RegExp(r'\b(\d+(?:GB|TB))\b', caseSensitive: false);
          final sm = storageMatcher.firstMatch(mf);
          if (sm != null) fromRaw['storage'] = sm.group(1)!.toUpperCase();
          // Color
          const appleColors = [
            'ROSE GOLD', 'SPACE GRAY', 'NATURAL TITANIUM', 'BLACK TITANIUM',
            'WHITE TITANIUM', 'DESERT TITANIUM',
            'BLACK', 'WHITE', 'SILVER', 'GOLD', 'MIDNIGHT', 'STARLIGHT',
            'BLUE', 'GREEN', 'RED', 'PURPLE', 'YELLOW', 'PINK', 'ORANGE',
          ];
          for (final c in appleColors) {
            if (mf.toUpperCase().contains(c)) {
              fromRaw['color'] = c[0].toUpperCase() + c.substring(1).toLowerCase();
              break;
            }
          }
          // Extract model number from brackets e.g. [A2412]
          if (!fromRaw.containsKey('modelNumber')) {
            final bracketMatch = RegExp(r'\[([A-Z]\d{4}[A-Z]?)\]').firstMatch(mf);
            if (bracketMatch != null) fromRaw['modelNumber'] = bracketMatch.group(1)!;
          }
          // Clean model name
          var clean = mf;
          if (sm != null) {
            final idx = clean.toUpperCase().indexOf(sm.group(1)!.toUpperCase());
            if (idx > 0) clean = clean.substring(0, idx);
          }
          clean = clean.replaceAll(RegExp(r'\[.*?\]'), '').trim();
          clean = clean
              .replaceFirst(RegExp(r'^IPHONE\s*', caseSensitive: false), 'iPhone ')
              .replaceFirst(RegExp(r'^IPAD\s*', caseSensitive: false), 'iPad ')
              .trim();
          if (clean.isNotEmpty) fromRaw['modelName'] = clean;
        }

        if (fromRaw.isNotEmpty) {
          _imeiOrgParsed     = fromRaw;
          _imeiOrgFromParsed = true;
        }
      }
    }
  }

  @override
  void dispose() {
    _productSub?.cancel();
    _mismatchNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyImei() async {
    await Clipboard.setData(ClipboardData(text: imei));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IMEI ကူးပြီးပါပြီ'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _openCeir() async {
    final url = Uri.parse('https://ceir.gov.mm/check-imei');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _saveCeir() async {
    if (!_ceirFilled || _ceirSaving) return;
    setState(() => _ceirSaving = true);
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = FieldValue.serverTimestamp();
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(widget.doc.reference, {
        'ceirImeiStatus':     _ceirImeiStatus,
        'ceirTaxStatus':      _ceirTaxStatus,
        'ceirBlockingStatus': _ceirBlockingStatus,
        'ceirCheckedAt':      now,
        'ceirCheckedBy':      adminUid,
        'updatedAt':          now,
      });
      if (productId.isNotEmpty) {
        batch.update(
          FirebaseFirestore.instance.collection('products').doc(productId),
          {
            'ceirImeiStatus':     _ceirImeiStatus,
            'ceirTaxStatus':      _ceirTaxStatus,
            'ceirBlockingStatus': _ceirBlockingStatus,
            'ceirCheckedAt':      now,
            'ceirCheckedBy':      adminUid,
          },
        );
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('C.E.I.R. result သိမ်းပြီးပါပြီ ✅')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _ceirSaving = false);
    }
  }

  Future<void> _saveSpecs() async {
    if (!_specsFilled || _specsSaving) return;
    setState(() => _specsSaving = true);
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now      = FieldValue.serverTimestamp();
    final note     = _mismatchNoteCtrl.text.trim();
    try {
      final batch = FirebaseFirestore.instance.batch();
      final specsData = {
        'specsVerified':   _specsResult,
        'specsVerifiedAt': now,
        'specsVerifiedBy': adminUid,
        if (note.isNotEmpty) 'specsMismatchNote': note,
      };
      batch.update(widget.doc.reference, { ...specsData, 'updatedAt': now });
      if (productId.isNotEmpty) {
        batch.update(
          FirebaseFirestore.instance.collection('products').doc(productId),
          specsData,
        );
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device Verification result သိမ်းပြီးပါပြီ ✅')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _specsSaving = false);
    }
  }

  Future<void> _markImeiNotiRead() async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      if (adminUid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: adminUid)
          .get();
      final imeiPrefix = imei.length >= 8 ? imei.substring(0, 8) : imei;
      final toMark = snap.docs.where((doc) {
        final data = doc.data();
        final body = (data['body'] ?? '').toString();
        return data['type'] == 'new_imei_submission' &&
               data['isRead'] != true &&
               body.contains(imeiPrefix);
      }).toList();
      if (toMark.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in toMark) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markImeiNotiRead error: $e');
    }
  }

  Future<void> _markValid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('IMEI Valid အတည်ပြုမည်'),
        content: Text('$displayTitle\nIMEI: $imei\n\nVALID အဖြစ် mark လုပ်မည်။ သေချာပါသလား?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('မလုပ်တော့'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Valid'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await ImeiService.markValid(imei: imei, adminUid: adminUid);
      await _markImeiNotiRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IMEI VALID အတည်ပြုပြီးပါပြီ ✅')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _banSeller() async {
    final sellerId   = (d['sellerId']   ?? '').toString();
    final sellerName = (d['sellerName'] ?? 'Seller').toString();
    if (sellerId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seller Ban လုပ်မည်'),
        content: Text('$sellerName Ban လုပ်မည်။ သေချာပါသလား?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('မလုပ်တော့')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ban လုပ်မည်')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now      = FieldValue.serverTimestamp();
      final db       = FirebaseFirestore.instance;

      await db.collection('users').doc(sellerId).update({
        'isBanned':   true,
        'bannedAt':   now,
        'bannedBy':   adminUid,
      });

      final products = await db
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .where('active', isEqualTo: true)
          .get();
      final batch = db.batch();
      for (final doc in products.docs) {
        batch.update(doc.reference, {'active': false, 'updatedAt': now});
      }
      await batch.commit();

      await createNotification(
        userId:     sellerId,
        type:       'account_banned',
        title:      '🚫 အကောင့် ပိတ်သိမ်းခံရသည်',
        body:       'သင်၏ အကောင့်ကို ပိတ်သိမ်းလိုက်သည်။',
        targetRole: 'seller',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$sellerName Ban လုပ်ပြီးပါပြီ 🚫')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectProduct() async {
    if (_rejectSaving || productId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Product Reject လုပ်မည်'),
        content: const Text('ဤ product ကို remove လုပ်မည်။ သေချာပါသလား?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('မလုပ်တော့')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rejectSaving = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now      = FieldValue.serverTimestamp();
      final batch    = FirebaseFirestore.instance.batch();
      final sellerId = (d['sellerId'] ?? '').toString();

      if (productId.isNotEmpty) {
        final productSnap = await FirebaseFirestore.instance.collection('products').doc(productId).get();
        if (productSnap.exists) {
          batch.update(productSnap.reference, {
            'active':     false,
            'imeiStatus': 'REJECTED',
            'rejectedAt': now,
            'rejectedBy': adminUid,
            'updatedAt':  now,
          });
        }
      }

      batch.delete(widget.doc.reference);
      await batch.commit();
      await _markImeiNotiRead();

      if (sellerId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(sellerId).update({
          'rejectCount': FieldValue.increment(1),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product Reject လုပ်ပြီးပါပြီ ⚠️')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _rejectSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(title: 'IMEI Verification'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayTitle, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(imei, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontFamily: 'monospace', letterSpacing: 1.2)),
                  ),
                  IconButton(icon: const Icon(Icons.copy_rounded, size: 18), tooltip: 'Copy IMEI', onPressed: _copyImei, visualDensity: VisualDensity.compact),
                ],
              ),
            ),
            if (productId.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                    child: Text('Listing: #${productId.substring(0, productId.length.clamp(0, 8)).toUpperCase()}',
                        style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (productId.isNotEmpty) _SellerCard(productId: productId),
            const Divider(),
            const SizedBox(height: 12),
            if (productId.isNotEmpty)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('products').doc(productId).snapshots(),
                builder: (context, pSnap) {
                  final p = pSnap.data?.data() ?? {};
                  final imeiPhotoUrl = (p['imeiPhoto'] ?? '').toString();
                  final serialNumber = (p['serialNumber'] ?? '').toString();
                  final serialPhotoUrl = (p['serialPhotoUrl'] ?? '').toString();
                  final isApple = brand.toLowerCase() == 'apple';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IMEI Photo', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (imeiPhotoUrl.isNotEmpty)
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: AppNetworkImage(imeiPhotoUrl, height: 220, width: double.infinity, fit: BoxFit.contain))
                      else
                        Container(height: 60, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)), child: Text('IMEI Photo မရှိပါ', style: TextStyle(color: scheme.onSurfaceVariant))),
                      const SizedBox(height: 16),
                      Text('Seller-Listed Specs', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            _specRow('Model', (p['name'] ?? '').toString().isNotEmpty ? p['name'].toString() : '—', scheme, textTheme, isFirst: true),
                            _specRow('Condition', (p['condition'] ?? '').toString().isNotEmpty ? p['condition'].toString() : '—', scheme, textTheme),
                            _specRow('RAM', p['ram'] != null ? '${p['ram']} GB' : '—', scheme, textTheme),
                            _specRow('Storage', p['storage'] != null ? '${p['storage']} GB' : '—', scheme, textTheme),
                            _specRow('Color', (p['color'] ?? '').toString().isNotEmpty ? p['color'].toString() : '—', scheme, textTheme),
                            _specRow('Model No.', (p['modelNumber'] ?? '—').toString(), scheme, textTheme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Serial Number (S/N)', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          if (isApple && serialNumber.isNotEmpty)
                            TextButton.icon(icon: const Icon(Icons.open_in_new, size: 14), label: const Text('Apple Check'), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact), onPressed: () async {
                              final url = Uri.parse('https://checkcoverage.apple.com/?sn=$serialNumber');
                              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                            }),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (serialNumber.isNotEmpty)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(8), border: Border.all(color: scheme.outlineVariant)), child: Row(children: [Expanded(child: SelectableText(serialNumber, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFamily: 'monospace'))), GestureDetector(onTap: () async { await Clipboard.setData(ClipboardData(text: serialNumber)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('S/N ကူးပြီးပါပြီ'), duration: Duration(seconds: 1))); }, child: Icon(Icons.copy_rounded, size: 16, color: scheme.onSurfaceVariant))]))
                      else
                        Text('S/N မထည့်ပါ (optional)', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      if (serialPhotoUrl.isNotEmpty) ...[const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(8), child: AppNetworkImage(serialPhotoUrl, height: 140, width: double.infinity, fit: BoxFit.contain))],
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            // ── imei.org API Check Section ─────────────────────────────
            Row(
              children: [
                Text('imei.org Verification', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: _imeiOrgLoading ? null : _runImeiOrgCheck,
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
            if (_imeiOrgParsed.isNotEmpty || _imeiOrgError.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ImeiOrgAdminResultTable(
                parsed: _imeiOrgParsed,
                apiError: _imeiOrgError,
              ),
              const SizedBox(height: 10),
              _ImeiOrgVerificationSummaryCard(
                condition: (d['condition'] ?? '').toString(),
                productName: (d['productName'] ?? d['name'] ?? '').toString(),
                productStorage: int.tryParse((d['storage'] ?? '').toString()),
                parsed: _imeiOrgParsed,
                apiError: _imeiOrgError,
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            Row(children: [Text('C.E.I.R. Verification', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)), const Spacer(), TextButton.icon(icon: const Icon(Icons.open_in_new, size: 16), label: const Text('ceir.gov.mm'), onPressed: _openCeir)]),
            const SizedBox(height: 4),
            Text('IMEI ကို copy ယူပြီး C.E.I.R. website မှာ စစ်ကြည့်ပြီး result ထည့်ပါ', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: _ceirImeiStatus.isEmpty ? null : _ceirImeiStatus, decoration: const InputDecoration(labelText: 'IMEI Status', border: OutlineInputBorder(), isDense: true), hint: const Text('ရွေးပါ'), items: const [DropdownMenuItem(value: 'correct', child: Text('✅ Correct')), DropdownMenuItem(value: 'incorrect', child: Text('❌ Incorrect'))], onChanged: (v) => setState(() => _ceirImeiStatus = v ?? '')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: _ceirTaxStatus.isEmpty ? null : _ceirTaxStatus, decoration: const InputDecoration(labelText: 'Tax Payment Status', border: OutlineInputBorder(), isDense: true), hint: const Text('ရွေးပါ'), items: const [DropdownMenuItem(value: 'paid', child: Text('✅ Paid')), DropdownMenuItem(value: 'unpaid', child: Text('❌ Unpaid'))], onChanged: (v) => setState(() => _ceirTaxStatus = v ?? '')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: _ceirBlockingStatus.isEmpty ? null : _ceirBlockingStatus, decoration: const InputDecoration(labelText: 'Device Blocking Status', border: OutlineInputBorder(), isDense: true), hint: const Text('ရွေးပါ'), items: const [DropdownMenuItem(value: 'allowed', child: Text('✅ Allowed')), DropdownMenuItem(value: 'blocked', child: Text('🚫 Blocked'))], onChanged: (v) => setState(() => _ceirBlockingStatus = v ?? '')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: _ceirSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(_ceirSaving ? 'သိမ်းနေသည်…' : d['ceirCheckedAt'] != null ? 'C.E.I.R. Result သိမ်းပြီးပြီ ✅' : 'C.E.I.R. Result သိမ်းမည်'), onPressed: _ceirFilled && !_ceirSaving && d['ceirCheckedAt'] == null ? _saveCeir : null)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            if (_isRefurbished) ...[
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.orange.shade900.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade700)), child: Row(children: [Icon(Icons.info_outline, size: 16, color: Colors.orange.shade400), const SizedBox(width: 8), Expanded(child: Text('China Refurbished — Device Verification မလိုအပ်ပါ။ CEIR စစ်ဆေးချက်ပဲ လုပ်ဆောင်ပါ။', style: TextStyle(fontSize: 12.5, color: Colors.orange.shade300)))]))
            ] else ...[
              Text('Device Verification', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('IMEI Photo + S/N ကို seller-listed specs နဲ့ cross-check လုပ်ပြီး result ထည့်ပါ', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _imeiToggleBtn(label: '✅ Specs Matched', selected: _specsResult == 'verified', color: Colors.green, onTap: () => setState(() { _specsResult = 'verified'; _mismatchNoteCtrl.clear(); }), scheme: scheme)), const SizedBox(width: 8), Expanded(child: _imeiToggleBtn(label: '❌ Mismatch', selected: _specsResult == 'mismatch', color: scheme.error, onTap: () => setState(() => _specsResult = 'mismatch'), scheme: scheme))]),
              if (_specsResult == 'mismatch') ...[const SizedBox(height: 10), TextField(controller: _mismatchNoteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'မတူညီသည့် specs (ဥပမာ: Storage 256GB မဟုတ် 128GB)', border: OutlineInputBorder(), isDense: true))],
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: _specsSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.verified_outlined), label: Text(_specsSaving ? 'သိမ်းနေသည်…' : d['specsVerifiedAt'] != null ? 'Device Verification Result သိမ်းပြီးပြီ ✅' : 'Device Verification Result သိမ်းမည်'), onPressed: _specsFilled && !_specsSaving && d['specsVerifiedAt'] == null ? _saveSpecs : null)),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600), onPressed: _markValid, child: const Text('✅ Valid'))), const SizedBox(width: 8), Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700), onPressed: _rejectSaving ? null : _rejectProduct, child: _rejectSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('⚠️ Reject'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error)), onPressed: _banSeller, child: const Text('🚫 Ban')))]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

Widget _specRow(String label, String value, ColorScheme scheme, TextTheme textTheme, {bool isFirst = false}) {
  return Column(children: [if (!isFirst) Divider(height: 1, color: scheme.outlineVariant), Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [SizedBox(width: 90, child: Text(label, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500))), Expanded(child: Text(value, style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)))]))]);
}

Widget _imeiToggleBtn({required String label, required bool selected, required Color color, required VoidCallback onTap, required ColorScheme scheme}) {
  return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: selected ? color.withValues(alpha: 0.15) : Colors.transparent, border: Border.all(color: selected ? color : scheme.outlineVariant, width: selected ? 1.5 : 1), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? color : scheme.onSurfaceVariant))));
}

class _SellerCard extends StatelessWidget {
  final String productId;
  const _SellerCard({required this.productId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').doc(productId).snapshots(),
      builder: (context, pSnap) {
        final p = pSnap.data?.data() ?? {};
        final sellerId = (p['sellerId'] ?? '').toString();
        final sellerName = (p['sellerName'] ?? '').toString();
        if (sellerId.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(sellerId).snapshots(),
          builder: (context, uSnap) {
            final u = uSnap.data?.data() ?? {};
            final photoUrl = (u['photoUrl'] ?? '').toString();
            final isVerified = u['isVerified'] == true;
            final scheme = Theme.of(context).colorScheme;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(AppRoutes.sellerWallPath(sellerId)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.outlineVariant)),
                child: Row(children: [CircleAvatar(radius: 22, backgroundColor: scheme.surfaceContainerHighest, backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null, child: photoUrl.isEmpty ? Icon(Icons.person, color: scheme.onSurfaceVariant) : null), const SizedBox(width: 12), Expanded(child: Row(children: [Flexible(child: Text(sellerName.isNotEmpty ? sellerName : 'Seller', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)), if (isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF1DA1F2))]])), Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20)]),
              ),
            );
          },
        );
      },
    );
  }
}

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

    final rows = parsed.entries
        .where((e) => e.value != null && 
                     e.value.toString().trim().isNotEmpty &&
                     !['id', 'status', 'Status', 'error', 'errorMessage', 'service_id', 'input', 'order_id', 'orderId'].contains(e.key))
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
                        ),
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
  final String condition;
  final String? productName;
  final int? productStorage;
  final Map<String, dynamic> parsed;
  final String? apiError;

  const _ImeiOrgVerificationSummaryCard({
    required this.condition,
    this.productName,
    this.productStorage,
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
    final isBrandNewClaimed = condition.toLowerCase().contains('brand new') ||
        condition.toLowerCase().contains('sealed');

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
