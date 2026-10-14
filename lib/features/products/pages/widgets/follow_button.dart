import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowButton extends StatelessWidget {

  final String sellerId;

  const FollowButton({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const SizedBox();

    return ElevatedButton(

      child: const Text("Follow"),

      onPressed: () async {

        await FirebaseFirestore.instance
            .collection("followers")
            .doc(sellerId)
            .collection("users")
            .doc(user.uid)
            .set({
          "createdAt": FieldValue.serverTimestamp(),
        });

      },
    );
  }
}