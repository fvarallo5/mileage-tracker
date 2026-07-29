import 'package:flutter/foundation.dart';

import 'supabase_config.dart';

/// App-wide constants for TrekTrack.
class AppConfig {
  static const privacyUrlOverride = String.fromEnvironment('PRIVACY_URL');
  static const termsUrlOverride = String.fromEnvironment('TERMS_URL');

  /// Prefer the marketing site.
  static const productionPrivacyUrl = 'https://trektrack.pro/privacy.html';
  static const productionTermsUrl = 'https://trektrack.pro/terms.html';

  /// Free tier: auto-detect trips allowed per calendar month.
  static const freeAutoTripsPerMonth = 30;

  /// Bump when legal copy changes (for future acceptance logging).
  static const legalTermsVersion = '1.1';
  static const legalPrivacyVersion = '1.2';

  static const legalEntityName = 'UltraForge LLC';
  static const legalEntityState = 'New Jersey';

  static bool get isRelease => kReleaseMode;

  static bool get isDebug => kDebugMode;

  static String get privacyPolicyUrl =>
      privacyUrlOverride.isNotEmpty ? privacyUrlOverride : productionPrivacyUrl;

  static String get termsOfServiceUrl =>
      termsUrlOverride.isNotEmpty ? termsUrlOverride : productionTermsUrl;

  static String get supabaseUrl => SupabaseConfig.url;

  static String get supportEmail => 'info@trektrack.pro';

  static String get websiteUrl => 'https://trektrack.pro';

  static String get appName => 'TrekTrack';

  static String get appTagline => 'Mileage tracking for gig drivers. Built for the road.';

  /// Shown near tax export, Pro paywall, and share sheets.
  static const taxDisclaimer =
      'Not tax, legal, or accounting advice. IRS rates and deduction totals are estimates. '
      'You are responsible for classifying miles and what you file. Confirm with a tax professional.';

  static const taxDisclaimerShort =
      'Not tax advice. Confirm rates and filings with a tax professional.';

  /// OSRM Match base (no trailing path). Override for self-hosted routing.
  static const osrmBaseUrlOverride = String.fromEnvironment('OSRM_BASE_URL');

  static String get osrmBaseUrl => osrmBaseUrlOverride.isNotEmpty
      ? osrmBaseUrlOverride
      : 'https://router.project-osrm.org';

  /// Max GPS samples sent to map-match (URL length + demo server limits).
  static const mapMatchMaxPoints = 80;

  static const mapMatchTimeout = Duration(seconds: 12);
}