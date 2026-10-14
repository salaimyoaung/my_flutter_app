import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';


class SellerActions extends StatelessWidget {

  final String sellerId;

  const SellerActions({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid == sellerId;

    if (!isOwner) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),

      child: ElevatedButton.icon(

        icon: const Icon(Icons.edit),

        label: const Text("Edit Profile"),

        onPressed: () {

          context.push(
            "/profile/edit",
            extra: {
              "currentName": "",
              "currentPhone": "",
              "currentCoverImage": "",
              "currentProfileImage": "",
            },
          );

        },
      ),
    );
  }
}