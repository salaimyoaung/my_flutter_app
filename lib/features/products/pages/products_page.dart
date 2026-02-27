import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../widgets/brand_wall_view.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {

  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = "";

  void _enterSearch() {
    setState(() => _isSearching = true);
  }

  void _exitSearch() {
    _searchCtrl.clear();
    setState(() {
      _q = "";
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(
          "Home",
          style: AppTextStyles.heading(context),
        ),
        actions: [

          /// 🔥 Admin Buttons
          IconButton(
            tooltip: "Manage Brands Order",
            icon: const Icon(Icons.format_list_numbered),
            onPressed: () {
              context.push(AppRoutes.manageBrands);
            },
          ),
          IconButton(
            tooltip: "Manage Models",
            icon: const Icon(Icons.settings_suggest_outlined),
            onPressed: () {
              context.push(AppRoutes.manageModels);
            },
          ),
          IconButton(
            tooltip: "Admin Orders",
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () {
              context.push(AppRoutes.adminOrders);
            },
          ),

          /// ➕ Add Product
          IconButton(
            tooltip: "Add Product",
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () {
              context.push(AppRoutes.addProduct);
            },
          ),

          /// 🔔 Notifications
          IconButton(
            tooltip: "Notifications",
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              context.push(AppRoutes.notifications);
            },
          ),

          /// 🛍 Buyer Orders
          IconButton(
            tooltip: "My Orders",
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () {
              context.push(AppRoutes.buyerOrders);
            },
          ),

          /// 🏪 Seller Orders
          IconButton(
            tooltip: "Seller Orders",
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () {
              context.push(AppRoutes.sellerOrders);
            },
          ),

          const SizedBox(width: 6),
        ],
      ),
      body: const BrandWallView(),
    );
  }
}