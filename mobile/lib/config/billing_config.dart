import 'dart:io';

/// In-app purchase product identifiers and paywall copy.
///
/// Create matching products before release:
/// - App Store Connect: com.mileagetracker.premium.monthly / .yearly
/// - Play Console: premium_monthly / premium_yearly
/// - 7-day free trial on both
class BillingConfig {
  static const premiumMonthlyIos = 'com.mileagetracker.premium.monthly';
  static const premiumYearlyIos = 'com.mileagetracker.premium.yearly';
  static const premiumMonthlyAndroid = 'premium_monthly';
  static const premiumYearlyAndroid = 'premium_yearly';

  static const trialDays = 7;

  static const fallbackMonthlyLabel = '\$3.99 / month';
  static const fallbackYearlyLabel = '\$29.99 / year';
  static const fallbackYearlyPerMonthLabel = '\$2.50 / mo billed yearly';

  static String get trialDetailLabel =>
      '$trialDays-day free trial, then billed. Cancel anytime.';

  static const defaultPreferAnnual = true;

  static String get monthlyProductId {
    if (Platform.isAndroid) return premiumMonthlyAndroid;
    return premiumMonthlyIos;
  }

  static String get yearlyProductId {
    if (Platform.isAndroid) return premiumYearlyAndroid;
    return premiumYearlyIos;
  }

  static Set<String> get productIds => {monthlyProductId, yearlyProductId};

  static const fallbackPriceLabel = fallbackMonthlyLabel;
}
