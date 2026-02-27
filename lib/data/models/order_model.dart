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
  final String buyerAddress;


  final int quantity;
  final String status;

  final bool sellerAccepted;
  final bool sellerRejected;
  final String sellerRejectReason;

  final int depositAmount;
  final String depositStatus;
  final String depositCity;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

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
    required this.buyerAddress,
    required this.quantity,
    required this.status,
    required this.sellerAccepted,
    required this.sellerRejected,
    required this.sellerRejectReason,
    required this.depositAmount,
    required this.depositStatus,
    required this.depositCity,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---------- helpers ----------
  static String _s(dynamic v) => (v ?? '').toString().trim();

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  static bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    return fallback;
  }

  static Timestamp? _ts(dynamic v) {
    if (v is Timestamp) return v;
    return null;
  }

  // ---------- from Firestore ----------
  factory OrderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OrderModel.fromMap(doc.id, data);
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    return OrderModel(
      id: id,

      productId: _s(data['productId']),
      productName: _s(data['productName']),
      productPrice: _s(data['productPrice']),
      productImage: _s(data['productImage']),

      sellerId: _s(data['sellerId']),
      sellerName: _s(data['sellerName']),

      buyerId: _s(data['buyerId']),
      buyerName: _s(data['buyerName']),
      buyerPhone: _s(data['buyerPhone']),
      buyerAddress: _s(data['buyerAddress']),

      quantity: _i(data['quantity']),
      status: _s(data['status']),

      sellerAccepted: _b(data['sellerAccepted']),
      sellerRejected: _b(data['sellerRejected']),
      sellerRejectReason: _s(data['sellerRejectReason']),

      depositAmount: _i(data['depositAmount']),
      depositStatus: _s(data['depositStatus']),
      depositCity: _s(data['depositCity']),

      createdAt: _ts(data['createdAt']),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
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

      'sellerAccepted': sellerAccepted,
      'sellerRejected': sellerRejected,
      'sellerRejectReason': sellerRejectReason,

      'depositAmount': depositAmount,
      'depositStatus': depositStatus,
      'depositCity': depositCity,

      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}