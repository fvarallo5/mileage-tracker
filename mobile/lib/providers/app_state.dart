import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/supabase_config.dart';
import '../data/sample_map_trips.dart';
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
import '../services/charging_gate_service.dart';
import '../services/data_export_service.dart';
import '../services/entitlement_service.dart';
import '../services/home_widget_service.dart';
import '../services/irs_mileage_rate.dart';
import '../services/lock_screen_trip_service.dart';
import '../services/map_match_service.dart';
import '../services/premium_service.dart';
import '../services/supabase_service.dart';
import '../services/tax_export_service.dart';
import '../services/trip_tracker.dart';
import '../services/usage_service.dart';
import '../services/work_hours_service.dart';

part 'app_state_data.dart';
part 'app_state_tracking.dart';
part 'app_state_premium.dart';

/// Shared fields + service wiring. Domain methods live in mixins.
///
/// - [AppStateData] — trips, reports, exports
/// - [AppStateTracking] — GPS sessions, lock screen, map match
/// - [AppStatePremium] — billing, gates, auto-detect
abstract class AppStateBase extends ChangeNotifier {
  AppStateBase(this._supabase);

  final SupabaseService _supabase;
  late final TripTracker _tracker;
  late final PremiumService _premium;
  late final EntitlementService _entitlements;
  late final BillingService _billing;
  late final BatteryService _battery;
  late final UsageService _usage;
  late final WorkHoursService _workHours;
  late final CarBluetoothService _carBluetooth;
  late final ChargingGateService _chargingGate;
  late final ActivityRecognitionService _activity;
  late final MapMatchService _mapMatch;
  late final LockScreenTripService _lockScreen;
  late final AutoDetectService _autoDetect;
  Timer? _workHoursTimer;
  Timer? _liveMilesTimer;
  bool _alive = true;
  /// Guards concurrent stopTracking (auto-end + UI/notification).
  bool _stopInFlight = false;
  /// When true, parked detection can end trips automatically.
  bool autoStopEnabled = true;
  /// Fingerprint of last closed GPS session (blocks double-save of same drive).
  String? _lastClosedSessionKey;
  DateTime? _lastClosedSessionAt;

  SupabaseService get supabase => _supabase;
  PremiumService get premium => _premium;
  EntitlementService get entitlements => _entitlements;
  BillingService get billing => _billing;
  BatteryService get battery => _battery;
  UsageService get usage => _usage;
  WorkHoursService get workHours => _workHours;
  CarBluetoothService get carBluetooth => _carBluetooth;
  ChargingGateService get chargingGate => _chargingGate;
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
  bool get chargingGateEnabled => _chargingGate.gateEnabled;
  bool get isPhonePluggedIn => _chargingGate.isPluggedIn;
  bool get activityGateEnabled => _activity.gateEnabled;
  bool get activityInVehicle => _activity.inVehicle;
  BatteryMode get batteryMode => _battery.mode;
  bool get workHoursEnabled => _workHours.enabled;

  /// All optional power gates currently allow watching (or are off).
  bool get powerGatesAllowWatch =>
      _carBluetooth.allowsAutoDetectWatch &&
      _chargingGate.allowsAutoDetectWatch &&
      _activity.allowsAutoDetectWatch &&
      _workHours.allowsAutoDetectWatch;

  /// True when a power gate is holding GPS watch off.
  bool get isWaitingOnPowerGate =>
      autoDetectEnabled &&
      canUseAutoDetect &&
      !trackingIsAuto &&
      !powerGatesAllowWatch;

