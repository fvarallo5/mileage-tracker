import 'package:flutter/material.dart';

import '../providers/app_state.dart';
import '../screens/location_permission_sheet.dart';

/// Shows the disclosure sheet, then requests OS permissions via [AppState].
class PremiumPermissionFlow {
  static Future<void> startManualTrip(BuildContext context, AppState state) async {
    if (state.isPremium) {
      final accepted = await showLocationPermissionExplainer(
        context,
        reason: LocationPermissionReason.backgroundTracking,
      );
      if (!accepted || !context.mounted) return;
    }

    await state.startTracking();
    if (!context.mounted) return;
    if (state.error != null) {
      _showPermissionSnackBar(context, state);
    }
  }

  static Future<void> setAutoDetect(
    BuildContext context,
    AppState state,
    bool enabled,
  ) async {
    if (!enabled) {
      await state.setAutoDetect(false);
      return;
    }

    if (!state.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-detect is a Premium feature.')),
      );
      return;
    }

    final accepted = await showLocationPermissionExplainer(
      context,
      reason: LocationPermissionReason.autoDetect,
    );
    if (!accepted || !context.mounted) return;

    final error = await state.enableAutoDetect();
    if (!context.mounted) return;
    if (error != null) {
      _showPermissionSnackBar(context, state, message: error);
    }
  }

  static void _showPermissionSnackBar(
    BuildContext context,
    AppState state, {
    String? message,
  }) {
    final text = message ?? state.error ?? 'Permission required';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    if (text.contains('Settings')) {
      state.openLocationSettings();
    }
  }
}