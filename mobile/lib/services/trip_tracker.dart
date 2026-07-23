import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/geo_point.dart';
import '../utils/stream_restart_scheduler.dart';
import 'battery_mode.dart';

class TripTracker {
  static const _activeKey = 'tracking_active';
  static const _milesKey = 'tracking_miles';
  static const _backgroundKey = 'tracking_background';
  static const _autoKey = 'tracking_auto';

  /// Reject GPS fixes worse than this (meters) — cuts noise without more samples.
  static const maxAccuracyMeters = 45.0;

  /// Reject jumps that imply > ~120 mph (teleport / multipath glitches).
  static const maxSpeedMps = 53.0;

  /// Ignore samples older than this (stale cached fixes).
  static const maxFixAge = Duration(seconds: 30);

  /// Don't write SharedPreferences more often than this while driving.
  static const _persistMinInterval = Duration(seconds: 3);

  StreamSubscription<Position>? _subscription;
  final List<Position> _positions = [];
  double _miles = 0;
  bool _tracking = false;
  bool _background = false;
  bool _autoStarted = false;
  BatteryMode _batteryMode = BatteryMode.balanced;
  DateTime? _lastPersistAt;
  final _restart = StreamRestartScheduler();

  /// Latest horizontal accuracy (meters) for UI diagnostics; null if none yet.
  double? lastAccuracyMeters;

  /// Last stream error message, if any.
  String? lastStreamError;

  void Function(Position position)? onPosition;

  bool get isTracking => _tracking;
  bool get isBackground => _background;
  bool get isAutoStarted => _autoStarted;
  double get currentMiles => _miles;
  int get positionCount => _positions.length;
  BatteryMode get batteryMode => _batteryMode;

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
      // Request again so the system can show "Always" upgrade when only "While Using".
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse) {
        return 'Background tracking requires "Always" location access. Enable it in Settings → ${AppConfig.appName} → Location → Always.';
      }
      if (permission != LocationPermission.always) {
        return 'Location permission is required for background tracking.';
      }
    }

    return null;
  }

  Future<void> restoreSession({
    BatteryMode batteryMode = BatteryMode.balanced,
  }) async {
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
    BatteryMode batteryMode = BatteryMode.balanced,
  }) async {
    if (_tracking) return;

    _positions.clear();
    _miles = 0;
    _tracking = true;
    _background = background;
    _autoStarted = autoStarted;
    _batteryMode = batteryMode;
    lastAccuracyMeters = null;
    lastStreamError = null;
    _restart.reset();

    // Seed one fix quickly so the first segment isn't a long silent wait.
    await _seedFirstFix();
    await _beginStream(background: background);
    await _persistSession(force: true);
  }

  /// Hot-swap GPS sampling while a trip is running (battery mode change).
  Future<void> applyBatteryMode(BatteryMode mode) async {
    _batteryMode = mode;
    if (!_tracking) return;
    await _beginStream(background: _background);
  }

  Future<void> _seedFirstFix() async {
    try {
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _batteryMode.activeLocationSettings.accuracy,
          timeLimit: const Duration(seconds: 8),
        ),
      );
      if (_tracking) _onPosition(fix);
    } catch (_) {
      // Stream will pick up; seed is best-effort.
    }
  }

  Future<void> _beginStream({required bool background}) async {
    await _subscription?.cancel();
    _restart.cancel();

    final settings = _buildSettings(background: background);
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        lastStreamError = null;
        _restart.reset();
        _onPosition(position);
        onPosition?.call(position);
      },
      onError: (Object e) {
        lastStreamError = e.toString();
        _scheduleStreamRestart(background: background);
      },
      onDone: () {
        if (_tracking) {
          _scheduleStreamRestart(background: background);
        }
      },
      cancelOnError: false,
    );
  }

  void _scheduleStreamRestart({required bool background}) {
    if (!_tracking) return;
    _restart.schedule(() {
      if (_tracking) unawaited(_beginStream(background: background));
    });
  }

  LocationSettings _buildSettings({required bool background}) {
    final base = _batteryMode.activeLocationSettings;

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: base.accuracy,
        distanceFilter: base.distanceFilter,
        intervalDuration: Duration(seconds: _batteryMode.activeIntervalSeconds),
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
        // Keep updates alive for Pro / auto / explicit background sessions.
        allowBackgroundLocationUpdates: background,
      );
    }

    return base;
  }

  void _onPosition(Position position) {
    if (!_tracking) return;

    if (!isUsableTripFix(position)) return;

    lastAccuracyMeters = position.accuracy;

    if (_positions.isNotEmpty) {
      final last = _positions.last;
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );

      if (!shouldAcceptSegment(
        meters: meters,
        dtMs: position.timestamp.difference(last.timestamp).inMilliseconds,
        distanceFilter: _batteryMode.activeLocationSettings.distanceFilter,
        currentSpeedMps: position.speed,
      )) {
        return;
      }

      _miles += meters / 1609.34;
      unawaited(_persistSession());
    }
    _positions.add(position);
  }

  /// Shared filter for unit tests and live tracking.
  static bool isUsableTripFix(Position position) {
    if (position.accuracy > maxAccuracyMeters) return false;
    if (position.latitude == 0 && position.longitude == 0) return false;
    if (position.isMocked) return false;

    final age = DateTime.now().difference(position.timestamp);
    // Allow slightly future clocks; reject clearly stale samples.
    if (age > maxFixAge) return false;
    if (age < const Duration(seconds: -5)) return false;

    return true;
  }

  /// Segment acceptance: teleport, jitter, and stationary multipath.
  static bool shouldAcceptSegment({
    required double meters,
    required int dtMs,
    required int distanceFilter,
    double currentSpeedMps = -1,
  }) {
    if (dtMs > 0) {
      final speed = meters / (dtMs / 1000.0);
      if (speed > maxSpeedMps && meters > 80) return false;
    } else if (meters > 200) {
      return false;
    }

    // Tiny jitter below a fraction of the distance filter is noise.
    final minStep = distanceFilter * 0.35;
    if (meters < minStep && meters < 8) return false;

    // Stationary multipath: device says stopped but coords wander a few meters.
    if (currentSpeedMps >= 0 && currentSpeedMps < 0.8 && meters < 12) {
      return false;
    }

    return true;
  }

  /// Stops tracking and returns miles + sparse route for map / cloud.
  TripTrackResult stop() {
    _tracking = false;
    _background = false;
    _autoStarted = false;
    _subscription?.cancel();
    _subscription = null;
    _restart.cancel();

    final route = _positions
        .map((p) => GeoPoint(p.latitude, p.longitude))
        .toList(growable: false);
    final result = TripTrackResult(miles: _miles, route: route);

    _positions.clear();
    _miles = 0;
    lastAccuracyMeters = null;
    unawaited(_clearSession());
    return result;
  }

  Future<void> _persistSession({bool force = false}) async {
    if (!_tracking) return;
    final now = DateTime.now();
    if (!force &&
        _lastPersistAt != null &&
        now.difference(_lastPersistAt!) < _persistMinInterval) {
      return;
    }
    _lastPersistAt = now;
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
    _restart.dispose();
  }
}
