import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/product_model.dart';
import '../../features/admin/pages/admin_add_model_page.dart';
import '../../features/admin/pages/admin_fee_settings_page.dart';
import '../../features/admin/pages/admin_imei_reports_page.dart';
import '../../features/admin/pages/admin_imei_verification_page.dart';
import '../../features/admin/pages/admin_model_requests_page.dart';
import '../../features/admin/pages/admin_orders_page.dart';
import '../../features/admin/pages/admin_payment_settings_page.dart';
import '../../features/admin/pages/admin_pending_fees_page.dart';
import '../../features/admin/pages/admin_shipping_settings_page.dart';
import '../../features/admin/pages/admin_banned_users_page.dart';
import '../../features/admin/pages/admin_user_reports_page.dart';
import '../../features/admin/pages/admin_verify_sellers_page.dart';
import '../../features/admin/pages/admin_announce_page.dart';
import '../../features/admin/pages/admin_dashboard_page.dart';
import '../../features/admin/pages/fix_phone_brands_page.dart';
import '../../features/admin/pages/manage_models_page.dart';
import '../../features/admin/pages/manage_phone_brands_page.dart';
import '../../features/auth/pages/email_verification_page.dart';
import '../../features/auth/pages/force_update_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/phone_login_page.dart';
import '../../features/auth/pages/signup_page.dart';
import '../../features/auth/pages/splash_page.dart';
import '../../features/chat/pages/chat_list_page.dart';
import '../../features/chat/pages/chat_page.dart';
import '../../features/chat/pages/report_page.dart';
import '../../features/orders/pages/buyer_orders_page.dart';
import '../../features/orders/pages/order_detail_router_page.dart';
import '../../features/orders/pages/order_form_page.dart';
import '../../features/orders/pages/orders_hub_page.dart';
import '../../features/orders/pages/seller_orders_page.dart';
import '../../features/products/pages/add_product_page.dart';
import '../../features/products/pages/brand_collection_page.dart';
import '../../features/products/pages/edit_product_page.dart';
import '../../features/products/pages/home_page.dart';
import '../../features/products/pages/model_list_page.dart';
import '../../features/products/pages/model_listings_page.dart';
import '../../features/products/pages/product_detail_route_page.dart';
import '../../features/products/pages/seller_model_list_page.dart';
import '../../features/products/pages/seller_product_listings_page.dart';
import '../../features/products/pages/seller_reviews_page.dart';
import '../../features/products/pages/seller_wall_page.dart';
import '../../features/products/pages/series_list_page.dart';
import '../../features/profile/pages/edit_profile_page.dart';
import '../../features/profile/pages/favorites_page.dart';
import '../../features/profile/pages/notifications_page.dart';
import '../../features/profile/pages/my_model_requests_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../providers/admin_provider.dart';
import '../../providers/force_update_provider.dart';
import 'app_navigator_keys.dart';
import 'app_routes.dart';

// ─── Router Refresh Listenable ────────────────────────────────────────────────
// Combines auth state changes + admin state changes so GoRouter re-evaluates
// redirect whenever either changes.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Stream<dynamic> authStream, Ref ref) {
    _authSub = authStream.listen((_) => notifyListeners());
    _adminSub = ref.listen(adminProvider, (_, _) => notifyListeners());
    _updateSub = ref.listen(forceUpdateProvider, (_, _) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _authSub;
  late final ProviderSubscription<AsyncValue<bool>> _adminSub;
  late final ProviderSubscription<AsyncValue<dynamic>> _updateSub;

  @override
  void dispose() {
    _authSub.cancel();
    _adminSub.close();
    _updateSub.close();
    super.dispose();
  }
}

// ─── Router Provider ──────────────────────────────────────────────────────────

