import 'package:cloud_firestore/cloud_firestore.dart';

/// Platform fee tiers for seller invoicing.
///
/// Tiers are loaded from Firestore `settings/fees` and cached in-memory.
/// Falls back to hardcoded defaults if Firestore is unavailable.
///
/// Agreed tiers (Myanmar Kyat):
///   price < 500,000  → 5,000 Ks
///   price < 5,000,000 → 10,000 Ks
///   price ≥ 5,000,000 → 15,000 Ks
class FeeService {
  FeeService._();

  // ─── Hardcoded defaults ───────────────────────────────────────────────────

  static const int _defaultTier1Max = 500000;    // 5 သိန်း
  static const int _defaultTier1Fee = 5000;       // ၅ ထောင်
  static const int _defaultTier2Max = 5000000;   // ၅၀ သိန်း
  static const int _defaultTier2Fee = 10000;     // ၁ သောင်း
  static const int _defaultTier3Fee = 15000;     // ၁ သောင်းခွဲ

  // ─── Pure calculation (uses hardcoded tiers) ──────────────────────────────

  /// Returns the platform fee for [price] using hardcoded default tiers.
  /// Use this when you already have tiers from Firestore (pass them in).
  static int calculateFee(
    double price, {
    int tier1Max = _defaultTier1Max,
    int tier1Fee = _defaultTier1Fee,
    int tier2Max = _defaultTier2Max,
    int tier2Fee = _defaultTier2Fee,
    int tier3Fee = _defaultTier3Fee,
  }) {
    if (price < tier1Max) return tier1Fee;
    if (price < tier2Max) return tier2Fee;
    return tier3Fee;
  }

  // ─── Load tiers from Firestore ────────────────────────────────────────────

  /// Loads fee tiers from `settings/fees` and returns them as a map.
  /// Returns defaults if Firestore read fails.
  static Future<Map<String, int>> loadTiers() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('fees')
          .get();
      final data = doc.data() ?? {};

      return {
        'tier1Max': _parseInt(data['tier1Max'], _defaultTier1Max),
        'tier1Fee': _parseInt(data['tier1Fee'], _defaultTier1Fee),
        'tier2Max': _parseInt(data['tier2Max'], _defaultTier2Max),
        'tier2Fee': _parseInt(data['tier2Fee'], _defaultTier2Fee),
        'tier3Fee': _parseInt(data['tier3Fee'], _defaultTier3Fee),
      };
    } catch (_) {
      return {
        'tier1Max': _defaultTier1Max,
        'tier1Fee': _defaultTier1Fee,
        'tier2Max': _defaultTier2Max,
        'tier2Fee': _defaultTier2Fee,
        'tier3Fee': _defaultTier3Fee,
      };
    }
  }

  /// Calculates fee by loading tiers from Firestore first.
  /// Convenient one-shot call for display purposes (not for transactions).
  static Future<int> calculateFeeAsync(double price) async {
    final tiers = await loadTiers();
    return calculateFee(
      price,
      tier1Max: tiers['tier1Max']!,
      tier1Fee: tiers['tier1Fee']!,
      tier2Max: tiers['tier2Max']!,
      tier2Fee: tiers['tier2Fee']!,
      tier3Fee: tiers['tier3Fee']!,
    );
  }

  // ─── Save tiers to Firestore (Admin) ──────────────────────────────────────

  static Future<void> saveTiers({
    required int tier1Max,
    required int tier1Fee,
    required int tier2Max,
    required int tier2Fee,
    required int tier3Fee,
  }) async {
    await FirebaseFirestore.instance
        .collection('settings')
        .doc('fees')
        .set({
      'tier1Max': tier1Max,
      'tier1Fee': tier1Fee,
      'tier2Max': tier2Max,
      'tier2Fee': tier2Fee,
      'tier3Fee': tier3Fee,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Human-readable label ─────────────────────────────────────────────────

  /// Returns a display string for a fee, e.g. "5,000 Ks"
  static String formatFee(int fee) {
    return '${fee.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} Ks';
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static int _parseInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? fallback;
  }
}
