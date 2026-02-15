import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/product_model.dart';
import 'app_routes.dart';

extension AppNavigation on BuildContext {
  void goHome() => go(AppRoutes.home);
  void goLogin() => go(AppRoutes.login);
  void goSignup() => go(AppRoutes.signup);
  void goProduct(String id, {required Product product}) {
    push(
      AppRoutes.productPath(id),
      extra: {
        'product': product,
      },
    );
  }

  void goOrdersHub() => go(AppRoutes.ordersHub);
  void goAdminOrders() => go(AppRoutes.adminOrders);
}
