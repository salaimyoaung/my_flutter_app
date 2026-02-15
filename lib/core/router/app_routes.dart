class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String product = '/product/:id';
  static const String ordersHub = '/orders';
  static const String buyerOrders = '/orders/buyer';
  static const String sellerOrders = '/orders/seller';
  static const String adminOrders = '/orders/admin';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String addProduct = '/add-product';
  static const String editProduct = '/product/:id/edit';
  static const String manageBrands = '/admin/brands';
  static const String manageModels = '/admin/models';
  static const String orderForm = '/orders/new';
  static const String orderDetail = '/orders/:id';
  static const String pickupOtp = '/orders/:id/otp';
  static const String notifications = '/notifications';
  static const String brandCollection = '/brands/:brand';
  static const String fixPhoneBrands = '/admin/fix-brands';

  static String productPath(String id) => '/product/$id';
  static String editProductPath(String id) => '/product/$id/edit';
  static String orderDetailPath(String id) => '/orders/$id';
  static String pickupOtpPath(String id) => '/orders/$id/otp';
  static String brandCollectionPath(String brand) => '/brands/$brand';
}
