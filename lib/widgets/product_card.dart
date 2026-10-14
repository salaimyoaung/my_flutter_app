import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_routes.dart';
import '../data/models/product_model.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';

class ProductCard extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> data;

  const ProductCard({super.key, required this.productId, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final imageUrl = (data['image'] ?? '').toString();
    final price = (data['price'] ?? '').toString();
    final originalPrice = (data['originalPrice'] ?? '').toString();

    final hasDiscount =
        originalPrice.isNotEmpty && originalPrice != price;
    final name = (data['name'] ?? '').toString();
    final sellerId = (data['sellerId'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        final p = Product.fromFirestore(productId, data);
        context.push(
          AppRoutes.productPath(productId),
          extra: {
            'product': p,
            'sellerName': p.sellerName,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: scheme.surface.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
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
                    ? Hero(
                        tag: 'product-$productId',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppNetworkImage(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.phone_android,
                              size: 48,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.phone_android,
                        size: 48,
                        color: scheme.primary,
                      ),
              ),
            ),

            const SizedBox(height: 5),

            /// NAME
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium,
            ),

            const SizedBox(height: 5),

            /// PRICE + HEART
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasDiscount)
                      Row(
                        children: [
                          const Icon(Icons.close, color: Colors.grey, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "$originalPrice MMK (original)",
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),

                    Row(
                      children: [
                        Icon(Icons.check_circle, color: scheme.tertiary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          hasDiscount
                              ? "$price MMK (discount)"
                              : "$price MMK",
                          style: textTheme.titleSmall?.copyWith(
                            color: scheme.tertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                        color: isFav ? scheme.error : scheme.onSurfaceVariant,
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
                final sellerName = (user['name'] ?? '').toString();
                final profile = (user['profileImage'] ?? '').toString();
                final isVerified = user['isVerified'] == true;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundImage: profile.isNotEmpty
                          ? NetworkImage(profile)
                          : null,
                      child: profile.isEmpty
                          ? const Icon(Icons.person, size: 12)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        sellerName,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 3),
                      Icon(Icons.verified, color: scheme.primary, size: 11),
                    ],
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
