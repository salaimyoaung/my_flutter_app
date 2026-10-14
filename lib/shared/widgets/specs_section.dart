import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/device_types.dart';
import '../../../core/utils/condition_utils.dart'; // ✅ shared helper

/// Warranty days → human-readable label.
String warrantyLabel(int days) {
  if (days == 0) return "No warranty";
  if (days == 90) return "3 months";
  if (days == 180) return "6 months";
  if (days == 365) return "1 year";
  if (days == 730) return "2 years";
  return "$days days";
}

class SpecsSection extends StatelessWidget {
  final int? selectedRam;
  final int? selectedStorage;
  final String selectedColor;
  final int? selectedBatteryPercent;
  final int? selectedCycleCount;
  final int? selectedWarrantyDays;

  final String? selectedVersion;
  final String? selectedRom;
  final String modelNumber;

  final ValueChanged<int?> onRamChanged;
  final ValueChanged<int?> onStorageChanged;
  final ValueChanged<String?> onColorChanged;
  final ValueChanged<int?> onBatteryChanged;
  final ValueChanged<int?>? onCycleCountChanged;
  final ValueChanged<int?> onWarrantyChanged;

  final ValueChanged<String?> onVersionChanged;
  final ValueChanged<String?> onRomChanged;
  final ValueChanged<String> onModelNumberChanged;

  // ── Apple-only ───────────────────────────────────────────────────────────────
  final String selectedIcloudStatus;
  final String selectedCarrierLock;
  final String? selectedSimType;
  final bool batteryUnverifiable;
  final ValueChanged<String> onIcloudStatusChanged;
  final ValueChanged<String> onCarrierLockChanged;
  final ValueChanged<String?> onSimTypeChanged;
  final ValueChanged<bool> onBatteryUnverifiableChanged;

  final String deviceType;
  final String condition;

  bool get isApple => deviceType == DeviceTypes.iphone || deviceType == DeviceTypes.ipad;
  bool get isAndroid =>
      deviceType == DeviceTypes.androidPhone || deviceType == DeviceTypes.androidTablet;

  const SpecsSection({
    super.key,
    required this.selectedRam,
    required this.selectedStorage,
    required this.selectedColor,
    required this.selectedBatteryPercent,
    this.selectedCycleCount,
    required this.selectedWarrantyDays,
    required this.deviceType,
    required this.selectedVersion,
    required this.selectedRom,
    required this.modelNumber,
    required this.onRamChanged,
    required this.onStorageChanged,
    required this.onColorChanged,
    required this.onBatteryChanged,
    this.onCycleCountChanged,
    required this.onWarrantyChanged,
    required this.onVersionChanged,
    required this.onRomChanged,
    required this.onModelNumberChanged,
    this.selectedIcloudStatus = 'clean',
    this.selectedCarrierLock = 'unlocked',
    this.selectedSimType,
    this.batteryUnverifiable = false,
    required this.onIcloudStatusChanged,
    required this.onCarrierLockChanged,
    required this.onSimTypeChanged,
    required this.onBatteryUnverifiableChanged,
    required this.condition,
  });

  // ─── Options ───────────────────────────────────────────────────────────────
  static const List<int> ramOptions = [4, 6, 8, 12, 16, 24];
  static const List<int> storageOptions = [64, 128, 256, 512, 1024, 2048];

