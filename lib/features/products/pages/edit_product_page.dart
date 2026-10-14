import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/models/product_model.dart';
import '../../../../core/utils/thousands_separator_input_formatter.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class EditProductPage extends StatefulWidget {
  final Product product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _priceCtrl;
  late final TextEditingController _originalPriceCtrl;
  late final TextEditingController _detailCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // ✅ Initialize with formatted values (strip decimals if any)
    _priceCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatString(widget.product.price.toStringAsFixed(0)),
    );
    _originalPriceCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatString(
        widget.product.originalPrice?.toStringAsFixed(0) ?? '',
      ),
    );
    _detailCtrl = TextEditingController(text: widget.product.detail);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _originalPriceCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // ✅ Save as Number (double) — ensure consistency with AddProductController and sorting logic
      final priceNum = double.tryParse(_priceCtrl.text.trim().replaceAll(',', '')) ?? 0.0;
      final originalPriceStr = _originalPriceCtrl.text.trim().replaceAll(',', '');
      final originalPriceNum = originalPriceStr.isEmpty ? null : double.tryParse(originalPriceStr);

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .update({
        'price': priceNum,
        'originalPrice': originalPriceNum,
        'detail': _detailCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _snack('Product updated ✅');
      Navigator.pop(context);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(title: 'Edit Product'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Product Name (read only) ──────────────────────────
              Text(
                widget.product.name,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // ── Price ─────────────────────────────────────────────
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price (Ks)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'ဈေးနှုန်း ထည့်ပါ';
                  // Remove commas before validation
                  if (int.tryParse(v.replaceAll(',', '').trim()) == null) return 'ဂဏန်းသာ ထည့်ပါ';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ── Original Price ────────────────────────────────────
              TextFormField(
                controller: _originalPriceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Original Price (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // ── Detail ────────────────────────────────────────────
              TextFormField(
                controller: _detailCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detail',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              // ── Save Button ───────────────────────────────────────
              // ✅ Button disabled instead of AbsorbPointer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Update Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}