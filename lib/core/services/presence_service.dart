import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Reliable online presence tracking using Firebase Realtime Database.
///
/// RTDB ကို သုံးသောကြောင့် network ပြတ်သွားသော အခါ (app kill, network loss)
/// onDisconnect() handler သည် server side မှ automatic အလိုအလျောက် offline ကို set လုပ်မည်။
///
/// Firestore ရှိ users/{uid}.isOnline သည် UI read အတွက် sync ဖြစ်နေစေမည်။
///
/// ⚠️  RTDB Rules — Firebase Console → Realtime Database → Rules မှာ deploy ရမည်:
///   {
///     "rules": {
///       "presence": {
///         "$uid": {
///           ".read":  "auth != null",
///           ".write": "auth != null && auth.uid == $uid"
///         }
///       },
///       "$other": { ".read": false, ".write": false }
///     }
///   }
///   Root-level "$other" deny rule မပါရင် test mode default rules (public r/w) က
///   presence path အပြင် ဘယ် path ကိုမဆို ဖတ်/ရေးနိုင်မည် — production မတင်ခင် deploy ရမည်။
class PresenceService {
  static DatabaseReference? _ref;

  // Asia-Southeast1 RTDB URL — explicit so the SDK doesn't guess US-central
  static const _dbUrl =
      'https://e-commence-app-4eafb-default-rtdb.asia-southeast1.firebasedatabase.app';

  // ✅ Cached instance — setOnline() call တိုင်း new instance မဖန်တီးတော့ပါ
  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _dbUrl,
      );

  // ── Go online ─────────────────────────────────────────────────────────────
  /// Call when app resumes or user logs in.
  /// 1) Register onDisconnect first (server-side safety net)
  /// 2) Set online status
  /// 3) Sync to Firestore for UI
  static Future<void> setOnline() async {
    if (kIsWeb) return; // RTDB presence on web ကို ဒီ implementation မှာ skip

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Register server-side disconnect handler FIRST — critical ordering
      final ref = _db.ref('presence/$uid');
      await ref.onDisconnect().update({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      // Now mark as online
      await ref.update({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      _ref = ref;

      // Firestore sync handled by Cloud Function onPresenceChanged
    } catch (e) {
      if (kDebugMode) debugPrint('[PresenceService] setOnline error: $e');
    }
  }

  // ── Go offline (intentional) ──────────────────────────────────────────────
  /// Call when app pauses, user logs out, or dispose runs.
  /// Cancel the onDisconnect so only one write happens.
  static Future<void> setOffline() async {
    if (kIsWeb) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _ref = null;
      return;
    }

    try {
      // ✅ Cold restart fix — _ref က null ဖြစ်နေနိုင်တယ် (static field reset after force-kill)
      // _ref မရှိသော်လည်း uid သိထားသောကြောင့် RTDB ref ကို တိုက်ရိုက် construct လုပ်နိုင်
      // ဒီနည်းနဲ့ RTDB + Firestore နှစ်ခုလုံး consistent ဖြစ်မည်
      final ref = _ref ?? _db.ref('presence/$uid');

      // Cancel pending onDisconnect — we're going offline intentionally
      await ref.onDisconnect().cancel();
      await ref.update({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });
      _ref = null;

      // Firestore sync handled by Cloud Function onPresenceChanged
    } catch (e) {
      if (kDebugMode) debugPrint('[PresenceService] setOffline error: $e');
    }
  }

  // ── Firestore sync ────────────────────────────────────────────────────────
  // DEPRECATED: Handled by Cloud Function onPresenceChanged
}
