import 'package:cloud_firestore/cloud_firestore.dart';

class BrandService {
  final FirebaseFirestore _firestore;

  BrandService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ✅ active filter added — inactive brands excluded
  // ✅ error handling added — stream error returns empty list instead of crashing UI
  Stream<List<String>> streamActiveBrands() {
    return _firestore
        .collection('phone_brands')
        .where('active', isEqualTo: true)
        .orderBy('order')
        .orderBy('nameLower')
        .snapshots()
        .map((snap) {
      final list = <String>[];
      for (final d in snap.docs) {
        final name = (d.data()['name'] ?? '').toString().trim();
        if (name.isNotEmpty) list.add(name);
      }
      return list;
    })
        .handleError((_) => <String>[]); // ✅ prevents UI crash on stream error
  }

  // ✅ One-shot fetch for search/filter features
  Future<List<String>> getBrandsOnce() async {
    try {
      final snap = await _firestore
          .collection('phone_brands')
          .where('active', isEqualTo: true)
          .orderBy('nameLower')
          .get();

      return snap.docs
          .map((d) => (d.data()['name'] ?? '').toString().trim())
          .where((b) => b.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}