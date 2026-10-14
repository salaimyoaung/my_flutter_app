import 'package:cloud_firestore/cloud_firestore.dart';

/// Order status constants — mirrors OrderService.s* values.
/// Single source of truth for UI status checks.
class OrderStatus {
  static const String depositPending = 'DEPOSIT_PENDING';
  static const String depositApproved = 'DEPOSIT_APPROVED';
  static const String onTheWay = 'ON_THE_WAY';
  static const String feePending = 'FEE_PENDING';
  static const String completed = 'COMPLETED';
  static const String refunded = 'REFUNDED';
  static const String cancelled = 'CANCELLED';
  static const String rejected = 'REJECTED';
  static const String sellerRejected = 'SELLER_REJECTED';
  static const String returnPending = 'RETURN_PENDING';
  static const String returnRejected = 'RETURN_REJECTED';
  static const String returnClaimed = 'RETURN_CLAIMED';

  // ✅ Helpers for UI
  static bool isActive(String status) =>
      status == depositPending ||
          status == depositApproved ||
          status == onTheWay ||
          status == feePending ||
          status == returnPending ||
          status == returnRejected ||
          status == returnClaimed;

  static bool isTerminal(String status) =>
      status == completed ||
          status == refunded ||
          status == cancelled ||
          status == rejected ||
          status == sellerRejected;

  // ✅ Human-readable label for display
  static String label(String status) {
    return switch (status) {
      depositPending => 'Deposit Pending',
      depositApproved => 'Deposit Approved',
      onTheWay => 'On The Way',
      feePending => 'Fee Pending',
      completed => 'Completed',
      refunded => 'Refunded',
      cancelled => 'Cancelled',
      rejected => 'Rejected',
      sellerRejected => 'Seller Rejected',
      returnPending => 'Return Pending',
      returnRejected => 'Return Rejected',
      returnClaimed => 'Return Claimed',
      _ => status,
    };
  }

  // ✅ Color hint for UI badges
  static String emoji(String status) {
    return switch (status) {
      depositPending => '💰',
      depositApproved => '✅',
      onTheWay => '🚚',
      feePending => '⏳',
      completed => '🎉',
      refunded => '↩️',
      cancelled => '❌',
      rejected => '🚫',
      sellerRejected => '🚫',
      returnPending => '🚩',
      returnRejected => '⚠️',
      returnClaimed => '📋',
      _ => '❓',
    };
  }
}

class OrderModel {
  final String id;

  // ── Product ────────────────────────────────────────────────────────────────
  final String productId;
  final String productName;
  final String productBrand;
  final String productSeries;
  // ✅ double instead of String — matches OrderService.createOrder() param type
  final double productPrice;
  final String productImage;

  // ── Seller ─────────────────────────────────────────────────────────────────
  final String sellerId;
  final String sellerName;

  // ── Buyer ──────────────────────────────────────────────────────────────────
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String buyerAddress;

  // ── Order ──────────────────────────────────────────────────────────────────
  final int quantity;
  final String status;
  final String rejectReason;
  final String rejectedBy; // 'admin' or 'seller'

  // ── Deposit ────────────────────────────────────────────────────────────────
  final int depositAmount;
  final String depositStatus;
  final String depositCity;
  // ✅ Added — was saved in createOrder() but missing from model
  final String depositTxId;
  final String depositScreenshotUrl;

  // ── Refund Account (buyer fills at order time) ─────────────────────────────
  final String refundBankName;
  final String refundAccountNo;
  final String refundAccountName;

  // ── Delivery (filled by seller when marking shipped) ──────────────────────
  final String deliveryServiceName;
  final String deliveryPhone;
  final String deliveryVoucherUrl;
  final String deliveryProductUrl; // photo of product being shipped

  // ── Received Proof (filled by buyer when confirming receipt) ───────────────
  final String receivedReceiptUrl;   // delivery service receipt photo
  final String receivedProductUrl;   // product received photo

  // ── Reject Refund Proof (filled by admin when rejecting deposit) ───────────
  final String rejectRefundProofUrl; // optional proof that deposit was returned

