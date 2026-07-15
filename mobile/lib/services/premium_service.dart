import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumService {
  static const _premiumKey = 'premium_active';
  static const _autoDetectKey = 'autodetect_enabled';
  static const _billingKey = 'premium_from_billing';
  static const _purchaseIdKey = 'premium_purchase_id';

  bool isPremium = false;
  bool autoDetectEnabled = false;
  bool premiumFromBilling = false;
  String? purchaseId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium = prefs.getBool(_premiumKey) ?? false;
    autoDetectEnabled = prefs.getBool(_autoDetectKey) ?? false;
    premiumFromBilling = prefs.getBool(_billingKey) ?? false;
    purchaseId = prefs.getString(_purchaseIdKey);
  }

  Future<void> activateFromBilling(String? id) async {
    isPremium = true;
    premiumFromBilling = true;
    purchaseId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    await prefs.setBool(_billingKey, true);
    if (id != null) await prefs.setString(_purchaseIdKey, id);
  }

  Future<void> activateForDevelopment() async {
    if (!kDebugMode) return;
    isPremium = true;
    premiumFromBilling = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    await prefs.setBool(_billingKey, false);
  }

  Future<void> deactivatePremium() async {
    isPremium = false;
    autoDetectEnabled = false;
    premiumFromBilling = false;
    purchaseId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, false);
    await prefs.setBool(_autoDetectKey, false);
    await prefs.setBool(_billingKey, false);
    await prefs.remove(_purchaseIdKey);
  }

  Future<bool> setAutoDetect(bool enabled) async {
    if (!isPremium) return false;
    autoDetectEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDetectKey, enabled);
    return true;
  }

  Future<void> unlockForDevelopment() async {
    await activateForDevelopment();
  }
}