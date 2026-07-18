import 'package:flutter/foundation.dart';

import 'supabase_config.dart';

/// App-wide constants for TrekTrack.
class AppConfig {
  static const privacyUrlOverride = String.fromEnvironment('PRIVACY_URL');

  static const productionPrivacyUrl =
      'https://raw.githubusercontent.com/fvarallo5/mileage-tracker/main/static/privacy.html';

  /// Free tier: auto-detect trips allowed per calendar month.
  static const freeAutoTripsPerMonth = 30;

  static bool get isRelease => kReleaseMode;

  static bool get isDebug => kDebugMode;

  static String get privacyPolicyUrl =>
      privacyUrlOverride.isNotEmpty ? privacyUrlOverride : productionPrivacyUrl;

  static String get supabaseUrl => SupabaseConfig.url;

  static String get supportEmail => 'support@trektrack.app';

  static String get appName => 'TrekTrack';

  static String get appTagline => 'Audit-ready mileage. Built for the road.';
}