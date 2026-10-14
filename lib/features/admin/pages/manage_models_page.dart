import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/device_types.dart';
import '../../../core/router/app_routes.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class ManageModelsPage extends StatefulWidget {
  const ManageModelsPage({super.key});

  @override
  State<ManageModelsPage> createState() => _ManageModelsPageState();
}

class _ManageModelsPageState extends State<ManageModelsPage> {
  late final TextEditingController _seriesCtrl;
  
  // =========================
  // Device Types
  // =========================
  final List<String> _deviceTypes = const [
    DeviceTypes.androidPhone,
    DeviceTypes.androidTablet,
    DeviceTypes.iphone,
    DeviceTypes.ipad,
  ];

  String _deviceTypeLabel(String dt) {
    switch (dt) {
      case DeviceTypes.androidPhone:
        return "Android Phones";
      case DeviceTypes.androidTablet:
        return "Android Tablets";
      case DeviceTypes.iphone:
        return "iPhone";
      case DeviceTypes.ipad:
        return "iPad";
      default:
        return "Android Phones";
    }
  }

  final String _selectedDeviceType = DeviceTypes.androidPhone;

  // =========================
  // Helpers
  // =========================
  String _normKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
  String _cleanBrand(String s) => s.trim();
  String _cleanModel(String s) => s.trim();

  // =========================
  // Firestore Collections
  // =========================
  CollectionReference<Map<String, dynamic>> get _modelsCol =>
      FirebaseFirestore.instance.collection('phone_models');

  CollectionReference<Map<String, dynamic>> get _brandsCol =>
      FirebaseFirestore.instance.collection('phone_brands');

  // =========================
  // Controllers
  // =========================
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _searchCtrl;
  late final FocusNode _modelFocus;

  @override
  void initState() {
    super.initState();
    _seriesCtrl = TextEditingController();
    _brandCtrl = TextEditingController();
    _modelCtrl = TextEditingController();
    _searchCtrl = TextEditingController();
    _modelFocus = FocusNode();
  }

  @override
  void dispose() {
    _seriesCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _searchCtrl.dispose();
    _modelFocus.dispose();
    super.dispose();
  }

