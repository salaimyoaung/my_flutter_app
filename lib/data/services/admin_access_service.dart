import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAccessService {
  AdminAccessService._();
  static final AdminAccessService instance = AdminAccessService._();

  // ✅ Cache admin status — avoids repeated Firestore reads on every route
  bool? _cached;
  DateTime? _cachedAt;

  // ✅ Cache valid for 5 minutes
  static const Duration _cacheDuration = Duration(minutes: 5);

  bool get _isCacheValid =>
      _cached != null &&
          _cachedAt != null &&
          DateTime.now().difference(_cachedAt!) < _cacheDuration;

  /// Returns true if the given uid has admin role.
  /// Result is cached for [_cacheDuration] to reduce Firestore reads.
  Future<bool> isAdmin(String uid) async {
    if (_isCacheValid) return _cached!;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data();
      if (data == null) {
        _cached = false;
        _cachedAt = DateTime.now();
        return false;
      }

      // ✅ Single source of truth — role field only
      // 'isAdmin' boolean field removed: not in Firestore rules, causes dual-maintenance
      final role = (data['role'] ?? '').toString().toLowerCase().trim();
      final result = role == 'admin';

      _cached = result;
      _cachedAt = DateTime.now();
      return result;
    } catch (_) {
      // On error, don't cache — allow retry on next call
      return false;
    }
  }

  /// Clear cache — call on logout or role change
  void clear() {
    _cached = null;
    _cachedAt = null;
  }
}