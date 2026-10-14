import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ✅ Production: createNotification calls Cloud Function (sendNotification)
/// Admin SDK in the function writes to Firestore — bypasses client rules.
/// Firestore rules: notifications { allow create: if false }
Future<void> createNotification({
  required String userId,
  required String type,
  required String title,
  required String body,
  String? chatId,
  String? orderId,
  String? senderName,
  String? targetRole,
}) async {
  try {
    await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('sendNotification')
        .call({
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'chatId': chatId,
      'orderId': orderId,
      'senderName': senderName,
      ...?targetRole != null ? {'targetRole': targetRole} : null,
    });
  } catch (e) {
    debugPrint('❌ createNotification error: $e');
    debugPrint('❌ userId=$userId type=$type title=$title');
    rethrow; // caller must handle — so errors are visible, not silently swallowed
  }
}

/// Bell icon notification types — announcement + admin actions to user
/// These are shown ONLY in the bell (notifications page), not on order/chat icons.
const kBellNotifTypes = [
  'announcement',
  'product_rejected',
  'account_banned',
  'fee_freeze',
  'verify_request',
  'new_imei_submission',
];

/// Real-time unread notification count for Bell Icon
Stream<int> bellUnreadNotificationCountStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);

  final bellTypes = kBellNotifTypes.toSet();

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs
          .where((doc) => bellTypes.contains(doc.data()['type'] as String?))
          .length)
      .handleError((_) => 0);
}

/// Real-time unread notification count — role-based
/// targetRole: "buyer" | "seller" | "admin"
/// Bell types (announcement, product_rejected, account_banned, fee_freeze) are
/// always excluded so they never appear on order/chat icon badges.
/// NOTE: type exclusion is done client-side to avoid Firestore composite index
/// requirements when combining whereNotIn + targetRole equality filter.
Stream<int> unreadNotificationCountStream({
  String? targetRole,
  List<String> extraExclude = const [],
}) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);

  // Always exclude chat + bell types from order badges (filtered client-side)
  final excludeTypes = <String>{
    'chat',
    ...kBellNotifTypes,
    ...extraExclude,
  };

  // Simple Firestore query — no whereNotIn to avoid composite index issues
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .where('isRead', isEqualTo: false);

  if (targetRole != null) {
    query = query.where('targetRole', isEqualTo: targetRole);
  }

  return query
      .snapshots()
      .map((snap) => snap.docs
          .where((doc) => !excludeTypes.contains(doc.data()['type'] as String?))
          .length)
      .handleError((_) => 0);
}