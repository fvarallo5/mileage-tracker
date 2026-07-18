import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional gate: only run auto-detect GPS watching when a car-like Bluetooth
/// audio device is connected (stereo / HFP / CarPlay-style routes).
class CarBluetoothService extends ChangeNotifier {
  static const _gateKey = 'car_bluetooth_gate_enabled';
  static const _method = MethodChannel('com.mileagetracker/car_bluetooth');
  static const _events = EventChannel('com.mileagetracker/car_bluetooth_events');

  bool gateEnabled = false;
  bool available = true;
  bool connected = false;
  bool hasPermission = true;
  String? deviceName;

  StreamSubscription? _sub;
  bool _started = false;

  /// True when auto-detect is allowed to watch GPS (gate off, or car linked).
  bool get allowsAutoDetectWatch => !gateEnabled || connected;

  String get statusLabel {
    if (!gateEnabled) return 'Gate off — always watch when auto-detect is on';
    if (!hasPermission) return 'Bluetooth permission needed';
    if (!available) return 'Bluetooth not available on this device';
    if (connected) {
      final name = deviceName;
      return name == null || name.isEmpty
          ? 'Car Bluetooth connected'
          : 'Connected · $name';
    }
    return 'Waiting for car Bluetooth…';
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
    } else {
      await stop();
      await _refreshOnce();
    }
    notifyListeners();
  }

  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      hasPermission = true;
      return true;
    }
    if (!Platform.isAndroid) {
      hasPermission = true;
      return true;
    }

    // Android 12+ requires BLUETOOTH_CONNECT to read connected devices.
    var status = await Permission.bluetoothConnect.status;
    if (status.isDenied) {
      status = await Permission.bluetoothConnect.request();
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
    } catch (_) {
      // Keep last known state.
    }
  }

  void _onEvent(dynamic event) {
    if (event is Map) {
      _applyMap(Map<Object?, Object?>.from(event));
      notifyListeners();
    }
  }

  void _applyMap(Map<Object?, Object?> map) {
    available = map['available'] as bool? ?? true;
    connected = map['connected'] as bool? ?? false;
    hasPermission = map['permission'] as bool? ?? true;
    final name = map['deviceName'];
    deviceName = name is String && name.isNotEmpty ? name : null;
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
