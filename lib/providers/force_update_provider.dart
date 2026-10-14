import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ForceUpdateState {
  final bool needsUpdate;
  final String storeUrl;
  final String message;

  ForceUpdateState({
    this.needsUpdate = false,
    this.storeUrl = '',
    this.message = '',
  });
}

final forceUpdateProvider = StreamProvider<ForceUpdateState>((ref) {
  if (kIsWeb) return Stream.value(ForceUpdateState());

  return FirebaseFirestore.instance
      .collection('settings')
      .doc('app_version')
      .snapshots()
      .asyncMap((snap) async {
    try {
      if (!snap.exists) return ForceUpdateState();

      final data = snap.data()!;
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.0.1"

      final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final minVersionKey = isAndroid ? 'android_min_version' : 'ios_min_version';
      final storeUrlKey = isAndroid ? 'android_store_url' : 'ios_store_url';

      final minVersion = (data[minVersionKey] ?? '').toString();
      if (minVersion.isEmpty) return ForceUpdateState();

      final needsUpdate = _isVersionLower(currentVersion, minVersion);
      if (!needsUpdate) return ForceUpdateState();

      return ForceUpdateState(
        needsUpdate: true,
        storeUrl: (data[storeUrlKey] ?? '').toString(),
        message: (data['force_update_message'] ?? 'App အသစ်ထွက်ပြီ။ Update လုပ်ပါ').toString(),
      );
    } catch (e) {
      debugPrint('[ForceUpdateProvider] error: $e');
      return ForceUpdateState();
    }
  });
});

bool _isVersionLower(String current, String minimum) {
  final cur = _parse(current);
  final min = _parse(minimum);
  for (int i = 0; i < 3; i++) {
    if (cur[i] < min[i]) return true;
    if (cur[i] > min[i]) return false;
  }
  return false;
}

List<int> _parse(String version) {
  final parts = version.trim().split('.').map((p) => int.tryParse(p) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.take(3).toList();
}
