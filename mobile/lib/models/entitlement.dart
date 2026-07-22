/// How Pro was granted on this device / account.
enum PremiumSource {
  none,
  store,
  debug,
  server,
  manual,
}

/// Server + local representation of Pro access.
class Entitlement {
  final bool active;
  final PremiumSource source;
  final String? productId;
  final String? platform;
  final String? storePurchaseId;
  final String? period;
  final DateTime? expiresAt;
  final String? purchaseToken;
  final DateTime? updatedAt;

  const Entitlement({
    required this.active,
    this.source = PremiumSource.none,
    this.productId,
    this.platform,
    this.storePurchaseId,
    this.period,
    this.expiresAt,
    this.purchaseToken,
    this.updatedAt,
  });

  static const inactive = Entitlement(active: false);

  bool get isExpired {
    if (expiresAt == null) return false;
    return !expiresAt!.isAfter(DateTime.now().toUtc());
  }

  /// Effective Pro access (active and not past [expiresAt]).
  bool get isPremium => active && !isExpired;

  String get periodLabel {
    return switch (period) {
      'yearly' => 'Annual',
      'monthly' => 'Monthly',
      _ => productId != null && productId!.contains('year')
          ? 'Annual'
          : productId != null && productId!.contains('month')
              ? 'Monthly'
              : 'Pro',
    };
  }

  String get statusSubtitle {
    if (!isPremium) return 'Free plan';
    final plan = periodLabel;
    return switch (source) {
      PremiumSource.debug => 'Pro · debug unlock',
      PremiumSource.store => 'Pro · $plan (App Store / Play)',
      PremiumSource.server => 'Pro · $plan (account)',
      PremiumSource.manual => 'Pro · $plan',
      PremiumSource.none => 'Pro',
    };
  }

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'] as String?;
    final updatedRaw = json['updated_at'] as String?;
    return Entitlement(
      active: json['active'] as bool? ?? false,
      source: premiumSourceFromString(json['source'] as String?),
      productId: json['product_id'] as String?,
      platform: json['platform'] as String?,
      storePurchaseId: json['store_purchase_id'] as String?,
      period: json['period'] as String?,
      expiresAt: expiresRaw != null ? DateTime.tryParse(expiresRaw)?.toUtc() : null,
      purchaseToken: json['purchase_token'] as String?,
      updatedAt: updatedRaw != null ? DateTime.tryParse(updatedRaw)?.toUtc() : null,
    );
  }

  Map<String, dynamic> toUpsertPayload(String userId) {
    // DB check allows store|debug|server|manual — never write "none".
    final sourceName = switch (source) {
      PremiumSource.debug => 'debug',
      PremiumSource.manual => 'manual',
      _ => 'store',
    };
    return {
      'user_id': userId,
      'active': active,
      'product_id': productId,
      'platform': platform,
      'store_purchase_id': storePurchaseId,
      'source': sourceName,
      'period': period,
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'purchase_token': purchaseToken,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Entitlement copyWith({
    bool? active,
    PremiumSource? source,
    String? productId,
    String? platform,
    String? storePurchaseId,
    String? period,
    DateTime? expiresAt,
    String? purchaseToken,
    DateTime? updatedAt,
  }) {
    return Entitlement(
      active: active ?? this.active,
      source: source ?? this.source,
      productId: productId ?? this.productId,
      platform: platform ?? this.platform,
      storePurchaseId: storePurchaseId ?? this.storePurchaseId,
      period: period ?? this.period,
      expiresAt: expiresAt ?? this.expiresAt,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

PremiumSource premiumSourceFromString(String? value) {
  return switch (value) {
    'store' => PremiumSource.store,
    'debug' => PremiumSource.debug,
    'server' => PremiumSource.server,
    'manual' => PremiumSource.manual,
    _ => PremiumSource.none,
  };
}

/// Infer monthly vs yearly from a store product id.
String? periodFromProductId(String? productId) {
  if (productId == null) return null;
  final id = productId.toLowerCase();
  if (id.contains('year') || id.contains('annual')) return 'yearly';
  if (id.contains('month')) return 'monthly';
  return null;
}
