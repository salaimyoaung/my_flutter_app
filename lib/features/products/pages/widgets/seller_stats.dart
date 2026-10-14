import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerStats extends StatelessWidget {

  final String sellerId;

  const SellerStats({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .snapshots(),

      builder: (context, snap) {

        final count = snap.data?.docs.length ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,

            children: [

              _item("Listings", count.toString()),
              _item("Sold", "34"),
              _item("Member", "2026"),

            ],
          ),
        );
      },
    );
  }

  Widget _item(String title, String value) {

    return Column(
      children: [

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),

        const SizedBox(height: 4),

        Text(title),

      ],
    );
  }
}