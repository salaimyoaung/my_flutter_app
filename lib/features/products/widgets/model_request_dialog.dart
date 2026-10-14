import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../data/services/model_request_service.dart';

class ModelRequestDialog extends StatefulWidget {
  final String brand;
  final String deviceType;
  final String series; // ✅ pre-selected series from add product page

  // ✅ Service injected — testable
  final ModelRequestService? service;

  const ModelRequestDialog({
    super.key,
    required this.brand,
    required this.deviceType,
    this.series = '',
    this.service,
  });

  @override
  State<ModelRequestDialog> createState() => _ModelRequestDialogState();
}

class _ModelRequestDialogState extends State<ModelRequestDialog> {
  final _modelCtrl = TextEditingController();
  final _seriesCtrl = TextEditingController();

  late final ModelRequestService _service =
      widget.service ?? ModelRequestService();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // ✅ Auto-fill series + model from pre-selected series
    if (widget.series.isNotEmpty) {
      _seriesCtrl.text = widget.series;
      _modelCtrl.text  = widget.series; // user adds only e.g. " 50" at the end
      // Place cursor at end so user can type immediately
      _modelCtrl.selection = TextSelection.collapsed(
        offset: _modelCtrl.text.length,
      );
    }
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _seriesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final model = _modelCtrl.text.trim();
    final series = _seriesCtrl.text.trim();

    // ✅ Validation — min length check added
    if (model.isEmpty) {
      _showSnack('Model name ထည့်ပါ');
      return;
    }
    if (model.length < 2) {
      _showSnack('Model name အနည်းဆုံး ၂ လုံးထည့်ပါ');
      return;
    }

    setState(() => _saving = true);

    try {
      // ✅ Fetch seller name from users collection — not displayName
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final sellerName =
      (userDoc.data()?['name'] ?? user.displayName ?? 'Seller').toString();

      await _service.submitRequest(
        sellerId: user.uid,
        sellerName: sellerName,
        brand: widget.brand,
        model: model,
        series: series,
        deviceType: widget.deviceType,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model request ပို့ပြီးပါပြီ')),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request New Model'),
      // ✅ SingleChildScrollView — prevents overflow on small screens
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Text widget instead of TextEditingController in build()
            //    — was leaking a new controller on every rebuild
            _ReadOnlyField(label: 'Device Type', value: widget.deviceType),
            const SizedBox(height: 12),
            _ReadOnlyField(label: 'Brand', value: widget.brand),
            const SizedBox(height: 12),
            TextField(
              controller: _seriesCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Series (optional)',
                hintText: 'e.g. Galaxy S, iPhone 15',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Model Name *',
                hintText: 'e.g. Galaxy S23 Ultra',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
          // ✅ Loading indicator instead of just text change
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

// ✅ Extracted widget — no controller leak, clean and reusable
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
      ),
      child: Text(
        value,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}