import 'package:flutter/material.dart';
import '../../core/constants/device_types.dart';
import '../../data/services/model_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BrandModelStatus — loading / error indicator strip
// ─────────────────────────────────────────────────────────────────────────────

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
            final loading =
                brandSnap.connectionState == ConnectionState.waiting ||
                    modelSnap.connectionState == ConnectionState.waiting;

            return Column(
              children: [
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(),
                  ),
                if (brandSnap.hasError)
                  _ErrorRow(
                    message: 'Brand load error',
                    color: scheme.error,
                  ),
                if (modelSnap.hasError)
                  _ErrorRow(
                    message: 'Models load error',
                    color: scheme.error,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final Color color;

  const _ErrorRow({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 16),
          const SizedBox(width: 6),
          Text(message, style: TextStyle(color: color, fontSize: 13)),
          const Spacer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BrandModelSection — brand / series / model pickers
// ─────────────────────────────────────────────────────────────────────────────

class BrandModelSection extends StatefulWidget {
  final Stream<List<String>> brandsStream;
  final Stream<List<PhoneModelEntry>> modelsStream;
  final TextEditingController brandController;
  final TextEditingController seriesController;
  final TextEditingController modelController;
  final String selectedDeviceType;
  final VoidCallback onBrandChanged;
  final VoidCallback onSeriesChanged;
  final VoidCallback onModelChanged;
  final VoidCallback onModelInputChanged;

  const BrandModelSection({
    super.key,
    required this.brandsStream,
    required this.modelsStream,
    required this.brandController,
    required this.seriesController,
    required this.modelController,
    required this.selectedDeviceType,
    required this.onBrandChanged,
    required this.onSeriesChanged,
    required this.onModelChanged,
    required this.onModelInputChanged,
  });

  @override
  State<BrandModelSection> createState() => _BrandModelSectionState();
}

class _BrandModelSectionState extends State<BrandModelSection> {
  // ✅ Cached map — rebuilt only when entries reference changes
  List<PhoneModelEntry>? _cachedEntries;
  Map<String, Map<String, Map<String, Set<String>>>>? _cachedMap;

  // ✅ Search result limits as constants
  static const int _defaultSuggestions = 8;
  static const int _searchSuggestions = 20;

  // ✅ Dropdown toggle state — tap field again to close
  bool _modelDropdownOpen = false;
  bool _modelFocusListenerAdded = false;
  bool _seriesDropdownOpen = false;
  bool _seriesFocusListenerAdded = false;

  // ✅ Shared normalizer — was duplicated as _normKey and _normSearch
  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  Map<String, Map<String, Map<String, Set<String>>>> _buildSeriesModelMap(
      List<PhoneModelEntry> entries,
      ) {
    if (_cachedEntries == entries && _cachedMap != null) return _cachedMap!;

    final map = {
      DeviceTypes.androidPhone: <String, Map<String, Set<String>>>{},
      DeviceTypes.androidTablet: <String, Map<String, Set<String>>>{},
      DeviceTypes.iphone: <String, Map<String, Set<String>>>{},
      DeviceTypes.ipad: <String, Map<String, Set<String>>>{},
    };

    for (final e in entries) {
      if (!e.active) continue;
      if (e.brand.trim().isEmpty || e.model.trim().isEmpty) continue;

      final dt     = DeviceTypes.safe(e.deviceType);
      final brand  = e.brand.trim();
      final series = (e.series?.trim().isEmpty ?? true) ? 'Other' : e.series!.trim();
      final model  = e.model.trim();

      map[dt]!.putIfAbsent(brand, () => {});
      map[dt]![brand]!.putIfAbsent(series, () => {});
      map[dt]![brand]![series]!.add(model);
    }

    _cachedEntries = entries;
    _cachedMap     = map;
    return map;
  }

  String? _findRealBrand(
      Map<String, Map<String, Map<String, Set<String>>>> data,
      String brand,
      String deviceType,
      ) {
    final map = data[deviceType] ?? {};
    for (final b in map.keys) {
      if (_norm(b) == _norm(brand)) return b;
    }
    return null;
  }

  String? _findRealSeries(
      Map<String, Map<String, Map<String, Set<String>>>> data,
      String brand,
      String series,
      String deviceType,
      ) {
    final realBrand = _findRealBrand(data, brand, deviceType);
    if (realBrand == null) return null;
    final seriesMap = data[deviceType]![realBrand]!;
    for (final s in seriesMap.keys) {
      if (_norm(s) == _norm(series)) return s;
    }
    return null;
  }

  List<String> _seriesForSelectedBrand(
      Map<String, Map<String, Map<String, Set<String>>>> data,
      String brand,
      String deviceType,
      ) {
    if (brand.trim().isEmpty) return const [];
    final realBrand = _findRealBrand(data, brand, deviceType);
    if (realBrand == null) return const [];
    return data[deviceType]![realBrand]!.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _modelsForSelectedBrandAndSeries(
      Map<String, Map<String, Map<String, Set<String>>>> data,
      String brand,
      String series,
      String deviceType,
      ) {
    if (brand.trim().isEmpty || series.trim().isEmpty) return const [];
    final realBrand = _findRealBrand(data, brand, deviceType);
    if (realBrand == null) return const [];
    final realSeries = _findRealSeries(data, brand, series, deviceType);
    if (realSeries == null) return const [];
    return (data[deviceType]![realBrand]![realSeries] ?? {}).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Iterable<String> _searchItems(List<String> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items.take(_defaultSuggestions);
    final startsWith = items.where((x) => x.toLowerCase().startsWith(q));
    final contains = items.where(
          (x) => !x.toLowerCase().startsWith(q) && x.toLowerCase().contains(q),
    );
    return [...startsWith, ...contains].take(_searchSuggestions);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showBrandPicker(List<String> brands) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => _SearchPickerSheet(
        title: 'Select Brand',
        items: brands,
        isSelected: (b) => _norm(widget.brandController.text) == _norm(b),
        onTapItem: (b) {
          widget.brandController.text = b;
          widget.seriesController.clear();
          widget.modelController.clear();
          widget.onBrandChanged();
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _showSeriesPicker(List<String> brands, List<String> seriesList) {
    if (widget.brandController.text.trim().isEmpty) {
      _showSnack('Brand ကိုအရင်ရွေးပါ');
      return;
    }
    if (seriesList.isEmpty) {
      _showSnack('ဒီ Brand/DeviceType အတွက် Series list မရှိသေးပါ');
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => _SearchPickerSheet(
        title: 'Select Series',
        items: seriesList,
        topWidget: Row(
          children: [
            Expanded(
              child: Text(
                'Brand: ${widget.brandController.text.trim()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: scheme.onSurface),
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
              label: const Text('Change'),
            ),
          ],
        ),
        isSelected: (s) => _norm(widget.seriesController.text) == _norm(s),
        onTapItem: (s) {
          widget.seriesController.text = s;
          widget.modelController.clear();
          widget.onSeriesChanged();
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _showModelPicker(
      List<String> brands,
      List<String> seriesList,
      List<String> models,
      ) {
    if (widget.brandController.text.trim().isEmpty) {
      _showSnack('Brand ကိုအရင်ရွေးပါ');
      return;
    }
    if (widget.seriesController.text.trim().isEmpty) {
      _showSnack('Series ကိုအရင်ရွေးပါ');
      return;
    }
    if (models.isEmpty) {
      _showSnack('Model list မရှိသေးပါ — Model ကို လက်ဖြင့်ရိုက်ထည့်ပါ');
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => _SearchPickerSheet(
        title: 'Select Model',
        items: models,
        topWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brand: ${widget.brandController.text.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Series: ${widget.seriesController.text.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Future.microtask(() {
                      if (mounted) _showSeriesPicker(brands, seriesList);
                    });
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Change'),
                ),
              ],
            ),
          ],
        ),
        isSelected: (m) => _norm(widget.modelController.text) == _norm(m),
        onTapItem: (m) {
          widget.modelController.text = m;
          widget.onModelChanged();
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  // ── Autocomplete field builder helper ────────────────────────────────────

  Widget _autocompleteField({
    Key? key,
    required TextEditingController externalController,
    required String label,
    required List<String> items,
    required VoidCallback onClear,
    required void Function(String) onExternalChanged,
    required void Function(String) onSelected,
    bool tapToClose = false,
    bool Function()? getOpen,
    void Function(bool)? setOpen,
    bool Function()? getFocusAdded,
    void Function()? markFocusAdded,
  }) {
    return Autocomplete<String>(
      key: key,
      optionsBuilder: (v) {
        // Exact match → already selected, hide dropdown
        final q = v.text.trim().toLowerCase();
        if (items.any((x) => x.trim().toLowerCase() == q)) return const [];
        return _searchItems(items, v.text);
      },
      onSelected: (value) {
        externalController.text = value;
        if (tapToClose) setOpen?.call(false);
        onSelected(value);
      },
      fieldViewBuilder: (context, controller, focusNode, _) {
        // ✅ Sync only when external value differs — prevents cursor jump
        if (controller.text != externalController.text) {
          controller.value = TextEditingValue(
            text: externalController.text,
            selection:
            TextSelection.collapsed(offset: externalController.text.length),
          );
        }
        // ✅ Track focus loss to reset toggle state (add listener once)
        if (tapToClose && getFocusAdded != null && !getFocusAdded()) {
          markFocusAdded?.call();
          focusNode.addListener(() {
            if (mounted && !focusNode.hasFocus) {
              setState(() => setOpen?.call(false));
            }
          });
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onTap: tapToClose ? () {
            if (getOpen?.call() ?? false) {
              focusNode.unfocus();
              setState(() => setOpen?.call(false));
            } else {
              setState(() => setOpen?.call(true));
            }
          } : null,
          onChanged: (value) {
            externalController.text = value;
            onClear();
            onExternalChanged(value);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final screenWidth = MediaQuery.of(context).size.width; // ✅ responsive
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: screenWidth - 80, // ✅ was hardcoded 300
              height: 200,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
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

            // ✅ Cached — no rebuild unless entries list reference changes
            final data = _buildSeriesModelMap(entries);

            final seriesList = _seriesForSelectedBrand(
              data,
              widget.brandController.text,
              widget.selectedDeviceType,
            );

            final models = _modelsForSelectedBrandAndSeries(
              data,
              widget.brandController.text,
              widget.seriesController.text,
              widget.selectedDeviceType,
            );

            return Column(
              children: [
                // ── Brand ────────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _autocompleteField(
                        // ✅ Recreate when device type changes so stale brand
                        // suggestions (e.g. Apple after switching to Android) are cleared.
                        key: ValueKey('brand_${widget.selectedDeviceType}'),
                        externalController: widget.brandController,
                        label: 'Brand (type to search)',
                        items: brands,
                        onClear: () {
                          widget.seriesController.clear();
                          widget.modelController.clear();
                        },
                        onExternalChanged: (_) => widget.onBrandChanged(),
                        onSelected: (_) {
                          widget.seriesController.clear();
                          widget.modelController.clear();
                          widget.onBrandChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showBrandPicker(brands),
                      icon: const Icon(Icons.list),
                      label: const Text('Select'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Series ───────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _autocompleteField(
                        // ✅ Recreate Autocomplete when device type or brand changes
                        // so stale _options from previous selection are cleared.
                        key: ValueKey(
                            'series_${widget.selectedDeviceType}_${widget.brandController.text}'),
                        externalController: widget.seriesController,
                        label: 'Series (type to search)',
                        items: widget.brandController.text.trim().isEmpty
                            ? const []
                            : seriesList,
                        onClear: () => widget.modelController.clear(),
                        onExternalChanged: (_) => widget.onSeriesChanged(),
                        onSelected: (_) {
                          widget.modelController.clear();
                          widget.onSeriesChanged();
                        },
                        tapToClose: true,
                        getOpen: () => _seriesDropdownOpen,
                        setOpen: (v) => setState(() => _seriesDropdownOpen = v),
                        getFocusAdded: () => _seriesFocusListenerAdded,
                        markFocusAdded: () { _seriesFocusListenerAdded = true; },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showSeriesPicker(brands, seriesList),
                      icon: const Icon(Icons.category_outlined),
                      label: const Text('Select'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Model ────────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _autocompleteField(
                        // ✅ Recreate when device type, brand, or series changes
                        key: ValueKey(
                            'model_${widget.selectedDeviceType}_${widget.brandController.text}_${widget.seriesController.text}'),
                        externalController: widget.modelController,
                        label: 'Model (type to search)',
                        items: (widget.brandController.text.trim().isEmpty ||
                            widget.seriesController.text.trim().isEmpty)
                            ? const []
                            : models,
                        onClear: () {},
                        onExternalChanged: (_) => widget.onModelInputChanged(),
                        onSelected: (_) => widget.onModelChanged(),
                        tapToClose: true,
                        getOpen: () => _modelDropdownOpen,
                        setOpen: (v) => setState(() => _modelDropdownOpen = v),
                        getFocusAdded: () => _modelFocusListenerAdded,
                        markFocusAdded: () { _modelFocusListenerAdded = true; },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showModelPicker(brands, seriesList, models),
                      icon: const Icon(Icons.phone_android),
                      label: const Text('Select'),
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

// ─────────────────────────────────────────────────────────────────────────────
// _SearchPickerSheet
// ─────────────────────────────────────────────────────────────────────────────

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
  String _q = '';

  String _norm(String s) =>
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
      return _norm(x).contains(_norm(_q));
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
              child: Text(
                widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  fontSize: 16,
                ),
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
                  hintText: 'Search…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
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
                  ? const Center(child: Text('မတွေ့ပါ'))
                  : ListView.separated(
                itemCount: filtered.length,
                // ✅ __ not _ — fixes Dart 3 compile error
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = filtered[i];
                  final selected = widget.isSelected(item);
                  return ListTile(
                    leading: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
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