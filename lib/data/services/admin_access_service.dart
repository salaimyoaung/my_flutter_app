import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAccessService {
  AdminAccessService._();
  static final AdminAccessService instance = AdminAccessService._();

  // Cache admin status in memory to avoid repeated reads
  bool? _isAdminCache;
  DateTime? _lastCheck;

  void clearCache() {
    _isAdminCache = null;
    _lastCheck = null;
  }

  Future<bool> isAdmin(String uid) async {
    // Return cached if valid (e.g. < 5 min old)
    if (_isAdminCache != null && _lastCheck != null) {
      if (DateTime.now().difference(_lastCheck!).inMinutes < 5) {
        return _isAdminCache!;
      }
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) {
        _isAdminCache = false;
        return false;
      }

      final role = (data['role'] ?? '').toString().toLowerCase().trim();
      final isAdminBool = data['isAdmin'] == true;
      
      final isReallyAdmin = (role == 'admin') || isAdminBool;
      
      _isAdminCache = isReallyAdmin;
      _lastCheck = DateTime.now();
      return isReallyAdmin;
    } catch (e) {
      return false;
    }
  }
}
