import 'package:flutter/material.dart';

class SpecsSection extends StatelessWidget {
  final int? selectedRam;
  final int? selectedStorage;
  final String selectedColor;
  final int? selectedBatteryPercent;
  final int? selectedWarrantyDays;
  final ValueChanged<int?> onRamChanged;
  final ValueChanged<int?> onStorageChanged;
  final ValueChanged<String?> onColorChanged;
  final ValueChanged<int?> onBatteryChanged;
  final ValueChanged<int?> onWarrantyChanged;

  const SpecsSection({
    super.key,
    required this.selectedRam,
    required this.selectedStorage,
    required this.selectedColor,
    required this.selectedBatteryPercent,
    required this.selectedWarrantyDays,
    required this.onRamChanged,
    required this.onStorageChanged,
    required this.onColorChanged,
    required this.onBatteryChanged,
    required this.onWarrantyChanged,
  });

  static const List<int> ramOptions = [4, 6, 8, 12];
  static const List<int> storageOptions = [64, 128, 256, 512, 1024];
  static const List<String> colorOptions = [
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
  static const List<int> batteryOptions = [
    70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
    90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100,
  ];
  static const List<int> warrantyOptions = [
    0,
    3,
    7,
    14,
    30,
    90,
    180,
    365,
    730,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                onChanged: onRamChanged,
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
                onChanged: onStorageChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: selectedColor.isEmpty ? null : selectedColor,
          decoration: const InputDecoration(
            labelText: "Color (optional)",
            border: OutlineInputBorder(),
          ),
          items:
              colorOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: onColorChanged,
        ),
        const SizedBox(height: 15),
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
                onChanged: onBatteryChanged,
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
                          child: Text(() {
                            if (w == 0) return "No warranty";
                            if (w == 90) return "3 months";
                            if (w == 180) return "6 months";
                            if (w == 365) return "1 year";
                            if (w == 730) return "2 years";
                            return "$w days";
                          }()),
                        ))
                    .toList(),
                onChanged: onWarrantyChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}
