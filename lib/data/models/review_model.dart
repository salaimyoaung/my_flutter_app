import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String sellerId;
  final String buyerId;
  final String buyerName;
  final String buyerProfileImage;
  final String orderId;
  final String productName;
  final int rating;        // 1–5
  final String comment;
  final Timestamp? createdAt;

  const ReviewModel({
    required this.id,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    required this.buyerProfileImage,
    required this.orderId,
    required this.productName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();
  static int    _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  factory ReviewModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ReviewModel(
      id:                 doc.id,
      sellerId:           _s(d['sellerId']),
      buyerId:            _s(d['buyerId']),
      buyerName:          _s(d['buyerName']),
      buyerProfileImage:  _s(d['buyerProfileImage']),
      orderId:            _s(d['orderId']),
      productName:        _s(d['productName']),
      rating:             _i(d['rating']),
      comment:            _s(d['comment']),
      createdAt:          d['createdAt'] is Timestamp
                              ? d['createdAt'] as Timestamp
                              : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'sellerId':          sellerId,
    'buyerId':           buyerId,
    'buyerName':         buyerName,
    'buyerProfileImage': buyerProfileImage,
    'orderId':           orderId,
    'productName':       productName,
    'rating':            rating,
    'comment':           comment,
    'createdAt':         FieldValue.serverTimestamp(),
  };
}
