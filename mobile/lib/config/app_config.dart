import 'package:flutter/foundation.dart';

/// App-wide constants for dev vs App Store release builds.
class AppConfig {
  /// Set at build time: --dart-define=API_URL=https://your-api.com/api
  static const apiUrlOverride = String.fromEnvironment('API_URL');

  /// Set at build time: --dart-define=PRIVACY_URL=https://your-api.com/privacy
  static const privacyUrlOverride = String.fromEnvironment('PRIVACY_URL');

  /// Default production API — update after deploying to Render/Railway.
  static const productionApiUrl = 'https://mileage-tracker-api.onrender.com/api';

  /// Default privacy policy URL (served by backend).
  static const productionPrivacyUrl =
      'https://mileage-tracker-api.onrender.com/privacy';

  static bool get isRelease => kReleaseMode;

  static bool get isDebug => kDebugMode;

  static String get privacyPolicyUrl =>
      privacyUrlOverride.isNotEmpty ? privacyUrlOverride : productionPrivacyUrl;

  static String get supportEmail => 'support@mileagetracker.app';

  static String get appName => 'Mileage Tracker';
}