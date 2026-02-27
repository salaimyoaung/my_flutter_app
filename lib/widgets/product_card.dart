import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_routes.dart';

class ProductCard extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> data;

  const ProductCard({
    super.key,
    required this.productId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final imageUrl = (data['image'] ?? '').toString();
    final price = (data['price'] ?? '').toString();
    final name = (data['name'] ?? '').toString();
    final sellerId = (data['sellerId'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        context.push(AppRoutes.productPath(productId));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withOpacity(0.75),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [

            /// IMAGE
            Expanded(
              child: Center(
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : Icon(Icons.phone_android,
                    size: 48, color: scheme.primary),
              ),
            ),

            const SizedBox(height: 5),

            /// NAME
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 5),

            /// PRICE + HEART
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  "$price MMK",
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser == null
                      ? null
                      : FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('favorites')
                      .doc(productId)
                      .snapshots(),
                  builder: (context, snapshot) {

                    final isFav = snapshot.data?.exists ?? false;

                    return GestureDetector(
                      onTap: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          context.go(AppRoutes.signup);
                          return;
                        }

                        final favRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('favorites')
                            .doc(productId);

                        if (isFav) {
                          await favRef.delete();
                        } else {
                          await favRef.set({
                            'productId': productId,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }
                      },
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isFav ? Colors.red : Colors.grey,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 5),

            /// SELLER BADGE
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(sellerId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) {
                  return const SizedBox.shrink();
                }

                final user = snap.data!.data()!;
                final sellerName =
                (user['name'] ?? '').toString();
                final profile =
                (user['profileImage'] ?? '').toString();

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundImage:
                      profile.isNotEmpty ? NetworkImage(profile) : null,
                      child: profile.isEmpty
                          ? const Icon(Icons.person, size: 12)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        sellerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}