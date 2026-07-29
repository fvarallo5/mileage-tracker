import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';

/// Pushes trip status to the phone home-screen widget (Android + iOS).
///
/// ## Differentiation roadmap (not this package)
/// CarPlay / Android Auto would be a separate native layer later — high impact
/// for full-time drivers. Home widgets ship first (fast path); in-car OS UIs
/// remain a planned differentiator after IAP launch.
class HomeWidgetService {
  HomeWidgetService._();

  static const androidWidgetName = 'TrekTrackWidgetProvider';
  static const iOSWidgetName = 'TrekTrackWidget';

  /// iOS App Group — must match Runner + Widget Extension entitlements.
  static const appGroupId = 'group.com.mileagetracker.mileageTracker';

  static bool _configured = false;
  static DateTime? _lastUpdate;

  static Future<void> ensureConfigured() async {
    if (_configured) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      _configured = true;
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidget configure: $e');
    }
  }

  /// Persist snapshot and request a native widget refresh.
  static Future<void> publish({
    required bool tracking,
    required double tripMiles,
    required List<Trip> trips,
  }) async {
    await ensureConfigured();

    // Throttle while GPS is live so we don't spam widget updates.
    final now = DateTime.now();
    if (_lastUpdate != null &&
        now.difference(_lastUpdate!) < const Duration(seconds: 2) &&
        tracking) {
      return;
    }
    _lastUpdate = now;

    final today = DateFormat('yyyy-MM-dd').format(now);
    final todayMiles = trips
        .where((t) => t.isBusiness && t.date == today)
        .fold<double>(0, (s, t) => s + t.miles);
    // Include in-progress trip miles for "today" display.
    final displayToday = todayMiles + (tracking ? tripMiles : 0);

    final status = tracking ? 'Tracking' : 'Ready';
    final tripLabel = tracking
        ? '${tripMiles.toStringAsFixed(1)} mi this trip'
        : 'Tap to open TrekTrack';
    final todayLabel = '${displayToday.toStringAsFixed(1)} mi today';

    try {
      await HomeWidget.saveWidgetData<bool>('tracking', tracking);
      await HomeWidget.saveWidgetData<String>('status', status);
      await HomeWidget.saveWidgetData<String>(
        'trip_miles',
        tripMiles.toStringAsFixed(1),
      );
      await HomeWidget.saveWidgetData<String>(
        'today_miles',
        displayToday.toStringAsFixed(1),
      );
      await HomeWidget.saveWidgetData<String>('trip_label', tripLabel);
      await HomeWidget.saveWidgetData<String>('today_label', todayLabel);
      await HomeWidget.saveWidgetData<String>(
        'action_label',
        tracking ? 'Stop trip' : 'Start trip',
      );

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
        qualifiedAndroidName:
            'com.mileagetracker.mileage_tracker.TrekTrackWidgetProvider',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidget publish: $e');
    }
  }
}
