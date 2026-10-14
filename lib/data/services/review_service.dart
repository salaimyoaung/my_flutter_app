import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review_model.dart';

class ReviewService {
  static final _db      = FirebaseFirestore.instance;
  static final _reviews = _db.collection('reviews');

  // ── Submit a review ────────────────────────────────────────────────────────
  static Future<void> submitReview({
    required String sellerId,
    required String orderId,
    required String productName,
    required int    rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Login required');

    // ✅ Duplicate guard — one review per order only
    final existing = await _reviews
        .where('orderId',  isEqualTo: orderId)
        .where('buyerId',  isEqualTo: user.uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('ဤ order အတွက် review တင်ပြီးသားဖြစ်သည်');
    }

    // Fetch buyer profile image
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final profileImage = (userDoc.data()?['profileImage'] ?? '').toString();
    final buyerName    = (userDoc.data()?['name'] ?? '').toString();

    // ✅ Document ID = orderId — Firestore rules မှာ reviewId == orderId check ဖြင့်
    //    duplicate ကို server-side ပိတ်သည်။ doc already exists ဆိုရင်
    //    allow update = false ဖြစ်သောကြောင့် automatic deny ဖြစ်မည်။
    await _reviews.doc(orderId).set({
      'sellerId':          sellerId,
      'buyerId':           user.uid,
      'buyerName':         buyerName,
      'buyerProfileImage': profileImage,
      'orderId':           orderId,
      'productName':       productName,
      'rating':            rating,
      'comment':           comment,
      'createdAt':         FieldValue.serverTimestamp(),
    });

    // avgRating + reviewCount → onReviewCreated Cloud Function က handle လုပ်မည်။
    // Client-side မှ ရေးရန် မလိုတော့ — rules မှာ allow မထားသောကြောင့် fail ဖြစ်မည်။
  }

  // ── Check if buyer has reviewed this order ─────────────────────────────────
  static Future<bool> hasReviewed(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final snap = await _reviews
        .where('orderId', isEqualTo: orderId)
        .where('buyerId', isEqualTo: uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Stream reviews for a seller ────────────────────────────────────────────
  static Stream<List<ReviewModel>> sellerReviewsStream(String sellerId) {
    return _reviews
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ReviewModel.fromDoc).toList();
          list.sort((a, b) {
            final at = a.createdAt?.toDate() ?? DateTime(0);
            final bt = b.createdAt?.toDate() ?? DateTime(0);
            return bt.compareTo(at);
          });
          return list;
        });
  }

}
