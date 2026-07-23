import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../config/supabase_config.dart';
import '../models/entitlement.dart';
import '../models/geo_point.dart';
import '../models/period_report.dart';
import '../models/trip.dart';
import '../services/activity_recognition_service.dart';
import '../services/autodetect_service.dart';
import '../services/battery_mode.dart';
import '../services/battery_service.dart';
import '../services/billing_service.dart';
import '../services/car_bluetooth_service.dart';
import '../services/entitlement_service.dart';
import '../services/irs_mileage_rate.dart';
import '../services/lock_screen_trip_service.dart';
import '../services/map_match_service.dart';
import '../services/premium_service.dart';
import '../services/supabase_service.dart';
import '../services/tax_export_service.dart';
import '../services/trip_tracker.dart';
import '../services/usage_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._supabase) {
    _tracker = TripTracker();
    _premium = PremiumService();
    _entitlements = EntitlementService(_premium, _supabase);
    _billing = BillingService(_entitlements)..onChanged = notifyListeners;
    _battery = BatteryService()..addListener(notifyListeners);
    _usage = UsageService();
    _carBluetooth = CarBluetoothService()..addListener(_onPowerGateChanged);
    _activity = ActivityRecognitionService()..addListener(_onPowerGateChanged);
    _mapMatch = MapMatchService()..addListener(notifyListeners);
    _lockScreen = LockScreenTripService();
    _autoDetect = AutoDetectService(
      onTripStarted: _handleAutoTripStarted,
      onTripEnded: _handleAutoTripEnded,
    )..addListener(notifyListeners);
    _tracker.onPosition = _onTrackerPosition;
  }

  final SupabaseService _supabase;
  late final TripTracker _tracker;
  late final PremiumService _premium;
  late final EntitlementService _entitlements;
  late final BillingService _billing;
  late final BatteryService _battery;
  late final UsageService _usage;
  late final CarBluetoothService _carBluetooth;
  late final ActivityRecognitionService _activity;
  late final MapMatchService _mapMatch;
  late final LockScreenTripService _lockScreen;
  late final AutoDetectService _autoDetect;

  SupabaseService get supabase => _supabase;
  PremiumService get premium => _premium;
  EntitlementService get entitlements => _entitlements;
  BillingService get billing => _billing;
  BatteryService get battery => _battery;
  UsageService get usage => _usage;
  CarBluetoothService get carBluetooth => _carBluetooth;
  ActivityRecognitionService get activityRecognition => _activity;
  MapMatchService get mapMatch => _mapMatch;
  LockScreenTripService get lockScreen => _lockScreen;
  bool get lockScreenControlsEnabled => _lockScreen.enabled;
  bool get mapMatchEnabled => _mapMatch.enabled;
  bool get isPremium => _premium.isPremium;
  Entitlement get entitlement => _premium.entitlement;
  bool get autoDetectEnabled => _premium.autoDetectEnabled;
  bool get autoDetectMonitoring => _autoDetect.isMonitoring;
  AutoDetectPhase get autoDetectPhase => _autoDetect.phase;
  String get autoDetectStatusLabel => _autoDetect.statusLabel;
  String? get autoDetectStatusDetail => _autoDetect.statusDetail;
  bool get carBluetoothGateEnabled => _carBluetooth.gateEnabled;
  bool get carBluetoothConnected => _carBluetooth.connected;
  bool get activityGateEnabled => _activity.gateEnabled;
  bool get activityInVehicle => _activity.inVehicle;
  BatteryMode get batteryMode => _battery.mode;

  /// All optional power gates currently allow watching (or are off).
  bool get powerGatesAllowWatch =>
      _carBluetooth.allowsAutoDetectWatch && _activity.allowsAutoDetectWatch;

  /// True when a power gate is holding GPS watch off.
  bool get isWaitingOnPowerGate =>
      autoDetectEnabled &&
      canUseAutoDetect &&
      !trackingIsAuto &&
      !powerGatesAllowWatch;

  /// Human-readable reason GPS watch is sleeping.
  String? get powerGateWaitLabel {
    if (!isWaitingOnPowerGate) return null;
    if (!_carBluetooth.allowsAutoDetectWatch) return _carBluetooth.statusLabel;
    if (!_activity.allowsAutoDetectWatch) return _activity.statusLabel;
    return null;
  }

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
  Timer? _liveMilesTimer;

  /// Free→Pro funnel sheet waiting to be shown by [HomeShell].
  FunnelPrompt? pendingFunnelPrompt;

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

    await _supabase.initialize();
    await _entitlements.loadLocal();
    await _usage.load();
    await _battery.load();
    await _carBluetooth.load();
    await _activity.load();
    await _mapMatch.load();
    await _entitlements.reconcile();
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

    connected = await _supabase.healthCheck();
    if (!connected) {
      loading = false;
      error = 'Cannot reach Supabase. Check your connection and project settings.';
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _supabase.getTrips(limit: 100),
        _supabase.getReportSummary(),
        _entitlements.reconcile(),
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
      final stored = await _supabase.getMileageRate();
      if ((stored - irs).abs() > 0.0005) {
        mileageRate = await _supabase.setMileageRate(irs);
      }
    } catch (_) {
      // Offline or RLS — still use IRS locally for reports.
      mileageRate = irs;
    }
  }

  Future<void> loadReportHistory() async {
    reportHistory = await _supabase.getReports(reportPeriod, count: 8);
    notifyListeners();
  }

  Future<void> setReportPeriod(String period) async {
    reportPeriod = period;
    await loadReportHistory();
  }

  Future<TaxYearSummary> exportTaxPackage({int? year}) async {
    return TaxExportService.shareTaxPackage(
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
    // Hot-swap GPS sampling if a trip is already running.
    if (tracking) {
      await _tracker.applyBatteryMode(mode);
    }
    notifyListeners();
  }

  Future<void> setCarBluetoothGate(bool enabled) async {
    await _carBluetooth.setGateEnabled(enabled);
    if (enabled && !_carBluetooth.hasPermission) {
      lastAutoDetectMessage =
          'Bluetooth permission is required for the car Bluetooth gate.';
    } else if (enabled && _carBluetooth.connected) {
      lastAutoDetectMessage = 'Car Bluetooth connected — auto-detect can watch.';
    } else if (enabled) {
      lastAutoDetectMessage =
          'Car Bluetooth gate on — GPS watching sleeps until the car connects.';
    }
    await _syncAutoDetectMonitoring();
    notifyListeners();
  }

  Future<void> setActivityGate(bool enabled) async {
    await _activity.setGateEnabled(enabled);
    if (enabled && !_activity.hasPermission) {
      lastAutoDetectMessage =
          'Motion / activity permission is required for the vehicle gate.';
    } else if (enabled && _activity.inVehicle) {
      lastAutoDetectMessage = 'In vehicle — auto-detect can watch.';
    } else if (enabled) {
      lastAutoDetectMessage =
          'Vehicle motion gate on — GPS watching sleeps until you drive.';
    }
    await _syncAutoDetectMonitoring();
    notifyListeners();
  }

  void _onPowerGateChanged() {
    // Car BT or activity flipped — start or stop idle GPS watch.
    unawaited(_syncAutoDetectMonitoring());
  }

  Future<String> purchasePremium({bool? annual}) async {
    final message = await _billing.purchasePremium(annual: annual);
    notifyListeners();
    return message;
  }

  Future<String> restorePurchases() async {
    final message = await _billing.restorePurchases();
    notifyListeners();
    return message;
  }

  void consumeFunnelPrompt() {
    pendingFunnelPrompt = null;
  }

  Future<String> unlockPremiumForDevelopment() async {
    await _billing.unlockForDevelopment();
    notifyListeners();
    if (_entitlements.lastSyncError != null) {
      return 'Pro unlocked locally. Cloud sync: ${_entitlements.lastSyncError}';
    }
    return 'Pro unlocked for development testing (synced to account).';
  }

  Future<void> disableAutoDetect() async {
    await _premium.setAutoDetect(false);
    await _syncAutoDetectMonitoring();
    notifyListeners();
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
    final gateOk = powerGatesAllowWatch;
    final shouldWatch = _premium.autoDetectEnabled &&
        canUseAutoDetect &&
        !tracking &&
        gateOk;

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
      // Don't kill an in-progress auto trip if a gate drops mid-drive.
      if (!tracking) {
        await _autoDetect.stopMonitoring();
      }
      if (_premium.autoDetectEnabled && !canUseAutoDetect && !isPremium) {
        lastAutoDetectMessage =
            'Free auto trips used up this month (${_usage.autoTripsThisMonth}/${_usage.freeLimit}). Upgrade for unlimited.';
      }
    }
    notifyListeners();
  }

  Future<void> _handleAutoTripStarted() async {
    if (tracking) return;

    if (!canUseAutoDetect) {
      lastAutoDetectMessage = 'Auto-detect paused — free monthly limit reached.';
      await _premium.setAutoDetect(false);
      await _syncAutoDetectMonitoring();
      notifyListeners();
      return;
    }

    if (!connected) {
      lastAutoDetectMessage =
          'Drive detected, but you\'re offline. Connect to save auto trips.';
      // Stay ready to try again after cooldown.
      _autoDetect.resumeAfterTrip();
      notifyListeners();
      return;
    }

    lastAutoDetectMessage = 'Drive confirmed — starting trip';
    notifyListeners();

    // Stop idle watch; active trip GPS is owned by TripTracker.
    await _autoDetect.stopMonitoring();
    _autoDetect.pauseForActiveTrip();
    await startTracking(background: true, autoStarted: true);

    if (tracking) {
      lastAutoDetectMessage = 'Auto trip in progress';
    } else {
      // Start failed — don't leave auto-detect stuck in "trip active".
      lastAutoDetectMessage = error ?? 'Could not start auto trip GPS';
      _autoDetect.resumeAfterTrip();
      await _syncAutoDetectMonitoring();
    }
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
      final prompt = await _usage.recordAutoTrip(isPremium: isPremium);
      final left = _usage.remainingFreeAutoTrips;
      lastAutoDetectMessage = isPremium
          ? 'Auto-saved ${trip.miles.toStringAsFixed(1)} mi'
          : 'Auto-saved ${trip.miles.toStringAsFixed(1)} mi · $left free left this month';
      if (prompt != null) {
        pendingFunnelPrompt = prompt;
      }
      if (!isPremium && !_usage.hasFreeAutoTripsRemaining) {
        lastAutoDetectMessage =
            'Auto-saved ${trip.miles.toStringAsFixed(1)} mi · free limit reached';
        await _premium.setAutoDetect(false);
      }
    } else {
      lastAutoDetectMessage = milesSnapshot < 0.25
          ? 'Skipped short hop (${milesSnapshot.toStringAsFixed(2)} mi) — not saved'
          : 'Trip too short to save (${milesSnapshot.toStringAsFixed(2)} mi)';
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
    _liveMilesTimer?.cancel();
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
    _liveMilesTimer = Timer(const Duration(milliseconds: 500), _pollLiveMiles);
  }

  void _stopLiveMilesPoll() {
    _liveMilesTimer?.cancel();
    _liveMilesTimer = null;
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
    _stopLiveMilesPoll();
    notifyListeners();

    await _lockScreen.publishImmediate(tracking: false);

    if (_premium.autoDetectEnabled) {
      _autoDetect.resumeAfterTrip();
      await _syncAutoDetectMonitoring();
    }

    // Auto-detect uses a higher floor so parking-lot noise doesn't create trips.
    final minMiles = wasAuto ? 0.25 : 0.1;
    if (result.miles < minMiles) return null;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final refined = await _mapMatch.refine(
      points: result.route,
      gpsMiles: result.miles,
    );
    return saveTrip(
      date: today,
      miles: refined.miles,
      tips: tips,
      notes: notes,
      source: wasAuto ? 'autodetect' : source,
      isBusiness: true,
      startLat: result.start?.lat,
      startLng: result.start?.lng,
      endLat: result.end?.lat,
      endLng: result.end?.lng,
      route: refined.route,
    );
  }

  Future<void> setMapMatchEnabled(bool enabled) =>
      _mapMatch.setEnabled(enabled);

  Future<Trip> saveTrip({
    int? id,
    required String date,
    required double miles,
    double tips = 0,
    String notes = '',
    String source = 'manual',
    bool isBusiness = true,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    List<GeoPoint> route = const [],
  }) async {
    final Trip trip;
    if (id != null) {
      trip = await _supabase.updateTrip(
        id,
        date: date,
        miles: miles,
        tips: tips,
        notes: notes,
        isBusiness: isBusiness,
      );
    } else {
      trip = await _supabase.createTrip(
        date: date,
        miles: miles,
        tips: tips,
        notes: notes,
        source: source,
        isBusiness: isBusiness,
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

  /// One-tap Business ↔ Personal. Updates list optimistically, then syncs.
  Future<void> setTripBusiness(int id, bool isBusiness) async {
    final index = trips.indexWhere((t) => t.id == id);
    if (index >= 0) {
      trips = List<Trip>.from(trips)..[index] = trips[index].copyWith(isBusiness: isBusiness);
      notifyListeners();
    }

    try {
      final updated = await _supabase.setTripBusiness(id, isBusiness);
      if (index >= 0) {
        trips = List<Trip>.from(trips)..[index] = updated;
      }
      // Refresh summary so week/month/tax numbers exclude personal miles.
      summary = await _supabase.getReportSummary();
      reportHistory = await _supabase.getReports(reportPeriod, count: 8);
      error = null;
      notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      await refresh();
    } catch (e) {
      error = 'Failed to update trip purpose: $e';
      await refresh();
    }
  }

  Future<void> deleteTrip(int id) async {
    await _supabase.deleteTrip(id);
    await refresh();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  void dispose() {
    _stopLiveMilesPoll();
    _billing.dispose();
    _battery.removeListener(notifyListeners);
    _carBluetooth.removeListener(_onPowerGateChanged);
    _carBluetooth.dispose();
    _activity.removeListener(_onPowerGateChanged);
    _activity.dispose();
    _mapMatch.removeListener(notifyListeners);
    _autoDetect.removeListener(notifyListeners);
    _autoDetect.dispose();
    unawaited(_lockScreen.clear());
    _tracker.dispose();
    super.dispose();
  }
}