  /// Human-readable reason GPS watch is sleeping.
  String? get powerGateWaitLabel {
    if (!isWaitingOnPowerGate) return null;
    if (!_workHours.allowsAutoDetectWatch) return _workHours.statusLabel;
    if (!_chargingGate.allowsAutoDetectWatch) return _chargingGate.statusLabel;
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

  /// Free→Pro funnel sheet waiting to be shown by [HomeShell].
  FunnelPrompt? pendingFunnelPrompt;

  TripTracker get tracker => _tracker;
  bool get trackingInBackground => tracking && _tracker.isBackground;
  bool get trackingIsAuto => tracking && _tracker.isAutoStarted;

  Future<void> _publishHomeWidget() {
    return HomeWidgetService.publish(
      tracking: tracking,
      tripMiles: liveMiles,
      trips: trips,
    );
  }

  /// Avoid notify after [dispose] (async billing / GPS can finish late).
  void _safeNotify() {
    if (!_alive) return;
    notifyListeners();
  }

  // —— Cross-mixin contracts (implemented by domain mixins) ——
  // ignore: unused_element — referenced via subclass / other mixins
  Future<void> refresh();
  // ignore: unused_element
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
    DateTime? startedAt,
    DateTime? endedAt,
  });
  // ignore: unused_element
  Future<void> startTracking({
    bool background = false,
    bool autoStarted = false,
  });
  // ignore: unused_element
  Future<Trip?> stopTracking({
    double tips = 0,
    String notes = '',
    String source = 'gps',
  });
  // ignore: unused_element
  Future<String> startTrackingFromVoice();
  // ignore: unused_element
  Future<String> stopTrackingFromVoice();
  // ignore: unused_element
  void _pollLiveMiles();
  // ignore: unused_element
  void _stopLiveMilesPoll();
  // ignore: unused_element
  void _onTrackerPosition(Position position);
  // ignore: unused_element
  void _ensureWorkHoursTimer();
  // ignore: unused_element
  void _onPowerGateChanged();
  // ignore: unused_element
  Future<void> _syncAutoDetectMonitoring();
  // ignore: unused_element
  Future<void> _handleAutoTripStarted();
  // ignore: unused_element
  Future<void> _handleAutoTripEnded();
  // ignore: unused_element
  Future<void> _loadAutoStopPref();
}

/// App-wide state facade used by the UI ([Provider]).
class AppState extends AppStateBase
    with AppStateData, AppStateTracking, AppStatePremium {
  AppState(super.supabase) {
    _tracker = TripTracker();
    _premium = PremiumService();
    _entitlements = EntitlementService(_premium, _supabase);
    _billing = BillingService(_entitlements)..onChanged = _safeNotify;
    _battery = BatteryService()..addListener(_safeNotify);
    _usage = UsageService();
    _workHours = WorkHoursService()..addListener(_onPowerGateChanged);
    _carBluetooth = CarBluetoothService()..addListener(_onPowerGateChanged);
    _chargingGate = ChargingGateService()..addListener(_onPowerGateChanged);
    _activity = ActivityRecognitionService()..addListener(_onPowerGateChanged);
    _mapMatch = MapMatchService()..addListener(_safeNotify);
    _lockScreen = LockScreenTripService();
    _autoDetect = AutoDetectService(
      onTripStarted: _handleAutoTripStarted,
      onTripEnded: _handleAutoTripEnded,
    )..addListener(_safeNotify);
    _tracker.onPosition = _onTrackerPosition;
  }

  Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      loading = false;
      connected = false;
      error =
          'Supabase not configured. Rebuild with SUPABASE_URL and SUPABASE_ANON_KEY.';
      notifyListeners();
      return;
    }

    await _supabase.initialize();
    await _entitlements.loadLocal();
    await _usage.load();
    await _battery.load();
    await _workHours.load();
    await _carBluetooth.load();
    await _chargingGate.load();
    await _activity.load();
    await _mapMatch.load();
    await _loadAutoStopPref();
    await _entitlements.reconcile();
    await _billing.initialize();
    await _tracker.restoreSession(batteryMode: _battery.mode);
    _ensureWorkHoursTimer();
    tracking = _tracker.isTracking;
    if (tracking) {
      liveMiles = _tracker.currentMiles;
      _pollLiveMiles();
      // Re-arm parked auto-stop after process death if applicable.
      final auto = _tracker.isAutoStarted;
      if (autoStopEnabled && (auto || _premium.autoDetectEnabled)) {
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
    unawaited(_publishHomeWidget());
  }

  @override
  void dispose() {
    _alive = false;
    _stopLiveMilesPoll();
    _workHoursTimer?.cancel();
    _billing.onChanged = null;
    _billing.dispose();
    _battery.removeListener(_safeNotify);
    _workHours.removeListener(_onPowerGateChanged);
    _carBluetooth.removeListener(_onPowerGateChanged);
    _carBluetooth.dispose();
    _chargingGate.removeListener(_onPowerGateChanged);
    _chargingGate.dispose();
    _activity.removeListener(_onPowerGateChanged);
    _activity.dispose();
    _mapMatch.removeListener(_safeNotify);
    _autoDetect.removeListener(_safeNotify);
    _autoDetect.dispose();
    unawaited(_lockScreen.clear());
    _tracker.dispose();
    super.dispose();
  }
}
