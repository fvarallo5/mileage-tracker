import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional gate: only run auto-detect GPS watching when the OS reports
/// vehicle-like motion (in vehicle / bicycle).
class ActivityRecognitionService extends ChangeNotifier {
  static const _gateKey = 'activity_recognition_gate_enabled';
  static const _method = MethodChannel('com.mileagetracker/activity_recognition');
  static const _events = EventChannel('com.mileagetracker/activity_recognition_events');

  bool gateEnabled = false;
  bool available = true;
  bool inVehicle = false;
  bool hasPermission = true;
  String activity = 'unknown';
  int confidence = 0;

  StreamSubscription? _sub;
  bool _started = false;

  /// True when auto-detect may watch GPS (gate off, or currently in a vehicle).
  bool get allowsAutoDetectWatch => !gateEnabled || inVehicle;

  String get activityLabel {
    return switch (activity) {
      'in_vehicle' => 'In vehicle',
      'on_bicycle' => 'Cycling',
      'on_foot' || 'walking' => 'Walking',
      'running' => 'Running',
      'still' => 'Still',
      'tilting' => 'Device moving',
      'unavailable' => 'Unavailable',
      _ => 'Unknown',
    };
  }

  String get statusLabel {
    if (!gateEnabled) return 'Gate off — always watch when auto-detect is on';
    if (!hasPermission) return 'Motion / activity permission needed';
    if (!available) return 'Activity recognition not available';
    if (inVehicle) return '$activityLabel — GPS can watch';
    return 'Waiting for vehicle motion… ($activityLabel)';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    gateEnabled = prefs.getBool(_gateKey) ?? false;
    if (gateEnabled) {
      await start();
    } else {
      await _refreshOnce();
    }
    notifyListeners();
  }

  Future<void> setGateEnabled(bool enabled) async {
    if (enabled) {
      final ok = await ensurePermission();
      if (!ok) {
        gateEnabled = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_gateKey, false);
        notifyListeners();
        return;
      }
    }

    gateEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gateKey, enabled);

    if (enabled) {
      await start();
      try {
        await _method.invokeMethod<void>('start');
      } catch (_) {}
    } else {
      try {
        await _method.invokeMethod<void>('stop');
      } catch (_) {}
      await stop();
      await _refreshOnce();
    }
    notifyListeners();
  }

  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      // iOS prompts via NSMotionUsageDescription on first CMMotionActivity use.
      hasPermission = true;
      return true;
    }
    if (!Platform.isAndroid) {
      hasPermission = true;
      return true;
    }

    var status = await Permission.activityRecognition.status;
    if (status.isDenied) {
      status = await Permission.activityRecognition.request();
    }
    hasPermission = status.isGranted || status.isLimited;
    notifyListeners();
    return hasPermission;
  }

  Future<void> start() async {
    if (kIsWeb || _started) {
      await _refreshOnce();
      return;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      available = false;
      notifyListeners();
      return;
    }

    _started = true;
    try {
      _sub = _events.receiveBroadcastStream().listen(
        _onEvent,
        onError: (_) {
          available = false;
          notifyListeners();
        },
      );
      await _refreshOnce();
    } on MissingPluginException {
      available = false;
      _started = false;
      notifyListeners();
    } catch (_) {
      available = false;
      _started = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _refreshOnce() async {
    if (kIsWeb) {
      available = false;
      return;
    }
    try {
      final raw = await _method.invokeMethod<dynamic>('getState');
      if (raw is Map) {
        _applyMap(Map<Object?, Object?>.from(raw));
      }
    } on MissingPluginException {
      available = false;
    } catch (_) {}
  }

  void _onEvent(dynamic event) {
    if (event is Map) {
      _applyMap(Map<Object?, Object?>.from(event));
      notifyListeners();
    }
  }

  void _applyMap(Map<Object?, Object?> map) {
    available = map['available'] as bool? ?? true;
    inVehicle = map['inVehicle'] as bool? ?? false;
    hasPermission = map['permission'] as bool? ?? true;
    activity = map['activity'] as String? ?? 'unknown';
    final c = map['confidence'];
    confidence = c is int ? c : (c is num ? c.toInt() : 0);
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
