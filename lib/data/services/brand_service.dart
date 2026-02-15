import 'package:cloud_firestore/cloud_firestore.dart';

class BrandService {
  final FirebaseFirestore _firestore;

  BrandService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
    });
  }
}
