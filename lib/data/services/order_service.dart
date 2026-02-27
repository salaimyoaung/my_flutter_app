// order_service.dart
// FINAL VERSION - COD + DEPOSIT ONLY (NO OTP / NO ESCROW FLOW B)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _orders =
  _db.collection('orders');

  // =========================================================
  // STATUS CONSTANTS
  // =========================================================

  static const String sDepositPending = "DEPOSIT_PENDING";
  static const String sDepositApproved = "DEPOSIT_APPROVED";
  static const String sOnTheWay = "ON_THE_WAY";
  static const String sCompleted = "COMPLETED";
  static const String sRefunded = "REFUNDED";
  static const String sCancelled = "CANCELLED";

  // =========================================================
  // CREATE ORDER (BUYER)
  // =========================================================

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
    required String buyerAddress,
    required int quantity,
    required int depositAmount,
    required String depositCity,
    required String depositTxId,
    required String depositScreenshotUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Login required");

    await _orders.add({
      // visibility
      'buyerVisible': true,
      'sellerVisible': true,

      // product
      'productId': productId,
      'productName': productName,
      'productPrice': productPrice,
      'productImage': productImage,

      // seller
      'sellerId': sellerId,
      'sellerName': sellerName,

      // buyer
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'buyerAddress': buyerAddress,


      // quantity
      'quantity': quantity,

      // deposit info
      'depositAmount': depositAmount,
      'depositCity': depositCity,
      'depositTxId': depositTxId,
      'depositScreenshotUrl': depositScreenshotUrl,
      'depositStatus': "PENDING",

      // order status
      'status': sDepositPending,

      // timestamps
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // =========================================================
  // STREAMS
  // =========================================================

  static Stream<QuerySnapshot<Map<String, dynamic>>> buyerOrdersStream(
      String buyerId) {
    return _orders
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> sellerOrdersStream(
      String sellerId) {
    return _orders
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // =========================================================
  // ADMIN APPROVE DEPOSIT
  // =========================================================

  static Future<void> adminApproveDeposit({
    required String orderId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Login required");

    await _orders.doc(orderId).update({
      'status': sDepositApproved,
      'depositStatus': "APPROVED",
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // =========================================================
  // SELLER MARK AS SHIPPED (ON THE WAY)
  // =========================================================

  static Future<void> sellerMarkShipped({
    required String orderId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Login required");

    await _orders.doc(orderId).update({
      'status': sOnTheWay,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // =========================================================
  // BUYER CONFIRM RECEIVED (COMPLETED)
  // =========================================================

  static Future<void> buyerConfirmReceived({
    required String orderId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Login required");

    await _orders.doc(orderId).update({
      'status': sCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // =========================================================
  // ADMIN REFUND DEPOSIT
  // =========================================================

  static Future<void> adminRefundDeposit({
    required String orderId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Login required");

    await _orders.doc(orderId).update({
      'status': sRefunded,
      'depositStatus': "REFUNDED",
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // =========================================================
  // BUYER CANCEL (ONLY BEFORE APPROVAL)
  // =========================================================

  static Future<void> buyerCancel({
    required String orderId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Login required");

    await _orders.doc(orderId).update({
      'status': sCancelled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }
}