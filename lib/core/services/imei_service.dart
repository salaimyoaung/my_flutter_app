import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/imei_status.dart';

class ImeiService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _registry =>
      _db.collection('imei_registry');

  // ✅ Kept for admin/lookup use only — never use as pre-check before submit.
  // The controller transaction is the authoritative duplicate check.
  static Future<bool> isDuplicate(String imei) async {
    final snap = await _registry.doc(imei).get();
    return snap.exists;
  }

  static String mask(String imei) {
    if (imei.length < 8) return imei;
    return '${imei.substring(0, 6)}******${imei.substring(imei.length - 3)}';
  }

  // ✅ registerImei() removed — controller transaction handles atomic write.
  //    Calling this separately would bypass atomicity and risk double-writes.

  static Future<void> markValid({
    required String imei,
    required String adminUid,
  }) async {
    final registryRef = _registry.doc(imei);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(registryRef);
      if (!snap.exists) throw Exception('IMEI registry not found');

      final data = snap.data()!;
      final productId = (data['productId'] ?? '').toString();

      tx.update(registryRef, {
        'status': ImeiStatus.valid,
        'updatedAt': FieldValue.serverTimestamp(),
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': adminUid,
        'blacklistReason': '',
      });

      if (productId.isNotEmpty) {
        // ✅ updatedAt added
        tx.update(_db.collection('products').doc(productId), {
          'imeiStatus': ImeiStatus.valid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  static Future<void> markBlacklisted({
    required String imei,
    required String adminUid,
    required String reason,
  }) async {
    final registryRef = _registry.doc(imei);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(registryRef);
      if (!snap.exists) throw Exception('IMEI registry not found');

      final data = snap.data()!;
      final productId = (data['productId'] ?? '').toString();

      tx.update(registryRef, {
        'status': ImeiStatus.blacklisted,
        'updatedAt': FieldValue.serverTimestamp(),
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': adminUid,
        'blacklistReason': reason,
      });

      if (productId.isNotEmpty) {
        // ✅ updatedAt added
        tx.update(_db.collection('products').doc(productId), {
          'imeiStatus': ImeiStatus.blacklisted,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ✅ Ordered by createdAt for admin panel display
  static Stream<QuerySnapshot<Map<String, dynamic>>> pendingImeiStream() {
    return _registry
        .where('status', isEqualTo: ImeiStatus.notVerified)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}