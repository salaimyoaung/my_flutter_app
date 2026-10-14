import 'package:flutter/material.dart';

import '../../../core/widgets/brand_app_bar.dart';
import 'buyer_orders_page.dart';
import 'seller_orders_page.dart';

class OrdersHubPage extends StatelessWidget {
  const OrdersHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        // ✅ BrandAppBar with TabBar — consistent gradient, no hardcoded colors
        appBar: BrandAppBar(
          title: 'Orders',
          bottom: const TabBar(
            // ✅ White tabs to match BrandAppBar gradient
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Buyer'),
              Tab(text: 'Seller'),
            ],
          ),
        ),

        // ✅ CustomScrollView children — avoids nested Scaffold/AppBar issue
        // BuyerOrdersPage and SellerOrdersPage each have their own Scaffold+AppBar
        // so we use them directly in TabBarView which hides the outer scaffold body.
        // If double AppBar becomes an issue, refactor inner pages to bodyOnly widgets.
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