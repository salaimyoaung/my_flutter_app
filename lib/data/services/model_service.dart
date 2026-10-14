import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneModelEntry {
  final String id; // ✅ doc ID for edit/delete flows
  final String brand;
  final String? series; // ✅ nullable — empty series is genuinely absent
  final String model;
  final String deviceType;
  final bool active;

  const PhoneModelEntry({
    required this.id,
    required this.brand,
    required this.series,
    required this.model,
    required this.deviceType,
    required this.active,
  });

  // ✅ fromDoc factory — mapping logic out of service layer
  factory PhoneModelEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final v = data['active'];
    final active = (v is bool) ? v : true;

    final series = (data['series'] ?? '').toString().trim();

    return PhoneModelEntry(
      id: doc.id,
      brand: (data['brand'] ?? '').toString().trim(),
      series: series.isEmpty ? null : series,
      model: (data['model'] ?? '').toString().trim(),
      deviceType: (data['deviceType'] ?? '').toString().trim(),
      active: active,
    );
  }
}

class ModelService {
  final FirebaseFirestore _firestore;

  ModelService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream active phone models filtered by deviceType.
  /// ✅ active filter added — inactive models excluded.
  /// ✅ deviceType filter added — no cross-type pollution.
  Stream<List<PhoneModelEntry>> streamPhoneModelsByDevice(String deviceType) {
    return _firestore
        .collection('phone_models')
        .where('active', isEqualTo: true)
        .where('deviceType', isEqualTo: deviceType)
        .snapshots()
        .map((snap) => snap.docs.map(PhoneModelEntry.fromDoc).toList())
        .handleError((_) => <PhoneModelEntry>[]); // ✅ error handling
  }

  /// Legacy stream — all active models (use only where deviceType is unknown).
  /// Prefer streamPhoneModelsByDevice for AddProductPage.
  Stream<List<PhoneModelEntry>> streamPhoneModels() {
    return _firestore
        .collection('phone_models')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(PhoneModelEntry.fromDoc).toList())
        .handleError((_) => <PhoneModelEntry>[]); // ✅ error handling
  }

  /// Stream active brands for a given device type.
  /// ✅ active filter added.
  /// ✅ error handling added.
  Stream<List<String>> streamBrandsByDevice(String deviceType) {
    return _firestore
        .collection('phone_brands')
        .where('deviceTypes', arrayContains: deviceType)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final brands = snap.docs
          .map((d) => (d.data()['name'] ?? '').toString().trim())
          .where((b) => b.isNotEmpty)
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return brands;
    })
        .handleError((_) => <String>[]); // ✅ error handling
  }
}