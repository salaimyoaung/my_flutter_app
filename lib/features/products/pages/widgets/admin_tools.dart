import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminTools extends StatelessWidget {

  final String sellerId;

  const AdminTools({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {

    return ElevatedButton.icon(
      icon: const Icon(Icons.block),
      label: const Text("Ban Seller"),

      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),

      onPressed: () async {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .update({'isBanned': true});

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Seller banned"),
            ),
          );
        }
      },
    );
  }
}