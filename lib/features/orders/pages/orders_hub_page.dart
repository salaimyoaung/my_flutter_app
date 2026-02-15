import 'package:flutter/material.dart';
import '../../../app_styles.dart';
import 'buyer_orders_page.dart';
import 'seller_orders_page.dart';

class OrdersHubPage extends StatelessWidget {
  const OrdersHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text("Orders", style: AppTextStyles.heading(context)),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 0.5,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Buyer"),
              Tab(text: "Seller"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BuyerOrdersPage(),
            SellerOrdersPage(),
          ],
        ),
      ),
    );
  }
}