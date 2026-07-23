import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import '../utils/stream_restart_scheduler.dart';
import 'battery_mode.dart';

/// High-level phase for UI status chips.
enum AutoDetectPhase {
  off,
  watching,
  confirmingStart,
  tripActive,
  confirmingStop,
}

/// Speed + distance based driving detection with battery-mode-aware sampling.
///
/// Start requires sustained motion (speed + meters moved), not a single GPS blip.
/// Stop requires sustained stillness with little displacement (parked, not traffic).
class AutoDetectService extends ChangeNotifier {
  AutoDetectService({
    required this.onTripStarted,
    required this.onTripEnded,
  });

  final Future<void> Function() onTripStarted;
  final Future<void> Function() onTripEnded;

  /// ~9 mph — above jogging, typical for vehicles in traffic.
  static const startSpeedMps = 4.0;

  /// ~3.4 mph — crawl / GPS noise while stopped.
  static const stopSpeedMps = 1.5;

  /// Ignore fixes worse than this (meters).
  static const maxAccuracyMeters = 55.0;

  /// Must cover at least this much ground during start confirmation.
  static const minStartDistanceMeters = 90.0;

  /// If we move this far during a "stop" window, cancel parking detection.
  static const stopCancelDistanceMeters = 45.0;

  /// After an auto trip ends, ignore new starts briefly (double-fire guard).
  static const postTripCooldown = Duration(seconds: 45);

  StreamSubscription<Position>? _subscription;
  final _restart = StreamRestartScheduler();
  bool _monitoring = false;
  bool _tripActive = false;
  bool _startInFlight = false;
  DateTime? _drivingSince;
  DateTime? _stoppedSince;
  DateTime? _cooldownUntil;
  DateTime? _tripStartedAt;
  Position? _lastPosition;
  Position? _startAnchor; // first good sample in a start-confirm window
  double _startDistanceMeters = 0;
  Position? _stopAnchor;
  double _stopDistanceMeters = 0;
  Position? _activeAnchor;
  double _activeDistanceMeters = 0;
  BatteryMode _mode = BatteryMode.balanced;
  AutoDetectPhase _phase = AutoDetectPhase.off;
  String? _statusDetail;
  double? _lastSpeedMps;

  bool get isMonitoring => _monitoring;
  bool get isTripActive => _tripActive;
  BatteryMode get mode => _mode;
  AutoDetectPhase get phase => _phase;
  String? get statusDetail => _statusDetail;
  double? get lastSpeedMps => _lastSpeedMps;

  /// Human-readable status for Track tab.
  String get statusLabel {
    switch (_phase) {
      case AutoDetectPhase.off:
        return 'Off';
      case AutoDetectPhase.watching:
        return 'Watching for a drive';
      case AutoDetectPhase.confirmingStart:
        return 'Drive detected — confirming…';
      case AutoDetectPhase.tripActive:
        return 'Trip in progress';
      case AutoDetectPhase.confirmingStop:
        return 'Parked — ending trip…';
    }
  }

  Future<void> startMonitoring({BatteryMode mode = BatteryMode.balanced}) async {
    _mode = mode;
    if (_monitoring) {
      await _restartStream();
      _setPhase(AutoDetectPhase.watching);
      return;
    }
    _monitoring = true;
    _tripActive = false;
    _startInFlight = false;
    _restart.reset();
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    await _restartStream();
    _setPhase(AutoDetectPhase.watching);
  }

  Future<void> applyMode(BatteryMode mode) async {
    _mode = mode;
    if (_monitoring && !_tripActive) {
      await _restartStream();
    }
  }

