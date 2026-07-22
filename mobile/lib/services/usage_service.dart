import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Soft funnel moments after auto-detect trips.
enum FunnelPrompt {
  firstTrip,
  softNearLimit,
  hardLimitReached,
}

/// Tracks free-tier monthly auto-detect trip usage.
class UsageService {
  static const _countKey = 'auto_trips_month_count';
  static const _monthKey = 'auto_trips_month_key';
  static const _softSheetMonthKey = 'funnel_soft_sheet_month';
  static const _upgradeModalDayKey = 'funnel_upgrade_modal_day';

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

  /// Record an auto trip. Returns a funnel prompt when one should show.
  Future<FunnelPrompt?> recordAutoTrip({required bool isPremium}) async {
    await load();
    autoTripsThisMonth += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_monthKey, _monthKeyValue);
    await prefs.setInt(_countKey, autoTripsThisMonth);

    if (isPremium) return null;

    if (autoTripsThisMonth == 1) {
      return FunnelPrompt.firstTrip;
    }

    if (!hasFreeAutoTripsRemaining) {
      return FunnelPrompt.hardLimitReached;
    }

    // Soft nudge at 25/30 (5 left).
    if (remainingFreeAutoTrips == 5) {
      final shownMonth = prefs.getString(_softSheetMonthKey);
      if (shownMonth != _monthKeyValue) {
        await prefs.setString(_softSheetMonthKey, _monthKeyValue);
        return FunnelPrompt.softNearLimit;
      }
    }

    return null;
  }

  Future<bool> canShowUpgradeModalToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _currentDayKey();
    final last = prefs.getString(_upgradeModalDayKey);
    return last != today;
  }

  Future<void> markUpgradeModalShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_upgradeModalDayKey, _currentDayKey());
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _currentDayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
