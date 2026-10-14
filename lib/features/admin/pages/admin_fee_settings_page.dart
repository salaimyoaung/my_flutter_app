import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/fee_service.dart';
import '../../../core/widgets/brand_app_bar.dart';

/// Admin page for managing platform fee tiers.
///
/// Tiers are stored in Firestore `settings/fees`:
///   tier1Max, tier1Fee, tier2Max, tier2Fee, tier3Fee
///
/// Agreed defaults:
///   price < 500,000  → 5,000 Ks  (tier 1)
///   price < 5,000,000 → 10,000 Ks (tier 2)
///   price ≥ 5,000,000 → 15,000 Ks (tier 3)
class AdminFeeSettingsPage extends StatefulWidget {
  const AdminFeeSettingsPage({super.key});

  @override
  State<AdminFeeSettingsPage> createState() => _AdminFeeSettingsPageState();
}

class _AdminFeeSettingsPageState extends State<AdminFeeSettingsPage> {
  // ── Controllers ─────────────────────────────────────────────────────────────
  final _tier1MaxCtrl = TextEditingController();
  final _tier1FeeCtrl = TextEditingController();
  final _tier2MaxCtrl = TextEditingController();
  final _tier2FeeCtrl = TextEditingController();
  final _tier3FeeCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  @override
  void dispose() {
    _tier1MaxCtrl.dispose();
    _tier1FeeCtrl.dispose();
    _tier2MaxCtrl.dispose();
    _tier2FeeCtrl.dispose();
    _tier3FeeCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadTiers() async {
    final tiers = await FeeService.loadTiers();
    if (!mounted) return;
    setState(() {
      _tier1MaxCtrl.text = tiers['tier1Max'].toString();
      _tier1FeeCtrl.text = tiers['tier1Fee'].toString();
      _tier2MaxCtrl.text = tiers['tier2Max'].toString();
      _tier2FeeCtrl.text = tiers['tier2Fee'].toString();
      _tier3FeeCtrl.text = tiers['tier3Fee'].toString();
      _loading = false;
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final tier1Max = int.tryParse(_tier1MaxCtrl.text.trim()) ?? 0;
    final tier1Fee = int.tryParse(_tier1FeeCtrl.text.trim()) ?? 0;
    final tier2Max = int.tryParse(_tier2MaxCtrl.text.trim()) ?? 0;
    final tier2Fee = int.tryParse(_tier2FeeCtrl.text.trim()) ?? 0;
    final tier3Fee = int.tryParse(_tier3FeeCtrl.text.trim()) ?? 0;

    if (tier1Max <= 0 || tier2Max <= tier1Max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tier 1 threshold သည် 0 ထက်ကြီးရမည်။ Tier 2 threshold သည် Tier 1 ထက်ကြီးရမည်။'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FeeService.saveTiers(
        tier1Max: tier1Max,
        tier1Fee: tier1Fee,
        tier2Max: tier2Max,
        tier2Fee: tier2Fee,
        tier3Fee: tier3Fee,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee tiers သိမ်းပြီးပါပြီ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BrandAppBar(title: 'Platform Fee Settings'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info Card ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: scheme.onSecondaryContainer, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Order တစ်ခု ပြီးစီးသောအခါ seller ၏ pending fee ထဲသို့ '
                            'ဖုန်းစျေးနှုန်းအလိုက် အောက်ပါ fee များ ထည့်ပါမည်။',
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Tier 1 ──────────────────────────────────────────────
                  _sectionHeader(context, 'Tier 1 — စျေးနည်း'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _intField(
                          controller: _tier1MaxCtrl,
                          label: 'Price အထိ (Ks)',
                          hint: 'e.g. 500000',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _intField(
                          controller: _tier1FeeCtrl,
                          label: 'Platform Fee (Ks)',
                          hint: 'e.g. 5000',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _previewRow(
                    context,
                    'Price < ${_fmt(_tier1MaxCtrl.text)}',
                    'Fee: ${_fmt(_tier1FeeCtrl.text)} Ks',
                  ),

                  const SizedBox(height: 24),

                  // ── Tier 2 ──────────────────────────────────────────────
                  _sectionHeader(context, 'Tier 2 — စျေးမကြီးမဆိုး'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _intField(
                          controller: _tier2MaxCtrl,
                          label: 'Price အထိ (Ks)',
                          hint: 'e.g. 5000000',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _intField(
                          controller: _tier2FeeCtrl,
                          label: 'Platform Fee (Ks)',
                          hint: 'e.g. 10000',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _previewRow(
                    context,
                    '${_fmt(_tier1MaxCtrl.text)} ≤ Price < ${_fmt(_tier2MaxCtrl.text)}',
                    'Fee: ${_fmt(_tier2FeeCtrl.text)} Ks',
                  ),

                  const SizedBox(height: 24),

                  // ── Tier 3 ──────────────────────────────────────────────
                  _sectionHeader(context, 'Tier 3 — ဈေးကြီး'),
                  const SizedBox(height: 12),
                  _intField(
                    controller: _tier3FeeCtrl,
                    label: 'Platform Fee (Ks)',
                    hint: 'e.g. 15000',
                  ),
                  const SizedBox(height: 8),
                  _previewRow(
                    context,
                    'Price ≥ ${_fmt(_tier2MaxCtrl.text)}',
                    'Fee: ${_fmt(_tier3FeeCtrl.text)} Ks',
                  ),

                  const SizedBox(height: 32),

                  // ── Save Button ─────────────────────────────────────────
                  _saving
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Fee Tiers သိမ်းမည်'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _intField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}), // refresh preview
    );
  }

  Widget _previewRow(BuildContext context, String condition, String result) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(condition,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Text(result,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary)),
        ],
      ),
    );
  }

  /// Format a raw int string with commas for display
  String _fmt(String raw) {
    final n = int.tryParse(raw.trim()) ?? 0;
    return n
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
