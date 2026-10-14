import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';

class SellerCover extends StatelessWidget {

  final String sellerId;

  const SellerCover({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .snapshots(),

      builder: (context, snap) {

        final data = snap.data?.data() as Map<String, dynamic>?;

        final cover = data?['coverImage'] ?? '';

        return Container(
          height: 150,
          width: double.infinity,
          color: Colors.grey[300],

          child: cover.isNotEmpty
              ? AppNetworkImage(
                  cover,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                )
              : const Icon(Icons.image),
        );
      },
    );
  }
}