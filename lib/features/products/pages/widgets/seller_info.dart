import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerInfo extends StatelessWidget {

  final String sellerId;

  const SellerInfo({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .snapshots(),

      builder: (context, snap) {

        if (!snap.hasData) {
          return const SizedBox();
        }

        final data = snap.data!.data() as Map<String, dynamic>?;

        final name = data?['name'] ?? '';
        final city = data?['shopCity'] ?? '';
        final address = data?['shopAddress'] ?? '';

        return Column(
          children: [

            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                const Icon(Icons.location_on, size: 16),

                const SizedBox(width: 4),

                Text("$address ($city)"),

              ],
            ),
          ],
        );
      },
    );
  }
}