  // ── IMEI ───────────────────────────────────────────────────────────────────
  final String imeiFull;
  final String imeiPhoto;

  // ── Timestamps ─────────────────────────────────────────────────────────────
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? completedAt;
  final Timestamp? approvedAt;
  // ✅ Added — saved by OrderService but missing from model
  final Timestamp? cancelledAt;
  final Timestamp? refundedAt;
  final Timestamp? shippedAt;

  final String updatedBy;

  // ── Platform Fee ───────────────────────────────────────────────────────────
  /// Fee owed by seller to admin. Set when order is COMPLETED.
  final int platformFee;

  /// Seller's name for fee payment proof.
  final String feePayerName;

  /// Screenshot URL of fee payment transfer.
  final String feeProofUrl;

  /// Actual amount transferred by seller (for admin reconciliation).
  final int feeTransferAmount;

  /// Admin confirmed fee received.
  final bool feeConfirmed;

  // ── Deposit Return ──────────────────────────────────────────────────────────
  /// Admin has returned the deposit to the buyer.
  final bool depositReturned;

  /// Screenshot URL of deposit return transfer.
  final String depositReturnProofUrl;

  /// Timestamp when deposit was returned.
  final Timestamp? depositReturnedAt;

  // ── Return Product (mismatch case) ─────────────────────────────────────────
  final String returnReason;
  final List<String> returnPhotos;
  final Timestamp? returnedAt;
  final String returnRejectReason;
  final String undeliverableProofUrl; // proof when delivery fails & returns to seller

  // ── Seller Compensation (return rejection case) ───────────────────────────
  final String sellerReturnClaimProofUrl;
  final int sellerReturnClaimAmount;
  final String sellerClaimBankName;
  final String sellerClaimAccountName;
  final String sellerClaimAccountNo;
  final String adminReturnPayProofUrl;
  final String refundedTo; // 'buyer' or 'seller'

  // ── Visibility ─────────────────────────────────────────────────────────────
  final bool buyerVisible;
  final bool sellerVisible;

