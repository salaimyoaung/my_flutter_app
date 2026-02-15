// order_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class OrderService {
  static final _db = FirebaseFirestore.instance;
  static final _orders = _db.collection('orders');

  // -------------------------
  // Status constants (Flow B)
  // -------------------------
  static const String sPaymentPending = 'PAYMENT_PENDING';
  static const String sPaymentApproved = 'PAYMENT_APPROVED';

  static const String sPickupOtpSent = 'PICKUP_OTP_SENT';
  static const String sPickupConfirmed = 'PICKUP_CONFIRMED';

  // ✅ Drop flow (Phase 1A: admin prepare-drop)
  static const String sDeliveryOtpSent = 'DELIVERY_OTP_SENT';
  static const String sDelivered = 'DELIVERED';

  static const String sCancelled = 'CANCELLED';

  // Payment proof status
  static const String pSubmitted = 'SUBMITTED';

  // -------------------------
  // Streams
  // -------------------------
  static Stream<QuerySnapshot<Map<String, dynamic>>> sellerOrdersStream(
      String sellerId,
      ) {
    return _orders.where('sellerId', isEqualTo: sellerId).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> buyerOrdersStream(
      String buyerId,
      ) {
    return _orders.where('buyerId', isEqualTo: buyerId).snapshots();
  }

  // =========================================================
  // Helpers (OTP + hashing)
  // =========================================================
  static String _genOtp6() {
    final r = Random.secure();
    final n = 100000 + r.nextInt(900000);
    return n.toString();
  }

  static String _genToken({int bytes = 24}) {
    final r = Random.secure();
    final b = List<int>.generate(bytes, (_) => r.nextInt(256));
    // base64url without padding
    return base64UrlEncode(b).replaceAll('=', '');
  }

  static String _genSalt({int bytes = 12}) {
    final r = Random.secure();
    final b = List<int>.generate(bytes, (_) => r.nextInt(256));
    return base64UrlEncode(b).replaceAll('=', '');
  }

  static String _sha256Hex(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // ✅ buyer plaintext secret doc (fixed id = drop)
  static DocumentReference<Map<String, dynamic>> _buyerSecretRef(String orderId) {
    return _orders.doc(orderId).collection('buyer_secrets').doc('drop');
  }

  // -------------------------
  // Create Order (Buyer pays -> PAYMENT_PENDING)
  // -------------------------
  static Future<void> createOrder({
    required String productId,
    required String productName,
    required String productPrice,
    required String productImage,
    required String sellerId,
    required String sellerName,
    required String buyerId,
    required String buyerName,
    required String buyerPhone,
    required String deliveryAddress,
    required int quantity,
    required String paymentMethod,

    // payment proof (optional)
    String? paymentTxId,
    String? paymentProofUrl,
    String? paymentProofStatus, // e.g. 'SUBMITTED'
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    final txId = (paymentTxId ?? '').trim();
    final proofUrl = (paymentProofUrl ?? '').trim();
    final proofStatus = (paymentProofStatus ?? '').trim();

    await _orders.add({
      // visibility flags (default)
      'sellerVisible': true,
      'buyerVisible': true,

      'productId': productId.trim(),
      'productName': productName.trim(),
      'productPrice': productPrice.trim(),
      'productImage': productImage.trim(),

      'sellerId': sellerId.trim(),
      'sellerName': sellerName.trim(),

      'buyerId': buyerId.trim(),
      'buyerName': buyerName.trim(),
      'buyerPhone': buyerPhone.trim(),
      'deliveryAddress': deliveryAddress.trim(),

      'quantity': quantity,
      'paymentMethod': paymentMethod.trim(),

      // Flow B
      'status': sPaymentPending,

      // payment proof fields
      'paymentTxId': txId,
      'paymentProofUrl': proofUrl,
      'paymentProofStatus': proofStatus,
      'paymentProofAt': (txId.isNotEmpty || proofUrl.isNotEmpty)
          ? FieldValue.serverTimestamp()
          : null,
      'paymentProofBy': (txId.isNotEmpty || proofUrl.isNotEmpty) ? uid : '',

      // payment approval fields
      'paymentApproved': false,
      'paymentApprovedAt': null,
      'paymentApprovedBy': '',

      // seller acceptance flags
      'sellerAccepted': false,
      'sellerAcceptedAt': null,
      'sellerRejected': false,
      'sellerRejectedAt': null,

      // reject reason fields
      'sellerRejectReason': '',
      'sellerRejectReasonAt': null,

      // pickup otp fields
      'pickupOtp': '',
      'pickupOtpAt': null,
      'pickupOtpSentBy': '',
      'pickupConfirmedAt': null,
      'pickupConfirmedBy': '',
      'pickupOtpUsed': false,
      'pickupOtpUsedAt': null,

      // ✅ Drop stage (SECURE: hash-only in orders doc)
      'dropOtpHash': '',
      'dropOtpSalt': '',
      'dropOtpCreatedAt': null,
      'dropOtpUsed': false,
      'dropOtpUsedAt': null,

      'deliveryLinkTokenHash': '',
      'deliveryLinkCreatedAt': null,
      'deliveryLinkUsed': false,
      'deliveryLinkUsedAt': null,

      // delivered audit (Phase 2 later)
      'deliveredAt': null,
      'deliveredBy': '',

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // =========================================================
  // Buyer submit payment proof (Rules-friendly)
  // =========================================================
  static Future<void> buyerSubmitPaymentProof({
    required String orderId,
    required String paymentTxId,
    required String paymentProofUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    final txId = paymentTxId.trim();
    final url = paymentProofUrl.trim();

    if (txId.length < 4 || txId.length > 120) {
      throw Exception("Transaction ID length must be 4..120");
    }
    if (url.length < 10) {
      throw Exception("Proof URL invalid");
    }

    await _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception("Order not found");

      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final status = (data['status'] ?? '').toString().trim().toUpperCase();

      final buyerId = (data['buyerId'] ?? '').toString().trim();
      if (buyerId != uid) throw Exception("Not your order");

      if (status != sPaymentPending) {
        throw Exception("Payment proof only allowed at PAYMENT_PENDING (status=$status)");
      }

      tx.set(
        ref,
        {
          'paymentTxId': txId,
          'paymentProofUrl': url,
          'paymentProofAt': FieldValue.serverTimestamp(),
          'paymentProofBy': uid,
          'paymentProofStatus': pSubmitted,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
  }

  // -------------------------
  // Buyer cancel (PAYMENT_PENDING only)
  // -------------------------
  static Future<void> buyerCancelOrder({required String orderId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    await _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception("Order not found");

      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final status = (data['status'] ?? '').toString().trim().toUpperCase();

      if (status != sPaymentPending) {
        throw Exception("Only PAYMENT_PENDING order can be cancelled (status=$status)");
      }

      tx.set(
        ref,
        {
          'status': sCancelled,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
  }

  // -------------------------
  // COD MVP: Cloud Function callables
  // -------------------------
  static Future<void> adminApproveDepositR({
    required String orderId,
    required bool approved,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('adminApproveDeposit');
    await callable.call({'orderId': orderId, 'approved': approved});
  }

  static Future<void> sellerMarkShippedR({
    required String orderId,
    required String deliveryService,
    String? deliveryNote,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('sellerMarkShipped');
    await callable.call({
      'orderId': orderId,
      'deliveryService': deliveryService,
      'deliveryNote': (deliveryNote ?? '').toString(),
    });
  }

  static Future<void> buyerConfirmReceivedR({
    required String orderId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('buyerConfirmReceived');
    await callable.call({'orderId': orderId});
  }
  // -------------------------
  // Admin approve payment
  // PAYMENT_PENDING -> PAYMENT_APPROVED
  // -------------------------
  static Future<void> adminApprovePayment({required String orderId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    await _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception("Order not found");

      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final status = (data['status'] ?? '').toString().trim().toUpperCase();

      if (status != sPaymentPending) {
        throw Exception("Approve only allowed at PAYMENT_PENDING (status=$status)");
      }

      tx.set(
        ref,
        {
          'status': sPaymentApproved,
          'paymentApproved': true,
          'paymentApprovedAt': FieldValue.serverTimestamp(),
          'paymentApprovedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
  }

  // -------------------------
  // Admin-only generic status update (optional)
  // -------------------------
  static Future<void> adminUpdateStatus({
    required String orderId,
    required String newStatus,
    Map<String, dynamic>? extra,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    await _orders.doc(orderId).set(
      {
        'status': newStatus.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
        if (extra != null) ...extra,
      },
      SetOptions(merge: true),
    );
  }

  // =========================================================
  // Seller Accept
  // PAYMENT_APPROVED -> PICKUP_OTP_SENT
  // =========================================================
  static Future<void> sellerAccept({required String orderId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    await _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception("Order not found");

      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final status = (data['status'] ?? '').toString().trim().toUpperCase();

      final sellerAccepted = (data['sellerAccepted'] == true);
      final sellerRejected = (data['sellerRejected'] == true);

      if (status != sPaymentApproved) {
        throw Exception("Only PAYMENT_APPROVED order can be accepted (status=$status)");
      }
      if (sellerAccepted) throw Exception("Already accepted");
      if (sellerRejected) throw Exception("Already rejected");

      final existingOtp = (data['pickupOtp'] ?? '').toString().trim();
      final otp = existingOtp.isNotEmpty ? existingOtp : _genOtp6();

      tx.set(
        ref,
        {
          'status': sPickupOtpSent,

          'sellerAccepted': true,
          'sellerAcceptedAt': FieldValue.serverTimestamp(),
          'sellerRejected': false,
          'sellerRejectedAt': null,

          'sellerRejectReason': '',
          'sellerRejectReasonAt': null,

          'pickupOtp': otp,
          'pickupOtpAt': FieldValue.serverTimestamp(),
          'pickupOtpSentBy': uid,

          'sellerVisible': true,

          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
  }

  // =========================================================
  // Seller Reject (PAYMENT_APPROVED only) - status unchanged
  // =========================================================
  static Future<void> sellerReject({
    required String orderId,
    required String reason,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    final r = reason.trim();
    if (r.length < 3) throw Exception("Reason too short (min 3 chars)");
    if (r.length > 200) throw Exception("Reason too long (max 200 chars)");

    await _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception("Order not found");

      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final status = (data['status'] ?? '').toString().trim().toUpperCase();

      final sellerAccepted = (data['sellerAccepted'] == true);
      final sellerRejected = (data['sellerRejected'] == true);

      if (status != sPaymentApproved) {
        throw Exception("Only PAYMENT_APPROVED order can be rejected (status=$status)");
      }
      if (sellerRejected) throw Exception("Already rejected");
      if (sellerAccepted) throw Exception("Already accepted");

      tx.set(
        ref,
        {
          'sellerRejected': true,
          'sellerRejectedAt': FieldValue.serverTimestamp(),

          'sellerAccepted': false,
          'sellerAcceptedAt': null,

          'sellerRejectReason': r,
          'sellerRejectReasonAt': FieldValue.serverTimestamp(),

          'sellerVisible': true,

          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
  }

  // =========================================================
  // Pickup OTP Verify (Seller enters OTP)
  // PICKUP_OTP_SENT -> PICKUP_CONFIRMED
  // =========================================================
  static Future<void> verifyPickupOtp({
    required String orderId,
    required String inputOtp,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    final input = inputOtp.trim();
    if (input.isEmpty) throw Exception("OTP required");

    await _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception("Order not found");

      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final status = (data['status'] ?? '').toString().trim().toUpperCase();

      if (status != sPickupOtpSent) {
        throw Exception("OTP verify not allowed at status=$status");
      }

      final realOtp = (data['pickupOtp'] ?? '').toString().trim();
      if (realOtp.isEmpty) throw Exception("Pickup OTP missing");
      if (realOtp != input) throw Exception("OTP မမှန်ပါ");

      tx.set(
        ref,
        {
          'status': sPickupConfirmed,

          'pickupConfirmedAt': FieldValue.serverTimestamp(),
          'pickupConfirmedBy': uid,

          'pickupOtpUsed': true,
          'pickupOtpUsedAt': FieldValue.serverTimestamp(),

          // clear otp
          'pickupOtp': '',

          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
  }

  // =========================================================
  // ✅ Admin Prepare Drop (SECURE)
  // PICKUP_CONFIRMED -> DELIVERY_OTP_SENT
  //
  // - dropOtp plaintext -> /orders/{orderId}/buyer_secrets/drop
  // - orders doc -> hash-only (dropOtpHash, salt, tokenHash)
  // - returns RAW token (admin will send link)
  // =========================================================
  static Future<String> adminPrepareDrop({required String orderId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception("Login required");

    final dropOtp = _genOtp6(); // buyer-only secret
    final salt = _genSalt();

    // ✅ IMPORTANT: keep same hashing scheme with Cloud Function later
    // dropOtpHash = sha256("$otp|$salt")
    final dropOtpHash = _sha256Hex("$dropOtp|$salt");

    final token = _genToken(bytes: 24); // delivery link token (raw)
    final tokenHash = _sha256Hex("tok:$token");

    await _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception("Order not found");

      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final status = (data['status'] ?? '').toString().trim().toUpperCase();

      if (status != sPickupConfirmed) {
        throw Exception("Prepare drop only allowed at PICKUP_CONFIRMED (status=$status)");
      }

      // prevent re-generate
      final existTok = (data['deliveryLinkTokenHash'] ?? '').toString().trim();
      if (existTok.isNotEmpty) throw Exception("Already prepared (token exists)");

      // 1) order doc: hash-only
      tx.set(
        ref,
        {
          'status': sDeliveryOtpSent,

          'dropOtpHash': dropOtpHash,
          'dropOtpSalt': salt,
          'dropOtpCreatedAt': FieldValue.serverTimestamp(),
          'dropOtpUsed': false,
          'dropOtpUsedAt': null,

          'deliveryLinkTokenHash': tokenHash,
          'deliveryLinkCreatedAt': FieldValue.serverTimestamp(),
          'deliveryLinkUsed': false,
          'deliveryLinkUsedAt': null,

          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );

      // 2) buyer secret doc: plaintext OTP (buyer-only read via rules)
      final secretRef = _buyerSecretRef(orderId);
      tx.set(
        secretRef,
        {
          'dropOtp': dropOtp,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
        },
        SetOptions(merge: true),
      );
    });

    return token;
  }

// =========================================================
// ✅ Delivery verify step (NO client implementation here)
// - For "delivery web link without login", do it via Cloud Function (Admin SDK)
// - Function will check:
//    tokenHash == sha256("tok:$token")
//    dropOtpHash == sha256("$otp|$salt")
//   then mark delivered + used flags
// =========================================================
}
