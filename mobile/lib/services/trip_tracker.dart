import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripTracker {
  static const _activeKey = 'tracking_active';
  static const _milesKey = 'tracking_miles';
  static const _backgroundKey = 'tracking_background';
  static const _autoKey = 'tracking_auto';

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
          return 'Background location is required for Premium tracking. Enable "Allow all the time" in Settings.';
        }
      }
      if (status.isPermanentlyDenied) {
        return 'Background location is required. Enable it in Android Settings.';
      }
    }

    if (Platform.isIOS) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse) {
        return 'Background tracking requires "Always" location access. Enable it in Settings → Mileage Tracker → Location → Always.';
      }
      if (permission != LocationPermission.always) {
        return 'Location permission is required for background tracking.';
      }
    }

    return null;
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activeKey) ?? false)) return;

    _miles = prefs.getDouble(_milesKey) ?? 0;
    _background = prefs.getBool(_backgroundKey) ?? false;
    _autoStarted = prefs.getBool(_autoKey) ?? false;
    _tracking = true;
    await _beginStream(background: _background);
  }

  Future<void> start({bool background = false, bool autoStarted = false}) async {
    if (_tracking) return;

    _positions.clear();
    _miles = 0;
    _tracking = true;
    _background = background;
    _autoStarted = autoStarted;
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
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Mileage Tracker',
                notificationText: 'Tracking your trip in the background',
                enableWakeLock: true,
              )
            : null,
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: background,
        allowBackgroundLocationUpdates: background,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  void _onPosition(Position position) {
    if (!_tracking) return;

    if (_positions.isNotEmpty) {
      final last = _positions.last;
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      _miles += meters / 1609.34;
      _persistSession();
    }
    _positions.add(position);
  }

  double stop() {
    _tracking = false;
    _background = false;
    _autoStarted = false;
    _subscription?.cancel();
    _subscription = null;
    final result = _miles;
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