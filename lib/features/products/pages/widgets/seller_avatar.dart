import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerAvatar extends StatelessWidget {

  final String sellerId;

  const SellerAvatar({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .snapshots(),

      builder: (context, snap) {

        final data = snap.data?.data() as Map<String, dynamic>?;

        final profile = data?['profileImage'] ?? '';

        return CircleAvatar(
          radius: 40,

          backgroundImage:
          profile.isNotEmpty ? NetworkImage(profile) : null,

          child: profile.isEmpty
              ? const Icon(Icons.person)
              : null,
        );
      },
    );
  }
}