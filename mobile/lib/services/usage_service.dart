import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Tracks free-tier monthly auto-detect trip usage.
class UsageService {
  static const _countKey = 'auto_trips_month_count';
  static const _monthKey = 'auto_trips_month_key';

  int autoTripsThisMonth = 0;
  String _monthKeyValue = '';

  int get freeLimit => AppConfig.freeAutoTripsPerMonth;

  int get remainingFreeAutoTrips {
    final left = freeLimit - autoTripsThisMonth;
    return left < 0 ? 0 : left;
  }

  bool get hasFreeAutoTripsRemaining => remainingFreeAutoTrips > 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final current = _currentMonthKey();
    final stored = prefs.getString(_monthKey) ?? '';
    if (stored != current) {
      _monthKeyValue = current;
      autoTripsThisMonth = 0;
      await prefs.setString(_monthKey, current);
      await prefs.setInt(_countKey, 0);
    } else {
      _monthKeyValue = stored;
      autoTripsThisMonth = prefs.getInt(_countKey) ?? 0;
    }
  }

  Future<void> recordAutoTrip() async {
    await load();
    autoTripsThisMonth += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_monthKey, _monthKeyValue);
    await prefs.setInt(_countKey, autoTripsThisMonth);
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}