import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// User-selectable power / GPS sampling policy.
enum BatteryMode {
  batterySaver,
  balanced,
  accuracy,
}

extension BatteryModeX on BatteryMode {
  String get label => switch (this) {
        BatteryMode.batterySaver => 'Battery saver',
        BatteryMode.balanced => 'Balanced',
        BatteryMode.accuracy => 'Accuracy',
      };

  String get description => switch (this) {
        BatteryMode.batterySaver =>
          'Sparse GPS, longer confirm times. Best for full-shift auto-detect.',
        BatteryMode.balanced =>
          'Motion-friendly GPS while driving. Good everyday default.',
        BatteryMode.accuracy =>
          'Tighter sampling for audit-critical days. Uses more battery.',
      };

  IconData get icon => switch (this) {
        BatteryMode.batterySaver => Icons.battery_saver_outlined,
        BatteryMode.balanced => Icons.balance_outlined,
        BatteryMode.accuracy => Icons.gps_fixed,
      };

  /// Location settings while watching for a trip (idle auto-detect).
  LocationSettings get idleLocationSettings => switch (this) {
        BatteryMode.batterySaver => const LocationSettings(
            accuracy: LocationAccuracy.low,
            distanceFilter: 80,
          ),
        BatteryMode.balanced => const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 40,
          ),
        BatteryMode.accuracy => const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          ),
      };

  /// Location settings while a trip is active.
  LocationSettings get activeLocationSettings => switch (this) {
        BatteryMode.batterySaver => const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 40,
          ),
        BatteryMode.balanced => const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
          ),
        BatteryMode.accuracy => const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
      };

  /// How long speed must stay high before starting a trip.
  int get startConfirmSeconds => switch (this) {
        BatteryMode.batterySaver => 35,
        BatteryMode.balanced => 25,
        BatteryMode.accuracy => 18,
      };

  /// How long speed must stay low (and little displacement) before ending.
  int get stopConfirmSeconds => switch (this) {
        BatteryMode.batterySaver => 210,
        BatteryMode.balanced => 150,
        BatteryMode.accuracy => 100,
      };

  /// Android idle poll interval while watching for a drive.
  int get idleIntervalSeconds => switch (this) {
        BatteryMode.batterySaver => 20,
        BatteryMode.balanced => 12,
        BatteryMode.accuracy => 8,
      };
}