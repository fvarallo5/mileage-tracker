import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/billing_config.dart';
import 'premium_service.dart';

class BillingService {
  BillingService(this._premium);

  final PremiumService _premium;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Completer<String>? _purchaseCompleter;

  bool storeAvailable = false;
  bool loadingProducts = false;
  bool purchasing = false;
  bool restoring = false;
  String? lastError;
  ProductDetails? product;
  String priceLabel = BillingConfig.fallbackPriceLabel;

  void Function()? onChanged;

  Future<void> initialize() async {
    storeAvailable = await _iap.isAvailable();
    if (!storeAvailable) return;

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) {
        lastError = error.toString();
        purchasing = false;
        restoring = false;
        _purchaseCompleter?.complete('Purchase failed: $error');
        _purchaseCompleter = null;
        onChanged?.call();
      },
    );

    await loadProducts();
    await restorePurchases(silent: true);
  }

  Future<void> loadProducts() async {
    if (!storeAvailable) return;

    loadingProducts = true;
    lastError = null;
    onChanged?.call();

    final response = await _iap.queryProductDetails(BillingConfig.productIds);
    loadingProducts = false;

    if (response.error != null) {
      lastError = response.error!.message;
      onChanged?.call();
      return;
    }

    if (response.productDetails.isEmpty) {
      lastError = 'Premium subscription is not available in the store yet.';
      onChanged?.call();
      return;
    }

    product = response.productDetails.first;
    priceLabel = '${product!.price} / month';
    onChanged?.call();
  }

  Future<String> purchasePremium() async {
    if (!storeAvailable) {
      return 'App Store / Play Store billing is not available on this device.';
    }
    if (product == null) {
      await loadProducts();
    }
    if (product == null) {
      return lastError ?? 'Premium subscription is not available.';
    }
    if (purchasing) return 'Purchase already in progress.';

    purchasing = true;
    lastError = null;
    _purchaseCompleter = Completer<String>();
    onChanged?.call();

    final param = PurchaseParam(productDetails: product!);
    final started = await _iap.buyNonConsumable(purchaseParam: param);
    if (!started) {
      purchasing = false;
      _purchaseCompleter = null;
      onChanged?.call();
      return 'Could not start purchase. Try again.';
    }

    return _purchaseCompleter!.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        purchasing = false;
        onChanged?.call();
        return 'Purchase timed out. Check your subscription in the store app.';
      },
    );
  }

  Future<String> restorePurchases({bool silent = false}) async {
    if (!storeAvailable) {
      return silent ? '' : 'App Store / Play Store billing is not available.';
    }

    restoring = !silent;
    lastError = null;
    onChanged?.call();

    await _iap.restorePurchases();

    if (silent) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      restoring = false;
      onChanged?.call();
      return '';
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    restoring = false;
    onChanged?.call();

    if (_premium.isPremium && _premium.premiumFromBilling) {
      return 'Premium subscription restored.';
    }
    return 'No active Premium subscription found for this account.';
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (!BillingConfig.productIds.contains(purchase.productID)) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _premium.activateFromBilling(purchase.purchaseID);
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          purchasing = false;
          restoring = false;
          _purchaseCompleter?.complete('Premium activated. Background GPS and auto-detect are now available.');
          _purchaseCompleter = null;
          onChanged?.call();
        case PurchaseStatus.error:
          lastError = purchase.error?.message ?? 'Purchase failed';
          purchasing = false;
          restoring = false;
          _purchaseCompleter?.complete(lastError!);
          _purchaseCompleter = null;
          onChanged?.call();
        case PurchaseStatus.canceled:
          purchasing = false;
          restoring = false;
          _purchaseCompleter?.complete('Purchase canceled.');
          _purchaseCompleter = null;
          onChanged?.call();
      }
    }
  }

  Future<void> unlockForDevelopment() async {
    if (!kDebugMode) return;
    await _premium.unlockForDevelopment();
    onChanged?.call();
  }

  void dispose() {
    _purchaseSub?.cancel();
  }
}