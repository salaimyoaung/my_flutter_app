import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> saveFcmTokenForCurrentUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Android 13+ permission
  await FirebaseMessaging.instance.requestPermission();

  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;

  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'fcmToken': token,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}