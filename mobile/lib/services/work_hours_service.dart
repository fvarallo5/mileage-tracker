import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional schedule: only run auto-detect GPS watching during work hours.
class WorkHoursService extends ChangeNotifier {
  static const _enabledKey = 'work_hours_enabled';
  static const _startKey = 'work_hours_start_min';
  static const _endKey = 'work_hours_end_min';
  static const _daysKey = 'work_hours_days';

  bool enabled = false;

  /// Minutes from midnight (local).
  int startMinutes = 8 * 60; // 08:00
  int endMinutes = 18 * 60; // 18:00

  /// Mon=0 … Sun=6. Default weekdays on.
  List<bool> daysActive = [true, true, true, true, true, false, false];

  /// True when auto-detect may watch (gate off, or currently inside schedule).
  bool get allowsAutoDetectWatch => isWithinSchedule(DateTime.now());

  String get statusLabel {
    if (!enabled) return 'Off — auto-detect any time';
    if (allowsAutoDetectWatch) {
      return 'On shift · ${formatMinutes(startMinutes)}–${formatMinutes(endMinutes)}';
    }
    return 'Off shift · resumes ${formatMinutes(startMinutes)}';
  }

  String get summaryLabel {
    if (!enabled) return 'Any time';
    final days = _shortDays;
    return '$days · ${formatMinutes(startMinutes)}–${formatMinutes(endMinutes)}';
  }

  String get _shortDays {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final on = <String>[];
    for (var i = 0; i < 7; i++) {
      if (daysActive[i]) on.add(labels[i]);
    }
    if (on.length == 5 &&
        daysActive[0] &&
        daysActive[1] &&
        daysActive[2] &&
        daysActive[3] &&
        daysActive[4] &&
        !daysActive[5] &&
        !daysActive[6]) {
      return 'Weekdays';
    }
    if (on.isEmpty) return 'No days';
    return on.join('');
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? false;
    startMinutes = prefs.getInt(_startKey) ?? 8 * 60;
    endMinutes = prefs.getInt(_endKey) ?? 18 * 60;
    final raw = prefs.getString(_daysKey);
    if (raw != null && raw.length == 7) {
      daysActive = raw.split('').map((c) => c == '1').toList();
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    notifyListeners();
  }

  Future<void> setStartMinutes(int minutes) async {
    startMinutes = minutes.clamp(0, 24 * 60 - 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_startKey, startMinutes);
    notifyListeners();
  }

  Future<void> setEndMinutes(int minutes) async {
    endMinutes = minutes.clamp(0, 24 * 60 - 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_endKey, endMinutes);
    notifyListeners();
  }

  Future<void> setDayActive(int dayIndex, bool active) async {
    if (dayIndex < 0 || dayIndex > 6) return;
    daysActive = List<bool>.from(daysActive)..[dayIndex] = active;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _daysKey,
      daysActive.map((d) => d ? '1' : '0').join(),
    );
    notifyListeners();
  }

  /// [now] local time. Supports overnight windows (e.g. 22:00–06:00).
  bool isWithinSchedule(DateTime now) {
    if (!enabled) return true;
    final dayIndex = now.weekday - 1; // Mon=0
    if (!daysActive[dayIndex]) return false;

    final mins = now.hour * 60 + now.minute;
    if (startMinutes == endMinutes) return true; // 24h on active days
    if (startMinutes < endMinutes) {
      return mins >= startMinutes && mins < endMinutes;
    }
    // Overnight: e.g. 22:00–06:00
    return mins >= startMinutes || mins < endMinutes;
  }

  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  static int timeOfDayToMinutes(int hour, int minute) => hour * 60 + minute;
}
