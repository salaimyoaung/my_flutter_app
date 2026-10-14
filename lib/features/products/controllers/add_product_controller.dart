import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/device_types.dart';
import '../../../core/constants/imei_status.dart';
import '../../../core/services/imei_service.dart';
import '../../../core/utils/condition_utils.dart';
import '../../../core/utils/imei_validator.dart';
import '../../../data/models/add_product_form_data.dart';
import '../../../data/services/product_service.dart';
import '../../../data/services/storage_service.dart';

class AddProductController {
  final ProductService productService;
  final StorageService storageService;
  final FirebaseFirestore firestore;

  AddProductController({
    required this.productService,
    required this.storageService,
    required this.firestore,
  });

  String? validate(AddProductFormData data) {
    if (data.images.isEmpty) return "ပုံရွေးပေးပါ";
    if (data.price.trim().isEmpty) return "ဈေးနှုန်း ထည့်ပါ";
    if (data.phone.trim().isEmpty) return "ဖုန်းနံပါတ် ထည့်ပါ";

    // IMEI is optional — but if provided, format + photo are required
    final imei = data.imei.trim();
    if (imei.isNotEmpty) {
      if (!RegExp(r'^\d{15}$').hasMatch(imei)) return "IMEI 15 digits ဖြစ်ရမည်";
      if (!ImeiValidator.isValid(imei)) return "IMEI မမှန်ကန်ပါ (Luhn check fail)";
      if (data.imeiPhoto == null) return "IMEI ထည့်ပါက Live Photo မဖြစ်မနေ ရိုက်ရမည်";
    }

    final isUsed = isUsedCondition(data.condition);

    if (data.brand.trim().isEmpty) return "Brand ထည့်ပါ";
    if (data.model.trim().isEmpty) return "Model ထည့်ပါ";

    final isApple = data.deviceType == DeviceTypes.iphone || data.deviceType == DeviceTypes.ipad;

    // ✅ Centralized validation from UI
    if (isApple && data.modelNumber.trim().isEmpty) {
      return "Model Number ထည့်ပါ";
    }
    if (!isApple && data.version == null) {
      return "Version ရွေးပါ";
    }
    if (!isApple && data.rom == null) {
      return "ROM ရွေးပါ";
    }

    // Apple device မှာ RAM field မပြ — RAM check ကို Android မှသာ လုပ်
    if (!isApple && data.ram == null) return "RAM ရွေးပါ";
    if (data.storage == null) return "Storage ရွေးပါ";

    if (isApple && isUsed && !data.batteryUnverifiable) {
      if (data.batteryPercent == null) return "Battery Health (%) ရွေးပါ (70–100)\nစစ်မရပါက checkbox ကို အမှတ်ခြစ်ပါ";
    }

    if (data.warrantyDays == null) return "Warranty ရွေးပါ";

    return null;
  }

