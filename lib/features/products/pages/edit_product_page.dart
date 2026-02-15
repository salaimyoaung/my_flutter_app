import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/models/product_model.dart';
import '../../../app_styles.dart';

class EditProductPage extends StatefulWidget {
  final String productId;
  const EditProductPage({super.key, required this.productId});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final List<int> ramOptions = [4, 6, 8, 12];
  final List<int> storageOptions = [64, 128, 256, 512, 1024];
  final List<String> colorOptions = [
    "Black",
    "White",
    "Blue",
    "Red",
    "Green",
    "Gold",
    "Silver",
    "Gray",
    "Space Black",
    "Midnight",
    "Starlight",
    "Purple",
  ];
  final List<int> batteryOptions = [
    70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
    90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100,
  ];
  final List<int> warrantyOptions = [0, 3, 7, 14, 30];
  final List<String> conditionOptions = [
    "Brand New",
    "Like New",
    "Used (Good)",
    "Used (Fair)",
  ];

  int? selectedRam;
  int? selectedStorage;
  String selectedColor = "";
  int? selectedBatteryPercent;
  int? selectedWarrantyDays;
  String selectedCondition = "";
  bool _saving = false;

  Future<void> _save() async {
    if (selectedRam == null || selectedStorage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("RAM/Storage တန်ဖိုးရွေးပါ")),
      );
      return;
    }
    if (selectedBatteryPercent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Battery Health ရွေးပါ")),
      );
      return;
    }
    if (selectedWarrantyDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Warranty ရွေးပါ")),
      );
      return;
    }
    if (selectedCondition.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Condition ရွေးပါ")),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .set({
        'specs': {
          'ram': selectedRam,
          'storage': selectedStorage,
          'color': selectedColor.trim(),
          'batteryPercent': selectedBatteryPercent,
          'warrantyDays': selectedWarrantyDays,
          'condition': selectedCondition.trim(),
        },
        'condition': selectedCondition.trim(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ပြင်ဆင်ပြီးပါပြီ")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Product ပြင်ဆင်ရန်", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }
          final data = snap.data?.data() ?? <String, dynamic>{};
          final product = Product.fromFirestore(widget.productId, data);
          selectedRam ??= product.ram;
          selectedStorage ??= product.storage;
          if (selectedColor.isEmpty) selectedColor = product.color;
          selectedBatteryPercent ??= product.batteryPercent;
          selectedWarrantyDays ??= product.warrantyDays;
          if (selectedCondition.isEmpty) selectedCondition = product.condition;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCondition.isEmpty ? null : selectedCondition,
                  decoration: const InputDecoration(
                    labelText: "Condition",
                    border: OutlineInputBorder(),
                  ),
                  items: conditionOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedCondition = (v ?? "")),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedRam,
                        decoration: const InputDecoration(
                          labelText: "RAM (GB)",
                          border: OutlineInputBorder(),
                        ),
                        items: ramOptions
                            .map((r) => DropdownMenuItem(value: r, child: Text("$r")))
                            .toList(),
                        onChanged: (v) => setState(() => selectedRam = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedStorage,
                        decoration: const InputDecoration(
                          labelText: "Storage (GB)",
                          border: OutlineInputBorder(),
                        ),
                        items: storageOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text("$s")))
                            .toList(),
                        onChanged: (v) => setState(() => selectedStorage = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedColor.isEmpty ? null : selectedColor,
                  decoration: const InputDecoration(
                    labelText: "Color",
                    border: OutlineInputBorder(),
                  ),
                  items: colorOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedColor = (v ?? "")),
                ),
                const Spacer(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedBatteryPercent,
                        decoration: const InputDecoration(
                          labelText: "Battery Health (%)",
                          border: OutlineInputBorder(),
                        ),
                        items: batteryOptions
                            .map((b) => DropdownMenuItem(value: b, child: Text("$b")))
                            .toList(),
                        onChanged: (v) => setState(() => selectedBatteryPercent = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedWarrantyDays,
                        decoration: const InputDecoration(
                          labelText: "Warranty (days)",
                          border: OutlineInputBorder(),
                        ),
                        items: warrantyOptions
                            .map((w) => DropdownMenuItem(
                                  value: w,
                                  child: Text(w == 0 ? "No warranty" : "$w"),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => selectedWarrantyDays = v),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("ပြင်ဆင်ပြီးပါပြီ"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
