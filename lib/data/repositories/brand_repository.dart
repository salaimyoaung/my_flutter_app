import 'package:cloud_firestore/cloud_firestore.dart';

class BrandRepository {
  final FirebaseFirestore _firestore;

  BrandRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getBrandByName(String name) async {
    final id = name.trim().toLowerCase();
    if (id.isEmpty) return null;
    final doc = await _firestore.collection('brands').doc(id).get();
    if (!doc.exists) return null;
    return doc.data();
  }
}
