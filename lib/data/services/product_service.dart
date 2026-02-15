import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final FirebaseFirestore _firestore;

  ProductService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createProduct(Map<String, dynamic> data) async {
    await _firestore.collection('products').add(data);
  }

  Future<void> ensureModelExists(String brand, String model) async {
    final brandId = brand.trim().toLowerCase();
    final modelId = model.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (brandId.isEmpty || modelId.isEmpty) return;
    final id = "$brandId" "__" "$modelId";
    final ref = _firestore.collection('phone_models').doc(id);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'brand': brand,
      'model': model,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
