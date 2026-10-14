import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_helper.dart';
import '../../data/services/admin_access_service.dart';

/// Current user auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Admin status provider
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  return AdminAccessService.instance.isAdmin(user.uid);
});

/// Pending orders (Admin)
final pendingOrdersProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  if (!isAdmin) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'DEPOSIT_PENDING')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Admin order notifications (Unread)
final adminOrderNotifsProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  final user = ref.watch(authStateProvider).value;
  if (!isAdmin || user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .where('isRead', isEqualTo: false)
      .where('type', isEqualTo: 'order')
      .where('targetRole', isEqualTo: 'admin')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Model requests (Admin)
final modelRequestsProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  if (!isAdmin) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('model_requests')
      .where('status', isEqualTo: 'PENDING')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// IMEI pending (Admin)
final imeiPendingProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  if (!isAdmin) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('imei_registry')
      .where('status', isEqualTo: 'NOT_VERIFIED')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Seller verification requests (Admin)
final verifyRequestsProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  if (!isAdmin) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('users')
      .where('verificationDocUrl', isGreaterThan: '')
      .where('isVerified', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Report notifications (Admin)
final reportNotifsProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  final user = ref.watch(authStateProvider).value;
  if (!isAdmin || user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .where('isRead', isEqualTo: false)
      .where('type', isEqualTo: 'report')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Buyer unread notifications
final buyerUnreadProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(0);

  return unreadNotificationCountStream(
    targetRole: isAdmin ? 'admin' : 'buyer',
    extraExclude: isAdmin
        ? const ['new_order', 'model_request', 'verify_request', 'new_imei_submission']
        : const [],
  );
});

/// Seller unread notifications
final sellerUnreadProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  final user = ref.watch(authStateProvider).value;
  if (user == null || isAdmin) return Stream.value(0);

  return unreadNotificationCountStream(
    targetRole: 'seller',
    extraExclude: const ['model_request'],
  );
});

/// Bell unread notifications (Announcement + Admin Actions)
final bellUnreadProvider = StreamProvider<int>((ref) {
  return bellUnreadNotificationCountStream();
});

/// Model request unseen count (Seller)
final sellerModelRequestUnseenProvider = StreamProvider<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('model_requests')
      .where('sellerId', isEqualTo: user.uid)
      .where('isSeenBySeller', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});
