// order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;

  final String productId;
  final String productName;
  final String productPrice;
  final String productImage;

  final String sellerId;
  final String sellerName;

  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String deliveryAddress;

  final int quantity;
  final String paymentMethod;
  final String status;

  // ✅ seller accept/reject flags
  final bool sellerAccepted;
  final bool sellerRejected;

  // ✅ optional
  final String sellerRejectReason;

  // ✅ Payment proof fields (Buyer uploads / submits)
  final String paymentTxId;
  final String paymentProofUrl;
  final String paymentProofStatus; // e.g. SUBMITTED / REVIEWING / REJECTED / APPROVED
  final Timestamp? paymentProofAt;
  final String paymentProofBy;

  // ✅ Drop stage flags/audit (stored in orders doc)
  final bool dropOtpUsed;
  final Timestamp? dropOtpCreatedAt;

  final bool deliveryLinkUsed;
  final Timestamp? deliveryLinkCreatedAt;

  // ✅ Delivered audit (stored in orders doc)
  final Timestamp? deliveredAt;
  final String deliveredBy;

  final Timestamp? createdAt;

  const OrderModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productImage,
    required this.sellerId,
    required this.sellerName,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.deliveryAddress,
    required this.quantity,
    required this.paymentMethod,
    required this.status,
    required this.sellerAccepted,
    required this.sellerRejected,
    required this.sellerRejectReason,

    // ✅ payment proof
    required this.paymentTxId,
    required this.paymentProofUrl,
    required this.paymentProofStatus,
    required this.paymentProofAt,
    required this.paymentProofBy,

    // ✅ drop stage
    required this.dropOtpUsed,
    required this.dropOtpCreatedAt,
    required this.deliveryLinkUsed,
    required this.deliveryLinkCreatedAt,

    // ✅ delivered audit
    required this.deliveredAt,
    required this.deliveredBy,

    required this.createdAt,
  });

  // ---------- helpers ----------
  static String _s(dynamic v) => (v ?? '').toString().trim();

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 1;
  }

  static bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  static Timestamp? _ts(dynamic v) {
    if (v is Timestamp) return v;
    return null;
  }

  // ---------- from Firestore Document ----------
  factory OrderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OrderModel.fromMap(doc.id, data);
  }

  // ---------- from Map ----------
  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    final bool accepted = _b(data['sellerAccepted'], fallback: false);
    final bool rejected = _b(data['sellerRejected'], fallback: false);

    return OrderModel(
      id: id,

      productId: _s(data['productId']),
      productName: _s(data['productName'] ?? data['name']),
      productPrice: _s(data['productPrice'] ?? data['price']),
      productImage: _s(data['productImage'] ?? data['image']),

      sellerId: _s(data['sellerId']),
      sellerName: _s(data['sellerName']),

      buyerId: _s(data['buyerId']),
      buyerName: _s(data['buyerName']),
      buyerPhone: _s(data['buyerPhone']),
      deliveryAddress: _s(data['deliveryAddress']),

      quantity: _i(data['quantity']),
      paymentMethod: _s(data['paymentMethod']),
      status: _s(data['status']),

      sellerAccepted: accepted,
      sellerRejected: rejected,
      sellerRejectReason: _s(data['sellerRejectReason']),

      // ✅ payment proof
      paymentTxId: _s(data['paymentTxId']),
      paymentProofUrl: _s(data['paymentProofUrl']),
      paymentProofStatus: _s(data['paymentProofStatus']),
      paymentProofAt: _ts(data['paymentProofAt']),
      paymentProofBy: _s(data['paymentProofBy']),

      // ✅ drop stage (orders doc)
      dropOtpUsed: _b(data['dropOtpUsed'], fallback: false),
      dropOtpCreatedAt: _ts(data['dropOtpCreatedAt']),

      deliveryLinkUsed: _b(data['deliveryLinkUsed'], fallback: false),
      deliveryLinkCreatedAt: _ts(data['deliveryLinkCreatedAt']),

      // ✅ delivered audit (orders doc)
      deliveredAt: _ts(data['deliveredAt']),
      deliveredBy: _s(data['deliveredBy']),

      createdAt: _ts(data['createdAt']),
    );
  }

  // (optional) if you ever need to write map again later
  Map<String, dynamic> toMap() {
    return {
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
      'status': status.trim(),

      'sellerAccepted': sellerAccepted,
      'sellerRejected': sellerRejected,
      'sellerRejectReason': sellerRejectReason.trim(),

      // ✅ payment proof
      'paymentTxId': paymentTxId.trim(),
      'paymentProofUrl': paymentProofUrl.trim(),
      'paymentProofStatus': paymentProofStatus.trim(),
      'paymentProofAt': paymentProofAt,
      'paymentProofBy': paymentProofBy.trim(),

      // ✅ drop stage
      'dropOtpUsed': dropOtpUsed,
      'dropOtpCreatedAt': dropOtpCreatedAt,
      'deliveryLinkUsed': deliveryLinkUsed,
      'deliveryLinkCreatedAt': deliveryLinkCreatedAt,

      // ✅ delivered audit
      'deliveredAt': deliveredAt,
      'deliveredBy': deliveredBy.trim(),

      'createdAt': createdAt,
    };
  }
}