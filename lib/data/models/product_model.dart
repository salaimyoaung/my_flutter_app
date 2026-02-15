import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String price;
  final String image;
  final List<String> images;
  final String coverImage;
  final String category;
  final String phone;
  final String sellerId;
  final int? ram;
  final int? storage;
  final String color;
  final int? batteryPercent;
  final int? warrantyDays;
  final String condition;
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

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    this.images = const [],
    this.coverImage = "",
    required this.category,
    required this.phone,
    required this.sellerId,
    this.ram,
    this.storage,
    this.color = "",
    this.batteryPercent,
    this.warrantyDays,
    this.condition = "",
    this.badgeRecommended = false,
    this.badgeTrusted = false,
    this.badgeCalculatedAt,
    this.badgeOverrideEnabled = false,
    this.badgeOverrideRecommended,
    this.badgeOverrideTrusted,
    this.badgeOverrideReason = "",
    this.badgeOverrideAdminId = "",
    this.badgeOverrideAdminName = "",
    this.badgeOverriddenAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();
  static List<String> _ls(dynamic v) {
    if (v is List) {
      return v
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
  static int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    return n;
  }
  static bool _b(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    final specs = (data['specs'] is Map<String, dynamic>) ? (data['specs'] as Map<String, dynamic>) : <String, dynamic>{};
    final badge = (data['badge'] is Map<String, dynamic>)
        ? (data['badge'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final adminOverride = (badge['adminOverride'] is Map<String, dynamic>)
        ? (badge['adminOverride'] as Map<String, dynamic>)
        : <String, dynamic>{};
    return Product(
      id: id,
      name: _s(data['name']),
      price: _s(data['price']),
      image: _s(data['image']),
      images: _ls(data['images']),
      coverImage: _s(data['coverImage']).isNotEmpty
          ? _s(data['coverImage'])
          : _s(data['image']),
      category: _s(data['category']),
      phone: _s(data['phone']),
      sellerId: _s(data['sellerId']),
      ram: _i(specs['ram']),
      storage: _i(specs['storage']),
      color: _s(specs['color']),
      batteryPercent: _i(specs['batteryPercent']),
      warrantyDays: _i(specs['warrantyDays']),
      condition: _s(specs['condition']).isNotEmpty
          ? _s(specs['condition'])
          : _s(data['condition']),
      badgeRecommended: _b(badge['recommended']),
      badgeTrusted: _b(badge['trusted']),
      badgeCalculatedAt: badge['calculatedAt'] is Timestamp
          ? (badge['calculatedAt'] as Timestamp)
          : null,
      badgeOverrideEnabled: _b(adminOverride['enabled']),
      badgeOverrideRecommended:
          adminOverride.containsKey('recommended') && adminOverride['recommended'] != null
              ? _b(adminOverride['recommended'])
              : null,
      badgeOverrideTrusted:
          adminOverride.containsKey('trusted') && adminOverride['trusted'] != null
              ? _b(adminOverride['trusted'])
              : null,
      badgeOverrideReason: _s(adminOverride['reason']),
      badgeOverrideAdminId: _s(adminOverride['adminId']),
      badgeOverrideAdminName: _s(adminOverride['adminName']),
      badgeOverriddenAt: adminOverride['overriddenAt'] is Timestamp
          ? (adminOverride['overriddenAt'] as Timestamp)
          : null,
    );
  }

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Product.fromFirestore(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'price': price.trim(),
      'image': image.trim(),
      'images': images.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'coverImage': coverImage.trim(),
      'category': category.trim(),
      'phone': phone.trim(),
      'sellerId': sellerId.trim(),
      'specs': {
        'ram': ram,
        'storage': storage,
        'color': color.trim(),
        'batteryPercent': batteryPercent,
        'warrantyDays': warrantyDays,
        'condition': condition.trim(),
      },
    };
  }

  bool get effectiveBadgeRecommended {
    if (badgeOverrideEnabled && badgeOverrideRecommended != null) {
      return badgeOverrideRecommended == true;
    }
    return badgeRecommended;
  }

  bool get effectiveBadgeTrusted {
    if (badgeOverrideEnabled && badgeOverrideTrusted != null) {
      return badgeOverrideTrusted == true;
    }
    return badgeTrusted;
  }

  bool get hasEffectiveBadge => effectiveBadgeRecommended || effectiveBadgeTrusted;
}
