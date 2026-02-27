import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';

class ModelListingsPage extends StatelessWidget {
  final String brand;
  final String model;

  const ModelListingsPage({
    super.key,
    required this.brand,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final ref = FirebaseFirestore.instance
        .collection('products')
        .where('brand', isEqualTo: brand)
        .where('model', isEqualTo: model)
        .orderBy('price');

    return Scaffold(
      appBar: AppBar(title: Text(model)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No listings"));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();

              final imageUrl = (data['image'] ?? '').toString();
              final price = (data['price'] ?? '').toString();
              final sellerId = (data['sellerId'] ?? '').toString();
              final fallbackName =
              (data['sellerName'] ?? 'Unknown').toString();

              return GestureDetector(
                onTap: () {
                  context.push(
                    AppRoutes.productPath(doc.id),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// 📷 Product Image
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                              : Container(
                            color: scheme.surfaceVariant,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.phone_android,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      /// TEXT AREA
                      Padding(
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 💰 Price
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "$price MMK",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),

                                /// ❤️ Favorite Button
                                _FavoriteButton(productId: doc.id),
                              ],
                            ),

                            const SizedBox(height: 0),

                            /// 👤 Seller (Realtime from users collection)
                            if (sellerId.isNotEmpty)
                              StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(sellerId)
                                    .snapshots(),
                                builder: (context, userSnap) {
                                  String name = fallbackName;
                                  String profileUrl = '';

                                  if (userSnap.hasData &&
                                      userSnap.data!.exists) {
                                    final userData =
                                        userSnap.data!.data() ?? {};
                                    name = (userData['name'] ??
                                        fallbackName)
                                        .toString();
                                    profileUrl =
                                        (userData['profileImage'] ?? '')
                                            .toString();
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      context.push(
                                        AppRoutes.sellerWall,
                                        extra: {
                                          "sellerId": sellerId,
                                          "sellerName": name,
                                        },
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor:
                                          scheme.surfaceVariant,
                                          backgroundImage:
                                          profileUrl.isNotEmpty
                                              ? NetworkImage(profileUrl)
                                              : null,
                                          child: profileUrl.isEmpty
                                              ? const Icon(
                                            Icons.person,
                                            size: 14,
                                          )
                                              : null,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme
                                                  .onSurfaceVariant,
                                              fontWeight:
                                              FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
class _FavoriteButton extends StatelessWidget {
  final String productId;

  const _FavoriteButton({required this.productId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final scheme = Theme.of(context).colorScheme;

    if (uid == null) {
      return IconButton(
        icon: Icon(
          Icons.favorite_border,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        onPressed: () {
          context.push(AppRoutes.login); // your login route
        },
      );
    }

    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(productId);

    return StreamBuilder<DocumentSnapshot>(
      stream: favRef.snapshots(),
      builder: (context, snap) {
        final isFav = snap.data?.exists ?? false;

        return IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.red : scheme.onSurfaceVariant,
            size: 18,
          ),
          onPressed: () async {
            if (isFav) {
              await favRef.delete();
            } else {
              await favRef.set({
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          },
        );
      },
    );
  }
}