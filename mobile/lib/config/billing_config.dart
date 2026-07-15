import 'dart:io';

/// In-app purchase product identifiers.
///
/// Create matching products before release:
/// - App Store Connect → Subscriptions → `com.mileagetracker.premium.monthly`
/// - Google Play Console → Subscriptions → `premium_monthly`
///
/// iOS simulator: enable `ios/Runner/Products.storekit` in Xcode scheme.
class BillingConfig {
  static const premiumMonthlyIos = 'com.mileagetracker.premium.monthly';
  static const premiumMonthlyAndroid = 'premium_monthly';

  static const fallbackPriceLabel = '\$4.99 / month';

  static Set<String> get productIds => {primaryProductId};

  static String get primaryProductId {
    if (Platform.isIOS) return premiumMonthlyIos;
    if (Platform.isAndroid) return premiumMonthlyAndroid;
    return premiumMonthlyIos;
  }
}