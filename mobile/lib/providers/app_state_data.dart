part of 'app_state.dart';

/// Trip list, reports, tax/data export, and cloud sync.
mixin AppStateData on AppStateBase {
  @override
  Future<void> refresh() async {
    loading = true;
    error = null;
    _safeNotify();

    connected = await _supabase.healthCheck();
    if (!connected) {
      loading = false;
      error =
          'Cannot reach Supabase. Check your connection and project settings.';
      _safeNotify();
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
      unawaited(_publishHomeWidget());
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Failed to load data: $e';
    } finally {
      loading = false;
      _safeNotify();
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
    _safeNotify();
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

  /// Persist built-in sample GPS routes so the map + trip list both show them.
  Future<int> seedSampleMapTrips() async {
    final samples = SampleMapTrips.asTrips();
    for (final t in samples) {
      await _supabase.createTrip(
        date: t.date,
        miles: t.miles,
        tips: t.tips,
        notes: t.notes,
        source: t.source,
        isBusiness: t.isBusiness,
        startLat: t.startLat,
        startLng: t.startLng,
        endLat: t.endLat,
        endLng: t.endLng,
        route: t.route.map((p) => p.toJson()).toList(),
      );
    }
    await refresh();
    return samples.length;
  }

  @override
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
      // Always sparsify before cloud write so map payload stays small.
      final storedRoute = route.length > 40
          ? GeoPoint.sparsify(route, maxPoints: 40)
          : route;
      trip = await _supabase.createTrip(
        date: date,
        miles: miles,
        tips: tips,
        notes: notes,
        source: source,
        isBusiness: isBusiness,
        startLat: startLat ??
            (storedRoute.isNotEmpty ? storedRoute.first.lat : null),
        startLng: startLng ??
            (storedRoute.isNotEmpty ? storedRoute.first.lng : null),
        endLat: endLat ?? (storedRoute.isNotEmpty ? storedRoute.last.lat : null),
        endLng: endLng ?? (storedRoute.isNotEmpty ? storedRoute.last.lng : null),
        route: storedRoute.map((p) => p.toJson()).toList(),
        startedAt: startedAt,
        endedAt: endedAt,
      );
      // Surface silent geometry loss (DB missing route columns).
      if (storedRoute.length >= 2 && !trip.hasMapGeometry) {
        error =
            'Trip saved, but the map could not store the route. '
            'In Supabase SQL Editor run migrations 002_trip_routes.sql '
            '(and 007_trip_timestamps.sql for trip times).';
        _safeNotify();
      }
    }
    await refresh();
    return trip;
  }

  /// One-tap Business ↔ Personal. Updates list optimistically, then syncs.
  Future<void> setTripBusiness(int id, bool isBusiness) async {
    final index = trips.indexWhere((t) => t.id == id);
    if (index >= 0) {
      trips = List<Trip>.from(trips)
        ..[index] = trips[index].copyWith(isBusiness: isBusiness);
      _safeNotify();
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
      _safeNotify();
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

  /// Full portable export of every trip (business + personal).
  Future<void> exportAllTrips() async {
    final all = await _supabase.getTrips();
    await DataExportService.shareAllTrips(all);
  }

  /// Delete every trip; keep the account and settings.
  Future<int> deleteAllTrips() async {
    if (tracking || _tracker.isTracking) {
      await _tracker.stop();
      tracking = false;
      liveMiles = 0;
      _stopLiveMilesPoll();
      await _lockScreen.publishImmediate(tracking: false);
    }
    final n = await _supabase.deleteAllTrips();
    await refresh();
    unawaited(_publishHomeWidget());
    return n;
  }

  /// Wipe cloud data for this user, clear local prefs, and end the session.
  ///
  /// Caller should sign out via [AuthState] after this returns.
  Future<void> deleteAccountData() async {
    if (tracking || _tracker.isTracking) {
      await _tracker.stop();
      tracking = false;
      liveMiles = 0;
      _stopLiveMilesPoll();
    }
    try {
      await _premium.setAutoDetect(false);
    } catch (_) {}
    await _supabase.deleteAccountData();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    trips = [];
    summary = null;
    reportHistory = [];
    pendingFunnelPrompt = null;
    error = null;
    _safeNotify();
  }
}
