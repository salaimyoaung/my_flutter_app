import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logHomeView() {
    return _analytics.logEvent(name: 'home_view');
  }

  static Future<void> logFilterOpen() {
    return _analytics.logEvent(name: 'filter_open');
  }

  static Future<void> logFilterOptionChange({
    required String type,
    required String value,
  }) {
    return _analytics.logEvent(
      name: 'filter_option_change',
      parameters: {
        'type': type,
        'value': value,
      },
    );
  }

  static Future<void> logFilterApply({
    required int selectedCount,
  }) {
    return _analytics.logEvent(
      name: 'filter_apply',
      parameters: {
        'selected_count': selectedCount,
      },
    );
  }

  static Future<void> logFilterClear() {
    return _analytics.logEvent(name: 'filter_clear');
  }

  static Future<void> logFilterCancel() {
    return _analytics.logEvent(name: 'filter_cancel');
  }

  static Future<void> logProductImpression({
    required String productId,
  }) {
    return _analytics.logEvent(
      name: 'product_impression',
      parameters: {
        'product_id': productId,
      },
    );
  }

  static Future<void> logProductClick({
    required String productId,
  }) {
    return _analytics.logEvent(
      name: 'product_click',
      parameters: {
        'product_id': productId,
      },
    );
  }

  static Future<void> logFavoriteAdd({
    required String productId,
  }) {
    return _analytics.logEvent(
      name: 'favorite_add',
      parameters: {
        'product_id': productId,
      },
    );
  }

  static Future<void> logQuickExit({
    required String productId,
    required int seconds,
  }) {
    return _analytics.logEvent(
      name: 'quick_exit',
      parameters: {
        'product_id': productId,
        'seconds': seconds,
      },
    );
  }
}
