import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';
class ManagePhoneBrandsPage extends StatefulWidget {
  const ManagePhoneBrandsPage({super.key});

  @override
  State<ManagePhoneBrandsPage> createState() => _ManagePhoneBrandsPageState();
}


class _ManagePhoneBrandsPageState extends State<ManagePhoneBrandsPage> {
  final TextEditingController _brandCtrl = TextEditingController();
  @override
  void dispose() {
    _brandCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }



  Future<void> _pickAndUploadLogo(String brandId) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);

      final size = await file.length();
      if (size > 2000000) {
        _setLog("Image too large ❌ (max 2MB)");
        return;
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('brand_logos/$brandId.png');

      await ref.putFile(
        file,
        SettableMetadata(contentType: "image/png"),
      );

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('phone_brands')
          .doc(brandId)
          .set({
        "logoUrl": url,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _setLog("Logo updated ✅");
    } catch (e) {
      _setLog("Logo upload error ❌ $e");
    }
  }
  bool _saving = false;
  String _log = "";
  String _q = "";

  void _setLog(String s) => setState(() => _log = s);

  String _normLower(String s) => s.toLowerCase().replaceAll(RegExp(r"\s+"), " ").trim();

  Future<void> _saveOrder(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _log = "";
    });

    try {
      final batch = FirebaseFirestore.instance.batch();

      // order = 1..N
      for (int i = 0; i < docs.length; i++) {
        batch.set(
          docs[i].reference,
          {
            "order": i + 1,
            "updatedAt": FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      _setLog("Saved ✅ (${docs.length} brands)");
    } catch (e) {
      _setLog("ERROR ❌ $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive(DocumentReference<Map<String, dynamic>> ref, bool newVal) async {
    try {
      await ref.set(
        {
          "active": newVal,
          "updatedAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      _setLog("Toggle error ❌ $e");
    }
  }

  Future<void> _renameBrand(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    final oldName = (data["name"] ?? "").toString().trim();
    final ctrl = TextEditingController(text: oldName);

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename brand"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Brand name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    final name = (res ?? "").trim();
    if (name.isEmpty || name == oldName) return;
    final newId = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    final existing = await FirebaseFirestore.instance
        .collection("phone_brands")
        .doc(newId)
        .get();

    if (existing.exists) {
      _setLog("Brand already exists ⚠️");
      return;
    }

    try {
      await ref.set(
        {
          "name": name,
          "nameLower": _normLower(name),
          "updatedAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _setLog("Renamed ✅ $oldName -> $name");
    } catch (e) {
      _setLog("Rename error ❌ $e");
    }
  }

  Future<void> _addBrand() async {
    _brandCtrl.clear();

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Brand"),
        content: TextField(
          controller: _brandCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Brand name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _brandCtrl.text),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    final brand = (name ?? "").trim();
    if (brand.isEmpty) return;

    try {
      final id = brand
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');

      final doc = await FirebaseFirestore.instance
          .collection("phone_brands")
          .doc(id)
          .get();

      if (doc.exists) {
        _setLog("Brand already exists ⚠️");
        return;
      }
      await FirebaseFirestore.instance
          .collection("phone_brands")
          .doc(id)
          .set({
        "name": brand,
        "nameLower": _normLower(brand),
        "active": true,
        "order": 999,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      _setLog("Brand added ✅ $brand");
    } catch (e) {
      _setLog("Add brand error ❌ $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // ✅ Admin panel: show ALL brands (active true/false) so you can toggle
    // Sorting: order then nameLower
    final stream = FirebaseFirestore.instance
        .collection('phone_brands')
        .orderBy('order')
        .orderBy('nameLower')
        .snapshots();

    return Scaffold(
      appBar: BrandAppBar(
        title: "Manage Phone Brands",
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search brand…",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _q = ""),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add Brand"),
                  onPressed: _addBrand,
                ),
              ],
            ),
          ),

          if (_log.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_log),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text("Error: ${snap.error}"));
                }

                final docsAll = snap.data?.docs ?? [];
                if (docsAll.isEmpty) return const Center(child: Text("No brands"));

                // Filter by search (client-side)
                final qn = _normLower(_q);
                final docs = qn.isEmpty
                    ? docsAll.toList()
                    : docsAll.where((d) {
                  final data = d.data();
                  final name = (data["name"] ?? "").toString();
                  final nameLower = (data["nameLower"] ?? "").toString();
                  return _normLower(name).contains(qn) || nameLower.contains(qn);
                }).toList();

                // Note: ReorderableListView needs a mutable list (we already have docs list)
                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: docs.length,
                  buildDefaultDragHandles: false, // we'll place our own drag handle
                  onReorderItem: (oldIndex, newIndex) async {
                    // IMPORTANT: when searching, reordering filtered list will produce wrong global order
                    if (qn.isNotEmpty) {
                      _setLog("Search ဖွင့်ထားချိန် reorder မလုပ်ပါ (Search ပိတ်ပြီးလုပ်ပါ)");
                      return;
                    }

                    final moved = docs.removeAt(oldIndex);
                    docs.insert(newIndex, moved);

                    await _saveOrder(docs);
                  },
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final name = (data["name"] ?? "").toString().trim();
                    final active = (data["active"] is bool) ? (data["active"] as bool) : true;
                    final order = data["order"];

                    return Card(
                      key: ValueKey(d.id),
                      child: ListTile(
                        // Drag handle
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Icons.drag_handle),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _pickAndUploadLogo(d.id),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: scheme.surfaceContainerHighest,
                                backgroundImage: (data["logoUrl"] ?? "").toString().isNotEmpty
                                    ? NetworkImage(data["logoUrl"])
                                    : null,
                                child: (data["logoUrl"] ?? "").toString().isEmpty
                                    ? const Icon(Icons.image, size: 18)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        title: Text(name.isEmpty ? "(no name)" : name),
                        subtitle: Text("order: ${order ?? '-'}  •  id: ${d.id}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Active toggle
                            Switch(
                              value: active,
                              onChanged: (v) => _toggleActive(d.reference, v),
                            ),
                            // Rename
                            IconButton(
                              tooltip: "Rename",
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _renameBrand(d.reference, data),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}