  Future<List<String>> _loadBrandNames() async {
    final snap = await _brandsCol.where('active', isEqualTo: true).get();
    final brands = snap.docs
        .map((d) => (d.data()['name'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return brands;
  }

  _Computed _computeFromDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final dtBrandToModels = <String, Map<String, Set<String>>>{};
    final pairKeySet = <String>{};

    for (final d in docs) {
      final data = d.data();
      final v = data['active'];
      final isActive = (v is bool) ? v : true;
      if (!isActive) continue;

      final brand = (data['brand'] ?? '').toString().trim();
      final model = (data['model'] ?? '').toString().trim();
      if (brand.isEmpty || model.isEmpty) continue;

      final dt = (data['deviceType'] ?? '').toString().trim().isEmpty
          ? DeviceTypes.androidPhone
          : (data['deviceType'] ?? '').toString().trim();

      (dtBrandToModels[dt] ??= <String, Set<String>>{});
      (dtBrandToModels[dt]![brand] ??= <String>{}).add(model);
      pairKeySet.add("${_normKey(dt)}||${_normKey(brand)}||${_normKey(model)}");
    }

    return _Computed(
      dtBrandToModels: dtBrandToModels,
      isDuplicate: (dt, b, m) => pairKeySet.contains("${_normKey(dt)}||${_normKey(b)}||${_normKey(m)}"),
    );
  }

  Future<void> _upsertModel({
    required String deviceType,
    required String brand,
    required String model,
    required String series,
  }) async {
    final dt = deviceType.trim();
    final b = _cleanBrand(brand);
    final m = _cleanModel(model);
    final modelId = "${_normKey(dt)}__${_normKey(b)}__${_normKey(m)}";
    final brandId = _normKey(b);
    final batch = FirebaseFirestore.instance.batch();

    batch.set(_brandsCol.doc(brandId), {
      "name": b,
      "active": true,
      "updatedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_modelsCol.doc(modelId), {
      "deviceType": dt,
      "brand": b,
      "model": m,
      "active": true,
      "series": series.trim(),
      "updatedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> _openBrandSheet({
    required ColorScheme scheme,
    required List<String> brandsSorted,
    required VoidCallback refreshDialog,
    required String deviceType,
  }) async {
    if (brandsSorted.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brand list မရှိသေးပါ")));
      return;
    }

    String q = "";
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = brandsSorted.where((b) => q.trim().isEmpty || b.toLowerCase().contains(q.trim().toLowerCase())).toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 44, height: 5, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(999))),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        decoration: const InputDecoration(hintText: "Search brand…", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                        onChanged: (v) => setSheet(() => q = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("No brand found"))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final b = filtered[i];
                                return ListTile(
                                  title: Text(b),
                                  onTap: () {
                                    _brandCtrl.text = b;
                                    _modelCtrl.clear();
                                    refreshDialog();
                                    Navigator.pop(ctx);
                                    Future.delayed(const Duration(milliseconds: 200), () => _modelFocus.requestFocus());
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAddDialog(_Computed computed) async {
    final scheme = Theme.of(context).colorScheme;
    _brandCtrl.clear();
    _modelCtrl.clear();
    _seriesCtrl.clear();
    String dt = _selectedDeviceType;
    bool showDupMsg = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setLocal) {
          return AlertDialog(
            backgroundColor: scheme.surface,
            title: const Text("Add Model"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: dt,
                    decoration: const InputDecoration(labelText: "Device Type", border: OutlineInputBorder()),
                    items: _deviceTypes.map((x) => DropdownMenuItem(value: x, child: Text(_deviceTypeLabel(x)))).toList(),
                    onChanged: (v) { if (v != null) setLocal(() => dt = v); },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<List<String>>(
                          future: _loadBrandNames(),
                          builder: (context, snap) {
                            final brands = snap.data ?? [];
                            return Autocomplete<String>(
                              optionsBuilder: (v) => v.text.isEmpty ? brands : brands.where((b) => b.toLowerCase().contains(v.text.toLowerCase())),
                              onSelected: (v) {
                                _brandCtrl.text = v;
                                _modelCtrl.clear();
                                Future.delayed(const Duration(milliseconds: 200), () => _modelFocus.requestFocus());
                              },
                              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                                if (controller.text != _brandCtrl.text) controller.text = _brandCtrl.text;
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(labelText: "Brand", border: OutlineInputBorder()),
                                  onChanged: (v) { _brandCtrl.text = v; _modelCtrl.clear(); },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final brands = await _loadBrandNames();
                          if (!mounted) return;
                          await _openBrandSheet(scheme: scheme, brandsSorted: brands, refreshDialog: () => setLocal(() {}), deviceType: dt);
                        },
                        icon: const Icon(Icons.list),
                        label: const Text("Select"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _seriesCtrl, decoration: const InputDecoration(labelText: "Series (e.g. Galaxy S / Pro / Mate)", border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _modelCtrl, focusNode: _modelFocus, decoration: const InputDecoration(labelText: "Model", hintText: "e.g. Galaxy Tab S9", border: OutlineInputBorder())),
                  if (showDupMsg) Padding(padding: const EdgeInsets.only(top: 8), child: Text("ဒီ model ရှိပြီးသားပါ", style: TextStyle(color: scheme.error))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  final brand = _brandCtrl.text.trim();
                  final model = _modelCtrl.text.trim();
                  final series = _seriesCtrl.text.trim();
                  if (brand.isEmpty || model.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brand/Model ပြည့်ပြည့်စုံစုံ ထည့်ပါ")));
                    return;
                  }
                  if (computed.isDuplicate(dt, brand, model)) {
                    setLocal(() => showDupMsg = true);
                    return;
                  }
                  try {
                    await _upsertModel(deviceType: dt, brand: brand, model: model, series: series);
                    if (!mounted) return;
                    if (Navigator.canPop(dialogCtx)) {
                      Navigator.pop(dialogCtx);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Model ထည့်ပြီးပါပြီ")));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Add Error: $e")));
                  }
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final q = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: BrandAppBar(title: "Manage Models"),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _modelsCol.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));

          final docsRaw = (snap.data?.docs ?? []).toList();
          final computed = _computeFromDocs(docsRaw);
          final docs = docsRaw.where((d) {
            final data = d.data();
            final b = (data['brand'] ?? '').toString().toLowerCase();
            final m = (data['model'] ?? '').toString().toLowerCase();
            return q.isEmpty || b.contains(q) || m.contains(q);
          }).toList();

          docs.sort((a, b) {
            final ab = (a.data()['brand'] ?? '').toString().toLowerCase();
            final bb = (b.data()['brand'] ?? '').toString().toLowerCase();
            final am = (a.data()['model'] ?? '').toString().toLowerCase();
            final bm = (b.data()['model'] ?? '').toString().toLowerCase();
            final c1 = ab.compareTo(bb);
            return c1 != 0 ? c1 : am.compareTo(bm);
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search brand / model…",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () { _searchCtrl.clear(); setState(() {}); }),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(icon: const Icon(Icons.auto_fix_high), label: const Text("Fix Phone Brands"), onPressed: () => context.push(AppRoutes.fixPhoneBrands)),
                        ElevatedButton.icon(onPressed: () => _openAddDialog(computed), icon: const Icon(Icons.add), label: const Text("Add Model")),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: docs.isEmpty
                    ? Center(child: Text("No models", style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)))
                    : ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final data = d.data();
                          return ListTile(
                            title: Text((data['model'] ?? '').toString()),
                            subtitle: Text("${data['brand'] ?? ''} • ${data['series'] ?? ''}"),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: scheme.error),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Delete Model?"),
                                    content: const Text("Are you sure?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  try {
                                    await d.reference.delete();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                    }
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Computed {
  final Map<String, Map<String, Set<String>>> dtBrandToModels;
  final bool Function(String dt, String brand, String model) isDuplicate;
  _Computed({required this.dtBrandToModels, required this.isDuplicate});
}
