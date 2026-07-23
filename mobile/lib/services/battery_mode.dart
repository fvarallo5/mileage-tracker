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

  /// Android poll interval while a trip is actively recording miles.
  int get activeIntervalSeconds => switch (this) {
        BatteryMode.batterySaver => 8,
        BatteryMode.balanced => 4,
        BatteryMode.accuracy => 2,
      };

  /// Auto-detect: ignore "parked" until the trip has run at least this long.
  /// Prevents traffic-light false ends right after start.
  int get minActiveTripSeconds => switch (this) {
        BatteryMode.batterySaver => 120,
        BatteryMode.balanced => 90,
        BatteryMode.accuracy => 60,
      };

  /// Auto-detect: also require this much ground before auto-stop is allowed.
  double get minActiveTripMeters => switch (this) {
        BatteryMode.batterySaver => 250,
        BatteryMode.balanced => 180,
        BatteryMode.accuracy => 120,
      };
}