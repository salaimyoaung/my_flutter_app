import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore;

  ProductService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ✅ createProduct() removed — controller transaction handles atomic write.
  //    Using this separately bypasses IMEI atomicity.

  // ✅ Queries imei_registry (correct collection) — was querying 'products' before.
  // NOTE: Still a standalone read — only use for admin lookup, not as pre-submit check.
  //       The controller transaction is the authoritative duplicate guard.
  Future<bool> isImeiAlreadyExists(String imei) async {
    final snap =
    await _firestore.collection('imei_registry').doc(imei).get();
    return snap.exists;
  }

  // ✅ SetOptions(merge: true) — idempotent, eliminates read-then-write race condition
  Future<void> ensureModelExists(String brand, String model) async {
    final brandId = brand.trim().toLowerCase();

    // ✅ Strip special characters for a safe Firestore doc ID
    final modelId = model
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w]'), '')
        .replaceAll(RegExp(r'\s+'), '');

    if (brandId.isEmpty || modelId.isEmpty) return;

    final id = '${brandId}__$modelId';
    final ref = _firestore.collection('phone_models').doc(id);

    // ✅ merge: true — safe concurrent writes, no read needed
    await ref.set(
      {
        'brand': brand.trim(),
        'series': '',
        'model': model.trim(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ✅ Paginated — avoids loading all products for high-volume sellers
  Future<List<Product>> getProductsBySeller(
      String sellerId, {
        DocumentSnapshot? startAfter,
        int limit = 20,
      }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Product.fromDoc(doc)).toList();
  }
}