/// Helper to wrap admin-only pages with a loader while checking permissions.
/// Prevents "flashing" admin content to unauthorized users.
class AdminGuard extends ConsumerWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(adminProvider);
    return adminState.when(
      data: (isAdmin) {
        if (isAdmin) return child;
        // reliance on GoRouter redirect for actual navigation.
        // Return an empty box to avoid flashes or gesture conflicts.
        return const Scaffold(body: SizedBox.shrink());
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) {
        debugPrint('AdminGuard error: $err');
        FirebaseCrashlytics.instance.recordError(err, stack);
        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}

/// Expose the GoRouter as a Riverpod Provider so the redirect can read admin
/// state *synchronously* (from the cached adminProvider) — no await in redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: _RouterRefreshListenable(
      FirebaseAuth.instance.authStateChanges(),
      ref,
    ),

    // ─── Redirect ─────────────────────────────────────────────────────────
    // IMPORTANT: redirect must NOT be async — doing await here causes
    // navigation timing bugs in GoRouter. Admin state is read synchronously
    // from the Riverpod-cached adminProvider.
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.uri.path;

      // ── 0) Force Update Check ──────────────────────────────────────────
      // This is the highest priority check.
      final updateState = ref.read(forceUpdateProvider).value;
      if (updateState?.needsUpdate == true) {
        if (location == AppRoutes.forceUpdate) return null;
        return AppRoutes.forceUpdate;
      }
      // If we're on the update page but don't need an update anymore, go to splash/home
      if (location == AppRoutes.forceUpdate) return AppRoutes.splash;

      // ── 1) Not logged in ──────────────────────────────────────────────────
      if (user == null) {
        // Always allow auth pages
        if (location == AppRoutes.login ||
            location == AppRoutes.signup ||
            location == AppRoutes.phoneLogin) {
          return null;
        }
        // Splash → go to home (guest browsing allowed)
        if (location == AppRoutes.splash) return AppRoutes.home;

        // Allow public browsing routes without login
        if (_isPublicRoute(location)) return null;

        // Everything else requires login
        return AppRoutes.login;
      }

      // ── Logged in but not email-verified ──────────────────────────────
      // Phone auth users have no email — skip email verification for them
      // Google users are already verified by Google — skip email verification for them too
      final isPhoneUser = user.providerData
          .any((p) => p.providerId == 'phone');
      final isGoogleUser = user.providerData
          .any((p) => p.providerId == 'google.com');
      if (!user.emailVerified && !isPhoneUser && !isGoogleUser) {
        if (location == AppRoutes.emailVerification) return null;
        return AppRoutes.emailVerification;
      }

      // ── Logged in (verified) but on auth / splash pages ───────────────
      if (location == AppRoutes.login ||
          location == AppRoutes.signup ||
          location == AppRoutes.splash ||
          location == AppRoutes.phoneLogin ||
          location == AppRoutes.emailVerification) {
        return AppRoutes.home;
      }

      // Admin-only paths — check synchronously from cached provider value.
      // While adminProvider is still loading (AsyncLoading), value is null →
      // default to false (deny) to be safe. Once loaded it notifies and
      // redirect re-runs with the real value.
      final adminPaths = <String>{
        AppRoutes.adminOrders,
        AppRoutes.manageBrands,
        AppRoutes.manageModels,
        AppRoutes.fixPhoneBrands,
        AppRoutes.adminImeiReports,
        AppRoutes.adminImeiVerification,
        AppRoutes.adminUserReports,
        AppRoutes.adminBannedUsers,
        AppRoutes.adminModelRequests,
        AppRoutes.adminAddModel,
        AppRoutes.adminPaymentSettings,
        AppRoutes.adminShippingSettings,
        AppRoutes.adminFeeSettings,
        AppRoutes.adminPendingFees,
        AppRoutes.adminVerifySellers,
        AppRoutes.adminAnnounce,
        AppRoutes.adminDashboard,
      };

      if (adminPaths.any((path) => location.startsWith(path))) {
        final adminState = ref.read(adminProvider);
        // Still loading — allow through; refreshListenable will re-run
        // redirect once the provider resolves (AsyncData/AsyncError).
        if (adminState.isLoading) return null;
        final isAdmin = adminState.value ?? false;
        if (!isAdmin) return AppRoutes.home;
      }

      return null;
    },

    // ─── Routes ───────────────────────────────────────────────────────────
    routes: [

      // ── Splash / Auth ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.forceUpdate,
        builder: (context, state) => const ForceUpdatePage(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) => const EmailVerificationPage(),
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

      // ── Orders ───────────────────────────────────────────────────────────
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
        builder: (context, state) => const AdminGuard(child: AdminOrdersPage()),
      ),

      // ── Order Form ───────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.orderForm,
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map<String, dynamic> ? extra : const <String, dynamic>{};
          final product = map['product'] as Product?;
          final sellerName = (map['sellerName'] ?? '').toString();
          if (product == null) {
            return const Scaffold(
              body: Center(child: Text('Product data missing')),
            );
          }
          return OrderFormPage(product: product, sellerName: sellerName);
        },
      ),

      // ── Order Detail ─────────────────────────────────────────────────────
      // Fetching the order and deciding which view to show is now handled
      // inside OrderDetailRouterPage — not here — to avoid FutureBuilder
      // recreating on every navigation.
      GoRoute(
        path: AppRoutes.orderDetail,
        builder: (context, state) {
          final map = state.extra as Map<String, dynamic>? ?? {};
          final orderId = (map['orderId'] ?? '').toString();
          if (orderId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Invalid order')),
            );
          }
          return OrderDetailRouterPage(orderId: orderId);
        },
      ),

      // ── Profile ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) {
          final extra = state.extra as Map?;
          final userId = extra?['userId']?.toString();
          final sellerName = (extra?['sellerName'] ?? '').toString();
          if (userId != null && userId.isNotEmpty) {
            return SellerWallPage(sellerId: userId, sellerName: sellerName);
          }
          return const ProfilePage();
        },
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map<String, dynamic> ? extra : const <String, dynamic>{};
          return EditProfilePage(
            currentName: (map['currentName'] ?? '').toString(),
            currentPhone: (map['currentPhone'] ?? '').toString(),
            currentCoverImage: (map['currentCoverImage'] ?? '').toString(),
            currentProfileImage: (map['currentProfileImage'] ?? '').toString(),
          );
        },
      ),

      // ── Products ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.addProduct,
        builder: (context, state) => const AddProductPage(),
      ),
      GoRoute(
        path: AppRoutes.editProduct,
        builder: (context, state) {
          final product = state.extra as Product?;
          if (product == null) {
            return const Scaffold(
              body: Center(child: Text('Product data missing')),
            );
          }
          return EditProductPage(product: product);
        },
      ),
      GoRoute(
        path: AppRoutes.brandCollection,
        builder: (context, state) {
          final raw = state.pathParameters['brand'] ?? '';
          final brand = Uri.decodeComponent(raw);
          return BrandCollectionPage(brand: brand);
        },
      ),
      GoRoute(
        path: AppRoutes.product,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          return ProductDetailRoutePage(
            productId: id,
            product: extra?['product'] as Product?,
            sellerName: extra?['sellerName'] as String?,
          );
        },
      ),

      // ── Model / Series ───────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.modelList,
        builder: (context, state) {
          final map = state.extra as Map<String, dynamic>? ?? {};
          return ModelListPage(
            brand: (map['brand'] ?? '').toString(),
            deviceType: (map['deviceType'] ?? '').toString(),
            sellerId: map['sellerId']?.toString(),
            initialSeries: map['initialSeries']?.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.modelListings,
        pageBuilder: (context, state) {
          final map = state.extra as Map<String, dynamic>? ?? {};
          return NoTransitionPage(
            key: state.pageKey,
            child: ModelListingsPage(
              brand: (map['brand'] ?? '').toString(),
              model: (map['model'] ?? '').toString(),
              sellerId: map['sellerId']?.toString(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.seriesList,
        builder: (context, state) {
          final map = state.extra as Map<String, dynamic>? ?? {};
          return SeriesListPage(
            brand: (map['brand'] ?? '').toString(),
            deviceType: (map['deviceType'] ?? '').toString(),
            sellerId: map['sellerId']?.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sellerModels,
        builder: (context, state) {
          final extra = state.extra as Map? ?? {};
          return SellerModelListPage(
            sellerId: (extra['sellerId'] ?? '').toString(),
            brand: (extra['brand'] ?? '').toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sellerProducts,
        builder: (context, state) {
          final extra = state.extra as Map? ?? {};
          return SellerProductListingsPage(
            sellerId: (extra['sellerId'] ?? '').toString(),
            brand: (extra['brand'] ?? '').toString(),
            model: (extra['model'] ?? '').toString(),
          );
        },
      ),

      // ── Admin ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.manageBrands,
        builder: (context, state) => const AdminGuard(child: ManagePhoneBrandsPage()),
      ),
      GoRoute(
        path: AppRoutes.manageModels,
        builder: (context, state) => const AdminGuard(child: ManageModelsPage()),
      ),
      GoRoute(
        path: AppRoutes.fixPhoneBrands,
        builder: (context, state) => const AdminGuard(child: FixPhoneBrandsPage()),
      ),
      GoRoute(
        path: AppRoutes.adminImeiReports,
        builder: (context, state) => const AdminGuard(child: AdminImeiReportsPage()),
      ),
      GoRoute(
        path: AppRoutes.adminImeiVerification,
        builder: (context, state) => const AdminGuard(child: AdminImeiVerificationPage()),
      ),
      GoRoute(
        path: AppRoutes.adminModelRequests,
        builder: (context, state) => const AdminGuard(child: AdminModelRequestsPage()),
      ),
      GoRoute(
        path: AppRoutes.adminAddModel,
        builder: (context, state) => const AdminGuard(child: AdminAddModelPage()),
      ),
      GoRoute(
        path: AppRoutes.adminUserReports,
        builder: (context, state) => const AdminGuard(child: AdminUserReportsPage()),
      ),
      GoRoute(
        path: AppRoutes.adminBannedUsers,
        builder: (context, state) => const AdminGuard(child: AdminBannedUsersPage()),
      ),
      GoRoute(
        path: AppRoutes.adminPaymentSettings,
        builder: (context, state) => const AdminGuard(child: AdminPaymentSettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.adminShippingSettings,
        builder: (context, state) => const AdminGuard(child: AdminShippingSettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.adminFeeSettings,
        builder: (context, state) => const AdminGuard(child: AdminFeeSettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.adminPendingFees,
        builder: (context, state) => const AdminGuard(child: AdminPendingFeesPage()),
      ),
      GoRoute(
        path: AppRoutes.adminVerifySellers,
        builder: (context, state) => const AdminGuard(child: AdminVerifySellersPage()),
      ),
      GoRoute(
        path: AppRoutes.adminAnnounce,
        builder: (context, state) => const AdminGuard(child: AdminAnnouncePage()),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminGuard(child: AdminDashboardPage()),
      ),
      GoRoute(
        path: AppRoutes.phoneLogin,
        builder: (context, state) => const PhoneLoginPage(),
      ),

      // ── Seller Wall ───────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.sellerWall,
        name: AppRoutes.sellerWall,
        builder: (context, state) {
          final extra = state.extra as Map?;
          final sellerId = (extra?['sellerId']
                  ?? state.pathParameters['sellerId']
                  ?? '')
              .toString();
          final sellerName = (extra?['sellerName'] ?? '').toString();
          return SellerWallPage(sellerId: sellerId, sellerName: sellerName);
        },
      ),
      GoRoute(
        path: AppRoutes.sellerReviews,
        builder: (context, state) {
          final sellerId = state.pathParameters['sellerId'] ?? '';
          final extra = state.extra as Map?;
          final sellerName = (extra?['sellerName'] ?? '').toString();
          return SellerReviewsPage(sellerId: sellerId, sellerName: sellerName);
        },
      ),

      // ── Favorites ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.favorites,
        builder: (context, state) => const FavoritesPage(),
      ),

      // ── Notifications ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),

      // ── Chat ──────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final map = state.extra as Map<String, dynamic>?;
          if (map == null ||
              (map['chatId'] ?? '').toString().isEmpty ||
              (map['otherUserId'] ?? '').toString().isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Chat data missing')),
            );
          }
          return ChatPage(
            chatId: map['chatId'].toString(),
            otherUserId: map['otherUserId'].toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.chats,
        builder: (context, state) => const ChatListPage(),
      ),

      // ── Report ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.myModelRequests,
        builder: (context, state) => const MyModelRequestsPage(),
      ),
      GoRoute(
        path: AppRoutes.reportPage,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ReportPage(
            chatId: extra['chatId']?.toString(),
            otherUserId: (extra['otherUserId'] ?? '').toString(),
            otherUserName: (extra['otherUserName'] ?? '').toString(),
          );
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// ─── Convenience accessor ─────────────────────────────────────────────────────
// Used in main.dart for notification navigation outside widget tree.
// Set by MyMarketplaceApp after the router is created.
// Nullable — caller must null-check before use (router may not be ready yet).
GoRouter? _globalRouter;
GoRouter? get appRouter => _globalRouter;

void setGlobalRouter(GoRouter router) => _globalRouter = router;

// ─── Public Route Check ───────────────────────────────────────────────────────
// Routes accessible without login (guest browsing).
// Anything NOT in this list requires the user to be logged in.
bool _isPublicRoute(String location) {
  // Exact matches
  const exactPublic = {
    AppRoutes.home,
    AppRoutes.modelList,
    AppRoutes.modelListings,
    AppRoutes.seriesList,
    AppRoutes.sellerModels,
    AppRoutes.sellerProducts,
  };
  if (exactPublic.contains(location)) return true;

  // Prefix matches (path params)
  const prefixPublic = [
    '/product/',   // /product/:id
    '/brands/',    // /brands/:brand
    '/seller/',    // /seller/:sellerId
  ];
  return prefixPublic.any((p) => location.startsWith(p));
}