  static const List<String> colorOptions = [
    // ── Basic ──────────────────────────────────────────────
    "Black", "White", "Blue", "Red", "Green", "Yellow", "Orange", "Pink",
    "Purple", "Brown", "Gray", "Silver", "Gold",
    // ── Dark / Light variants ───────────────────────────────
    "Dark Blue", "Dark Green", "Dark Gray", "Dark Red", "Dark Purple",
    "Light Blue", "Light Green", "Light Gray", "Light Pink", "Light Purple",
    // ── Apple specific ──────────────────────────────────────
    "Space Black", "Space Gray", "Midnight", "Starlight", "Deep Purple",
    "Natural Titanium", "Black Titanium", "White Titanium", "Desert Titanium",
    "Ultramarine", "Teal", "Rose", "Coral", "Product Red",
    // ── Samsung / Android specific ──────────────────────────
    "Phantom Black", "Phantom White", "Cream", "Lavender", "Graphite",
    "Burgundy", "Mint", "Olive", "Lime", "Sky Blue", "Awesome Black",
    "Awesome White", "Awesome Blue", "Awesome Violet", "Awesome Orange",
    // ── Other premium colors ────────────────────────────────
    "Rose Gold", "Champagne", "Copper", "Bronze", "Titanium",
    "Navy", "Cyan", "Indigo", "Violet", "Maroon", "Peach",
    "Sage", "Sand", "Ceramic White", "Ceramic Black",
  ];

  // Version/ROM — Android only
  static const List<String> versionOptions = [
    "Global", "China", "India", "Japan", "Korea",
  ];

  static const List<String> romOptions = [
    "Global ROM", "China ROM",
  ];

  static const List<int> batteryOptions = [
    70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
    90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100,
  ];

  static const List<int> warrantyOptions = [
    0, 3, 7, 14, 30, 90, 180, 365, 730,
  ];

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ✅ shared helper — consistent with Controller and Page
    final isUsed = isUsedCondition(condition);
    final showBattery = isApple && isUsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── RAM + Storage ────────────────────────────────────────────────────
        Row(
          children: [
            if (!isApple) ...[
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedRam,
                  decoration: const InputDecoration(
                    labelText: "RAM (GB)",
                    border: OutlineInputBorder(),
                  ),
                  items: ramOptions
                      .map((r) =>
                      DropdownMenuItem(value: r, child: Text("$r GB")))
                      .toList(),
                  onChanged: onRamChanged,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: selectedStorage,
                decoration: const InputDecoration(
                  labelText: "Storage",
                  border: OutlineInputBorder(),
                ),
                items: storageOptions
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s >= 1024 ? "${s ~/ 1024} TB" : "$s GB"),
                        ))
                    .toList(),
                onChanged: onStorageChanged,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Color ────────────────────────────────────────────────────────────
        _ColorAutocompleteField(
          initialValue: selectedColor,
          onChanged: (v) => onColorChanged(v.isEmpty ? null : v),
        ),

        const SizedBox(height: 12),

        // ── Version + ROM — Android only ─────────────────────────────────────
        if (isAndroid) ...[
          DropdownButtonFormField<String>(
            initialValue: selectedVersion,
            decoration: const InputDecoration(
              labelText: "Version",
              border: OutlineInputBorder(),
            ),
            items: versionOptions
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: onVersionChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedRom,
            decoration: const InputDecoration(
              labelText: "ROM",
              border: OutlineInputBorder(),
            ),
            items: romOptions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: onRomChanged,
          ),
          const SizedBox(height: 12),
        ],

