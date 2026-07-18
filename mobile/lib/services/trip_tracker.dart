import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/geo_point.dart';
import 'battery_mode.dart';

class TripTracker {
  static const _activeKey = 'tracking_active';
  static const _milesKey = 'tracking_miles';
  static const _backgroundKey = 'tracking_background';
  static const _autoKey = 'tracking_auto';

  /// Reject GPS fixes worse than this (meters) — cuts noise without more samples.
  static const _maxAccuracyMeters = 45.0;

  /// Reject jumps that imply > ~120 mph (teleport / multipath glitches).
  static const _maxSpeedMps = 53.0;

  StreamSubscription<Position>? _subscription;
  final List<Position> _positions = [];
  double _miles = 0;
  bool _tracking = false;
  bool _background = false;
  bool _autoStarted = false;
  void Function(Position position)? onPosition;

  bool get isTracking => _tracking;
  bool get isBackground => _background;
  bool get isAutoStarted => _autoStarted;
  double get currentMiles => _miles;
  int get positionCount => _positions.length;

  Future<String?> requestForegroundPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Please turn on Location Services';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Location permission denied';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. Enable in Settings.';
    }
    return null;
  }

  Future<String?> requestBackgroundPermission() async {
    final foregroundError = await requestForegroundPermission();
    if (foregroundError != null) return foregroundError;

    if (Platform.isAndroid) {
      final status = await Permission.locationAlways.status;
      if (status.isDenied) {
        final result = await Permission.locationAlways.request();
        if (!result.isGranted) {
          return 'Background location is required for auto-detect and Pro tracking. Enable "Allow all the time" in Settings.';
        }
      }
      if (status.isPermanentlyDenied) {
        return 'Background location is required. Enable it in Android Settings.';
      }
    }

    if (Platform.isIOS) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse) {
        return 'Background tracking requires "Always" location access. Enable it in Settings → ${AppConfig.appName} → Location → Always.';
      }
      if (permission != LocationPermission.always) {
        return 'Location permission is required for background tracking.';
      }
    }

    return null;
  }

  BatteryMode _batteryMode = BatteryMode.batterySaver;

  Future<void> restoreSession({BatteryMode batteryMode = BatteryMode.batterySaver}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activeKey) ?? false)) return;

    _miles = prefs.getDouble(_milesKey) ?? 0;
    _background = prefs.getBool(_backgroundKey) ?? false;
    _autoStarted = prefs.getBool(_autoKey) ?? false;
    _tracking = true;
    _batteryMode = batteryMode;
    await _beginStream(background: _background);
  }

  Future<void> start({
    bool background = false,
    bool autoStarted = false,
    BatteryMode batteryMode = BatteryMode.batterySaver,
  }) async {
    if (_tracking) return;

    _positions.clear();
    _miles = 0;
    _tracking = true;
    _background = background;
    _autoStarted = autoStarted;
    _batteryMode = batteryMode;
    await _beginStream(background: background);
    await _persistSession();
  }

  Future<void> _beginStream({required bool background}) async {
    await _subscription?.cancel();

    final settings = _buildSettings(background: background);
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen((position) {
      _onPosition(position);
      onPosition?.call(position);
    });
  }

  LocationSettings _buildSettings({required bool background}) {
    final base = _batteryMode.activeLocationSettings;

    if (Platform.isAndroid) {
      // Always attach a foreground service notification while tracking so GPS
      // keeps running and the system shows an ongoing lock-screen entry.
      return AndroidSettings(
        accuracy: base.accuracy,
        distanceFilter: base.distanceFilter,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: AppConfig.appName,
          notificationText: background
              ? 'Tracking trip · ${_batteryMode.label}'
              : 'GPS active · ${_batteryMode.label}',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: base.accuracy,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: base.distanceFilter,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: background,
        allowBackgroundLocationUpdates: background,
      );
    }

    return base;
  }

  void _onPosition(Position position) {
    if (!_tracking) return;

    // Accuracy gate: ignore noisy fixes (no extra GPS work).
    if (position.accuracy > _maxAccuracyMeters) return;

    if (_positions.isNotEmpty) {
      final last = _positions.last;
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );

      // Teleport / multipath filter using time between samples when available.
      final dtMs = position.timestamp.difference(last.timestamp).inMilliseconds;
      if (dtMs > 0) {
        final speed = meters / (dtMs / 1000.0);
        if (speed > _maxSpeedMps && meters > 80) return;
      } else if (meters > 200) {
        // No timestamp delta but huge jump — skip.
        return;
      }

      // Tiny jitter below half the distance filter is noise.
      final minStep = (_batteryMode.activeLocationSettings.distanceFilter) * 0.35;
      if (meters < minStep && meters < 8) return;

      _miles += meters / 1609.34;
      _persistSession();
    }
    _positions.add(position);
  }

  /// Stops tracking and returns miles + sparse route for map / cloud.
  TripTrackResult stop() {
    _tracking = false;
    _background = false;
    _autoStarted = false;
    _subscription?.cancel();
    _subscription = null;

    final route = _positions
        .map((p) => GeoPoint(p.latitude, p.longitude))
        .toList(growable: false);
    final result = TripTrackResult(miles: _miles, route: route);

    _positions.clear();
    _miles = 0;
    _clearSession();
    return result;
  }

  Future<void> _persistSession() async {
    if (!_tracking) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, true);
    await prefs.setDouble(_milesKey, _miles);
    await prefs.setBool(_backgroundKey, _background);
    await prefs.setBool(_autoKey, _autoStarted);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await prefs.remove(_milesKey);
    await prefs.remove(_backgroundKey);
    await prefs.remove(_autoKey);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
