import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../config/supabase_config.dart';
import '../models/geo_point.dart';
import '../models/period_report.dart';
import '../models/trip.dart';
import '../services/autodetect_service.dart';
import '../services/battery_mode.dart';
import '../services/battery_service.dart';
import '../services/billing_service.dart';
import '../services/irs_mileage_rate.dart';
import '../services/lock_screen_trip_service.dart';
import '../services/premium_service.dart';
import '../services/supabase_service.dart';
import '../services/tax_export_service.dart';
import '../services/trip_tracker.dart';
import '../services/usage_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._api) {
    _tracker = TripTracker();
    _premium = PremiumService();
    _billing = BillingService(_premium)..onChanged = notifyListeners;
    _battery = BatteryService()..addListener(notifyListeners);
    _usage = UsageService();
    _lockScreen = LockScreenTripService();
    _autoDetect = AutoDetectService(
      onTripStarted: _handleAutoTripStarted,
      onTripEnded: _handleAutoTripEnded,
    );
    _tracker.onPosition = _onTrackerPosition;
  }

  final SupabaseService _api;
  late final TripTracker _tracker;
  late final PremiumService _premium;
  late final BillingService _billing;
  late final BatteryService _battery;
  late final UsageService _usage;
  late final LockScreenTripService _lockScreen;
  late final AutoDetectService _autoDetect;

  SupabaseService get api => _api;
  PremiumService get premium => _premium;
  BillingService get billing => _billing;
  BatteryService get battery => _battery;
  UsageService get usage => _usage;
  LockScreenTripService get lockScreen => _lockScreen;
  bool get lockScreenControlsEnabled => _lockScreen.enabled;
  bool get isPremium => _premium.isPremium;
  bool get autoDetectEnabled => _premium.autoDetectEnabled;
  bool get autoDetectMonitoring => _autoDetect.isMonitoring;
  BatteryMode get batteryMode => _battery.mode;

  /// Auto-detect can run if Pro (unlimited) or Free with remaining monthly trips.
  bool get canUseAutoDetect => isPremium || _usage.hasFreeAutoTripsRemaining;

  List<Trip> trips = [];
  ReportSummary? summary;
  List<PeriodReport> reportHistory = [];
  String reportPeriod = 'weekly';
  double mileageRate = IrsMileageRate.current;
  bool loading = true;
  bool connected = false;
  String? error;
  bool tracking = false;
  double liveMiles = 0;
  String? lastAutoDetectMessage;

  TripTracker get tracker => _tracker;
  bool get trackingInBackground => tracking && _tracker.isBackground;
  bool get trackingIsAuto => tracking && _tracker.isAutoStarted;

  Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      loading = false;
      connected = false;
      error = 'Supabase not configured. Rebuild with SUPABASE_URL and SUPABASE_ANON_KEY.';
      notifyListeners();
      return;
    }

    await _api.initialize();
    await _premium.load();
    await _usage.load();
    await _battery.load();
    await _billing.initialize();
    await _tracker.restoreSession(batteryMode: _battery.mode);
    tracking = _tracker.isTracking;
    if (tracking) {
      liveMiles = _tracker.currentMiles;
      _pollLiveMiles();
      if (_premium.autoDetectEnabled && _tracker.isAutoStarted) {
        _autoDetect.pauseForActiveTrip();
      }
    }
    await refresh();
    await _syncAutoDetectMonitoring();
    await _lockScreen.initialize(
      onStart: startTrackingFromVoice,
      onStop: stopTrackingFromVoice,
    );
    if (tracking) {
      await _lockScreen.publishImmediate(
        tracking: true,
        miles: liveMiles,
        isAuto: _tracker.isAutoStarted,
      );
    }
  }

  Future<void> setLockScreenControlsEnabled(bool enabled) async {
    await _lockScreen.setEnabled(enabled);
    if (enabled && tracking) {
      await _lockScreen.publishImmediate(
        tracking: true,
        miles: liveMiles,
        isAuto: _tracker.isAutoStarted,
      );
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();

    connected = await _api.healthCheck();
    if (!connected) {
      loading = false;
      error = 'Cannot reach Supabase. Check your connection and project settings.';
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _api.getTrips(limit: 100),
        _api.getReportSummary(),
      ]);
      trips = results[0] as List<Trip>;
      summary = results[1] as ReportSummary;
      await _syncIrsMileageRate();
      await loadReportHistory();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Failed to load data: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Keeps cloud settings in sync with the published IRS rate for this year.
  Future<void> _syncIrsMileageRate() async {
    final irs = IrsMileageRate.current;
    mileageRate = irs;
    try {
      final stored = await _api.getMileageRate();
      if ((stored - irs).abs() > 0.0005) {
        mileageRate = await _api.setMileageRate(irs);
      }
    } catch (_) {
      // Offline or RLS — still use IRS locally for reports.
      mileageRate = irs;
    }
  }

  Future<void> loadReportHistory() async {
    reportHistory = await _api.getReports(reportPeriod, count: 8);
    notifyListeners();
  }

  Future<void> setReportPeriod(String period) async {
    reportPeriod = period;
    await loadReportHistory();
  }

  Future<void> setMileageRate(double rate) async {
    mileageRate = await _api.setMileageRate(rate);
    await refresh();
  }

  Future<void> exportTaxPackage({int? year}) async {
    await TaxExportService.shareTaxPackage(
      trips: trips,
      year: year ?? IrsMileageRate.currentYear,
    );
  }

  Future<void> exportPeriodReport(PeriodReport report) async {
    await TaxExportService.sharePeriodExport(
      trips: trips,
      startDate: report.startDate,
      endDate: report.endDate,
      label: report.label,
    );
  }

  Future<void> setBatteryMode(BatteryMode mode) async {
    await _battery.setMode(mode);
    await _autoDetect.applyMode(mode);
    notifyListeners();
  }

  Future<String> purchasePremium() => _billing.purchasePremium();

  Future<String> restorePurchases() => _billing.restorePurchases();

  Future<String> unlockPremiumForDevelopment() async {
    await _billing.unlockForDevelopment();
    notifyListeners();
    return 'Pro unlocked for development testing.';
  }

  Future<String?> setAutoDetect(bool enabled) async {
    if (!enabled) {
      await _premium.setAutoDetect(false);
      await _syncAutoDetectMonitoring();
      notifyListeners();
      return null;
    }
    return 'Use enableAutoDetect() after showing the permission explainer.';
  }

  Future<String?> enableAutoDetect() async {
    if (!canUseAutoDetect) {
      return 'Free auto-detect limit reached (${AppConfig.freeAutoTripsPerMonth}/month). Upgrade to Pro for unlimited.';
    }

    final permError = await _tracker.requestBackgroundPermission();
    if (permError != null) return permError;

    await _premium.setAutoDetect(true);
    await _syncAutoDetectMonitoring();
    notifyListeners();
    return null;
  }

  Future<void> _syncAutoDetectMonitoring() async {
    final shouldWatch = _premium.autoDetectEnabled && canUseAutoDetect && !tracking;
    if (shouldWatch) {
      final permError = await _tracker.requestBackgroundPermission();
      if (permError != null) {
        error = permError;
        await _premium.setAutoDetect(false);
        notifyListeners();
        return;
      }
      await _autoDetect.startMonitoring(mode: _battery.mode);
    } else {
      await _autoDetect.stopMonitoring();
      if (_premium.autoDetectEnabled && !canUseAutoDetect && !isPremium) {
        lastAutoDetectMessage =
            'Free auto trips used up this month (${_usage.autoTripsThisMonth}/${_usage.freeLimit}). Upgrade for unlimited.';
      }
    }
    notifyListeners();
  }

  Future<void> _handleAutoTripStarted() async {
    if (tracking || !connected) return;
    if (!canUseAutoDetect) {
      lastAutoDetectMessage = 'Auto-detect paused — free monthly limit reached.';
      await _premium.setAutoDetect(false);
      await _syncAutoDetectMonitoring();
      notifyListeners();
      return;
    }

    lastAutoDetectMessage = 'Drive detected — starting trip';
    notifyListeners();
    await _autoDetect.stopMonitoring();
    _autoDetect.pauseForActiveTrip();
    await startTracking(background: true, autoStarted: true);
    lastAutoDetectMessage = null;
    notifyListeners();
  }

  Future<void> _handleAutoTripEnded() async {
    if (!tracking || !_tracker.isAutoStarted) return;
    _autoDetect.resumeAfterTrip();
    final milesSnapshot = liveMiles;
    final trip = await stopTracking(
      tips: 0,
      notes: 'Auto-detected trip',
      source: 'autodetect',
    );
    if (trip != null) {
      await _usage.recordAutoTrip();
      lastAutoDetectMessage =
          'Auto-saved ${trip.miles.toStringAsFixed(1)} mi · ${_usage.remainingFreeAutoTrips} free left this month';
      if (!isPremium && !_usage.hasFreeAutoTripsRemaining) {
        await _premium.setAutoDetect(false);
      }
    } else {
      lastAutoDetectMessage =
          'Trip too short to save (${milesSnapshot.toStringAsFixed(2)} mi)';
    }
    notifyListeners();
    await _syncAutoDetectMonitoring();
  }

  void _onTrackerPosition(Position position) {
    if (_premium.autoDetectEnabled && tracking && _tracker.isAutoStarted) {
      _autoDetect.evaluateActiveTrip(position);
    }
  }

  Future<String> startTrackingFromVoice() async {
    if (tracking) return 'Already tracking a trip.';
    if (!connected) {
      return 'Cannot reach Supabase. Open ${AppConfig.appName} and check your connection.';
    }

    await startTracking();
    if (error != null) return error!;
    return 'Started GPS trip tracking.';
  }

  Future<String> stopTrackingFromVoice() async {
    if (!tracking) return 'No active trip to stop.';

    final milesSnapshot = liveMiles;
    final trip = await stopTracking(tips: 0, notes: 'Stopped via voice');
    if (trip == null) {
      return 'Trip too short to save (${milesSnapshot.toStringAsFixed(2)} mi).';
    }
    return 'Saved ${trip.miles.toStringAsFixed(1)} mile trip.';
  }

  Future<void> startTracking({bool background = false, bool autoStarted = false}) async {
    final useBackground = background || autoStarted || _premium.isPremium;
    final permError = useBackground
        ? await _tracker.requestBackgroundPermission()
        : await _tracker.requestForegroundPermission();
    if (permError != null) {
      error = permError;
      notifyListeners();
      return;
    }

    await _tracker.start(
      background: useBackground,
      autoStarted: autoStarted,
      batteryMode: _battery.mode,
    );
    tracking = true;
    liveMiles = 0;
    error = null;
    notifyListeners();

    await _lockScreen.publishImmediate(
      tracking: true,
      miles: 0,
      isAuto: autoStarted,
    );
    _pollLiveMiles();
  }

  void _pollLiveMiles() {
    if (!tracking) return;
    liveMiles = _tracker.currentMiles;
    notifyListeners();
    unawaited(
      _lockScreen.publish(
        tracking: true,
        miles: liveMiles,
        isAuto: _tracker.isAutoStarted,
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), _pollLiveMiles);
  }

  Future<Trip?> stopTracking({
    double tips = 0,
    String notes = '',
    String source = 'gps',
  }) async {
    final wasAuto = _tracker.isAutoStarted;
    final result = _tracker.stop();
    tracking = false;
    liveMiles = 0;
    notifyListeners();

    await _lockScreen.publishImmediate(tracking: false);

    if (_premium.autoDetectEnabled) {
      _autoDetect.resumeAfterTrip();
      await _syncAutoDetectMonitoring();
    }

    if (result.miles < 0.1) return null;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final resolvedSource = wasAuto ? 'autodetect' : source;
    final sparse = result.sparseRoute();
    return saveTrip(
      date: today,
      miles: result.miles,
      tips: tips,
      notes: notes,
      source: resolvedSource,
      startLat: result.start?.lat,
      startLng: result.start?.lng,
      endLat: result.end?.lat,
      endLng: result.end?.lng,
      route: sparse,
    );
  }

  Future<Trip> saveTrip({
    int? id,
    required String date,
    required double miles,
    double tips = 0,
    String notes = '',
    String source = 'manual',
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    List<GeoPoint> route = const [],
  }) async {
    final Trip trip;
    if (id != null) {
      trip = await _api.updateTrip(id, date: date, miles: miles, tips: tips, notes: notes);
    } else {
      trip = await _api.createTrip(
        date: date,
        miles: miles,
        tips: tips,
        notes: notes,
        source: source,
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        route: route.map((p) => p.toJson()).toList(),
      );
    }
    await refresh();
    return trip;
  }

  Future<void> deleteTrip(int id) async {
    await _api.deleteTrip(id);
    await refresh();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  void dispose() {
    _billing.dispose();
    _battery.removeListener(notifyListeners);
    _autoDetect.dispose();
    unawaited(_lockScreen.clear());
    _tracker.dispose();
    super.dispose();
  }
}