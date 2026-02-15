import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/order_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/admin_access_service.dart';
import '../../features/admin/pages/admin_orders_page.dart';
import '../../features/admin/pages/fix_phone_brands_page.dart';
import '../../features/admin/pages/manage_models_page.dart';
import '../../features/admin/pages/manage_phone_brands_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/signup_page.dart';
import '../../features/auth/pages/splash_page.dart';
import '../../features/orders/pages/buyer_orders_page.dart';
import '../../features/orders/pages/order_detail_page.dart';
import '../../features/orders/pages/order_form_page.dart';
import '../../features/orders/pages/orders_hub_page.dart';
import '../../features/orders/pages/seller_orders_page.dart';
import '../../features/auth/pages/otp_verify_page.dart';
import '../../features/products/pages/add_product_page.dart';
import '../../features/products/pages/brand_collection_page.dart';
import '../../features/products/pages/edit_product_page.dart';
import '../../features/products/pages/home_page.dart';
import '../../features/products/pages/product_detail_route_page.dart';
import '../../features/profile/pages/edit_profile_page.dart';
import '../../features/profile/pages/notifications_page.dart';
import '../../features/profile/pages/profile_page.dart';
import 'app_routes.dart';
import 'auth_refresh_listenable.dart';
import 'app_navigator_keys.dart';

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  refreshListenable:
  AuthRefreshListenable(FirebaseAuth.instance.authStateChanges()),

  // ================= REDIRECT LOGIC =================
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final location = state.uri.path; // ✅ FIXED

    print("Redirect check → $location");

    // ===== Not Logged In =====
    if (user == null) {
      AdminAccessService.instance.clear();

      if (location == AppRoutes.login ||
          location == AppRoutes.signup) {
        return null;
      }

      return AppRoutes.login;
    }

    // ===== Logged In but on auth pages =====
    if (location == AppRoutes.login ||
        location == AppRoutes.signup ||
        location == AppRoutes.splash) {
      return AppRoutes.home;
    }

    // ===== Admin Protection =====
    final adminPaths = <String>{
      AppRoutes.adminOrders,
      AppRoutes.manageBrands,
      AppRoutes.manageModels,
      AppRoutes.fixPhoneBrands,
    };

    if (adminPaths.any((path) => location.startsWith(path))) {
      final ok = await AdminAccessService.instance.isAdmin(user.uid);
      if (!ok) {
        print("❌ Not admin → redirect home");
        return AppRoutes.home;
      }
    }

    return null;
  },

  // ================= ROUTES =================
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const SignupPage(),
    ),

    // ===== Product Detail =====
    GoRoute(
      path: AppRoutes.product,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final extra = state.extra;
        final map = extra is Map<String, dynamic> ? extra : null;

        final product = map?['product'] as Product?;
        final sellerName = map?['sellerName'] as String?;

        return ProductDetailRoutePage(
          productId: id,
          product: product,
          sellerName: sellerName,
        );
      },
    ),

    // ===== Orders =====
    GoRoute(
      path: AppRoutes.ordersHub,
      builder: (context, state) => const OrdersHubPage(),
    ),
    GoRoute(
      path: AppRoutes.buyerOrders,
      builder: (context, state) => const BuyerOrdersPage(),
    ),
    GoRoute(
      path: AppRoutes.sellerOrders,
      builder: (context, state) => const SellerOrdersPage(),
    ),
    GoRoute(
      path: AppRoutes.adminOrders,
      builder: (context, state) => const AdminOrdersPage(),
    ),

    // ===== Profile =====
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: AppRoutes.editProfile,
      builder: (context, state) {
        final extra = state.extra;
        final map = extra is Map<String, dynamic> ? extra : const {};

        return EditProfilePage(
          currentName: (map['currentName'] ?? '').toString(),
          currentPhone: (map['currentPhone'] ?? '').toString(),
          currentCoverImage:
          (map['currentCoverImage'] ?? '').toString(),
          currentProfileImage:
          (map['currentProfileImage'] ?? '').toString(),
        );
      },
    ),

    // ===== Products =====
    GoRoute(
      path: AppRoutes.addProduct,
      builder: (context, state) => const AddProductPage(),
    ),
    GoRoute(
      path: AppRoutes.editProduct,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return EditProductPage(productId: id);
      },
    ),

    // ===== Admin =====
    GoRoute(
      path: AppRoutes.manageBrands,
      builder: (context, state) =>
      const ManagePhoneBrandsPage(),
    ),
    GoRoute(
      path: AppRoutes.manageModels,
      builder: (context, state) =>
      const ManageModelsPage(),
    ),
    GoRoute(
      path: AppRoutes.fixPhoneBrands,
      builder: (context, state) =>
      const FixPhoneBrandsPage(),
    ),

    // ===== Orders Detail =====
    GoRoute(
      path: AppRoutes.orderForm,
      builder: (context, state) {
        final extra = state.extra;
        final map = extra is Map<String, dynamic> ? extra : const {};
        final product = map['product'] as Product?;
        final sellerName =
        (map['sellerName'] ?? '').toString();

        if (product == null) {
          return const SplashPage();
        }

        return OrderFormPage(
          product: product,
          sellerName: sellerName,
        );
      },
    ),

    GoRoute(
      path: AppRoutes.orderDetail,
      builder: (context, state) {
        final extra = state.extra;
        final map = extra is Map<String, dynamic> ? extra : const {};
        final order = map['order'] as OrderModel?;

        if (order == null) {
          return const SplashPage();
        }

        return OrderDetailPage(order: order);
      },
    ),

    GoRoute(
      path: AppRoutes.pickupOtp,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return PickupOtpVerifyPage(orderId: id);
      },
    ),

    // ===== Misc =====
    GoRoute(
      path: AppRoutes.notifications,
      builder: (context, state) =>
      const NotificationsPage(),
    ),
    GoRoute(
      path: AppRoutes.brandCollection,
      builder: (context, state) {
        final raw = state.pathParameters['brand'] ?? '';
        final brand = Uri.decodeComponent(raw);
        return BrandCollectionPage(brand: brand);
      },
    ),
  ],
);