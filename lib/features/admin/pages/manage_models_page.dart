import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';

class ManageModelsPage extends StatefulWidget {
  const ManageModelsPage({super.key});

  @override
  State<ManageModelsPage> createState() => _ManageModelsPageState();
}

class _ManageModelsPageState extends State<ManageModelsPage> {
  // =========================
  // Device Types (same as AddProductPage / ProductsPage)
  // =========================
  static const String dtAndroidPhone = "android_phone";
  static const String dtAndroidTablet = "android_tablet";
  static const String dtIphone = "iphone";
  static const String dtIpad = "ipad";

  final List<String> _deviceTypes = const [
    dtAndroidPhone,
    dtAndroidTablet,
    dtIphone,
    dtIpad,
  ];

  String _deviceTypeLabel(String dt) {
    switch (dt) {
      case dtAndroidPhone:
        return "Android Phones";
      case dtAndroidTablet:
        return "Android Tablets";
      case dtIphone:
        return "iPhone";
      case dtIpad:
        return "iPad";
      default:
        return "Android Phones";
    }
  }

  String _selectedDeviceType = dtAndroidPhone;

  // =========================
  // Helpers
  // =========================
  String _normKey(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
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
  // Controllers (keep in STATE -> no disposed crash)
  // =========================
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _brandCtrl = TextEditingController();
    _modelCtrl = TextEditingController();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================
  // Read brand list from phone_brands (optional picker)
  // =========================
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

  // =========================
  // Compute (NO setState side effects)
  // =========================
  _Computed _computeFromDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // dt -> brand -> models
    final dtBrandToModels = <String, Map<String, Set<String>>>{};

    // duplicate check (dt||brand||model)
    final pairKeySet = <String>{};

    for (final d in docs) {
      final data = d.data();

      // active missing => true
      final v = data['active'];
      final isActive = (v is bool) ? v : true;
      if (!isActive) continue;

      final brand = (data['brand'] ?? '').toString().trim();
      final model = (data['model'] ?? '').toString().trim();
      if (brand.isEmpty || model.isEmpty) continue;

      final dt = (data['deviceType'] ?? '').toString().trim().isEmpty
          ? dtAndroidPhone
          : (data['deviceType'] ?? '').toString().trim();

      (dtBrandToModels[dt] ??= <String, Set<String>>{});
      (dtBrandToModels[dt]![brand] ??= <String>{}).add(model);

      pairKeySet.add("${_normKey(dt)}||${_normKey(brand)}||${_normKey(model)}");
    }

    bool isDup(String dt, String brand, String model) {
      return pairKeySet.contains("${_normKey(dt)}||${_normKey(brand)}||${_normKey(model)}");
    }

    return _Computed(
      dtBrandToModels: dtBrandToModels,
      isDuplicate: isDup,
    );
  }

