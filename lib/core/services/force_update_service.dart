import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';

/// Force update check — app startup မှာ Firestore မှ min_version ကို စစ်ဆေးသည်။
///
/// ⚠️  pubspec.yaml မှာ packages ထည့်ရမည်—
///   package_info_plus: ^8.0.0
///   url_launcher: ^6.3.0
///
/// Firestore setup — Firebase Console မှ manually document ဖန်တီးပါ:
///   Collection: settings
///   Document ID: app_version
///   Fields:
///     android_min_version: "1.2.0"   (String)
///     ios_min_version: "1.2.0"       (String)
///     android_store_url: "https://play.google.com/store/apps/details?id=com.sigmamoby.app"
///     ios_store_url: "https://apps.apple.com/app/idXXXXXXXXX"
///     force_update_message: "App အသစ်ထွက်ပြီ။ Update လုပ်ပါ"  (optional)
class ForceUpdateService {
  static Future<bool> checkAndShowDialogIfNeeded(BuildContext context) async {
    // Web မှာ force update မလိုအပ်
    if (kIsWeb) return false;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_version')
          .get();

      if (!snap.exists) return false;

      final data = snap.data()!;
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.1.0"

      final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final minVersionKey = isAndroid ? 'android_min_version' : 'ios_min_version';
      final storeUrlKey = isAndroid ? 'android_store_url' : 'ios_store_url';

      final minVersion = (data[minVersionKey] ?? '').toString();
      if (minVersion.isEmpty) return false;

      final needsUpdate = _isVersionLower(currentVersion, minVersion);
      if (!needsUpdate) return false;

      final storeUrl = (data[storeUrlKey] ?? '').toString();
      final message = (data['force_update_message'] ?? 'App အသစ်ထွက်ပြီ။ Update လုပ်ပါ').toString();

      if (context.mounted) {
        await _showForceUpdateDialog(
          context,
          message: message,
          storeUrl: storeUrl,
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ForceUpdate] check error: $e');
      return false; // fail open — update check failure မသည် app ကိုမပိတ်
    }
  }

  /// Android အတွက် Play Store ထဲ သွားစရာမလိုဘဲ App ထဲမှာတင် Update လုပ်ရန်
  static Future<void> triggerInAppUpdate(String storeUrl) async {
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          // Immediate update သည် user ကို update မလုပ်မချင်း app သုံးခွင့်မပေးဘဲ ပိတ်ထားမည်
          await InAppUpdate.performImmediateUpdate();
          return;
        }
      } catch (e) {
        debugPrint('[InAppUpdate] Error: $e');
        // Fallback to browser if In-App Update fails
      }
    }

    // Fallback logic for iOS or if Android In-App Update fails
    if (storeUrl.isNotEmpty) {
      final uri = Uri.tryParse(storeUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  // ── Version comparison ─────────────────────────────────────────────────────
  // Returns true if [current] < [minimum]  (e.g. "1.1.0" < "1.2.0")
  static bool _isVersionLower(String current, String minimum) {
    final cur = _parse(current);
    final min = _parse(minimum);
    for (int i = 0; i < 3; i++) {
      if (cur[i] < min[i]) return true;
      if (cur[i] > min[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String version) {
    final parts = version.trim().split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.take(3).toList();
  }

  // ── Force update dialog ────────────────────────────────────────────────────
  // WillPopScope ဖြင့် back button ပိတ်ထားသောကြောင့် dialog dismiss မဖြစ်နိုင်
  static Future<void> _showForceUpdateDialog(
    BuildContext context, {
    required String message,
    required String storeUrl,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false, // Android back button disable
        child: AlertDialog(
          title: const Text('Update လိုအပ်သည်'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                if (storeUrl.isNotEmpty) {
                  final uri = Uri.tryParse(storeUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
