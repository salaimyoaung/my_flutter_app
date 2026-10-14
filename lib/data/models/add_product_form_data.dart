import 'package:image_picker/image_picker.dart';

import '../../core/constants/device_types.dart';
import '../../core/utils/condition_utils.dart'; // ✅ shared helper

class AddProductFormData {
  final String deviceType;
  final String condition;
  final String price;
  final String originalPrice;
  final String phone;
  final String imei;
  final String detail;
  final String brand;
  final String series;
  final String model;

  final int? ram;
  final int? storage;
  final String color;
  final int? batteryPercent;
  final int? cycleCount;
  final int? warrantyDays;

  final List<XFile> images;
  final XFile? imeiPhoto;

  final bool accBox;
  final bool accCharger;
  final bool accCable;
  final bool accEarphones;
  final bool accReceipt;

  final String? version;
  final String? rom;

  final String modelNumber;

  // ── Apple-only fields ───────────────────────────────────────────────────────
  final String icloudStatus;  // 'clean' | 'locked'
  final String carrierLock;   // 'unlocked' | 'locked'
  final String? simType;      // 'single' | 'dual_esim' | 'dual_nano' | 'esim_only'
  final bool batteryUnverifiable; // true = seller can't check battery %

  const AddProductFormData({
    required this.deviceType,
    required this.condition,
    required this.price,
    required this.originalPrice,
    required this.phone,
    required this.imei,
    required this.detail,
    required this.brand,
    required this.series,
    required this.model,
    required this.ram,
    required this.storage,
    required this.color,
    required this.batteryPercent,
    this.cycleCount,
    required this.warrantyDays,
    required this.images,
    this.imeiPhoto,
    required this.accBox,
    required this.accCharger,
    required this.accCable,
    required this.accEarphones,
    required this.accReceipt,
    this.version,
    this.rom,
    this.modelNumber = '',
    this.icloudStatus = 'clean',
    this.carrierLock = 'unlocked',
    this.simType,
    this.batteryUnverifiable = false,
  });

  bool get isUsed => isUsedCondition(condition);
  bool get isApple => deviceType == DeviceTypes.iphone || deviceType == DeviceTypes.ipad;

  AddProductFormData copyWith({
    String? deviceType,
    String? condition,
    String? price,
    String? originalPrice,
    String? phone,
    String? imei,
    String? detail,
    String? brand,
    String? series,
    String? model,
    int? ram,
    int? storage,
    String? color,
    int? batteryPercent,
    int? cycleCount,
    int? warrantyDays,
    List<XFile>? images,
    XFile? imeiPhoto,
    bool? accBox,
    bool? accCharger,
    bool? accCable,
    bool? accEarphones,
    bool? accReceipt,
    String? version,
    String? rom,
    String? modelNumber,
    String? icloudStatus,
    String? carrierLock,
    String? simType,
    bool? batteryUnverifiable,
  }) {
    return AddProductFormData(
      deviceType: deviceType ?? this.deviceType,
      condition: condition ?? this.condition,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      phone: phone ?? this.phone,
      imei: imei ?? this.imei,
      detail: detail ?? this.detail,
      brand: brand ?? this.brand,
      series: series ?? this.series,
      model: model ?? this.model,
      ram: ram ?? this.ram,
      storage: storage ?? this.storage,
      color: color ?? this.color,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      cycleCount: cycleCount ?? this.cycleCount,
      warrantyDays: warrantyDays ?? this.warrantyDays,
      images: images ?? this.images,
      imeiPhoto: imeiPhoto ?? this.imeiPhoto,
      accBox: accBox ?? this.accBox,
      accCharger: accCharger ?? this.accCharger,
      accCable: accCable ?? this.accCable,
      accEarphones: accEarphones ?? this.accEarphones,
      accReceipt: accReceipt ?? this.accReceipt,
      version: version ?? this.version,
      rom: rom ?? this.rom,
      modelNumber: modelNumber ?? this.modelNumber,
      icloudStatus: icloudStatus ?? this.icloudStatus,
      carrierLock: carrierLock ?? this.carrierLock,
      simType: simType ?? this.simType,
      batteryUnverifiable: batteryUnverifiable ?? this.batteryUnverifiable,
    );
  }
}
