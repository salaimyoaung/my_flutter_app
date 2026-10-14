import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/services/model_request_service.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

/// Admin can add phone models directly without going through seller requests.
/// Useful for pre-loading new model releases before sellers request them.
class AdminAddModelPage extends StatefulWidget {
  const AdminAddModelPage({super.key});

  @override
  State<AdminAddModelPage> createState() => _AdminAddModelPageState();
}

class _AdminAddModelPageState extends State<AdminAddModelPage> {
  final _service = ModelRequestService();

  final _brandCtrl = TextEditingController();
  final _seriesCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  String _selectedDeviceType = 'android_phone';
  bool _saving = false;
  bool _savedSuccess = false;

  // ✅ Recently added models shown in this session for quick reference
  final List<Map<String, String>> _addedThisSession = [];

  static const List<Map<String, String>> _deviceTypes = [
    {'value': 'android_phone', 'label': '🤖 Android Phone'},
    {'value': 'android_tablet', 'label': '📱 Android Tablet'},
    {'value': 'iphone', 'label': '🍎 iPhone'},
    {'value': 'ipad', 'label': '🍎 iPad'},
  ];

  // ✅ Common brands for quick-fill chips
  static const List<String> _quickBrands = [
    'Samsung', 'Apple', 'Xiaomi', 'OPPO', 'Vivo',
    'Realme', 'OnePlus', 'Huawei', 'Nokia', 'Infinix',
  ];

  @override
  void dispose() {
    _brandCtrl.dispose();
    _seriesCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final brand = _brandCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final series = _seriesCtrl.text.trim();

    if (brand.isEmpty) {
      _showSnack('Brand ထည့်ပါ');
      return;
    }
    if (model.isEmpty) {
      _showSnack('Model ထည့်ပါ');
      return;
    }
    if (model.length < 2) {
      _showSnack('Model name အနည်းဆုံး ၂ လုံးထည့်ပါ');
      return;
    }

    setState(() {
      _saving = true;
      _savedSuccess = false;
    });

    try {
      final modelId = _service.makeModelId(
        deviceType: _selectedDeviceType,
        brand: brand,
        model: model,
      );

      // ✅ Write directly to phone_models — no request flow needed for admin
      await FirebaseFirestore.instance
          .collection('phone_models')
          .doc(modelId)
          .set(
        {
          'brand': brand,
          'model': model,
          'series': series,
          'deviceType': _selectedDeviceType,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // ✅ idempotent — safe to re-add
      );

      // ✅ Track in session list
      _addedThisSession.insert(0, {
        'brand': brand,
        'model': model,
        'series': series,
        'deviceType': _selectedDeviceType,
      });

      setState(() {
        _savedSuccess = true;
        // ✅ Clear model + series only — keep brand and deviceType for batch entry
        _modelCtrl.clear();
        _seriesCtrl.clear();
      });
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(title: 'Model အသစ်ထည့်မည်'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Device Type ────────────────────────────────────────────────
            Text('Device Type', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _deviceTypes.map((dt) {
                final selected = _selectedDeviceType == dt['value'];
                return ChoiceChip(
                  label: Text(dt['label']!),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedDeviceType = dt['value']!),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Brand ──────────────────────────────────────────────────────
            Text('Brand', style: textTheme.labelLarge),
            const SizedBox(height: 8),

            // ✅ Quick-fill brand chips
            Wrap(
              spacing: 6,
              children: _quickBrands.map((b) {
                return ActionChip(
                  label: Text(b),
                  onPressed: () {
                    _brandCtrl.text = b;
                    setState(() {});
                  },
                  backgroundColor:
                  _brandCtrl.text == b ? scheme.primaryContainer : null,
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _brandCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Brand *',
                hintText: 'e.g. Samsung',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Series ─────────────────────────────────────────────────────
            TextField(
              controller: _seriesCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Series (optional)',
                hintText: 'e.g. Galaxy S, iPhone 15',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Model ──────────────────────────────────────────────────────
            TextField(
              controller: _modelCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Model *',
                hintText: 'e.g. Galaxy S24 Ultra',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // ── Submit ─────────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(_savedSuccess ? Icons.check : Icons.add),
              label: Text(_saving
                  ? 'Saving...'
                  : _savedSuccess
                  ? 'Saved! နောက်ထပ်ထည့်မည်'
                  : 'Model ထည့်မည်'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor:
                _savedSuccess ? scheme.tertiary : scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
            ),

            // ── Session History ────────────────────────────────────────────
            if (_addedThisSession.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    'ဒီ session မှာ ထည့်ပြီးသော models',
                    style: textTheme.labelLarge,
                  ),
                  const Spacer(),
                  Text(
                    '${_addedThisSession.length} ခု',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_addedThisSession.length, (i) {
                final m = _addedThisSession[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.check_circle, color: scheme.tertiary),
                  title: Text('${m['brand']} ${m['model']}'),
                  subtitle: Text(
                    [
                      if ((m['series'] ?? '').isNotEmpty) m['series']!,
                      m['deviceType'] ?? '',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}