class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String emailVerification = '/email-verification';
  static const String forceUpdate = '/force-update';
  static const String home = '/home';

  static const String product = '/product/:id';

  static const String ordersHub = '/orders';
  static const String buyerOrders = '/orders/buyer';
  static const String sellerOrders = '/orders/seller';
  static const String adminOrders = '/orders/admin';

  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String favorites = '/favorites';

  static const String addProduct = '/add-product';
  static const String editProduct = '/product/:id/edit';

  static const String manageBrands = '/admin/brands';
  static const String manageModels = '/admin/models';

  static const String orderForm = '/orders/new';
  static const String orderDetail = '/orders/:id';

  static const String notifications = '/notifications';

  static const String brandCollection = '/brands/:brand';

  static const String fixPhoneBrands = '/admin/fix-brands';
  static const String adminDashboard = '/admin/dashboard';

  // ⭐ Seller wall
  static const String sellerWall = '/seller/:sellerId';
  static const String sellerReviews = '/seller/:sellerId/reviews';

  // ─── Seller browse ─────────────────────────────────────────────────────────
  static const String sellerModels = '/seller-models';
  static const String sellerProducts = '/seller-products';

  // ─── Path helpers ──────────────────────────────────────────────────────────
  static String sellerWallPath(String sellerId) => '/seller/$sellerId';
  static String productPath(String id) => '/product/$id';
  static String editProductPath(String id) => '/product/$id/edit';
  static String orderDetailPath(String id) => '/orders/$id';
  static String pickupOtpPath(String id) => '/orders/$id/otp';
  static String brandCollectionPath(String brand) => '/brands/$brand';

  // ─── Admin ─────────────────────────────────────────────────────────────────
  static const String adminImeiReports = '/admin-imei-reports';
  static const String adminImeiVerification = '/admin-imei-verification';
  static const String adminModelRequests = '/admin-model-requests';
  static const String adminAddModel = '/admin-add-model';
  static const String adminUserReports = '/admin-user-reports';
  static const String adminBannedUsers = '/admin-banned-users';
  static const String adminPaymentSettings = '/admin/payment-settings';
  static const String adminShippingSettings = '/admin/shipping-settings';
  static const String adminFeeSettings = '/admin/fee-settings';
  static const String adminPendingFees = '/admin/pending-fees';
  static const String adminVerifySellers = '/admin/verify-sellers';
  static const String adminAnnounce      = '/admin/announce';

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static const String phoneLogin         = '/phone-login';

  // ─── Models / Series ───────────────────────────────────────────────────────
  static const String modelList = '/model-list';
  static const String modelListings = '/model-listings';
  static const String seriesList = '/series-list';

  // ─── Seller ────────────────────────────────────────────────────────────────
  static const String myModelRequests = '/my-model-requests';

  // ─── Chat ──────────────────────────────────────────────────────────────────
  static const String chat = '/chat';
  static const String chats = '/chats';

  // ─── Misc ──────────────────────────────────────────────────────────────────
  static const String reportPage = '/report';
}
