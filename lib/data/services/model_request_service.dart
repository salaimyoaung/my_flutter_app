import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Status constants — no more hardcoded strings
class ModelRequestStatus {
  static const String pending = 'PENDING';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';
}

class ModelRequestService {
  final FirebaseFirestore _db;

  ModelRequestService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reqCol =>
      _db.collection('model_requests');

  CollectionReference<Map<String, dynamic>> get _modelsCol =>
      _db.collection('phone_models');

  // ─── Normalize ────────────────────────────────────────────────────────────

  // ✅ Strips special characters — consistent with ProductService.ensureModelExists()
  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\w]'), '').replaceAll(RegExp(r'\s+'), '').trim();

  // ─── Model ID ─────────────────────────────────────────────────────────────

  // ✅ Centralized — ProductService.ensureModelExists() should import this too
  String makeModelId({
    required String deviceType,
    required String brand,
    required String model,
  }) {
    return '${_norm(deviceType)}__${_norm(brand)}__${_norm(model)}';
  }

  // ─── Submit Request ───────────────────────────────────────────────────────

  Future<void> submitRequest({
    required String sellerId,
    required String sellerName,
    required String brand,
    required String model,
    required String series,
    required String deviceType,
  }) async {
    final trimmedBrand = brand.trim();
    final trimmedModel = model.trim();
    final trimmedDeviceType = deviceType.trim();

    // ✅ Duplicate check — prevent same seller submitting same model twice
    final existing = await _reqCol
        .where('sellerId', isEqualTo: sellerId)
        .where('brand', isEqualTo: trimmedBrand)
        .where('model', isEqualTo: trimmedModel)
        .where('deviceType', isEqualTo: trimmedDeviceType)
        .where('status', isEqualTo: ModelRequestStatus.pending)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('ဒီ Model အတွက် Request တင်ပြီးသားပါ။ Admin စစ်ဆေးနေဆဲဖြစ်သည်။');
    }

    await _reqCol.add({
      'sellerId': sellerId,
      'sellerName': sellerName,
      'brand': trimmedBrand,
      'model': trimmedModel,
      'series': series.trim(),
      'deviceType': trimmedDeviceType,
      'status': ModelRequestStatus.pending,
      'adminNote': '',
      'reviewedBy': '',
      'reviewedAt': null,
      'approvedModelId': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notification ကို Cloud Function trigger (onNewModelRequest) က ကိုင်တွယ်မည်
  }

  // Notification ကို Cloud Function trigger (onModelRequestStatusChanged) က ကိုင်တွယ်မည်

  // ─── Stream Pending List ──────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingRequestsStream() {
    return _reqCol
        .where('status', isEqualTo: ModelRequestStatus.pending)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── Pending Count ────────────────────────────────────────────────────────

  // ✅ Uses count() — no longer pulls all docs just to get length
  Future<int> pendingRequestCount() async {
    try {
      final agg = await _reqCol
          .where('status', isEqualTo: ModelRequestStatus.pending)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ✅ Stream version for real-time badge count
  Stream<int> pendingRequestCountStream() {
    return _reqCol
        .where('status', isEqualTo: ModelRequestStatus.pending)
        .snapshots()
        .map((snap) => snap.size)
        .handleError((_) => 0);
  }

  // ─── Approve ──────────────────────────────────────────────────────────────

  // ✅ Transaction — prevents read-then-write race condition
  Future<void> approveRequest({
    required String requestId,
    required String adminUid,
  }) async {
    final reqRef = _reqCol.doc(requestId);

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw Exception('Request not found');

      final data = reqSnap.data()!;

      // ✅ Guard — only approve PENDING requests
      if (data['status'] != ModelRequestStatus.pending) {
        throw Exception('ဒီ Request ကို ပြင်ဆင်ပြီးသားဖြစ်သည် (${data['status']})');
      }

      final brand      = (data['brand']      ?? '').toString().trim();
      final model      = (data['model']      ?? '').toString().trim();
      final series     = (data['series']     ?? '').toString().trim();
      final deviceType = (data['deviceType'] ?? '').toString().trim();

      final modelId = makeModelId(
        deviceType: deviceType,
        brand: brand,
        model: model,
      );

      tx.set(
        _modelsCol.doc(modelId),
        {
          'brand': brand,
          'model': model,
          'series': series,
          'deviceType': deviceType,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.update(reqRef, {
        'status': ModelRequestStatus.approved,
        'reviewedBy': adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'approvedModelId': modelId,
        'isSeenBySeller': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Notification ကို Cloud Function trigger က ကိုင်တွယ်မည်
  }

  // ─── Reject ───────────────────────────────────────────────────────────────

  Future<void> rejectRequest({
    required String requestId,
    required String adminUid,
    required String note,
  }) async {
    // ✅ note required — seller needs to know why it was rejected
    if (note.trim().isEmpty) {
      throw Exception('Reject reason ထည့်ပါ');
    }

    final reqRef = _reqCol.doc(requestId);
    final reqSnap = await reqRef.get();

    if (!reqSnap.exists) throw Exception('Request not found');

    // ✅ Guard — only reject PENDING requests
    final data   = reqSnap.data()!;
    final status = data['status'];
    if (status != ModelRequestStatus.pending) {
      throw Exception('ဒီ Request ကို ပြင်ဆင်ပြီးသားဖြစ်သည် ($status)');
    }

    await reqRef.update({
      'status': ModelRequestStatus.rejected,
      'adminNote': note.trim(),
      'reviewedBy': adminUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'isSeenBySeller': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notification ကို Cloud Function trigger က ကိုင်တွယ်မည်
  }

  // ─── Edit (PENDING only) ──────────────────────────────────────────────────

  Future<void> editRequest({
    required String requestId,
    required String brand,
    required String model,
    required String series,
    required String deviceType,
  }) async {
    final reqRef = _reqCol.doc(requestId);
    final reqSnap = await reqRef.get();

    if (!reqSnap.exists) throw Exception('Request not found');

    // ✅ Guard — only edit PENDING requests
    final status = reqSnap.data()?['status'];
    if (status != ModelRequestStatus.pending) {
      throw Exception('PENDING request များသာ ပြင်နိုင်သည် ($status)');
    }

    await reqRef.update({
      'brand': brand.trim(),
      'model': model.trim(),
      'series': series.trim(),
      'deviceType': deviceType.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Edit + Approve ───────────────────────────────────────────────────────

  // ✅ Transaction — atomic edit + approve
  Future<void> editAndApprove({
    required String requestId,
    required String adminUid,
    required String brand,
    required String model,
    required String series,
    required String deviceType,
  }) async {
    final reqRef = _reqCol.doc(requestId);

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw Exception('Request not found');

      final data   = reqSnap.data()!;
      final status = data['status'];
      if (status != ModelRequestStatus.pending) {
        throw Exception('PENDING request များသာ approve နိုင်သည် ($status)');
      }

      final modelId = makeModelId(
        deviceType: deviceType.trim(),
        brand: brand.trim(),
        model: model.trim(),
      );

      tx.set(
        _modelsCol.doc(modelId),
        {
          'brand': brand.trim(),
          'model': model.trim(),
          'series': series.trim(),
          'deviceType': deviceType.trim(),
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.update(reqRef, {
        'brand': brand.trim(),
        'model': model.trim(),
        'series': series.trim(),
        'deviceType': deviceType.trim(),
        'status': ModelRequestStatus.approved,
        'reviewedBy': adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'approvedModelId': modelId,
        'isSeenBySeller': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Notification ကို Cloud Function trigger က ကိုင်တွယ်မည်
  }
}