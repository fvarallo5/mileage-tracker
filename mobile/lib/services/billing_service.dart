import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/billing_config.dart';
import 'entitlement_service.dart';

class BillingService {
  BillingService(this._entitlements);

  final EntitlementService _entitlements;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Completer<String>? _purchaseCompleter;

  bool storeAvailable = false;
  bool loadingProducts = false;
  bool purchasing = false;
  bool restoring = false;
  String? lastError;

  ProductDetails? monthlyProduct;
  ProductDetails? annualProduct;

  bool preferAnnual = BillingConfig.defaultPreferAnnual;

  String monthlyPriceLabel = BillingConfig.fallbackMonthlyLabel;
  String annualPriceLabel = BillingConfig.fallbackYearlyLabel;
  String annualPerMonthLabel = BillingConfig.fallbackYearlyPerMonthLabel;

  String get priceLabel => preferAnnual ? annualPriceLabel : monthlyPriceLabel;

  ProductDetails? get selectedProduct =>
      preferAnnual ? (annualProduct ?? monthlyProduct) : (monthlyProduct ?? annualProduct);

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

  void setPreferAnnual(bool annual) {
    preferAnnual = annual;
    onChanged?.call();
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
      lastError = 'Pro subscription is not available in the store yet.';
      onChanged?.call();
      return;
    }

    monthlyProduct = null;
    annualProduct = null;
    for (final p in response.productDetails) {
      if (p.id == BillingConfig.monthlyProductId) {
        monthlyProduct = p;
        monthlyPriceLabel = '${p.price} / month';
      } else if (p.id == BillingConfig.yearlyProductId) {
        annualProduct = p;
        annualPriceLabel = '${p.price} / year';
        final micros = p.rawPrice;
        if (micros > 0) {
          final perMonth = micros / 12;
          annualPerMonthLabel =
              '${p.currencyCode} ${perMonth.toStringAsFixed(2)} / mo billed yearly';
        } else {
          annualPerMonthLabel = BillingConfig.fallbackYearlyPerMonthLabel;
        }
      }
    }

    if (preferAnnual && annualProduct == null && monthlyProduct != null) {
      preferAnnual = false;
    }
    if (!preferAnnual && monthlyProduct == null && annualProduct != null) {
      preferAnnual = true;
    }

    onChanged?.call();
  }

  Future<String> purchasePremium({bool? annual}) async {
    if (annual != null) preferAnnual = annual;

    if (!storeAvailable) {
      return 'App Store / Play Store billing is not available on this device.';
    }
    if (selectedProduct == null) {
      await loadProducts();
    }
    final product = selectedProduct;
    if (product == null) {
      return lastError ?? 'Pro subscription is not available.';
    }
    if (purchasing) return 'Purchase already in progress.';

    purchasing = true;
    lastError = null;
    _purchaseCompleter = Completer<String>();
    onChanged?.call();

    final param = PurchaseParam(productDetails: product);
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
      await _entitlements.reconcile();
      restoring = false;
      onChanged?.call();
      return '';
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    await _entitlements.reconcile();
    restoring = false;
    onChanged?.call();

    if (_entitlements.isPremium) {
      return 'Pro restored for this account.';
    }
    return 'No active Pro subscription found for this store account.';
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!BillingConfig.productIds.contains(purchase.productID)) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _entitlements.grantFromStore(
            productId: purchase.productID,
            purchaseId: purchase.purchaseID,
            purchaseToken: purchase.verificationData.serverVerificationData,
          );
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          purchasing = false;
          restoring = false;
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete(
              'Pro unlocked. Unlimited auto-detect and background GPS are on.',
            );
          }
          _purchaseCompleter = null;
          onChanged?.call();
        case PurchaseStatus.error:
          lastError = purchase.error?.message ?? 'Purchase failed';
          purchasing = false;
          restoring = false;
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete(lastError!);
          }
          _purchaseCompleter = null;
          onChanged?.call();
        case PurchaseStatus.canceled:
          purchasing = false;
          restoring = false;
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete('Purchase canceled.');
          }
          _purchaseCompleter = null;
          onChanged?.call();
      }
    }
  }

  Future<void> unlockForDevelopment() async {
    if (!kDebugMode) return;
    await _entitlements.grantDebug();
    onChanged?.call();
  }

  void dispose() {
    _purchaseSub?.cancel();
  }
}
