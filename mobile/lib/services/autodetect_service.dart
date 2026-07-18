import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'battery_mode.dart';

/// Speed-based driving detection with battery-mode-aware sampling.
class AutoDetectService {
  AutoDetectService({
    required this.onTripStarted,
    required this.onTripEnded,
  });

  final Future<void> Function() onTripStarted;
  final Future<void> Function() onTripEnded;

  static const startSpeedMps = 4.0; // ~9 mph
  static const stopSpeedMps = 1.5; // ~3.4 mph

  StreamSubscription<Position>? _subscription;
  bool _monitoring = false;
  bool _tripActive = false;
  DateTime? _drivingSince;
  DateTime? _stoppedSince;
  BatteryMode _mode = BatteryMode.batterySaver;

  bool get isMonitoring => _monitoring;
  BatteryMode get mode => _mode;

  Future<void> startMonitoring({BatteryMode mode = BatteryMode.batterySaver}) async {
    _mode = mode;
    if (_monitoring) {
      await _restartStream();
      return;
    }
    _monitoring = true;
    _tripActive = false;
    _drivingSince = null;
    _stoppedSince = null;
    await _restartStream();
  }

  Future<void> applyMode(BatteryMode mode) async {
    _mode = mode;
    if (_monitoring && !_tripActive) {
      await _restartStream();
    }
  }

  Future<void> _restartStream() async {
    await _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: _mode.idleLocationSettings,
    ).listen(_onPosition, onError: (_) {});
  }

  void pauseForActiveTrip() {
    _tripActive = true;
    _drivingSince = null;
    _stoppedSince = null;
  }

  void resumeAfterTrip() {
    _tripActive = false;
    _drivingSince = null;
    _stoppedSince = null;
  }

  Future<void> stopMonitoring() async {
    _monitoring = false;
    _tripActive = false;
    _drivingSince = null;
    _stoppedSince = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onPosition(Position position) {
    if (!_monitoring || _tripActive) return;

    final speed = _speedMps(position);
    final now = DateTime.now();

    if (speed >= startSpeedMps) {
      _stoppedSince = null;
      _drivingSince ??= now;
      final elapsed = now.difference(_drivingSince!).inSeconds;
      if (elapsed >= _mode.startConfirmSeconds) {
        _tripActive = true;
        _drivingSince = null;
        onTripStarted();
      }
      return;
    }

    _drivingSince = null;

    if (speed <= stopSpeedMps) {
      _stoppedSince ??= now;
    } else {
      _stoppedSince = null;
    }
  }

  /// Call while a trip is active to auto-stop when the vehicle has been parked.
  void evaluateActiveTrip(Position position) {
    if (!_tripActive) return;

    final speed = _speedMps(position);
    final now = DateTime.now();

    if (speed <= stopSpeedMps) {
      _stoppedSince ??= now;
      final elapsed = now.difference(_stoppedSince!).inSeconds;
      if (elapsed >= _mode.stopConfirmSeconds) {
        _stoppedSince = null;
        onTripEnded();
      }
    } else {
      _stoppedSince = null;
    }
  }

  double _speedMps(Position position) {
    final reported = position.speed;
    if (reported >= 0) return reported;
    return 0;
  }

  void dispose() {
    _subscription?.cancel();
  }
}