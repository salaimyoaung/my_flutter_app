import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;

  // ── Core ───────────────────────────────────────────────────────────────────
  final String name;
  final String detail;
  // ✅ price stored as double in Firestore (consistent type)
  final double price;
  final double? originalPrice;
  final String image;
  final List<String> images;
  final String coverImage;
  final String category;
  final String phone;

  // ── Device ─────────────────────────────────────────────────────────────────
  final String deviceType;
  final String brand;   // ✅ added
  final String series;  // ✅ added
  final String model;   // ✅ added

  // ── Seller ─────────────────────────────────────────────────────────────────
  final String sellerId;
  final String sellerName; // ✅ added — avoids extra Firestore reads

  // ── Specs ──────────────────────────────────────────────────────────────────
  final int? ram;
  final int? storage;
  final int? cycleCount;
  final String color;
  final int? batteryPercent;
  final bool batteryUnverifiable;
  final int? warrantyDays;
  final String condition;
  // ✅ Nullable properly — empty string → null
  final String? version;
  final String? rom;
  final String? modelNumber;

  // ── Apple-only ──────────────────────────────────────────────────────────────
  final String icloudStatus; // 'clean' | 'locked' | ''
  final String carrierLock;  // 'unlocked' | 'locked' | ''
  final String simType;      // 'single' | 'dual_esim' | 'dual_nano' | 'esim_only' | ''

  // ── C.E.I.R. Verification (admin manual check) ───────────────────────────────
  final String ceirImeiStatus;     // '' | 'correct' | 'incorrect'
  final String ceirTaxStatus;      // '' | 'paid' | 'unpaid'
  final String ceirBlockingStatus; // '' | 'allowed' | 'blocked'
  final Timestamp? ceirCheckedAt;
  final String ceirCheckedBy;

  // ── Device / Specs Verification (admin manual check) ─────────────────────
  final String? specsVerified;       // null | 'verified' | 'mismatch'
  final Timestamp? specsVerifiedAt;
  final String specsVerifiedBy;
  final String specsMismatchNote;

  // ── Accessories ────────────────────────────────────────────────────────────
  final Map<String, dynamic> accessories;

  // ── IMEI ───────────────────────────────────────────────────────────────────
  final String imeiFull;
  final String imeiMasked;
  final String imei2Full;    // optional — dual-SIM
  final String imei2Masked;
  final String imeiPhoto;
  final String serialNumber;
  final String serialPhotoUrl;
  final String imeiRegisterStatus;
  final String imeiStatus;
  final Map<String, dynamic> imeiCheckParsed; // from imei.org API

  // ── Badge ──────────────────────────────────────────────────────────────────
  final bool badgeRecommended;
  final bool badgeTrusted;
  final Timestamp? badgeCalculatedAt;
  final bool badgeOverrideEnabled;
  final bool? badgeOverrideRecommended;
  final bool? badgeOverrideTrusted;
  final String badgeOverrideReason;
  final String badgeOverrideAdminId;
  final String badgeOverrideAdminName;
  final Timestamp? badgeOverriddenAt;

  // ── Order state ────────────────────────────────────────────────────────────
  final bool hasActiveOrder;
  final String activeOrderId;
  final Timestamp? soldAt; // set by Cloud Function when order COMPLETED

  // ── Meta ───────────────────────────────────────────────────────────────────
  final bool active;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const Product({
    required this.id,
    required this.name,
    required this.detail,
    required this.price,
    this.originalPrice,
    required this.image,
    this.images = const [],
    this.coverImage = '',
    required this.category,
    required this.phone,
    required this.deviceType,
    this.brand = '',
    this.series = '',
    this.model = '',
    required this.sellerId,
    this.sellerName = '',
    this.ram,
    this.storage,
    this.cycleCount,
    this.color = '',
    this.batteryPercent,
    this.batteryUnverifiable = false,
    this.warrantyDays,
    this.condition = '',
    this.version,
    this.rom,
    this.modelNumber,
    this.accessories = const {},
    this.icloudStatus = '',
    this.carrierLock = '',
    this.simType = '',
    this.ceirImeiStatus = '',
    this.ceirTaxStatus = '',
    this.ceirBlockingStatus = '',
    this.ceirCheckedAt,
    this.ceirCheckedBy = '',
    this.specsVerified,
    this.specsVerifiedAt,
    this.specsVerifiedBy = '',
    this.specsMismatchNote = '',
    this.imeiFull = '',
    this.imeiMasked = '',
    this.imei2Full = '',
    this.imei2Masked = '',
    this.imeiPhoto = '',
    this.serialNumber = '',
    this.serialPhotoUrl = '',
    this.imeiRegisterStatus = '',
    this.imeiStatus = '',
    this.imeiCheckParsed = const {},
    this.badgeRecommended = false,
    this.badgeTrusted = false,
    this.badgeCalculatedAt,
    this.badgeOverrideEnabled = false,
    this.badgeOverrideRecommended,
    this.badgeOverrideTrusted,
    this.badgeOverrideReason = '',
    this.badgeOverrideAdminId = '',
    this.badgeOverrideAdminName = '',
    this.badgeOverriddenAt,
    this.hasActiveOrder = false,
    this.activeOrderId = '',
    this.soldAt,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  // ─── Parse Helpers ────────────────────────────────────────────────────────

  static String _s(dynamic v) => (v ?? '').toString().trim();

  // ✅ Nullable string — empty string → null
  static String? _sn(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double _d(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return 0.0;
    // Strip commas if it was stored as string previously
    return double.tryParse(s.replaceAll(',', '')) ?? 0.0;
  }

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', ''));
  }

  static List<String> _ls(dynamic v) {
    if (v is List) {
      return v
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static int? _in(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static bool _b(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static Timestamp? _ts(dynamic v) {
    if (v is Timestamp) return v;
    return null;
  }

  // ─── Factories ────────────────────────────────────────────────────────────

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Product.fromFirestore(doc.id, doc.data() ?? {});
  }

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    final specs = data['specs'] is Map<String, dynamic>
        ? data['specs'] as Map<String, dynamic>
        : <String, dynamic>{};

    // ✅ Badge fields read from top-level (matches AddProductController save structure)
    // Legacy nested badge map also supported for backward compatibility
    final badge = data['badge'] is Map<String, dynamic>
        ? data['badge'] as Map<String, dynamic>
        : <String, dynamic>{};
    final adminOverride = badge['adminOverride'] is Map<String, dynamic>
        ? badge['adminOverride'] as Map<String, dynamic>
        : <String, dynamic>{};

    return Product(
      id: id,

      name: _s(data['name']),
      detail: _s(data['detail']),
      price: _d(data['price']),
      originalPrice: _dn(data['originalPrice']),
      image: _s(data['image']),
      images: _ls(data['images']),
      coverImage: _s(data['coverImage']).isNotEmpty
          ? _s(data['coverImage'])
          : _s(data['image']),
      category: _s(data['category']),
      phone: _s(data['phone']),

      deviceType: _s(data['deviceType']),
      brand: _s(data['brand']),     // ✅ added
      series: _s(data['series']),   // ✅ added
      model: _s(data['model']),     // ✅ added (top-level, not just in specs)

      sellerId: _s(data['sellerId']),
      sellerName: _s(data['sellerName']), // ✅ added

      ram: _in(specs['ram']),
      storage: _in(specs['storage']),
      cycleCount: _in(specs['cycleCount']),
      color: _s(specs['color']),
      batteryPercent: _in(specs['batteryPercent']),
      batteryUnverifiable: _b(specs['batteryUnverifiable']),
      warrantyDays: _in(specs['warrantyDays']),
      condition: _s(specs['condition']).isNotEmpty
          ? _s(specs['condition'])
          : _s(data['condition']),
      // ✅ Nullable properly — empty string becomes null
      version: _sn(specs['version']),
      rom: _sn(specs['rom']),
      modelNumber: _sn(specs['modelNumber']),

      accessories: data['accessories'] is Map<String, dynamic>
          ? data['accessories'] as Map<String, dynamic>
          : const {},

      icloudStatus: _s(data['icloudStatus']),
      carrierLock: _s(data['carrierLock']),
      simType: _s(data['simType']),

      ceirImeiStatus: _s(data['ceirImeiStatus']),
      ceirTaxStatus: _s(data['ceirTaxStatus']),
      ceirBlockingStatus: _s(data['ceirBlockingStatus']),
      ceirCheckedAt: _ts(data['ceirCheckedAt']),
      ceirCheckedBy: _s(data['ceirCheckedBy']),

      specsVerified: _sn(data['specsVerified']),
      specsVerifiedAt: _ts(data['specsVerifiedAt']),
      specsVerifiedBy: _s(data['specsVerifiedBy']),
      specsMismatchNote: _s(data['specsMismatchNote']),

      imeiFull: _s(data['imeiFull']),
      imeiMasked: _s(data['imeiMasked']),
      imei2Full: _s(data['imei2Full']),
      imei2Masked: _s(data['imei2Masked']),
      imeiPhoto: _s(data['imeiPhoto']),
      serialNumber: _s(data['serialNumber']),
      serialPhotoUrl: _s(data['serialPhotoUrl']),
      imeiRegisterStatus: _s(data['imeiRegisterStatus']),
      imeiStatus: _s(data['imeiStatus']),
      imeiCheckParsed: (data['imeiCheckParsed'] is Map)
          ? Map<String, dynamic>.from(data['imeiCheckParsed'] as Map)
          : const {},

      // ✅ Top-level badge fields (current save structure)
      // Falls back to nested badge map for legacy documents
      badgeRecommended: data.containsKey('badgeRecommended')
          ? _b(data['badgeRecommended'])
          : _b(badge['recommended']),
      badgeTrusted: data.containsKey('badgeTrusted')
          ? _b(data['badgeTrusted'])
          : _b(badge['trusted']),
      badgeCalculatedAt: data.containsKey('badgeCalculatedAt')
          ? _ts(data['badgeCalculatedAt'])
          : _ts(badge['calculatedAt']),
      badgeOverrideEnabled: data.containsKey('badgeOverrideEnabled')
          ? _b(data['badgeOverrideEnabled'])
          : _b(adminOverride['enabled']),
      badgeOverrideRecommended: data.containsKey('badgeOverrideRecommended')
          ? (data['badgeOverrideRecommended'] != null
          ? _b(data['badgeOverrideRecommended'])
          : null)
          : (adminOverride.containsKey('recommended')
          ? _b(adminOverride['recommended'])
          : null),
      badgeOverrideTrusted: data.containsKey('badgeOverrideTrusted')
          ? (data['badgeOverrideTrusted'] != null
          ? _b(data['badgeOverrideTrusted'])
          : null)
          : (adminOverride.containsKey('trusted')
          ? _b(adminOverride['trusted'])
          : null),
      badgeOverrideReason: _s(data['badgeOverrideReason']),
      badgeOverrideAdminId: _s(data['badgeOverrideAdminId']),
      badgeOverrideAdminName: _s(data['badgeOverrideAdminName']),
      badgeOverriddenAt: _ts(data['badgeOverriddenAt']),

      hasActiveOrder: _b(data['hasActiveOrder']),
      activeOrderId: _s(data['activeOrderId']),
      soldAt: _ts(data['soldAt']),
      active: _b(data['active']),
      createdAt: _ts(data['createdAt']),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  // ─── toMap ────────────────────────────────────────────────────────────────

  // ✅ Complete — all fields included
  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'detail': detail.trim(),
      'price': price,
      'originalPrice': originalPrice,
      'image': image.trim(),
      'images': images.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'coverImage': coverImage.trim(),
      'category': category.trim(),
      'phone': phone.trim(),

      'deviceType': deviceType,
      'brand': brand.trim(),
      'series': series.trim(),
      'model': model.trim(),

      'sellerId': sellerId.trim(),
      'sellerName': sellerName.trim(),

      'specs': {
        'ram': ram,
        'storage': storage,
        'cycleCount': cycleCount,
        'color': color.trim(),
        'batteryPercent': batteryPercent,
        'batteryUnverifiable': batteryUnverifiable,
        'warrantyDays': warrantyDays,
        'condition': condition.trim(),
        'version': version,
        'rom': rom,
        'modelNumber': modelNumber,
      },

      'accessories': accessories,

      'icloudStatus': icloudStatus,
      'carrierLock': carrierLock,
      'simType': simType,

      'ceirImeiStatus': ceirImeiStatus,
      'ceirTaxStatus': ceirTaxStatus,
      'ceirBlockingStatus': ceirBlockingStatus,
      'ceirCheckedAt': ceirCheckedAt,
      'ceirCheckedBy': ceirCheckedBy,

      'specsVerified': specsVerified,
      'specsVerifiedAt': specsVerifiedAt,
      'specsVerifiedBy': specsVerifiedBy,
      'specsMismatchNote': specsMismatchNote,

      // imeiFull / imei2Full intentionally omitted — stored in imei_registry only
      'imeiMasked': imeiMasked,
      'imei2Masked': imei2Masked,
      'imeiPhoto': imeiPhoto,
      'serialNumber': serialNumber,
      'serialPhotoUrl': serialPhotoUrl,
      'imeiRegisterStatus': imeiRegisterStatus,
      'imeiStatus': imeiStatus,
      'imeiCheckParsed': imeiCheckParsed,

      'badgeRecommended': badgeRecommended,
      'badgeTrusted': badgeTrusted,
      'badgeCalculatedAt': badgeCalculatedAt,
      'badgeOverrideEnabled': badgeOverrideEnabled,
      'badgeOverrideRecommended': badgeOverrideRecommended,
      'badgeOverrideTrusted': badgeOverrideTrusted,
      'badgeOverrideReason': badgeOverrideReason,
      'badgeOverrideAdminId': badgeOverrideAdminId,
      'badgeOverrideAdminName': badgeOverrideAdminName,
      'badgeOverriddenAt': badgeOverriddenAt,

      'hasActiveOrder': hasActiveOrder,
      'activeOrderId': activeOrderId,
      'active': active,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

  Product copyWith({
    String? name,
    String? detail,
    double? price,
    double? originalPrice,
    String? image,
    List<String>? images,
    String? coverImage,
    String? phone,
    String? brand,
    String? series,
    String? model,
    String? sellerName,
    int? ram,
    int? storage,
    int? cycleCount,
    String? color,
    int? batteryPercent,
    bool? batteryUnverifiable,
    int? warrantyDays,
    String? condition,
    String? version,
    String? rom,
    String? modelNumber,
    Map<String, dynamic>? accessories,
    String? imeiPhoto,
    String? serialNumber,
    String? serialPhotoUrl,
    String? imeiStatus,
    bool? active,
    bool? badgeRecommended,
    bool? badgeTrusted,
    bool? badgeOverrideEnabled,
    bool? badgeOverrideRecommended,
    bool? badgeOverrideTrusted,
    String? badgeOverrideReason,
    Timestamp? updatedAt,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      detail: detail ?? this.detail,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      image: image ?? this.image,
      images: images ?? this.images,
      coverImage: coverImage ?? this.coverImage,
      category: category,
      phone: phone ?? this.phone,
      deviceType: deviceType,
      brand: brand ?? this.brand,
      series: series ?? this.series,
      model: model ?? this.model,
      sellerId: sellerId,
      sellerName: sellerName ?? this.sellerName,
      ram: ram ?? this.ram,
      storage: storage ?? this.storage,
      cycleCount: cycleCount ?? this.cycleCount,
      color: color ?? this.color,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryUnverifiable: batteryUnverifiable ?? this.batteryUnverifiable,
      warrantyDays: warrantyDays ?? this.warrantyDays,
      condition: condition ?? this.condition,
      version: version ?? this.version,
      rom: rom ?? this.rom,
      modelNumber: modelNumber ?? this.modelNumber,
      accessories: accessories ?? this.accessories,
      imeiFull: imeiFull,
      imeiMasked: imeiMasked,
      imeiPhoto: imeiPhoto ?? this.imeiPhoto,
      serialNumber: serialNumber ?? this.serialNumber,
      serialPhotoUrl: serialPhotoUrl ?? this.serialPhotoUrl,
      imeiRegisterStatus: imeiRegisterStatus,
      imeiStatus: imeiStatus ?? this.imeiStatus,
      imeiCheckParsed: imeiCheckParsed,
      badgeRecommended: badgeRecommended ?? this.badgeRecommended,
      badgeTrusted: badgeTrusted ?? this.badgeTrusted,
      badgeCalculatedAt: badgeCalculatedAt,
      badgeOverrideEnabled: badgeOverrideEnabled ?? this.badgeOverrideEnabled,
      badgeOverrideRecommended:
      badgeOverrideRecommended ?? this.badgeOverrideRecommended,
      badgeOverrideTrusted: badgeOverrideTrusted ?? this.badgeOverrideTrusted,
      badgeOverrideReason: badgeOverrideReason ?? this.badgeOverrideReason,
      badgeOverrideAdminId: badgeOverrideAdminId,
      badgeOverrideAdminName: badgeOverrideAdminName,
      badgeOverriddenAt: badgeOverriddenAt,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── Convenience Getters ──────────────────────────────────────────────────

  // Price effective values
  bool get effectiveBadgeRecommended {
    if (badgeOverrideEnabled && badgeOverrideRecommended != null) {
      return badgeOverrideRecommended!;
    }
    return badgeRecommended;
  }

  bool get effectiveBadgeTrusted {
    if (badgeOverrideEnabled && badgeOverrideTrusted != null) {
      return badgeOverrideTrusted!;
    }
    return badgeTrusted;
  }

  bool get hasEffectiveBadge => effectiveBadgeRecommended || effectiveBadgeTrusted;

  double get priceDouble => price;
  double? get originalPriceDouble => originalPrice;

  // ✅ Formatted price for display
  String get formattedPrice {
    final p = price.toStringAsFixed(0);
    return '${p.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} MMK';
  }

  // ✅ Discount percentage for UI badge
  double? get discountPercent {
    final orig = originalPrice;
    if (orig == null || orig <= 0 || price >= orig) return null;
    return ((orig - price) / orig * 100).roundToDouble();
  }

  bool get isApple => deviceType == 'iphone' || deviceType == 'ipad';
  bool get isAndroid =>
      deviceType == 'android_phone' || deviceType == 'android_tablet';

  @override
  String toString() => 'Product(id: $id, name: $name, price: $price)';
}