  Future<String?> submit({
    required String sellerId,
    required String sellerName,
    required AddProductFormData data,
  }) async {
    final imei = data.imei.trim();
    final hasImei = imei.isNotEmpty;
    final imeiMasked = hasImei ? ImeiService.mask(imei) : '';

    // ── Fetch seller doc: banned check + city ────────────────────────────
    String sellerCity = '';
    try {
      final userSnap = await firestore.collection('users').doc(sellerId).get();
      final userData = userSnap.data() ?? {};
      if (userData['isBanned'] == true) {
        return "အကောင့် ပိတ်ထားသောကြောင့် ပစ္စည်းတင်၍ မရပါ";
      }
      sellerCity = (userData['shopCity'] ?? '').toString().trim();
    } catch (_) {}

    List<String> imageUrls = [];
    String imeiPhotoUrl = '';

    try {
      /// 🔥 STEP 1: IMAGE UPLOAD (Before document creation)
      try {
        imageUrls = await storageService.uploadProductImages(
          uid: sellerId,
          files: data.images,
        );
      } catch (e) {
        debugLog('Image upload failed: $e');
        return "ပုံ upload မအောင်မြင်ပါ";
      }

      if (imageUrls.isEmpty) {
        return "ပုံ upload မအောင်မြင်ပါ";
      }

      // IMEI photo upload — only when IMEI was provided; fail hard if it fails.
      if (hasImei && data.imeiPhoto != null) {
        try {
          imeiPhotoUrl = await storageService.uploadXFile(
            file: data.imeiPhoto!,
            storagePath: 'imei_photos/$sellerId/${DateTime.now().millisecondsSinceEpoch}.jpg',
            contentType: 'image/jpeg',
          );
        } catch (e) {
          debugLog('IMEI photo upload failed: $e');
          if (imageUrls.isNotEmpty) {
            await storageService.deleteFiles(imageUrls).catchError((_) {});
          }
          return "IMEI ဓာတ်ပုံ upload မအောင်မြင်ပါ — ထပ်ကြိုးစားပါ";
        }
      }

      final productRef = firestore.collection('products').doc();
      final imeiRef = hasImei
          ? firestore.collection('imei_registry').doc(imei)
          : null;

      // Parse price once
      final priceNum = double.tryParse(
            data.price.trim().replaceAll(',', '')) ?? 0.0;
      final origPriceNum = data.originalPrice.trim().isEmpty
          ? null
          : double.tryParse(data.originalPrice.trim().replaceAll(',', ''));

      final productData = {
        'active': true,
        'name': data.model.trim(),
        'detail': data.detail.trim(),
        'price': priceNum,
        'originalPrice': origPriceNum,
        'phone': data.phone.trim(),
        'image': imageUrls.first,
        'coverImage': imageUrls.first,
        'images': imageUrls,
        if (imeiPhotoUrl.isNotEmpty) 'imeiPhoto': imeiPhotoUrl,
        if (hasImei) 'imeiMasked': imeiMasked,
        if (hasImei) 'imeiStatus': ImeiStatus.notVerified,
        'hasImei': hasImei,
        'category': 'ဖုန်း',
        'deviceType': data.deviceType,
        'brand': data.brand.trim(),
        'series': data.series.trim(),
        'model': data.model.trim(),
        'condition': data.condition,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sellerCity': sellerCity,
        'specs': {
          'ram': data.ram,
          'storage': data.storage,
          'cycleCount': data.cycleCount,
          'color': data.color.trim(),
          'batteryPercent': data.batteryPercent,
          'batteryUnverifiable': data.batteryUnverifiable,
          'warrantyDays': data.warrantyDays,
          'condition': data.condition.trim(),
          'version': data.version,
          'rom': data.rom,
          'modelNumber': data.modelNumber,
        },
        if (data.isApple) ...{
          'icloudStatus': data.icloudStatus,
          'carrierLock': data.carrierLock,
          if (data.simType != null) 'simType': data.simType,
        },
        'accessories': {
          'box': data.accBox,
          'charger': data.accCharger,
          'cable': data.accCable,
          'earphones': data.accEarphones,
          'receipt': data.accReceipt,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      /// 🔥 STEP 2: TRANSACTION (or simple set if no IMEI)
      if (hasImei) {
        await firestore.runTransaction((tx) async {
          final imeiDoc = await tx.get(imeiRef!);
          if (imeiDoc.exists) {
            final d = imeiDoc.data()!;
            final existingStatus = d['status'] as String?;
            final existingPid = (d['productId'] ?? '').toString();

            if (existingStatus != 'REJECTED' && existingPid.isNotEmpty) {
              final pSnap = await tx.get(firestore.collection('products').doc(existingPid));
              if (pSnap.exists) {
                final pData = pSnap.data()!;
                final isActive = pData['active'] == true;
                final isSold = pData['soldAt'] != null;

                if (isActive && !isSold) {
                  throw Exception("ဒီ IMEI နဲ့ ဖုန်းရှိပြီးသားပါ (Listing #${existingPid.substring(0, 5)})");
                }
              }
            }
          }

          tx.set(productRef, productData);

          final imeiData = {
            'imeiFull': imei,
            'imeiMasked': imeiMasked,
            'slot': 1,
            'productId': productRef.id,
            'sellerId': sellerId,
            'sellerName': sellerName,
            'brand': data.brand.trim(),
            'model': data.model.trim(),
            'deviceType': data.deviceType,
            'condition': data.condition,
            'status': ImeiStatus.notVerified,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          tx.set(imeiRef, imeiData);
        });
      } else {
        await productRef.set(productData);
      }

      return null;
    } catch (e) {
      final toDelete = [...imageUrls, if (imeiPhotoUrl.isNotEmpty) imeiPhotoUrl];
      if (toDelete.isNotEmpty) {
        await storageService.deleteFiles(toDelete).catchError((_) {});
      }
      return e.toString().replaceAll("Exception: ", "");
    }
  }

  void debugLog(String message) {
    if (kDebugMode) debugPrint('[AddProductController] $message');
  }
}