  Future<void> _restartStream() async {
    await _subscription?.cancel();
    _restart.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: _idleLocationSettings(),
    ).listen(
      (position) {
        _restart.reset();
        _onPosition(position);
      },
      onError: (Object e) {
        _statusDetail = 'Location error — retrying…';
        notifyListeners();
        _scheduleIdleStreamRestart();
      },
      onDone: () {
        if (_monitoring && !_tripActive) _scheduleIdleStreamRestart();
      },
      cancelOnError: false,
    );
  }

  void _scheduleIdleStreamRestart() {
    if (!_monitoring || _tripActive) return;
    if (_restart.exhausted) {
      _statusDetail = 'Location unavailable — check permissions';
      notifyListeners();
      return;
    }
    _restart.schedule(() {
      if (_monitoring && !_tripActive) unawaited(_restartStream());
    });
  }

  /// Background-capable settings so watching continues when the app is not open.
  LocationSettings _idleLocationSettings() {
    final base = _mode.idleLocationSettings;

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: base.accuracy,
        distanceFilter: base.distanceFilter,
        intervalDuration: Duration(seconds: _mode.idleIntervalSeconds),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: '${AppConfig.appName} Auto-detect',
          notificationText: 'Watching for drives · ${_mode.label}',
          enableWakeLock: false,
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
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }

    return base;
  }

  void pauseForActiveTrip() {
    _tripActive = true;
    _startInFlight = false;
    _tripStartedAt = DateTime.now();
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    _setPhase(AutoDetectPhase.tripActive);
  }

  /// Abort a start that AppState rejected (e.g. near home place).
  void cancelPendingStart({String? detail}) {
    _tripActive = false;
    _startInFlight = false;
    _tripStartedAt = null;
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    if (_monitoring) {
      _setPhase(
        AutoDetectPhase.watching,
        detail: detail ?? 'Start skipped',
      );
    } else {
      _setPhase(AutoDetectPhase.off);
    }
  }

  void resumeAfterTrip() {
    _tripActive = false;
    _startInFlight = false;
    _tripStartedAt = null;
    _cooldownUntil = DateTime.now().add(postTripCooldown);
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    if (_monitoring) {
      _setPhase(AutoDetectPhase.watching, detail: 'Cooldown before next auto-start');
      // Resume idle watch stream after trip GPS took over.
      unawaited(_restartStream());
    } else {
      _setPhase(AutoDetectPhase.off);
    }
  }

  Future<void> stopMonitoring() async {
    _monitoring = false;
    _tripActive = false;
    _startInFlight = false;
    _tripStartedAt = null;
    _resetStartWindow();
    _resetStopWindow();
    _resetActiveDistance();
    _lastPosition = null;
    _lastSpeedMps = null;
    _restart.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _setPhase(AutoDetectPhase.off);
  }

  void _onPosition(Position position) {
    if (!_monitoring || _tripActive) return;
    if (!_isUsableFix(position)) return;

    final speed = estimateSpeedMps(position, _lastPosition);
    _lastSpeedMps = speed;

    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      _lastPosition = position;
      _statusDetail = 'Cooldown ${(_cooldownUntil!.difference(now).inSeconds)}s';
      notifyListeners();
      return;
    }

    if (speed >= startSpeedMps) {
      _onDrivingSample(position, now, speed);
      _lastPosition = position;
      return;
    }

    // Not driving — clear start window.
    if (_drivingSince != null) {
      _resetStartWindow();
      _setPhase(AutoDetectPhase.watching);
    }

    if (speed <= stopSpeedMps) {
      // Idle parked — nothing to do while watching.
      _statusDetail = speed > 0
          ? 'Idle · ${mpsToMph(speed).toStringAsFixed(0)} mph'
          : 'Idle · waiting for motion';
    } else {
      _statusDetail = 'Slow · ${mpsToMph(speed).toStringAsFixed(0)} mph';
    }

    _lastPosition = position;
    notifyListeners();
  }

  void _onDrivingSample(Position position, DateTime now, double speed) {
    _resetStopWindow();

    if (_drivingSince == null) {
      _drivingSince = now;
      _startAnchor = position;
      _startDistanceMeters = 0;
    } else if (_startAnchor != null) {
      _startDistanceMeters = Geolocator.distanceBetween(
        _startAnchor!.latitude,
        _startAnchor!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    final elapsed = now.difference(_drivingSince!).inSeconds;
    final needSeconds = _mode.startConfirmSeconds;
    final remaining = math.max(0, needSeconds - elapsed);
    final distOk = _startDistanceMeters >= minStartDistanceMeters;
    final timeOk = elapsed >= needSeconds;

    _setPhase(
      AutoDetectPhase.confirmingStart,
      detail:
          '${mpsToMph(speed).toStringAsFixed(0)} mph · '
          '${_startDistanceMeters.round()} m'
          '${timeOk ? '' : ' · ${remaining}s'}'
          '${distOk ? '' : ' · need ${minStartDistanceMeters.round()} m'}',
    );

    if (timeOk && distOk && !_startInFlight) {
      _tripActive = true;
      _startInFlight = true;
      _tripStartedAt = now;
      _resetStartWindow();
      _resetActiveDistance();
      _activeAnchor = position;
      _setPhase(AutoDetectPhase.tripActive, detail: 'Starting GPS trip…');
      // Fire-and-forget; AppState owns async start.
      unawaited(onTripStarted());
    }
  }

  /// Call while a trip is active to auto-stop when the vehicle has been parked.
  void evaluateActiveTrip(Position position) {
    if (!_tripActive) return;
    if (!_isUsableFix(position)) return;

    final speed = estimateSpeedMps(position, _lastPosition);
    _lastSpeedMps = speed;
    final now = DateTime.now();

    // Accumulate path length for min-distance gate before auto-stop.
    if (_activeAnchor != null) {
      final step = Geolocator.distanceBetween(
        _activeAnchor!.latitude,
        _activeAnchor!.longitude,
        position.latitude,
        position.longitude,
      );
      if (step > 3 && step < 500) {
        _activeDistanceMeters += step;
        _activeAnchor = position;
      } else if (step >= 500) {
        // Teleport — reset anchor without adding.
        _activeAnchor = position;
      }
    } else {
      _activeAnchor = position;
    }

    if (speed > stopSpeedMps) {
      if (_stoppedSince != null) {
        _resetStopWindow();
        _setPhase(AutoDetectPhase.tripActive, detail: 'Moving again');
      }
      _lastPosition = position;
      return;
    }

    // Too early / too short — don't start the parked timer yet.
    final tripAgeSec = _tripStartedAt == null
        ? 0
        : now.difference(_tripStartedAt!).inSeconds;
    final minSec = _mode.minActiveTripSeconds;
    final minM = _mode.minActiveTripMeters;
    if (tripAgeSec < minSec || _activeDistanceMeters < minM) {
      _resetStopWindow();
      final needSec = math.max(0, minSec - tripAgeSec);
      final needM = math.max(0, (minM - _activeDistanceMeters).round());
      _setPhase(
        AutoDetectPhase.tripActive,
        detail: needSec > 0
            ? 'Trip young · ${needSec}s before auto-end'
            : 'Need ${needM}m more before auto-end',
      );
      _lastPosition = position;
      return;
    }

    // Stationary / crawl — accumulate stop window.
    if (_stoppedSince == null) {
      _stoppedSince = now;
      _stopAnchor = position;
      _stopDistanceMeters = 0;
    } else if (_stopAnchor != null) {
      _stopDistanceMeters = Geolocator.distanceBetween(
        _stopAnchor!.latitude,
        _stopAnchor!.longitude,
        position.latitude,
        position.longitude,
      );
      if (_stopDistanceMeters >= stopCancelDistanceMeters) {
        // Creeping in traffic / long light — not parked.
        _resetStopWindow();
        _setPhase(
          AutoDetectPhase.tripActive,
          detail: 'Still moving (${_stopDistanceMeters.round()} m)',
        );
        _lastPosition = position;
        return;
      }
    }

    final elapsed = now.difference(_stoppedSince!).inSeconds;
    final need = _mode.stopConfirmSeconds;
    final remaining = math.max(0, need - elapsed);

    _setPhase(
      AutoDetectPhase.confirmingStop,
      detail: 'Parked ${elapsed}s · ends in ${remaining}s',
    );

    if (elapsed >= need) {
      _resetStopWindow();
      unawaited(onTripEnded());
    }

    _lastPosition = position;
  }

  bool _isUsableFix(Position position) {
    if (position.accuracy > maxAccuracyMeters) return false;
    if (position.latitude == 0 && position.longitude == 0) return false;
    return true;
  }

  void _resetStartWindow() {
    _drivingSince = null;
    _startAnchor = null;
    _startDistanceMeters = 0;
  }

  void _resetStopWindow() {
    _stoppedSince = null;
    _stopAnchor = null;
    _stopDistanceMeters = 0;
  }

  void _resetActiveDistance() {
    _activeAnchor = null;
    _activeDistanceMeters = 0;
  }

  void _setPhase(AutoDetectPhase phase, {String? detail}) {
    final changed = _phase != phase || _statusDetail != detail;
    _phase = phase;
    _statusDetail = detail;
    if (changed) notifyListeners();
  }

  /// Prefer device speed; fall back to distance/time between samples.
  static double estimateSpeedMps(Position current, Position? previous) {
    final reported = current.speed;
    if (reported >= 0 && reported < 90) {
      // Some devices report 0 when moving slowly — blend with derived if available.
      if (reported > 0.5 || previous == null) return reported;
    }

    if (previous == null) return reported >= 0 ? reported : 0;

    final meters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final dtMs = current.timestamp.difference(previous.timestamp).inMilliseconds;
    if (dtMs <= 0) return reported >= 0 ? reported : 0;
    final derived = meters / (dtMs / 1000.0);
    if (derived > 90) return reported >= 0 ? reported : 0; // teleport
    if (reported >= 0 && reported <= 0.5 && derived > reported) {
      return derived;
    }
    return reported >= 0 ? reported : derived;
  }

  static double mpsToMph(double mps) => mps * 2.23694;

  @override
  void dispose() {
    _subscription?.cancel();
    _restart.dispose();
    super.dispose();
  }
}
