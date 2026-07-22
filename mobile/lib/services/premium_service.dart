import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entitlement.dart';

/// Pro unlocks unlimited auto-detect trips + background-priority tracking.
/// Free tier includes auto-detect with a monthly trip limit.
///
/// Local cache is always loaded first; [EntitlementService] reconciles with Supabase.
class PremiumService {
  static const _premiumKey = 'premium_active';
  static const _autoDetectKey = 'autodetect_enabled';
  static const _billingKey = 'premium_from_billing';
  static const _purchaseIdKey = 'premium_purchase_id';
  static const _productIdKey = 'premium_product_id';
  static const _platformKey = 'premium_platform';
  static const _sourceKey = 'premium_source';
  static const _periodKey = 'premium_period';
  static const _expiresKey = 'premium_expires_at';
  static const _tokenKey = 'premium_purchase_token';

  Entitlement entitlement = Entitlement.inactive;
  bool autoDetectEnabled = false;

  bool get isPremium => entitlement.isPremium;
  bool get premiumFromBilling =>
      entitlement.source == PremiumSource.store ||
      entitlement.source == PremiumSource.server;
  String? get purchaseId => entitlement.storePurchaseId;
  String? get productId => entitlement.productId;
  PremiumSource get source => entitlement.source;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    autoDetectEnabled = prefs.getBool(_autoDetectKey) ?? false;

    final active = prefs.getBool(_premiumKey) ?? false;
    if (!active) {
      entitlement = Entitlement.inactive;
      return;
    }

    final expiresRaw = prefs.getString(_expiresKey);
    entitlement = Entitlement(
      active: true,
      source: premiumSourceFromString(prefs.getString(_sourceKey)) ==
              PremiumSource.none
          ? (prefs.getBool(_billingKey) == true
              ? PremiumSource.store
              : PremiumSource.manual)
          : premiumSourceFromString(prefs.getString(_sourceKey)),
      productId: prefs.getString(_productIdKey),
      platform: prefs.getString(_platformKey),
      storePurchaseId: prefs.getString(_purchaseIdKey),
      period: prefs.getString(_periodKey),
      expiresAt:
          expiresRaw != null ? DateTime.tryParse(expiresRaw)?.toUtc() : null,
      purchaseToken: prefs.getString(_tokenKey),
    );

    if (entitlement.isExpired) {
      await deactivatePremium();
    }
  }

  Future<void> applyEntitlement(Entitlement next) async {
    if (!next.isPremium) {
      await deactivatePremium();
      return;
    }
    entitlement = next.copyWith(active: true);
    await _persist();
  }

  Future<void> activateFromBilling({
    required String? purchaseId,
    required String productId,
    required String platform,
    String? purchaseToken,
    DateTime? expiresAt,
  }) async {
    await applyEntitlement(
      Entitlement(
        active: true,
        source: PremiumSource.store,
        productId: productId,
        platform: platform,
        storePurchaseId: purchaseId,
        period: periodFromProductId(productId),
        purchaseToken: purchaseToken,
        expiresAt: expiresAt,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> applyFromServer(Entitlement remote) async {
    if (!remote.isPremium) {
      if (entitlement.source == PremiumSource.server ||
          entitlement.source == PremiumSource.none) {
        await deactivatePremium();
      }
      return;
    }
    await applyEntitlement(
      remote.copyWith(active: true, source: PremiumSource.server),
    );
  }

  Future<void> activateForDevelopment() async {
    if (!kDebugMode) return;
    await applyEntitlement(
      Entitlement(
        active: true,
        source: PremiumSource.debug,
        platform: 'debug',
        period: 'yearly',
        productId: 'debug.pro',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> deactivatePremium() async {
    entitlement = Entitlement.inactive;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, false);
    await prefs.setBool(_billingKey, false);
    await prefs.remove(_purchaseIdKey);
    await prefs.remove(_productIdKey);
    await prefs.remove(_platformKey);
    await prefs.remove(_sourceKey);
    await prefs.remove(_periodKey);
    await prefs.remove(_expiresKey);
    await prefs.remove(_tokenKey);
  }

  Future<bool> setAutoDetect(bool enabled) async {
    autoDetectEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDetectKey, enabled);
    return true;
  }

  Future<void> unlockForDevelopment() async {
    await activateForDevelopment();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final e = entitlement;
    await prefs.setBool(_premiumKey, e.isPremium);
    await prefs.setBool(
      _billingKey,
      e.source == PremiumSource.store || e.source == PremiumSource.server,
    );
    await prefs.setString(_sourceKey, e.source.name);
    if (e.storePurchaseId != null) {
      await prefs.setString(_purchaseIdKey, e.storePurchaseId!);
    } else {
      await prefs.remove(_purchaseIdKey);
    }
    if (e.productId != null) {
      await prefs.setString(_productIdKey, e.productId!);
    } else {
      await prefs.remove(_productIdKey);
    }
    if (e.platform != null) {
      await prefs.setString(_platformKey, e.platform!);
    } else {
      await prefs.remove(_platformKey);
    }
    if (e.period != null) {
      await prefs.setString(_periodKey, e.period!);
    } else {
      await prefs.remove(_periodKey);
    }
    if (e.expiresAt != null) {
      await prefs.setString(_expiresKey, e.expiresAt!.toUtc().toIso8601String());
    } else {
      await prefs.remove(_expiresKey);
    }
    if (e.purchaseToken != null) {
      await prefs.setString(_tokenKey, e.purchaseToken!);
    } else {
      await prefs.remove(_tokenKey);
    }
  }
}
