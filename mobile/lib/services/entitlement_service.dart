import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/entitlement.dart';
import 'premium_service.dart';
import 'supabase_service.dart';

/// Reconciles local Pro state with Supabase [entitlements].
///
/// Flow:
/// 1. Load SharedPreferences (instant)
/// 2. Pull server row for this auth user (multi-device / reinstall)
/// 3. Push local store/debug grants so the account stays Pro
class EntitlementService {
  EntitlementService(this._premium, this._supabase);

  final PremiumService _premium;
  final SupabaseService _supabase;

  String? lastSyncError;
  DateTime? lastSyncedAt;
  bool syncing = false;

  PremiumService get premium => _premium;
  bool get isPremium => _premium.isPremium;
  Entitlement get entitlement => _premium.entitlement;

  Future<void> loadLocal() => _premium.load();

  /// Full reconcile: pull server, then push local store/debug if needed.
  Future<void> reconcile() async {
    if (syncing) return;
    syncing = true;
    lastSyncError = null;
    try {
      final remote = await _supabase.fetchEntitlement();
      await _merge(remote);
      lastSyncedAt = DateTime.now().toUtc();
    } on EntitlementSyncException catch (e) {
      lastSyncError = e.message;
      if (kDebugMode) {
        debugPrint('Entitlement sync: ${e.message}');
      }
    } catch (e) {
      lastSyncError = e.toString();
      if (kDebugMode) {
        debugPrint('Entitlement sync failed: $e');
      }
    } finally {
      syncing = false;
    }
  }

  Future<void> grantFromStore({
    required String productId,
    String? purchaseId,
    String? purchaseToken,
    DateTime? expiresAt,
  }) async {
    final platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : 'unknown';
    await _premium.activateFromBilling(
      purchaseId: purchaseId,
      productId: productId,
      platform: platform,
      purchaseToken: purchaseToken,
      expiresAt: expiresAt,
    );
    await pushLocalToServer();
  }

  Future<void> grantDebug() async {
    await _premium.unlockForDevelopment();
    await pushLocalToServer();
  }

  /// Upload current local grant (or clear) to Supabase.
  Future<void> pushLocalToServer() async {
    try {
      final local = _premium.entitlement;
      if (!local.isPremium) {
        await _supabase.upsertEntitlement(
          const Entitlement(active: false, source: PremiumSource.store),
        );
      } else {
        // Server stores store/debug; never label client push as "server".
        final source = local.source == PremiumSource.server
            ? PremiumSource.store
            : local.source == PremiumSource.none
                ? PremiumSource.store
                : local.source;
        await _supabase.upsertEntitlement(
          local.copyWith(source: source, active: true),
        );
      }
      lastSyncError = null;
      lastSyncedAt = DateTime.now().toUtc();
    } on EntitlementSyncException catch (e) {
      lastSyncError = e.message;
    } catch (e) {
      lastSyncError = e.toString();
    }
  }

  Future<void> _merge(Entitlement? remote) async {
    final local = _premium.entitlement;
    final localHard =
        local.isPremium &&
        (local.source == PremiumSource.store ||
            local.source == PremiumSource.debug);

    // Local store / debug always wins and is pushed so the account matches.
    if (localHard) {
      await pushLocalToServer();
      return;
    }

    if (remote != null && remote.isPremium) {
      await _premium.applyFromServer(remote);
      return;
    }

    // Server inactive / missing and local was only from a prior server grant.
    if (local.isPremium && local.source == PremiumSource.server) {
      await _premium.deactivatePremium();
      return;
    }

    // Local free, remote free — nothing to do.
    // Local free, remote missing — nothing to do.
  }
}

class EntitlementSyncException implements Exception {
  final String message;
  EntitlementSyncException(this.message);

  @override
  String toString() => message;
}
