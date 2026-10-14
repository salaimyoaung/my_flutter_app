import 'package:cloud_firestore/cloud_firestore.dart';

class ModelRequestModel {
  final String id;
  final String sellerId;
  final String sellerName;
  final String brand;
  final String model;
  final String series;
  final String deviceType;
  final String status;
  final String adminNote;
  final String reviewedBy;
  final Timestamp? reviewedAt;
  final String approvedModelId;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const ModelRequestModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.brand,
    required this.model,
    required this.series,
    required this.deviceType,
    required this.status,
    required this.adminNote,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.approvedModelId,
    required this.createdAt,
    required this.updatedAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  factory ModelRequestModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final d = doc.data() ?? {};
    return ModelRequestModel(
      id: doc.id,
      sellerId: _s(d['sellerId']),
      sellerName: _s(d['sellerName']),
      brand: _s(d['brand']),
      model: _s(d['model']),
      series: _s(d['series']),
      deviceType: _s(d['deviceType']),
      status: _s(d['status']),
      adminNote: _s(d['adminNote']),
      reviewedBy: _s(d['reviewedBy']),
      reviewedAt: d['reviewedAt'] is Timestamp ? d['reviewedAt'] as Timestamp : null,
      approvedModelId: _s(d['approvedModelId']),
      createdAt: d['createdAt'] is Timestamp ? d['createdAt'] as Timestamp : null,
      updatedAt: d['updatedAt'] is Timestamp ? d['updatedAt'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'sellerName': sellerName,
      'brand': brand,
      'model': model,
      'series': series,
      'deviceType': deviceType,
      'status': status,
      'adminNote': adminNote,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt,
      'approvedModelId': approvedModelId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}