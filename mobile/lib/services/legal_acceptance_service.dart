import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/legal_acceptance.dart';
import 'supabase_service.dart';

/// Tracks Terms + Privacy acceptance on-device and in Supabase.
///
/// Local prefs drive the UI gate. Server tables store durable evidence
/// (latest row + append-only events). Re-prompts when [AppConfig] versions bump.
class LegalAcceptanceService extends ChangeNotifier {
  static const _termsKey = 'legal_accepted_terms_version';
  static const _privacyKey = 'legal_accepted_privacy_version';
  static const _atKey = 'legal_accepted_at';
  static const _platformKey = 'legal_accepted_platform';
  static const _appVersionKey = 'legal_accepted_app_version';

  final SupabaseService _supabase = SupabaseService();

  bool loaded = false;
  bool reconciling = false;
  String? lastSyncError;

  String? acceptedTermsVersion;
  String? acceptedPrivacyVersion;
  DateTime? acceptedAt;
  String? acceptedPlatform;
  String? acceptedAppVersion;

  bool get hasAcceptedCurrent =>
      acceptedTermsVersion == AppConfig.legalTermsVersion &&
      acceptedPrivacyVersion == AppConfig.legalPrivacyVersion;

  LegalAcceptance? get currentRecord {
    if (acceptedTermsVersion == null ||
        acceptedPrivacyVersion == null ||
        acceptedAt == null) {
      return null;
    }
    return LegalAcceptance(
      termsVersion: acceptedTermsVersion!,
      privacyVersion: acceptedPrivacyVersion!,
      acceptedAt: acceptedAt!,
      platform: acceptedPlatform,
      appVersion: acceptedAppVersion,
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    acceptedTermsVersion = prefs.getString(_termsKey);
    acceptedPrivacyVersion = prefs.getString(_privacyKey);
    final at = prefs.getString(_atKey);
    acceptedAt = at != null ? DateTime.tryParse(at)?.toUtc() : null;
    acceptedPlatform = prefs.getString(_platformKey);
    acceptedAppVersion = prefs.getString(_appVersionKey);
    loaded = true;
    notifyListeners();
  }

  /// Accept current legal versions, persist locally, and log to the server.
  Future<void> acceptCurrent() async {
    final now = DateTime.now().toUtc();
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
    } catch (_) {}

    final platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : 'other';

    final record = LegalAcceptance(
      termsVersion: AppConfig.legalTermsVersion,
      privacyVersion: AppConfig.legalPrivacyVersion,
      acceptedAt: now,
      platform: platform,
      appVersion: appVersion,
    );

    await _persistLocal(record);
    await _pushToServer(record);
    notifyListeners();
  }

  /// After sign-in: pull server record if it satisfies current versions,
  /// otherwise push local acceptance if we already have one.
  Future<void> reconcileWithServer() async {
    if (reconciling) return;
    reconciling = true;
    lastSyncError = null;
    notifyListeners();

    try {
      await load();

      LegalAcceptance? remote;
      try {
        remote = await _supabase.fetchLegalAcceptance();
      } catch (e) {
        lastSyncError = e.toString();
        if (kDebugMode) debugPrint('LegalAcceptance fetch: $e');
      }

      if (remote != null &&
          remote.termsVersion == AppConfig.legalTermsVersion &&
          remote.privacyVersion == AppConfig.legalPrivacyVersion) {
        await _persistLocal(remote);
        lastSyncError = null;
        return;
      }

      if (hasAcceptedCurrent) {
        final local = currentRecord;
        if (local != null) {
          await _pushToServer(local);
        }
      }
    } finally {
      reconciling = false;
      notifyListeners();
    }
  }

  Future<void> _persistLocal(LegalAcceptance record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_termsKey, record.termsVersion);
    await prefs.setString(_privacyKey, record.privacyVersion);
    await prefs.setString(_atKey, record.acceptedAt.toUtc().toIso8601String());
    if (record.platform != null) {
      await prefs.setString(_platformKey, record.platform!);
    }
    if (record.appVersion != null) {
      await prefs.setString(_appVersionKey, record.appVersion!);
    }
    acceptedTermsVersion = record.termsVersion;
    acceptedPrivacyVersion = record.privacyVersion;
    acceptedAt = record.acceptedAt;
    acceptedPlatform = record.platform;
    acceptedAppVersion = record.appVersion;
  }

  Future<void> _pushToServer(LegalAcceptance record) async {
    try {
      await _supabase.upsertLegalAcceptance(record);
      lastSyncError = null;
    } catch (e) {
      lastSyncError = e.toString();
      if (kDebugMode) debugPrint('LegalAcceptance push: $e');
    }
  }
}
