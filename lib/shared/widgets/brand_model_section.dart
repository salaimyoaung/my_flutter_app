import 'package:flutter/material.dart';
import '../../data/services/model_service.dart';

class BrandModelStatus extends StatelessWidget {
  final Stream<List<String>> brandsStream;
  final Stream<List<PhoneModelEntry>> modelsStream;

  const BrandModelStatus({
    super.key,
    required this.brandsStream,
    required this.modelsStream,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<String>>(
      stream: brandsStream,
      builder: (context, brandSnap) {
        return StreamBuilder<List<PhoneModelEntry>>(
          stream: modelsStream,
          builder: (context, modelSnap) {
            final brandsLoading =
                brandSnap.connectionState == ConnectionState.waiting;
            final modelsLoading =
                modelSnap.connectionState == ConnectionState.waiting;
            return Column(
              children: [
                if (brandsLoading || modelsLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(),
                  ),
                if (brandSnap.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      "Brand load error: ${brandSnap.error}",
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                if (modelSnap.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      "Models load error: ${modelSnap.error}",
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class BrandModelSection extends StatefulWidget {
  final Stream<List<String>> brandsStream;
  final Stream<List<PhoneModelEntry>> modelsStream;
  final TextEditingController brandController;
  final TextEditingController modelController;
  final String selectedDeviceType;
  final VoidCallback onBrandChanged;
  final VoidCallback onModelChanged;
  final VoidCallback onModelInputChanged;

  const BrandModelSection({
    super.key,
    required this.brandsStream,
    required this.modelsStream,
    required this.brandController,
    required this.modelController,
    required this.selectedDeviceType,
    required this.onBrandChanged,
    required this.onModelChanged,
    required this.onModelInputChanged,
  });

  @override
  State<BrandModelSection> createState() => _BrandModelSectionState();
}

class _BrandModelSectionState extends State<BrandModelSection> {
  static const String dtAndroidPhone = "android_phone";
  static const String dtAndroidTablet = "android_tablet";
  static const String dtIphone = "iphone";
  static const String dtIpad = "ipad";

  String _safeType(String raw) {
    if (raw == dtAndroidPhone ||
        raw == dtAndroidTablet ||
        raw == dtIphone ||
        raw == dtIpad) {
      return raw;
    }
    return dtAndroidPhone;
  }

  String _normKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();

  Map<String, Map<String, Set<String>>> _buildModelMap(
    List<PhoneModelEntry> entries,
  ) {
    final map = {
      dtAndroidPhone: <String, Set<String>>{},
      dtAndroidTablet: <String, Set<String>>{},
      dtIphone: <String, Set<String>>{},
      dtIpad: <String, Set<String>>{},
    };

    for (final e in entries) {
      if (!e.active) continue;
      if (e.brand.isEmpty || e.model.isEmpty) continue;
      final dt = _safeType(e.deviceType);
      (map[dt]![e.brand] ??= <String>{}).add(e.model);
    }
    return map;
  }

  List<String> _modelsForSelectedBrand(
    Map<String, Map<String, Set<String>>> modelsByType,
    String brand,
    String deviceType,
  ) {
    if (brand.trim().isEmpty) return const [];
    final map = modelsByType[deviceType] ?? <String, Set<String>>{};
    String? realBrand;
    for (final b in map.keys) {
      if (_normKey(b) == _normKey(brand)) {
        realBrand = b;
        break;
      }
    }
    if (realBrand == null) return const [];
    final set = map[realBrand] ?? <String>{};
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void _showBrandPicker(List<String> brands) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return _SearchPickerSheet(
          title: "Select Brand",
          items: brands,
          isSelected: (b) => _normKey(widget.brandController.text) == _normKey(b),
          onTapItem: (b) {
            widget.brandController.text = b;
            widget.modelController.clear();
            widget.onBrandChanged();
            Navigator.pop(sheetContext);
          },
        );
      },
    );
  }

  void _showModelPicker(List<String> brands, List<String> models) {
    final scheme = Theme.of(context).colorScheme;

    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "ဒီ Brand/DeviceType အတွက် Model list မရှိသေးပါ (Model ကို လက်ဖြင့်ရိုက်ထည့်ပါ)",
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return _SearchPickerSheet(
          title: "Select Model",
          items: models,
          topWidget: Row(
            children: [
              Expanded(
                child: Text(
                  "Brand: ${widget.brandController.text.trim()}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    if (mounted) _showBrandPicker(brands);
                  });
                },
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text("Change"),
              ),
            ],
          ),
          isSelected: (m) =>
              _normKey(widget.modelController.text) == _normKey(m),
          onTapItem: (m) {
            widget.modelController.text = m;
            widget.onModelChanged();
            Navigator.pop(sheetContext);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: widget.brandsStream,
      builder: (context, brandSnap) {
        final brands = brandSnap.data ?? const [];
        return StreamBuilder<List<PhoneModelEntry>>(
          stream: widget.modelsStream,
          builder: (context, modelSnap) {
            final entries = modelSnap.data ?? const [];
            final modelsByType = _buildModelMap(entries);
            final models = _modelsForSelectedBrand(
              modelsByType,
              widget.brandController.text,
              widget.selectedDeviceType,
            );
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.brandController,
                        decoration: const InputDecoration(
                          labelText: "Brand (ရိုက်ထည့် / Select)",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => widget.onBrandChanged(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: brands.isEmpty ? null : () => _showBrandPicker(brands),
                      icon: const Icon(Icons.list),
                      label: const Text("Select"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.modelController,
                        decoration: InputDecoration(
                          labelText: "Model (ရိုက်ထည့် / Select)",
                          border: const OutlineInputBorder(),
                          helperText: (() {
                            if (widget.brandController.text.trim().isEmpty) {
                              return "Brand အရင်ထည့်ပါ";
                            }
                            if (models.isEmpty) {
                              return "Model list မရှိရင် လက်ဖြင့်ရိုက်ထည့်နိုင်ပါတယ်";
                            }
                            return "Models available: ${models.take(6).join(', ')}${models.length > 6 ? '…' : ''}";
                          })(),
                        ),
                        onChanged: (_) => widget.onModelInputChanged(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: widget.brandController.text.trim().isEmpty
                          ? null
                          : () => _showModelPicker(brands, models),
                      icon: const Icon(Icons.phone_android),
                      label: const Text("Select"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SearchPickerSheet extends StatefulWidget {
  const _SearchPickerSheet({
    required this.title,
    required this.items,
    required this.isSelected,
    required this.onTapItem,
    this.topWidget,
  });

  final String title;
  final List<String> items;
  final bool Function(String item) isSelected;
  final void Function(String item) onTapItem;
  final Widget? topWidget;

  @override
  State<_SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<_SearchPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = "";

  String _normSearch(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final filtered = widget.items.where((x) {
      if (_q.trim().isEmpty) return true;
      return _normSearch(x).contains(_normSearch(_q));
    }).toList();

    final h = MediaQuery.of(context).size.height * 0.78;

    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.topWidget != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: widget.topWidget!,
              ),
            ],
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search…",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _q = "");
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("မတွေ့ပါ"))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        final selected = widget.isSelected(item);

                        return ListTile(
                          leading: Icon(
                            selected ? Icons.check_circle : Icons.circle_outlined,
                            color: selected ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                          title: Text(item),
                          onTap: () => widget.onTapItem(item),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