  // =========================
  // Upsert model + ensure brand exists
  // =========================
  Future<void> _upsertModel({
    required String deviceType,
    required String brand,
    required String model,
  }) async {
    final dt = deviceType.trim();
    final b = _cleanBrand(brand);
    final m = _cleanModel(model);

    // deterministic ids
    final modelId = "${_normKey(dt)}__${_normKey(b)}__${_normKey(m)}";
    final brandId = _normKey(b);

    final batch = FirebaseFirestore.instance.batch();

    // ✅ ensure brand exists in phone_brands
    batch.set(
      _brandsCol.doc(brandId),
      {
        "name": b,
        "active": true,
        "updatedAt": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // ✅ upsert model
    batch.set(
      _modelsCol.doc(modelId),
      {
        "deviceType": dt,
        "brand": b,
        "model": m,
        "active": true,
        "updatedAt": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> _deleteDoc(DocumentReference ref) async {
    await ref.delete();
  }

  // =========================
  // Brand picker sheet (from phone_brands)
  // =========================
  Future<void> _openBrandSheet({
    required ColorScheme scheme,
    required List<String> brandsSorted,
    required VoidCallback refreshDialog,
  }) async {
    if (brandsSorted.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Brand list မရှိသေးပါ")),
      );
      return;
    }

    String q = "";

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final filtered = brandsSorted.where((b) {
              if (q.trim().isEmpty) return true;
              return b.toLowerCase().contains(q.trim().toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.7,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search brand…",
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setSheet(() => q = v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text("No brand found"))
                            : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final b = filtered[i];
                            return ListTile(
                              title: Text(b),
                              onTap: () {
                                _brandCtrl.text = b;
                                _modelCtrl.clear();
                                refreshDialog();
                                Navigator.pop(ctx);
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
        );
      },
    );
  }

  // =========================
  // Add dialog (deviceType + brand + model)
  // =========================
  Future<void> _openAddDialog(_Computed computed) async {
    final scheme = Theme.of(context).colorScheme;

    // reset (don’t dispose)
    _brandCtrl.clear();
    _modelCtrl.clear();
    String dt = _selectedDeviceType;

    bool showDupMsg = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setLocal) {
          void refreshDialog() => setLocal(() {});

          final b = _brandCtrl.text.trim();
          final m = _modelCtrl.text.trim();

          final isDup = b.isNotEmpty && m.isNotEmpty && computed.isDuplicate(dt, b, m);

          return AlertDialog(
            backgroundColor: scheme.surface,
            title: const Text("Add Model"),
            content: SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: dt,
                      decoration: const InputDecoration(
                        labelText: "Device Type",
                        border: OutlineInputBorder(),
                      ),
                      items: _deviceTypes
                          .map((x) => DropdownMenuItem(value: x, child: Text(_deviceTypeLabel(x))))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        dt = v;
                        showDupMsg = false;
                        refreshDialog();
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _brandCtrl,
                            decoration: const InputDecoration(
                              labelText: "Brand (type new or select)",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              showDupMsg = false;
                              _modelCtrl.clear();
                              refreshDialog();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final brands = await _loadBrandNames();
                            if (!mounted) return;
                            await _openBrandSheet(
                              scheme: scheme,
                              brandsSorted: brands,
                              refreshDialog: refreshDialog,
                            );
                          },
                          icon: const Icon(Icons.list),
                          label: const Text("Select"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _modelCtrl,
                      decoration: InputDecoration(
                        labelText: "Model (e.g. S24 Ultra)",
                        border: const OutlineInputBorder(),
                        errorText: showDupMsg && isDup ? "ဒီ DeviceType/Brand/Model ရှိပြီးသားပါ" : null,
                      ),
                      onChanged: (_) {
                        showDupMsg = false;
                        refreshDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final brand = _brandCtrl.text.trim();
                  final model = _modelCtrl.text.trim();

                  if (brand.isEmpty || model.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Brand/Model ပြည့်ပြည့်စုံစုံ ထည့်ပါ")),
                    );
                    return;
                  }

                  if (computed.isDuplicate(dt, brand, model)) {
                    showDupMsg = true;
                    setLocal(() {});
                    return;
                  }

                  try {
                    await _upsertModel(deviceType: dt, brand: brand, model: model);
                    if (!mounted) return;

                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Model ထည့်ပြီးပါပြီ")),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Add Error: $e")),
                    );
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

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Models"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _modelsCol.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Error: ${snap.error}", textAlign: TextAlign.center),
              ),
            );
          }

          final docsRaw = (snap.data?.docs ?? []).toList();

          // compute snapshot cache
          final computed = _computeFromDocs(docsRaw);

          // filter active + deviceType + search
          final docs = docsRaw.where((d) {
            final data = d.data();
            final v = data['active'];
            final isActive = (v is bool) ? v : true;
            if (!isActive) return false;

            final dt = (data['deviceType'] ?? '').toString().trim().isEmpty
                ? dtAndroidPhone
                : (data['deviceType'] ?? '').toString().trim();
            if (dt != _selectedDeviceType) return false;

            if (q.isEmpty) return true;

            final brand = (data['brand'] ?? '').toString().toLowerCase();
            final model = (data['model'] ?? '').toString().toLowerCase();
            return brand.contains(q) || model.contains(q);
          }).toList();

          docs.sort((a, b) {
            final ab = (a.data()['brand'] ?? '').toString().toLowerCase();
            final bb = (b.data()['brand'] ?? '').toString().toLowerCase();
            final am = (a.data()['model'] ?? '').toString().toLowerCase();
            final bm = (b.data()['model'] ?? '').toString().toLowerCase();
            final c1 = ab.compareTo(bb);
            if (c1 != 0) return c1;
            return am.compareTo(bm);
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  children: [
                    // device type filter
                    DropdownButtonFormField<String>(
                      value: _selectedDeviceType,
                      decoration: const InputDecoration(
                        labelText: "Device Type",
                        border: OutlineInputBorder(),
                      ),
                      items: _deviceTypes
                          .map((dt) =>
                          DropdownMenuItem(value: dt, child: Text(_deviceTypeLabel(dt))))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedDeviceType = v);
                      },
                    ),
                    const SizedBox(height: 10),

                    // search
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search brand / model…",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: q.isEmpty
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text("Fix Phone Brands (Admin)"),
                      onPressed: () {
                        context.push(AppRoutes.fixPhoneBrands);
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _openAddDialog(computed),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Model"),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: docs.isEmpty
                    ? Center(
                  child: Text(
                    "No models in ${_deviceTypeLabel(_selectedDeviceType)}",
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
                    : ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final brand = (data['brand'] ?? '').toString();
                    final model = (data['model'] ?? '').toString();

                    return ListTile(
                      title: Text(model),
                      subtitle: Text(brand),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          try {
                            await _deleteDoc(d.reference);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Delete Error: $e")),
                            );
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

  _Computed({
    required this.dtBrandToModels,
    required this.isDuplicate,
  });
}
