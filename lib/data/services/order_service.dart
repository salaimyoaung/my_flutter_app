// order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/services/fee_service.dart';

class OrderService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _orders =
      _db.collection('orders');

  // ─── Status Constants ──────────────────────────────────────────────────────
  static const String sDepositPending = 'DEPOSIT_PENDING';
  static const String sDepositApproved = 'DEPOSIT_APPROVED';
  static const String sOnTheWay = 'ON_THE_WAY';
  static const String sFeePending = 'FEE_PENDING';
  static const String sCompleted = 'COMPLETED';
  static const String sRefunded = 'REFUNDED';
  static const String sCancelled = 'CANCELLED';
  static const String sRejected = 'REJECTED';
  static const String sSellerRejected = 'SELLER_REJECTED';
  static const String sReturnPending = 'RETURN_PENDING';
  static const String sReturnRejected = 'RETURN_REJECTED';
  static const String sReturnClaimed = 'RETURN_CLAIMED';

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _uid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Login required');
    return uid;
  }

  // ─── Create Order (Buyer) ─────────────────────────────────────────────────

  static Future<String> createOrder({
    required String productId,
    required String productName,
    required String productBrand,
    required String productSeries,
    required double productPrice,
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
    required String refundBankName,
    required String refundAccountNo,
    required String refundAccountName,
    required String imeiFull,
    required String imeiPhoto,
  }) async {
    final uid = _uid();
    String orderId = '';

    await _db.runTransaction((tx) async {
      final productRef = _db.collection('products').doc(productId);
      final productSnap = await tx.get(productRef);

      if (!productSnap.exists) throw Exception('Product not found');

      final pData = productSnap.data()!;
      if (pData['active'] != true || pData['hasActiveOrder'] == true) {
        throw Exception('ဤပစ္စည်းသည် ရောင်းထွက်သွားပြီ သို့မဟုတ် ဝယ်ယူသူရှိနေပါသည်');
      }

      final newOrderRef = _orders.doc();
      orderId = newOrderRef.id;

      tx.set(newOrderRef, {
        'buyerVisible': true,
        'sellerVisible': false, // ✅ Sellers only see it after deposit approval
        'productId': productId,
        'productName': productName,
        'productBrand': productBrand,
        'productSeries': productSeries,
        'productPrice': productPrice,
        'productImage': productImage,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerPhone': buyerPhone,
        'buyerAddress': buyerAddress,
        'quantity': quantity,
        'depositAmount': depositAmount,
        'depositCity': depositCity,
        'depositTxId': depositTxId,
        'depositScreenshotUrl': depositScreenshotUrl,
        'refundBankName': refundBankName,
        'refundAccountNo': refundAccountNo,
        'refundAccountName': refundAccountName,
        'imeiFull': imeiFull,
        'imeiPhoto': imeiPhoto,
        'depositStatus': 'PENDING',
        'status': sDepositPending,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      // ✅ Lock product immediately to prevent duplicate deposits
      tx.update(productRef, {
        'hasActiveOrder': true,
        'active': false,
        'activeOrderId': orderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return orderId;
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  static const int _ordersPageSize = 50;

  static Stream<QuerySnapshot<Map<String, dynamic>>> buyerOrdersStream(
    String buyerId, {
    int limit = _ordersPageSize,
  }) {
    return _orders
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> sellerOrdersStream(
    String sellerId, {
    int limit = _ordersPageSize,
  }) {
    return _orders
        .where('sellerId', isEqualTo: sellerId)
        .where('sellerVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ─── Admin Approve Deposit ────────────────────────────────────────────────

  static Future<void> adminApproveDeposit({
    required String orderId,
    Map<String, dynamic>? imeiCheckParsed,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw Exception('Order not found');

      final order = orderSnap.data()!;
      if (order['status'] != sDepositPending) {
        throw Exception(
            'ဤ Order သည် ${order['status']} ဖြစ်နေသောကြောင့် approve မလုပ်နိုင်ပါ');
      }

      final productId = (order['productId'] ?? '').toString();
      if (productId.isEmpty) throw Exception('Product ID မတွေ့ပါ');

      final productRef = _db.collection('products').doc(productId);
      final productSnap = await tx.get(productRef);

      if (!productSnap.exists) {
        tx.update(orderRef, {
          'status': sRejected,
          'depositStatus': 'REJECTED',
          'rejectReason': 'Product not found',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
        return;
      }

      final product = productSnap.data()!;
      final imeiFull = (product['imeiFull'] ?? '').toString();
      final imeiPhoto = (product['imeiPhoto'] ?? '').toString();

      tx.update(orderRef, {
        'status': sDepositApproved,
        'depositStatus': 'APPROVED',
        'sellerVisible': true,
        'approvedAt': FieldValue.serverTimestamp(),
        if (imeiFull.isNotEmpty) 'imeiFull': imeiFull,
        if (imeiPhoto.isNotEmpty) 'imeiPhoto': imeiPhoto,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      tx.update(productRef, {
        'hasActiveOrder': true,
        'active': false,
        'activeOrderId': orderId,
        'imeiStatus': 'VALID',
        if (imeiCheckParsed != null && imeiCheckParsed.isNotEmpty)
          'imeiCheckParsed': imeiCheckParsed,
      });
    });
  }

  // ─── Admin Reject Deposit ─────────────────────────────────────────────────

  static Future<void> adminRejectDeposit({
    required String orderId,
    String reason = 'Admin rejected manually',
    String? refundProofUrl,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      if (snap.data()!['status'] != sDepositPending) {
        throw Exception('DEPOSIT_PENDING order များသာ reject နိုင်သည်');
      }

      final data = snap.data()!;
      final productId = (data['productId'] ?? '').toString();

      tx.update(orderRef, {
        'status': sRejected,
        'depositStatus': 'REJECTED',
        'rejectReason': reason,
        'rejectRefundProofUrl': refundProofUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      if (productId.isNotEmpty) {
        final productRef = _db.collection('products').doc(productId);
        tx.update(productRef, {
          'hasActiveOrder': false,
          'active': true,
          'activeOrderId': null,
        });
      }
    });
  }

  // ─── Seller Mark Shipped ──────────────────────────────────────────────────

  static Future<void> sellerMarkShipped({
    required String orderId,
    required String deliveryServiceName,
    required String deliveryPhone,
    required String deliveryVoucherUrl,
    required String deliveryProductUrl,
    String? trackingCode,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      final data = snap.data()!;
      if (data['status'] != sDepositApproved) {
        throw Exception('DEPOSIT_APPROVED order များသာ ship လုပ်နိုင်သည်');
      }

      tx.update(orderRef, {
        'status': sOnTheWay,
        'deliveryServiceName': deliveryServiceName,
        'deliveryPhone': deliveryPhone,
        'deliveryVoucherUrl': deliveryVoucherUrl,
        'deliveryProductUrl': deliveryProductUrl,
        if (trackingCode != null && trackingCode.isNotEmpty)
          'trackingCode': trackingCode,
        'shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
    });
  }

  // ─── Buyer Confirm Received ───────────────────────────────────────────────

  static Future<void> buyerConfirmReceived({
    required String orderId,
    required String receivedReceiptUrl,
    required String receivedProductUrl,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);
    final tiers = await FeeService.loadTiers();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      final data = snap.data()!;
      if (data['status'] != sOnTheWay) {
        throw Exception('ON_THE_WAY order များသာ confirm လုပ်နိုင်သည်');
      }

      final productPrice = (data['productPrice'] as num?)?.toDouble() ?? 0.0;
      final fee = FeeService.calculateFee(
        productPrice,
        tier1Max: tiers['tier1Max']!,
        tier1Fee: tiers['tier1Fee']!,
        tier2Max: tiers['tier2Max']!,
        tier2Fee: tiers['tier2Fee']!,
        tier3Fee: tiers['tier3Fee']!,
      );

      tx.update(orderRef, {
        'status': sFeePending,
        'platformFee': fee,
        'receivedReceiptUrl': receivedReceiptUrl,
        'receivedProductUrl': receivedProductUrl,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
    });
  }

  // ─── Admin Refund ─────────────────────────────────────────────────────────

  static Future<void> adminRefundDeposit({
    required String orderId,
    String? depositReturnProofUrl,
    String refundedTo = 'buyer',
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      final status = snap.data()!['status'];
      final refundable = [
        sDepositPending,
        sDepositApproved,
        sCancelled,
        sReturnPending,
        sReturnClaimed,
        sSellerRejected,
      ];
      if (!refundable.contains(status)) {
        throw Exception('ဤ Order ကို refund မလုပ်နိုင်ပါ ($status)');
      }

      final refundData = snap.data()!;
      final refundProductId = (refundData['productId'] ?? '').toString();

      tx.update(orderRef, {
        'status': sRefunded,
        'depositStatus': 'REFUNDED',
        'refundedTo': refundedTo,
        'refundedAt': FieldValue.serverTimestamp(),
        'depositReturned': depositReturnProofUrl != null,
        'depositReturnProofUrl': depositReturnProofUrl ?? '',
        'depositReturnedAt':
            depositReturnProofUrl != null ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      if (refundProductId.isNotEmpty) {
        final productRef = _db.collection('products').doc(refundProductId);
        tx.update(productRef, {
          'hasActiveOrder': false,
          'active': status == sReturnPending || status == sReturnClaimed
              ? false
              : true,
          'activeOrderId': null,
        });
      }
    });
  }

  // ─── Buyer Cancel ─────────────────────────────────────────────────────────

  static Future<void> buyerCancel({
    required String orderId,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      final data = snap.data()!;
      final status = data['status'];
      final cancellable = [sDepositPending, sDepositApproved];
      if (!cancellable.contains(status)) {
        throw Exception('ဤ Order ကို cancel မလုပ်နိုင်ပါ ($status)');
      }

      final productId = (data['productId'] ?? '').toString();

      tx.update(orderRef, {
        'status': sCancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      // ✅ Unlock product if buyer cancels
      if (productId.isNotEmpty) {
        final productRef = _db.collection('products').doc(productId);
        tx.update(productRef, {
          'hasActiveOrder': false,
          'active': true,
          'activeOrderId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ─── Admin Confirm Fee Received ───────────────────────────────────────────

  static Future<void> adminConfirmFeeReceived({
    required String orderId,
    required String sellerId,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);
    final sellerRef = _db.collection('users').doc(sellerId);

    bool wasFrozen = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      if (snap.data()!['status'] != sFeePending) {
        throw Exception('FEE_PENDING order များသာ confirm လုပ်နိုင်သည်');
      }

      final sellerSnap = await tx.get(sellerRef);
      wasFrozen = sellerSnap.data()?['listingsFrozen'] == true;

      tx.update(orderRef, {
        'status': sCompleted,
        'feeConfirmed': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      final orderFee = (snap.data()!['platformFee'] as num? ?? 0).toInt();
      final currentTotal =
          (sellerSnap.data()?['pendingFee'] as num? ?? 0).toInt();
      final newTotal = (currentTotal - orderFee).clamp(0, 999999999);

      tx.update(sellerRef, {
        'pendingFee': newTotal,
        'feeDeadline': newTotal <= 0 ? null : sellerSnap.data()?['feeDeadline'],
        'listingsFrozen': newTotal <= 0 ? false : wasFrozen,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (wasFrozen) {
      final productsSnap = await _db
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .get();
      if (productsSnap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in productsSnap.docs) {
          final pData = doc.data();
          if (pData['deactivatedByFeeFreeze'] == true) {
            batch.update(doc.reference, {
              'active': true,
              'deactivatedByFeeFreeze': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        await batch.commit();
      }
    }
  }

  // ─── Buyer Request Return ────────────────────────────────────────────────

  static Future<void> buyerRequestReturn({
    required String orderId,
    required String reason,
    required List<String> returnPhotos,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await orderRef.update({
      'status': sReturnPending,
      'returnReason': reason,
      'returnPhotos': returnPhotos,
      'returnedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // ─── Seller Reject Order ────────────────────────────────────────────────
  // Called when seller cannot deliver (e.g., city too far).
  static Future<void> sellerRejectOrder({
    required String orderId,
    required String reason,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      if (snap.data()!['status'] != sDepositApproved) {
        throw Exception('Approved ဖြစ်ပြီးသား order များသာ reject နိုင်သည်');
      }

      tx.update(orderRef, {
        'status': sSellerRejected,
        'rejectReason': reason,
        'rejectedBy': 'seller',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      // Product unlock will be handled by onOrderStatusChanged Cloud Function
      // (Admin SDK) to avoid permission-denied errors for the seller.
    });
  }

  // ─── Seller Report Delivery Failed ───────────────────────────────────────

  static Future<void> sellerReportDeliveryFailed({
    required String orderId,
    required String reason,
    required String proofUrl,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await orderRef.update({
      'status': sReturnRejected,
      'returnRejectReason': '[Delivery Failed] $reason',
      'undeliverableProofUrl': proofUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // ─── Admin Reject Return for Buyer ───────────────────────────────────────

  static Future<void> adminRejectReturnForBuyer({
    required String orderId,
    required String reason,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await orderRef.update({
      'status': sReturnRejected,
      'returnRejectReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // ─── Seller Claim Return Delivery ───────────────────────────────────────

  static Future<void> sellerClaimReturnDelivery({
    required String orderId,
    required int amount,
    required String proofUrl,
    required String bankName,
    required String accountName,
    required String accountNo,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await orderRef.update({
      'status': sReturnClaimed,
      'sellerReturnClaimAmount': amount,
      'sellerReturnClaimProofUrl': proofUrl,
      'sellerClaimBankName': bankName,
      'sellerClaimAccountName': accountName,
      'sellerClaimAccountNo': accountNo,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  // ─── Admin Mark Deposit Returned ──────────────────────────────────────────

  static Future<void> adminMarkDepositReturned({
    required String orderId,
    required String depositReturnProofUrl,
  }) async {
    final uid = _uid();
    final orderRef = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      final status = snap.data()!['status'];
      if (status != sFeePending && status != sCompleted) {
        throw Exception(
            'FEE_PENDING သို့မဟုတ် COMPLETED order များသာ deposit return လုပ်နိုင်သည်');
      }

      if (snap.data()!['depositReturned'] == true) {
        throw Exception('Deposit ပြန်လွှဲပြီးသားဖြစ်သည်');
      }

      tx.update(orderRef, {
        'depositReturned': true,
        'depositReturnProofUrl': depositReturnProofUrl,
        'depositReturnedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
    });
  }
}