        // ── Apple-only fields ─────────────────────────────────────────────────
        if (isApple) ...[
          TextFormField(
            initialValue: modelNumber,
            decoration: const InputDecoration(
              labelText: "Model Number (ZA/A, CH/A …)",
              border: OutlineInputBorder(),
            ),
            onChanged: onModelNumberChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedSimType,
            decoration: const InputDecoration(
              labelText: "SIM Type",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'single',    child: Text('Single SIM (Nano)')),
              DropdownMenuItem(value: 'dual_esim', child: Text('Dual SIM (Nano + eSIM)')),
              DropdownMenuItem(value: 'dual_nano', child: Text('Dual SIM (Nano + Nano)')),
              DropdownMenuItem(value: 'esim_only', child: Text('eSIM Only')),
            ],
            onChanged: onSimTypeChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedIcloudStatus,
                  decoration: const InputDecoration(
                    labelText: "iCloud",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'clean',  child: Text('✅ Clean')),
                    DropdownMenuItem(value: 'locked', child: Text('🔒 Locked')),
                  ],
                  onChanged: (v) { if (v != null) onIcloudStatusChanged(v); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedCarrierLock,
                  decoration: const InputDecoration(
                    labelText: "Carrier",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'unlocked', child: Text('🌐 Unlocked')),
                    DropdownMenuItem(value: 'locked',   child: Text('🔒 Locked')),
                  ],
                  onChanged: (v) { if (v != null) onCarrierLockChanged(v); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // ── Battery Health ────────────────────────────────────────────────────
        if (showBattery) ...[
          DropdownButtonFormField<int>(
            initialValue: batteryUnverifiable ? null : selectedBatteryPercent,
            decoration: InputDecoration(
              labelText: "Battery Health (%)",
              helperText: batteryUnverifiable ? null : "70% – 100%",
              border: const OutlineInputBorder(),
            ),
            items: batteryUnverifiable
                ? null
                : batteryOptions
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text("$b%"),
                        ))
                    .toList(),
            onChanged: batteryUnverifiable ? null : onBatteryChanged,
            disabledHint: const Text("စစ်မရပါ"),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => onBatteryUnverifiableChanged(!batteryUnverifiable),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: batteryUnverifiable,
                    onChanged: (v) =>
                        onBatteryUnverifiableChanged(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                const Text("စစ်မရပါ", style: TextStyle(fontSize: 12.5)),
                const SizedBox(width: 6),
                const Text(
                  "(China Refurbished only)",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: selectedCycleCount?.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: "Battery Cycle Count (optional)",
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              if (onCycleCountChanged != null) {
                onCycleCountChanged!(int.tryParse(v));
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        // ── Warranty ──────────────────────────────────────────────────────────
        DropdownButtonFormField<int>(
          initialValue: selectedWarrantyDays,
          decoration: const InputDecoration(
            labelText: "Warranty",
            border: OutlineInputBorder(),
          ),
          items: warrantyOptions
              .map((w) => DropdownMenuItem(
                    value: w,
                    child: Text(warrantyLabel(w)),
                  ))
              .toList(),
          onChanged: onWarrantyChanged,
        ),


        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Color Autocomplete Field ──────────────────────────────────────────────────
// Type to search existing colors — free text allowed for custom colors.

class _ColorAutocompleteField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _ColorAutocompleteField({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_ColorAutocompleteField> createState() =>
      _ColorAutocompleteFieldState();
}

class _ColorAutocompleteFieldState extends State<_ColorAutocompleteField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_ColorAutocompleteField old) {
    super.didUpdateWidget(old);
    // Sync if parent resets value (e.g. form clear)
    if (widget.initialValue != old.initialValue &&
        widget.initialValue != _ctrl.text) {
      _ctrl.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Iterable<String> _suggestions(String query) {
    if (query.trim().isEmpty) return SpecsSection.colorOptions.take(10);
    final q = query.toLowerCase().trim();
    final starts = SpecsSection.colorOptions
        .where((c) => c.toLowerCase().startsWith(q));
    final contains = SpecsSection.colorOptions
        .where((c) => !c.toLowerCase().startsWith(q) && c.toLowerCase().contains(q));
    return [...starts, ...contains].take(15);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (v) => _suggestions(v.text),
      onSelected: (value) {
        _ctrl.text = value;
        widget.onChanged(value);
      },
      fieldViewBuilder: (context, autoCtrl, focusNode, _) {
        // Sync autocomplete internal controller with our controller
        if (autoCtrl.text != _ctrl.text) {
          autoCtrl.value = TextEditingValue(
            text: _ctrl.text,
            selection: TextSelection.collapsed(offset: _ctrl.text.length),
          );
        }
        return TextField(
          controller: autoCtrl,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: "Color (optional)",
            hintText: "e.g. Black, Rose Gold, Midnight…",
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _ctrl.text = v;
            widget.onChanged(v);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final w = MediaQuery.of(context).size.width - 32;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: w,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 12, endIndent: 12),
                itemBuilder: (context, i) {
                  final color = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(color),
                    onTap: () => onSelected(color),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}