  const OrderModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productBrand,
    required this.productSeries,
    required this.productPrice,
    required this.productImage,
    required this.sellerId,
    required this.sellerName,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.buyerAddress,
    required this.quantity,
    required this.status,
    required this.rejectReason,
    this.rejectedBy = '',
    required this.depositAmount,
    required this.depositStatus,
    required this.depositCity,
    required this.depositTxId,
    required this.depositScreenshotUrl,
    required this.refundBankName,
    required this.refundAccountNo,
    required this.refundAccountName,
    required this.deliveryServiceName,
    required this.deliveryPhone,
    required this.deliveryVoucherUrl,
    required this.deliveryProductUrl,
    required this.receivedReceiptUrl,
    required this.receivedProductUrl,
    required this.rejectRefundProofUrl,
    required this.imeiFull,
    required this.imeiPhoto,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.approvedAt,
    required this.cancelledAt,
    required this.refundedAt,
    required this.shippedAt,
    required this.updatedBy,
    required this.platformFee,
    required this.feePayerName,
    required this.feeProofUrl,
    required this.feeTransferAmount,
    required this.feeConfirmed,
    required this.depositReturned,
    required this.depositReturnProofUrl,
    required this.depositReturnedAt,
    required this.returnReason,
    required this.returnPhotos,
    this.returnedAt,
    this.returnRejectReason = '',
    this.undeliverableProofUrl = '',
    this.sellerReturnClaimProofUrl = '',
    this.sellerReturnClaimAmount = 0,
    this.sellerClaimBankName = '',
    this.sellerClaimAccountName = '',
    this.sellerClaimAccountNo = '',
    this.adminReturnPayProofUrl = '',
    this.refundedTo = '',
    required this.buyerVisible,
    required this.sellerVisible,
  });

  // ─── Parse Helpers ────────────────────────────────────────────────────────

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static List<String> _ls(dynamic v) {
    if (v is List) {
      return v.map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  // ✅ double parser — productPrice is stored as double
  static double _d(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }

  static bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    return fallback;
  }

  static Timestamp? _ts(dynamic v) {
    if (v is Timestamp) return v;
    return null;
  }

  // ─── Factories ────────────────────────────────────────────────────────────

  factory OrderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OrderModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    return OrderModel(
      id: id,

      productId: _s(data['productId']),
      productName: _s(data['productName']),
      productBrand: _s(data['productBrand']),
      productSeries: _s(data['productSeries']),
      productPrice: _d(data['productPrice']), // ✅ double
      productImage: _s(data['productImage']),

      sellerId: _s(data['sellerId']),
      sellerName: _s(data['sellerName']),

      buyerId: _s(data['buyerId']),
      buyerName: _s(data['buyerName']),
      buyerPhone: _s(data['buyerPhone']),
      buyerAddress: _s(data['buyerAddress']),

      quantity: _i(data['quantity']),
      status: _s(data['status']),
      rejectReason: _s(data['rejectReason']),
      rejectedBy: _s(data['rejectedBy']),

      depositAmount: _i(data['depositAmount']),
      depositStatus: _s(data['depositStatus']),
      depositCity: _s(data['depositCity']),
      depositTxId: _s(data['depositTxId']),               // ✅ added
      refundBankName: _s(data['refundBankName']),
      refundAccountNo: _s(data['refundAccountNo']),
      refundAccountName: _s(data['refundAccountName']),
      deliveryServiceName: _s(data['deliveryServiceName']),
      deliveryPhone: _s(data['deliveryPhone']),
      deliveryVoucherUrl: _s(data['deliveryVoucherUrl']),
      deliveryProductUrl: _s(data['deliveryProductUrl']),
      receivedReceiptUrl: _s(data['receivedReceiptUrl']),
      receivedProductUrl: _s(data['receivedProductUrl']),
      rejectRefundProofUrl: _s(data['rejectRefundProofUrl']),
      depositScreenshotUrl: _s(data['depositScreenshotUrl']), // ✅ added

      imeiFull: _s(data['imeiFull']),
      imeiPhoto: _s(data['imeiPhoto']),

      createdAt: _ts(data['createdAt']),
      updatedAt: _ts(data['updatedAt']),
      completedAt: _ts(data['completedAt']),
      approvedAt: _ts(data['approvedAt']),
      cancelledAt: _ts(data['cancelledAt']),   // ✅ added
      refundedAt: _ts(data['refundedAt']),     // ✅ added
      shippedAt: _ts(data['shippedAt']),       // ✅ added

      updatedBy: _s(data['updatedBy']),

      platformFee: _i(data['platformFee']),
      feePayerName: _s(data['feePayerName']),
      feeProofUrl: _s(data['feeProofUrl']),
      feeTransferAmount: _i(data['feeTransferAmount']),
      feeConfirmed: _b(data['feeConfirmed']),

      depositReturned: _b(data['depositReturned']),
      depositReturnProofUrl: _s(data['depositReturnProofUrl']),
      depositReturnedAt: _ts(data['depositReturnedAt']),

      returnReason: _s(data['returnReason']),
      returnPhotos: _ls(data['returnPhotos']),
      returnedAt: _ts(data['returnedAt']),
      returnRejectReason: _s(data['returnRejectReason']),
      undeliverableProofUrl: _s(data['undeliverableProofUrl']),

      sellerReturnClaimProofUrl: _s(data['sellerReturnClaimProofUrl']),
      sellerReturnClaimAmount: _i(data['sellerReturnClaimAmount']),
      sellerClaimBankName: _s(data['sellerClaimBankName']),
      sellerClaimAccountName: _s(data['sellerClaimAccountName']),
      sellerClaimAccountNo: _s(data['sellerClaimAccountNo']),
      adminReturnPayProofUrl: _s(data['adminReturnPayProofUrl']),
      refundedTo: _s(data['refundedTo']),

      buyerVisible: _b(data['buyerVisible'], fallback: true),
      sellerVisible: _b(data['sellerVisible'], fallback: true),
    );
  }

  // ─── toMap ────────────────────────────────────────────────────────────────

  // ✅ All fields included — was missing imeiFull, imeiPhoto, timestamps
  Map<String, dynamic> toMap() {
    return {
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
      'status': status,
      'rejectReason': rejectReason,
      'rejectedBy': rejectedBy,

      'depositAmount': depositAmount,
      'depositStatus': depositStatus,
      'depositCity': depositCity,
      'depositTxId': depositTxId,
      'refundBankName': refundBankName,
      'refundAccountNo': refundAccountNo,
      'refundAccountName': refundAccountName,
      'deliveryServiceName': deliveryServiceName,
      'deliveryPhone': deliveryPhone,
      'deliveryVoucherUrl': deliveryVoucherUrl,
      'deliveryProductUrl': deliveryProductUrl,
      'receivedReceiptUrl': receivedReceiptUrl,
      'receivedProductUrl': receivedProductUrl,
      'rejectRefundProofUrl': rejectRefundProofUrl,
      'depositScreenshotUrl': depositScreenshotUrl,

      'imeiFull': imeiFull,
      'imeiPhoto': imeiPhoto,

      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'completedAt': completedAt,
      'approvedAt': approvedAt,
      'cancelledAt': cancelledAt,
      'refundedAt': refundedAt,
      'shippedAt': shippedAt,

      'updatedBy': updatedBy,

      'platformFee': platformFee,
      'feePayerName': feePayerName,
      'feeProofUrl': feeProofUrl,
      'feeTransferAmount': feeTransferAmount,
      'feeConfirmed': feeConfirmed,

      'depositReturned': depositReturned,
      'depositReturnProofUrl': depositReturnProofUrl,
      'depositReturnedAt': depositReturnedAt,

      'returnReason': returnReason,
      'returnPhotos': returnPhotos,
      'returnedAt': returnedAt,
      'returnRejectReason': returnRejectReason,
      'undeliverableProofUrl': undeliverableProofUrl,
      'sellerReturnClaimProofUrl': sellerReturnClaimProofUrl,
      'sellerReturnClaimAmount': sellerReturnClaimAmount,
      'sellerClaimBankName': sellerClaimBankName,
      'sellerClaimAccountName': sellerClaimAccountName,
      'sellerClaimAccountNo': sellerClaimAccountNo,
      'adminReturnPayProofUrl': adminReturnPayProofUrl,
      'refundedTo': refundedTo,

      'buyerVisible': buyerVisible,
      'sellerVisible': sellerVisible,
    };
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

  // ✅ copyWith — for local state updates without re-fetching Firestore
  OrderModel copyWith({
    String? status,
    String? depositStatus,
    String? rejectReason,
    String? rejectedBy,
    String? imeiFull,
    String? imeiPhoto,
    String? deliveryServiceName,
    String? deliveryPhone,
    String? deliveryVoucherUrl,
    String? deliveryProductUrl,
    Timestamp? completedAt,
    Timestamp? approvedAt,
    Timestamp? cancelledAt,
    Timestamp? refundedAt,
    Timestamp? shippedAt,
    Timestamp? updatedAt,
    String? updatedBy,
    int? platformFee,
    String? feePayerName,
    String? feeProofUrl,
    int? feeTransferAmount,
    bool? feeConfirmed,
    bool? depositReturned,
    String? depositReturnProofUrl,
    Timestamp? depositReturnedAt,
    String? returnReason,
    List<String>? returnPhotos,
    Timestamp? returnedAt,
    String? returnRejectReason,
    String? undeliverableProofUrl,
    String? sellerReturnClaimProofUrl,
    int? sellerReturnClaimAmount,
    String? sellerClaimBankName,
    String? sellerClaimAccountName,
    String? sellerClaimAccountNo,
    String? adminReturnPayProofUrl,
    String? refundedTo,
    bool? buyerVisible,
    bool? sellerVisible,
  }) {
    return OrderModel(
      id: id,
      productId: productId,
      productName: productName,
      productBrand: productBrand,
      productSeries: productSeries,
      productPrice: productPrice,
      productImage: productImage,
      sellerId: sellerId,
      sellerName: sellerName,
      buyerId: buyerId,
      buyerName: buyerName,
      buyerPhone: buyerPhone,
      buyerAddress: buyerAddress,
      quantity: quantity,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      depositAmount: depositAmount,
      depositStatus: depositStatus ?? this.depositStatus,
      depositCity: depositCity,
      depositTxId: depositTxId,
      depositScreenshotUrl: depositScreenshotUrl,
      refundBankName: refundBankName,
      refundAccountNo: refundAccountNo,
      refundAccountName: refundAccountName,
      deliveryServiceName: deliveryServiceName ?? this.deliveryServiceName,
      deliveryPhone: deliveryPhone ?? this.deliveryPhone,
      deliveryVoucherUrl: deliveryVoucherUrl ?? this.deliveryVoucherUrl,
      deliveryProductUrl: deliveryProductUrl ?? this.deliveryProductUrl,
      receivedReceiptUrl: receivedReceiptUrl,
      receivedProductUrl: receivedProductUrl,
      rejectRefundProofUrl: rejectRefundProofUrl,
      imeiFull: imeiFull ?? this.imeiFull,
      imeiPhoto: imeiPhoto ?? this.imeiPhoto,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      refundedAt: refundedAt ?? this.refundedAt,
      shippedAt: shippedAt ?? this.shippedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      platformFee: platformFee ?? this.platformFee,
      feePayerName: feePayerName ?? this.feePayerName,
      feeProofUrl: feeProofUrl ?? this.feeProofUrl,
      feeTransferAmount: feeTransferAmount ?? this.feeTransferAmount,
      feeConfirmed: feeConfirmed ?? this.feeConfirmed,
      depositReturned: depositReturned ?? this.depositReturned,
      depositReturnProofUrl: depositReturnProofUrl ?? this.depositReturnProofUrl,
      depositReturnedAt: depositReturnedAt ?? this.depositReturnedAt,
      returnReason: returnReason ?? this.returnReason,
      returnPhotos: returnPhotos ?? this.returnPhotos,
      returnedAt: returnedAt ?? this.returnedAt,
      returnRejectReason: returnRejectReason ?? this.returnRejectReason,
      undeliverableProofUrl: undeliverableProofUrl ?? this.undeliverableProofUrl,
      sellerReturnClaimProofUrl: sellerReturnClaimProofUrl ?? this.sellerReturnClaimProofUrl,
      sellerReturnClaimAmount: sellerReturnClaimAmount ?? this.sellerReturnClaimAmount,
      sellerClaimBankName: sellerClaimBankName ?? this.sellerClaimBankName,
      sellerClaimAccountName: sellerClaimAccountName ?? this.sellerClaimAccountName,
      sellerClaimAccountNo: sellerClaimAccountNo ?? this.sellerClaimAccountNo,
      adminReturnPayProofUrl: adminReturnPayProofUrl ?? this.adminReturnPayProofUrl,
      refundedTo: refundedTo ?? this.refundedTo,
      buyerVisible: buyerVisible ?? this.buyerVisible,
      sellerVisible: sellerVisible ?? this.sellerVisible,
    );
  }

  // ─── Convenience Getters ──────────────────────────────────────────────────

  // ✅ Useful for UI — no need to import OrderStatus everywhere
  bool get isPending => status == OrderStatus.depositPending;
  bool get isApproved => status == OrderStatus.depositApproved;
  bool get isOnTheWay => status == OrderStatus.onTheWay;
  bool get isFeePending => status == OrderStatus.feePending;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCancelled => status == OrderStatus.cancelled;
  bool get isRejected => status == OrderStatus.rejected || status == OrderStatus.sellerRejected;
  bool get isSellerRejected => status == OrderStatus.sellerRejected;
  bool get isRefunded => status == OrderStatus.refunded;
  bool get isReturnPending => status == OrderStatus.returnPending;
  bool get isReturnRejected => status == OrderStatus.returnRejected;
  bool get isReturnClaimed => status == OrderStatus.returnClaimed;
  bool get isActive => OrderStatus.isActive(status);
  bool get isTerminal => OrderStatus.isTerminal(status);

  String get statusLabel => OrderStatus.label(status);
  String get statusEmoji => OrderStatus.emoji(status);

  // ✅ Formatted price for display
  String get formattedPrice =>
      '${productPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} MMK';

  @override
  String toString() => 'OrderModel(id: $id, status: $status)';
}