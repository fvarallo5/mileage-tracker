import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional gate: only run auto-detect GPS watching while the phone is plugged in.
///
/// Phones cannot tell a car charger from a wall charger — this is "while charging
/// / connected to power," which is still a strong proxy for many drivers who
/// plug in only in the car.
class ChargingGateService extends ChangeNotifier {
  static const _gateKey = 'charging_gate_enabled';

  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _sub;

  bool gateEnabled = false;
  bool isPluggedIn = false;
  BatteryState lastState = BatteryState.unknown;

  /// True when auto-detect may watch GPS (gate off, or phone is on power).
  bool get allowsAutoDetectWatch => !gateEnabled || isPluggedIn;

  String get statusLabel {
    if (!gateEnabled) return 'Gate off — watch without needing a charger';
    if (isPluggedIn) {
      return switch (lastState) {
        BatteryState.charging => 'Charging — auto-detect can watch',
        BatteryState.full => 'Plugged in (full) — auto-detect can watch',
        BatteryState.connectedNotCharging =>
          'Plugged in — auto-detect can watch',
        _ => 'On power — auto-detect can watch',
      };
    }
    return 'Waiting for charger… GPS watching sleeps until plugged in';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    gateEnabled = prefs.getBool(_gateKey) ?? false;
    await _refreshState();
    if (gateEnabled) {
      _startListening();
    }
    notifyListeners();
  }

  Future<void> setGateEnabled(bool enabled) async {
    gateEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gateKey, enabled);
    if (enabled) {
      await _refreshState();
      _startListening();
    } else {
      await _sub?.cancel();
      _sub = null;
    }
    notifyListeners();
  }

  Future<void> _refreshState() async {
    try {
      lastState = await _battery.batteryState;
      isPluggedIn = _isPlugged(lastState);
    } catch (e) {
      if (kDebugMode) debugPrint('ChargingGate: $e');
      lastState = BatteryState.unknown;
      // Fail open when gate is on but we can't read state? Fail closed is safer
      // for battery (don't watch). Fail open is safer for not missing trips.
      // Match Bluetooth: if unknown, treat as not plugged (sleep watch).
      isPluggedIn = false;
    }
  }

  void _startListening() {
    _sub?.cancel();
    _sub = _battery.onBatteryStateChanged.listen((state) {
      lastState = state;
      final next = _isPlugged(state);
      if (next != isPluggedIn) {
        isPluggedIn = next;
        notifyListeners();
      } else {
        isPluggedIn = next;
        notifyListeners();
      }
    });
  }

  static bool _isPlugged(BatteryState state) {
    return state == BatteryState.charging ||
        state == BatteryState.full ||
        state == BatteryState.connectedNotCharging;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
