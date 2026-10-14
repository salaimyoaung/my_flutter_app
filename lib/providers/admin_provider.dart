import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Watches auth state and keeps an up-to-date admin flag via custom claims.
///
/// Custom claims သည် Firestore get() မလိုဘဲ JWT token မှ directly ဖတ်သောကြောင့်—
///   - Firestore read cost မရှိ
///   - Server-authoritative — client မှ role field ကို spoof မလုပ်နိုင်
///   - Token refresh ဖြစ်မှ latest claims ကိုရမည် (below မှာ forceRefresh ထည့်ထား)
///
/// ⚠️  Cloud Function setup လိုအပ်သည်—
///
/// functions/index.js (သို့မဟုတ် index.ts):
/// ```
/// exports.setAdminClaim = onCall(async (request) => {
///   // ဒီ function ကို admin portal မှ သာ call လုပ်ရမည် — caller isAdmin check ထည့်ပါ
///   const { targetUid } = request.data;
///   const callerUid = request.auth?.uid;
///   if (!callerUid) throw new HttpsError('unauthenticated', 'Login required');
///
///   const callerRecord = await admin.auth().getUser(callerUid);
///   if (callerRecord.customClaims?.role !== 'admin') {
///     throw new HttpsError('permission-denied', 'Admin only');
///   }
///
///   await admin.auth().setCustomUserClaims(targetUid, { role: 'admin' });
///   return { success: true };
/// });
///
/// // First admin ကို Firebase Admin SDK CLI မှ set ပါ—
/// // node -e "
/// //   const admin = require('firebase-admin');
/// //   admin.initializeApp();
/// //   admin.auth().setCustomUserClaims('ADMIN_UID_HERE', { role: 'admin' })
/// //     .then(() => console.log('Done'));
/// // "
/// ```
///
/// Emits:
///   - AsyncLoading  while token is being fetched
///   - AsyncData(true/false)  once fetched
///   - AsyncData(false) when signed out
///
/// The GoRouter redirect reads this synchronously via ref.read() so there is
/// no async await in the redirect callback — this prevents navigation timing bugs.
/// Checks admin status via Firestore users/{uid}.role field.
/// Consistent with AdminAccessService used in products_page.dart.
///
/// NOTE: Once custom claims are properly bootstrapped for all admin users,
/// this can be switched back to JWT claims (getIdTokenResult) for better
/// performance — but Firestore is authoritative and correct for now.
final adminProvider = StreamProvider<bool>((ref) async* {
  await for (final user in FirebaseAuth.instance.authStateChanges()) {
    if (user == null) {
      yield false;
      continue;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = (doc.data()?['role'] ?? '').toString().toLowerCase().trim();
      yield role == 'admin';
    } catch (_) {
      yield false;
    }
  }
});
