import 'package:cloud_firestore/cloud_firestore.dart';

class ImeiRegistryModel {
  final String imeiFull;
  final String sellerId;
  final String productId;
  final String status;
  final String imeiPhoto;
  final String deviceCondition;
  final String brand;
  final String model;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? verifiedAt;
  final String verifiedBy;
  final String blacklistReason;
  final String notes;

  const ImeiRegistryModel({
    required this.imeiFull,
    required this.sellerId,
    required this.productId,
    required this.status,
    required this.imeiPhoto,
    required this.deviceCondition,
    required this.brand,
    required this.model,
    this.createdAt,
    this.updatedAt,
    this.verifiedAt,
    this.verifiedBy = "",
    this.blacklistReason = "",
    this.notes = "",
  });

  factory ImeiRegistryModel.fromMap(Map<String, dynamic> data) {
    return ImeiRegistryModel(
      imeiFull: (data['imeiFull'] ?? '').toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      productId: (data['productId'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      imeiPhoto: (data['imeiPhoto'] ?? '').toString(),
      deviceCondition: (data['deviceCondition'] ?? '').toString(),
      brand: (data['brand'] ?? '').toString(),
      model: (data['model'] ?? '').toString(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      verifiedAt: data['verifiedAt'] as Timestamp?,
      verifiedBy: (data['verifiedBy'] ?? '').toString(),
      blacklistReason: (data['blacklistReason'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imeiFull': imeiFull,
      'sellerId': sellerId,
      'productId': productId,
      'status': status,
      'imeiPhoto': imeiPhoto,
      'deviceCondition': deviceCondition,
      'brand': brand,
      'model': model,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'verifiedAt': verifiedAt,
      'verifiedBy': verifiedBy,
      'blacklistReason': blacklistReason,
      'notes': notes,
    };
  }
}