import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../data/models/order_model.dart';
import 'admin_order_detail_page.dart';
import 'buyer_order_detail_page.dart';
import 'seller_order_detail_page.dart';

/// Loads an order by ID and delegates to the correct detail page
/// (buyer / seller / admin) based on the current user's role.
///
/// This page owns the Firestore fetch so the GoRouter builder stays
/// synchronous — no FutureBuilder in the router itself.
class OrderDetailRouterPage extends StatelessWidget {
  final String orderId;

  const OrderDetailRouterPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Order not found')),
          );
        }

        final order = OrderModel.fromMap(
          snapshot.data!.id,
          snapshot.data!.data()!,
        );
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

        if (uid == order.buyerId) return BuyerOrderDetailPage(order: order);
        if (uid == order.sellerId) return SellerOrderDetailPage(order: order);
        return AdminOrderDetailPage(order: order);
      },
    );
  }
}
