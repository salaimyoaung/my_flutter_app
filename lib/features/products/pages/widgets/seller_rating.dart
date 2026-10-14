import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerRating extends StatelessWidget {

  final String sellerId;

  const SellerRating({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .snapshots(),

      builder: (context, snap) {

        if (!snap.hasData) return const SizedBox();

        final data = snap.data!.data() as Map<String, dynamic>?;

        final rating = data?['rating'] ?? 0;
        final followers = data?['followers'] ?? 0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Icon(Icons.star, color: Theme.of(context).colorScheme.tertiary, size: 16),

            const SizedBox(width: 4),

            Text("$rating rating"),

            const SizedBox(width: 10),

            Text("$followers followers"),

          ],
        );
      },
    );
  }
}