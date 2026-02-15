import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FixPhoneBrandsPage extends StatefulWidget {
  const FixPhoneBrandsPage({super.key});

  @override
  State<FixPhoneBrandsPage> createState() => _FixPhoneBrandsPageState();
}

class _FixPhoneBrandsPageState extends State<FixPhoneBrandsPage> {
  bool _running = false;
  String _log = "";

  void _append(String s) {
    setState(() => _log = "$_log$s\n");
  }

  String _normLower(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _log = "";
    });

    try {
      final col = FirebaseFirestore.instance.collection('phone_brands');
      final snap = await col.get();

      _append("Found ${snap.docs.length} brand docs...");

      int updated = 0;
      int skipped = 0;

      // Firestore batch limit = 500 writes
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int ops = 0;

      Future<void> commitIfNeeded() async {
        if (ops == 0) return;
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        ops = 0;
      }

      for (final d in snap.docs) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim();

        if (name.isEmpty) {
          skipped++;
          _append("SKIP ${d.id}: missing name");
          continue;
        }

        final nameLower = _normLower(name);
        final hasNameLower = (data['nameLower'] ?? '').toString().trim().isNotEmpty;
        final hasOrder = data.containsKey('order');
        final hasActive = data.containsKey('active');

        final Map<String, dynamic> patch = {};

        // only set if missing or wrong
        if (!hasNameLower || (data['nameLower'] ?? '').toString() != nameLower) {
          patch['nameLower'] = nameLower;
        }

        if (!hasOrder) {
          patch['order'] = 9999; // default bottom
        }

        if (!hasActive) {
          patch['active'] = true;
        }

        patch['updatedAt'] = FieldValue.serverTimestamp();

        if (patch.keys.length == 1 && patch.containsKey('updatedAt')) {
          skipped++;
          continue;
        }

        batch.set(d.reference, patch, SetOptions(merge: true));
        ops++;
        updated++;

        if (ops >= 450) {
          // safe buffer under 500
          await commitIfNeeded();
          _append("Committed chunk... (updated so far: $updated)");
        }
      }

      await commitIfNeeded();
      _append("DONE ✅ updated=$updated, skipped=$skipped");
    } catch (e) {
      _append("ERROR ❌ $e");
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fix phone_brands")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? "Running..." : "Run Fix"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(_log.isEmpty ? "Log..." : _log),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}