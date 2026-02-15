import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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

  /// App စတင်ချိန်ခေါ်ပါ
  static Future<void> init() async {
    // Local notification initialize
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse res) async {
        // res.payload ကိုယူပြီး route ဖွင့်တာမျိုးလုပ်နိုင်
        // e.g. open NotificationsPage / OrderDetailPage
      },
    );

    // Android channel create
    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // iOS permission
    if (Platform.isIOS) {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Android 13+ permission (FirebaseMessaging requestPermission က Android မှာလည်း ok)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Foreground message (App ဖွင့်ထားချိန်) -> local notification ပြ
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _showLocal(message);
    });
  }

  /// Login ဝင်ပြီးတိုင်း ခေါ်ပါ (Token သိမ်း)
  static Future<void> saveTokenToUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null || token.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Token refresh ကိုလည်း update
    _fcm.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': newToken,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Marketplace';
    final body = message.notification?.body ?? '';

    const androidDetails = AndroidNotificationDetails(
      'marketplace_high',
      'Marketplace Notifications',
      channelDescription: 'Orders & status updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const notiDetails =
    NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notiDetails,
    );
  }
}