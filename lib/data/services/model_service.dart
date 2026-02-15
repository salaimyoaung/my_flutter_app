import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneModelEntry {
  final String brand;
  final String model;
  final String deviceType;
  final bool active;

  const PhoneModelEntry({
    required this.brand,
    required this.model,
    required this.deviceType,
    required this.active,
  });
}

class ModelService {
  final FirebaseFirestore _firestore;

  ModelService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<PhoneModelEntry>> streamPhoneModels() {
    return _firestore.collection('phone_models').snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        final brand = (data['brand'] ?? '').toString().trim();
        final model = (data['model'] ?? '').toString().trim();
        final deviceType = (data['deviceType'] ?? '').toString().trim();
        final v = data['active'];
        final active = (v is bool) ? v : true;
        return PhoneModelEntry(
          brand: brand,
          model: model,
          deviceType: deviceType,
          active: active,
        );
      }).toList();
    });
  }
}
