import 'package:flutter/material.dart';

class AccessoriesSection extends StatelessWidget {
  final bool box;
  final bool charger;
  final bool cable;
  final bool earphones;
  final bool receipt;

  final Function(bool) onBoxChanged;
  final Function(bool) onChargerChanged;
  final Function(bool) onCableChanged;
  final Function(bool) onEarphonesChanged;
  final Function(bool) onReceiptChanged;

  const AccessoriesSection({
    super.key,
    required this.box,
    required this.charger,
    required this.cable,
    required this.earphones,
    required this.receipt,
    required this.onBoxChanged,
    required this.onChargerChanged,
    required this.onCableChanged,
    required this.onEarphonesChanged,
    required this.onReceiptChanged,
  });

  @override
  Widget build(BuildContext context) {

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const SizedBox(height: 12),

        Text(
          "Accessories Included",
          style: textTheme.titleMedium,
        ),

        const SizedBox(height: 10),

        CheckboxListTile(
          value: box,
          onChanged: (v) => onBoxChanged(v ?? false),
          title: const Text("Box"),
        ),

        CheckboxListTile(
          value: charger,
          onChanged: (v) => onChargerChanged(v ?? false),
          title: const Text("Charger"),
        ),

        CheckboxListTile(
          value: cable,
          onChanged: (v) => onCableChanged(v ?? false),
          title: const Text("Cable"),
        ),

        CheckboxListTile(
          value: earphones,
          onChanged: (v) => onEarphonesChanged(v ?? false),
          title: const Text("Earphones"),
        ),

        CheckboxListTile(
          value: receipt,
          onChanged: (v) => onReceiptChanged(v ?? false),
          title: const Text("Receipt"),
        ),
      ],
    );
  }
}