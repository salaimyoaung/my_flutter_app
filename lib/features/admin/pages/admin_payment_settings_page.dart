import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

/// Admin page — manage deposit bank accounts stored in `settings/payment`.
/// Firestore shape:
///   settings/payment { bankAccounts: [ { name: "KBZPay", number: "09…", accountName: "Ko Mg" }, … ] }
class AdminPaymentSettingsPage extends StatefulWidget {
  const AdminPaymentSettingsPage({super.key});

  @override
  State<AdminPaymentSettingsPage> createState() =>
      _AdminPaymentSettingsPageState();
}

class _AdminPaymentSettingsPageState extends State<AdminPaymentSettingsPage> {
  final _nameCtrl        = TextEditingController(); // bank/wallet name
  final _numberCtrl      = TextEditingController(); // account number / phone
  final _accountNameCtrl = TextEditingController(); // account holder name
  bool _saving   = false;
  bool _timedOut = false;
  Timer? _loadTimer;

  static final _ref = FirebaseFirestore.instance
      .collection('settings')
      .doc('payment');

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Add ──────────────────────────────────────────────────────────────────

  Future<void> _add(List<Map<String, dynamic>> current) async {
    final name        = _nameCtrl.text.trim();
    final number      = _numberCtrl.text.trim();
    final accountName = _accountNameCtrl.text.trim();
    if (name.isEmpty || number.isEmpty) {
      _snack('Bank Name နဲ့ Number ဖြည့်ပါ');
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = [
        ...current,
        {
          'name': name,
          'number': number,
          'accountName': accountName,
        },
      ];
      await _ref.set({'bankAccounts': updated}, SetOptions(merge: true));
      _nameCtrl.clear();
      _numberCtrl.clear();
      _accountNameCtrl.clear();
      _snack('Bank account ထည့်ပြီးပါပြီ ✅');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _delete(
    List<Map<String, dynamic>> current,
    int index,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(
          '"${current[index]['name']} — ${current[index]['number']}" ကို ဖျက်မလား?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('မဖျက်ဘူး'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ဖျက်မည်'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final updated = [...current]..removeAt(index);
      await _ref.set({'bankAccounts': updated}, SetOptions(merge: true));
      _snack('ဖျက်ပြီးပါပြီ');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(title: 'Payment Settings'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          if (!snap.hasData && _timedOut) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 48),
                  const SizedBox(height: 12),
                  const Text('Network မရှိပါ — Firestore ချိတ်မရဘူး'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _timedOut = false;
                        _loadTimer?.cancel();
                        _loadTimer = Timer(const Duration(seconds: 8), () {
                          if (mounted) setState(() => _timedOut = true);
                        });
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snap.hasData) _loadTimer?.cancel();

          final accounts = snap.hasData
              ? List<Map<String, dynamic>>.from(
                  snap.data!.data()?['bankAccounts'] ?? [],
                )
              : <Map<String, dynamic>>[];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [

              // ── Current Accounts ────────────────────────────────────────
              Text('Current Bank Accounts', style: textTheme.titleMedium),
              const SizedBox(height: 12),

              if (!snap.hasData)
                const Center(child: CircularProgressIndicator())
              else if (accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Bank account မရှိသေးပါ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...accounts.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final a   = entry.value;
                  final acn = (a['accountName'] ?? '').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(
                        (a['name'] ?? '').toString(),
                        style: textTheme.titleSmall,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((a['number'] ?? '').toString()),
                          if (acn.isNotEmpty)
                            Text(
                              acn,
                              style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                        onPressed: _saving ? null : () => _delete(accounts, i),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 20),

              // ── Add New Account ──────────────────────────────────────────
              Text('Add Bank Account', style: textTheme.titleMedium),
              const SizedBox(height: 16),

              // Bank / Wallet name
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Bank / Wallet Name',
                  hintText: 'ဥပမာ — KBZ Pay, Wave Pay',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Account number / phone
              TextField(
                controller: _numberCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Account Number / Phone',
                  hintText: 'ဥပမာ — 09xxxxxxxxx',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Account holder name
              TextField(
                controller: _accountNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name',
                  hintText: 'ဥပမာ — Ko Mg Mg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),

              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: () => _add(accounts),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Account'),
                    ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
