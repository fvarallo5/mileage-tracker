import 'package:flutter/foundation.dart';

import 'supabase_config.dart';

/// App-wide constants for TrekTrack.
class AppConfig {
  static const privacyUrlOverride = String.fromEnvironment('PRIVACY_URL');

  /// Prefer the marketing site; jsDelivr fallback if DNS is not pointed yet.
  static const productionPrivacyUrl = 'https://trektrack.pro/privacy.html';

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

  /// OSRM Match base (no trailing path). Override for self-hosted routing.
  static const osrmBaseUrlOverride = String.fromEnvironment('OSRM_BASE_URL');

  static String get osrmBaseUrl => osrmBaseUrlOverride.isNotEmpty
      ? osrmBaseUrlOverride
      : 'https://router.project-osrm.org';

  /// Max GPS samples sent to map-match (URL length + demo server limits).
  static const mapMatchMaxPoints = 80;

  static const mapMatchTimeout = Duration(seconds: 12);
}