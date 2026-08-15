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
          'Drive-focused GPS: lower idle cost, solid accuracy while tracking. '
          'Default for soft launch.',
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
            distanceFilter: 100,
          ),
        // Was medium/40 — too chatty for all-day background GPS on iOS.
        BatteryMode.balanced => const LocationSettings(
            accuracy: LocationAccuracy.low,
            distanceFilter: 75,
          ),
        BatteryMode.accuracy => const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 30,
          ),
      };

  /// Location settings while a trip is active.
  LocationSettings get activeLocationSettings => switch (this) {
        BatteryMode.batterySaver => const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 40,
          ),
        // high/15 → medium/25: still audit-friendly, fewer wakeups.
        BatteryMode.balanced => const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 25,
          ),
        BatteryMode.accuracy => const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
      };

  /// Let iOS pause GPS when the device is still (idle watch only).
  /// Active trips keep this false so traffic crawls still record.
  bool get idlePauseLocationUpdatesAutomatically => switch (this) {
        BatteryMode.batterySaver => true,
        BatteryMode.balanced => true,
        BatteryMode.accuracy => false,
      };

  /// How long speed must stay high before starting a trip.
  int get startConfirmSeconds => switch (this) {
        BatteryMode.batterySaver => 40,
        BatteryMode.balanced => 30,
        BatteryMode.accuracy => 18,
      };

  /// How long speed must stay low (and little displacement) before ending.
  int get stopConfirmSeconds => switch (this) {
        BatteryMode.batterySaver => 150,
        BatteryMode.balanced => 90,
        BatteryMode.accuracy => 60,
      };

  /// Faster end when motion looks like walking after a real drive.
  int get walkTailStopConfirmSeconds => switch (this) {
        BatteryMode.batterySaver => 90,
        BatteryMode.balanced => 75,
        BatteryMode.accuracy => 50,
      };

  /// Android idle poll interval while watching for a drive.
  int get idleIntervalSeconds => switch (this) {
        BatteryMode.batterySaver => 25,
        BatteryMode.balanced => 18,
        BatteryMode.accuracy => 10,
      };

  /// Android poll interval while a trip is actively recording miles.
  int get activeIntervalSeconds => switch (this) {
        BatteryMode.batterySaver => 8,
        BatteryMode.balanced => 5,
        BatteryMode.accuracy => 2,
      };

  /// Auto-detect: ignore "parked" until the trip has run at least this long.
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

  /// Sustained speed (m/s) to treat motion as a vehicle start.
  /// Balanced ~11 mph — above jogging / brisk walk with GPS noise.
  double get startSpeedMps => switch (this) {
        BatteryMode.batterySaver => 5.5,
        BatteryMode.balanced => 5.0,
        BatteryMode.accuracy => 4.0,
      };

  /// Ground that must be covered during start confirmation (meters).
  double get minStartDistanceMeters => switch (this) {
        BatteryMode.batterySaver => 140,
        BatteryMode.balanced => 120,
        BatteryMode.accuracy => 90,
      };

  /// Below this (m/s) counts as parked crawl for stop detection (~3.4 mph).
  double get stopSpeedMps => switch (this) {
        BatteryMode.batterySaver => 1.5,
        BatteryMode.balanced => 1.5,
        BatteryMode.accuracy => 1.4,
      };

  /// Walking / pedestrian band: above stopSpeed, below this (~6.5 mph).
  double get walkSpeedCeilingMps => switch (this) {
        BatteryMode.batterySaver => 2.8,
        BatteryMode.balanced => 2.9,
        BatteryMode.accuracy => 2.6,
      };

  /// Segments slower than this (m/s) don't add miles on auto-started trips.
  /// ~7.5 mph — cuts walk tails while keeping traffic crawls if device reports
  /// slightly higher. Manual GPS trips still count all accepted segments.
  double get minSegmentSpeedMpsForAutoMiles => switch (this) {
        BatteryMode.batterySaver => 3.5,
        BatteryMode.balanced => 3.3,
        BatteryMode.accuracy => 2.5,
      };
}
