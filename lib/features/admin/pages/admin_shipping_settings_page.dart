import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

/// Admin page to manage:
///  - City list (add / remove)
///  - Same-city delivery fee
///  - Different-city delivery fee
///
/// Firestore path: settings/shipping
/// Document shape:
///   { cities: [String], sameCityFee: int, differentCityFee: int }
class AdminShippingSettingsPage extends StatefulWidget {
  const AdminShippingSettingsPage({super.key});

  @override
  State<AdminShippingSettingsPage> createState() =>
      _AdminShippingSettingsPageState();
}

class _AdminShippingSettingsPageState
    extends State<AdminShippingSettingsPage> {
  static final _ref = FirebaseFirestore.instance
      .collection('settings')
      .doc('shipping');

  final _cityCtrl = TextEditingController();
  final _sameFeeCtrl = TextEditingController();
  final _diffFeeCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _cityCtrl.dispose();
    _sameFeeCtrl.dispose();
    _diffFeeCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Add city ────────────────────────────────────────────────────────────────

  Future<void> _addCity(List<String> current) async {
    final city = _cityCtrl.text.trim();
    if (city.isEmpty) return;

    final normalised = city
        .split(' ')
        .map((w) => w.isEmpty
            ? w
            : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');

    if (current.any((c) => c.toLowerCase() == normalised.toLowerCase())) {
      _snack('$normalised ရှိပြီးသားပါ');
      return;
    }

    final updated = [...current, normalised]..sort();
    await _ref.set({'cities': updated}, SetOptions(merge: true));
    _cityCtrl.clear();
    _snack('$normalised ထည့်ပြီ');
  }

  // ── Remove city ─────────────────────────────────────────────────────────────

  Future<void> _removeCity(String city, List<String> current) async {
    final updated = current.where((c) => c != city).toList();
    await _ref.set({'cities': updated}, SetOptions(merge: true));
  }

  // ── Save fees ────────────────────────────────────────────────────────────────

  Future<void> _saveFees() async {
    final same = int.tryParse(_sameFeeCtrl.text.trim());
    final diff = int.tryParse(_diffFeeCtrl.text.trim());

    if (same == null || same < 0) {
      _snack('Same-city fee မှန်ကန်တဲ့ ဂဏန်းထည့်ပါ');
      return;
    }
    if (diff == null || diff < 0) {
      _snack('Different-city fee မှန်ကန်တဲ့ ဂဏန်းထည့်ပါ');
      return;
    }

    setState(() => _saving = true);
    try {
      await _ref.set(
        {'sameCityFee': same, 'differentCityFee': diff},
        SetOptions(merge: true),
      );
      _snack('Delivery fees သိမ်းပြီ ✓');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(title: 'Shipping Settings'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data?.data() ?? {};
          final cities = List<String>.from(data['cities'] ?? []);
          final sameFee = (data['sameCityFee'] ?? 10000) as int;
          final diffFee = (data['differentCityFee'] ?? 20000) as int;

          // ✅ Pre-fill fee fields only when not editing
          if (!_sameFeeCtrl.text.isNotEmpty &&
              snap.connectionState == ConnectionState.active) {
            _sameFeeCtrl.text = sameFee.toString();
            _diffFeeCtrl.text = diffFee.toString();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Delivery Fees ──────────────────────────────────────────
                Text('Delivery Fees',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sameFeeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Same City Fee (MMK)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_city),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _diffFeeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Different City Fee (MMK)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.swap_horiz),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveFees,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Fees သိမ်းမည်'),
                  ),
                ),

                const SizedBox(height: 28),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 12),

                // ── City List ──────────────────────────────────────────────
                Text('မြို့တွေ (${cities.length})',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                // Add city row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'မြို့အမည်',
                          hintText: 'e.g. Taunggyi',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.add_location_outlined),
                        ),
                        onSubmitted: (_) => _addCity(cities),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => _addCity(cities),
                      child: const Text('ထည့်'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!snap.hasData)
                  const Center(child: CircularProgressIndicator())
                else if (cities.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'မြို့ မရှိသေးပါ — ထည့်ပါ',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  // City chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cities.map((city) {
                      return Chip(
                        label: Text(city),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('မြို့ဖျက်မည်'),
                            content:
                                Text('"$city" ကို ဖျက်မလား?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('မဖျက်ဘူး'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _removeCity(city, cities);
                                },
                                child: Text(
                                  'ဖျက်မယ်',
                                  style: TextStyle(
                                      color: scheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
