import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAccessService {
  AdminAccessService._();

  static final AdminAccessService instance = AdminAccessService._();

  final Map<String, bool> _cache = {};

  Future<bool> isAdmin(String uid) async {
    final key = uid.trim();
    if (key.isEmpty) return false;
    if (_cache.containsKey(key)) return _cache[key] == true;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(key).get();
    final data = doc.data() ?? <String, dynamic>{};
    final role = (data['role'] ?? '').toString().toLowerCase().trim();
    final isAdmin = data['isAdmin'] == true || role == 'admin';
    _cache[key] = isAdmin;
    return isAdmin;
  }

  void clear() {
    _cache.clear();
  }
}
