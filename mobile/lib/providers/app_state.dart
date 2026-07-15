import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/period_report.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../services/autodetect_service.dart';
import '../services/billing_service.dart';
import '../services/premium_service.dart';
import '../services/trip_tracker.dart';

class AppState extends ChangeNotifier {
  AppState(this._api) {
    _tracker = TripTracker();
    _premium = PremiumService();
    _billing = BillingService(_premium)..onChanged = notifyListeners;
    _autoDetect = AutoDetectService(
      onTripStarted: _handleAutoTripStarted,
      onTripEnded: _handleAutoTripEnded,
    );
    _tracker.onPosition = _onTrackerPosition;
  }

  final ApiService _api;
  late final TripTracker _tracker;
  late final PremiumService _premium;
  late final BillingService _billing;
  late final AutoDetectService _autoDetect;

  ApiService get api => _api;
  PremiumService get premium => _premium;
  BillingService get billing => _billing;
  bool get isPremium => _premium.isPremium;
  bool get autoDetectEnabled => _premium.autoDetectEnabled;
  bool get autoDetectMonitoring => _autoDetect.isMonitoring;

  List<Trip> trips = [];
  ReportSummary? summary;
  List<PeriodReport> reportHistory = [];
  String reportPeriod = 'weekly';
  double mileageRate = 0.70;
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
    await _api.loadSavedBaseUrl();
    await _premium.load();
    await _billing.initialize();
    await _tracker.restoreSession();
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
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();

    connected = await _api.healthCheck();
    if (!connected) {
      loading = false;
      error = 'Cannot reach API at ${_api.baseUrl}. Check server and API URL in settings.';
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _api.getTrips(limit: 100),
        _api.getReportSummary(),
        _api.getMileageRate(),
      ]);
      trips = results[0] as List<Trip>;
      summary = results[1] as ReportSummary;
      mileageRate = results[2] as double;
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

  Future<void> setApiUrl(String url) async {
    await _api.setBaseUrl(url);
    await refresh();
  }

  String get apiUrl => _api.baseUrl;

  Future<String> purchasePremium() => _billing.purchasePremium();

  Future<String> restorePurchases() => _billing.restorePurchases();

  Future<String> unlockPremiumForDevelopment() async {
    await _billing.unlockForDevelopment();
    notifyListeners();
    return 'Premium unlocked for development testing.';
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
    if (!_premium.isPremium) {
      return 'Auto-detect is a Premium feature.';
    }

    final permError = await _tracker.requestBackgroundPermission();
    if (permError != null) return permError;

    await _premium.setAutoDetect(true);
    await _syncAutoDetectMonitoring();
    notifyListeners();
    return null;
  }

  Future<void> _syncAutoDetectMonitoring() async {
    if (_premium.isPremium && _premium.autoDetectEnabled && !tracking) {
      final permError = await _tracker.requestBackgroundPermission();
      if (permError != null) {
        error = permError;
        await _premium.setAutoDetect(false);
        notifyListeners();
        return;
      }
      await _autoDetect.startMonitoring();
    } else {
      await _autoDetect.stopMonitoring();
    }
    notifyListeners();
  }

  Future<void> _handleAutoTripStarted() async {
    if (tracking || !connected) return;
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
    final miles = liveMiles;
    final trip = await stopTracking(
      tips: 0,
      notes: 'Auto-detected trip',
      source: 'autodetect',
    );
    lastAutoDetectMessage = trip != null
        ? 'Auto-saved ${trip.miles.toStringAsFixed(1)} mi trip'
        : 'Trip too short to save (${miles.toStringAsFixed(2)} mi)';
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
      return 'Cannot reach the API. Open Mileage Tracker and check your connection.';
    }

    await startTracking();
    if (error != null) return error!;
    return 'Started GPS trip tracking.';
  }

  Future<String> stopTrackingFromVoice() async {
    if (!tracking) return 'No active trip to stop.';

    final miles = liveMiles;
    final trip = await stopTracking(tips: 0, notes: 'Stopped via voice');
    if (trip == null) {
      return 'Trip too short to save (${miles.toStringAsFixed(2)} mi).';
    }
    return 'Saved ${trip.miles.toStringAsFixed(1)} mile trip.';
  }

  Future<void> startTracking({bool background = false, bool autoStarted = false}) async {
    final useBackground = background || (_premium.isPremium && !autoStarted);
    final permError = useBackground
        ? await _tracker.requestBackgroundPermission()
        : await _tracker.requestForegroundPermission();
    if (permError != null) {
      error = permError;
      notifyListeners();
      return;
    }

    await _tracker.start(background: useBackground, autoStarted: autoStarted);
    tracking = true;
    liveMiles = 0;
    error = null;
    notifyListeners();

    _pollLiveMiles();
  }

  void _pollLiveMiles() {
    if (!tracking) return;
    liveMiles = _tracker.currentMiles;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 500), _pollLiveMiles);
  }

  Future<Trip?> stopTracking({
    double tips = 0,
    String notes = '',
    String source = 'gps',
  }) async {
    final wasAuto = _tracker.isAutoStarted;
    final miles = _tracker.stop();
    tracking = false;
    liveMiles = 0;
    notifyListeners();

    if (_premium.autoDetectEnabled) {
      _autoDetect.resumeAfterTrip();
      await _syncAutoDetectMonitoring();
    }

    if (miles < 0.1) return null;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final resolvedSource = wasAuto ? 'autodetect' : source;
    return saveTrip(
      date: today,
      miles: miles,
      tips: tips,
      notes: notes,
      source: resolvedSource,
    );
  }

  Future<Trip> saveTrip({
    int? id,
    required String date,
    required double miles,
    double tips = 0,
    String notes = '',
    String source = 'manual',
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
    _autoDetect.dispose();
    _tracker.dispose();
    super.dispose();
  }
}