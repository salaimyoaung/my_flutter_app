import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'marketplace_high',
    'Marketplace Notifications',
    description: 'Orders & status updates',
    importance: Importance.high,
  );

  // Track token refresh subscription to avoid stacking multiple listeners.
  // StreamSubscription ကို သိမ်းထားပြီး logout မှာ cancel လုပ်မည်။
  static StreamSubscription<String>? _tokenRefreshSub;

  /// Call once on app start.
  /// Background handler is registered in main.dart (@pragma vm:entry-point) —
  /// do NOT register it here or it will overwrite the one in main.dart.
  static Future<void> init() async {

    const androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );
    const initSettings =
    InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(settings: initSettings);

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // ✅ iOS Foreground Presentation Options:
    // alert: true ထားခြင်းဖြင့် iOS foreground တွင် FCM ရဲ့ native banner alert ကို တိုက်ရိုက်ပြသစေမည်
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) => _showLocal(message));
  }

  /// Call after login — saves FCM token to user doc.
  /// Uses update() instead of set(merge:true) to avoid triggering
  /// create rules when the document already exists.
  static Future<void> saveTokenToUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? token;
    try {
      // ✅ iOS: APNs token ရရှိရေးအတွက် 2s တကြိမ် 5 ကြိမ် ထိ retry လုပ်ပြီး စောင့်ပေးပါမည်
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        int retries = 0;
        while (apnsToken == null && retries < 5) {
          apnsToken = await _fcm.getAPNSToken();
          if (apnsToken == null) {
            await Future.delayed(const Duration(seconds: 2));
            retries++;
          }
        }
        if (apnsToken == null && kDebugMode) {
          debugPrint('⚠️ iOS APNs token is null. Ensure APNs Key is uploaded in Firebase Console & running on physical device.');
        }
      }

      token = await _fcm.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ saveTokenToUser getToken error: $e');
    }

    if (token != null && token.trim().isNotEmpty) {
      try {
        // ✅ update() — only works if doc exists, matches Firestore rules
        // Fields: fcmToken + updatedAt — both in owner onlyChanges allowlist
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (kDebugMode) debugPrint('saveTokenToUser firestore update error: $e');
      }
    }

    // Cancel previous subscription first — handles logout → re-login case.
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'fcmToken': newToken,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (kDebugMode) debugPrint('onTokenRefresh update error: $e');
      }
    });
  }

  /// Call on logout — cancels FCM token refresh subscription.
  static Future<void> onLogout() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    // iOS တွင် alert: true ကြောင့် FCM က native notification banner ကို တိုက်ရိုက်ပြပေးပါသည် (message.notification != null ဖြစ်လျှင်)
    // ထို့ကြောင့် message.notification ပါလာပါက _local.show() ခေါ်ရန် မလိုတော့ဘဲ duplication ကို တားဆီးပေးသည်
    if (defaultTargetPlatform == TargetPlatform.iOS && message.notification != null) {
      return;
    }

    // Cloud Function က data-only message ပို့နိုင်သောကြောင့် data မှ fallback ယူသည်
    final title = message.notification?.title
        ?? (message.data['title'] as String?)
        ?? 'Sigma Moby';
    final body = message.notification?.body
        ?? (message.data['body'] as String?)
        ?? '';

    // Empty body notification မပြ — heads-up အတွက် body လိုအပ်သည်
    if (body.trim().isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'marketplace_high',
      'Marketplace Notifications',
      channelDescription: 'Orders & status updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const notiDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentBadge: true,
      ),
    );

    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notiDetails,
    );
  }
}