part of 'app_state.dart';

/// Manual / GPS session control, lock screen, map-match, live miles.
mixin AppStateTracking on AppStateBase {
  static const _autoStopKey = 'auto_stop_trips';

  Future<void> setLockScreenControlsEnabled(bool enabled) async {
    await _lockScreen.setEnabled(enabled);
    if (enabled && tracking) {
      await _lockScreen.publishImmediate(
        tracking: true,
        miles: liveMiles,
        isAuto: _tracker.isAutoStarted,
      );
    } else if (!enabled || !tracking) {
      await _lockScreen.clearAll();
    }
    _safeNotify();
  }

  Future<void> setAutoStopEnabled(bool enabled) async {
    autoStopEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStopKey, enabled);
    _safeNotify();
  }

  @override
  Future<void> _loadAutoStopPref() async {
    final prefs = await SharedPreferences.getInstance();
    autoStopEnabled = prefs.getBool(_autoStopKey) ?? true;
  }

  Future<void> setMapMatchEnabled(bool enabled) =>
      _mapMatch.setEnabled(enabled);

  @override
  Future<String> startTrackingFromVoice() async {
    if (tracking) return 'Already tracking a trip.';
    if (!connected) {
      return 'Cannot reach Supabase. Open ${AppConfig.appName} and check your connection.';
    }

    await startTracking();
    if (error != null) return error!;
    return 'Started GPS trip tracking.';
  }

  @override
  Future<String> stopTrackingFromVoice() async {
    if (!tracking && !_tracker.isTracking) {
      await _forceIdleUi();
      return 'No active trip to stop.';
    }

    final milesSnapshot = liveMiles > 0 ? liveMiles : _tracker.currentMiles;
    final trip = await stopTracking(tips: 0, notes: 'Stopped via voice');
    if (trip == null) {
      // May already have been auto-saved — still clear the banner.
      await _forceIdleUi();
      if (milesSnapshot < 0.1) {
        return 'No active trip (already saved or too short).';
      }
      return 'Trip already saved or too short (${milesSnapshot.toStringAsFixed(2)} mi).';
    }
    return 'Saved ${trip.miles.toStringAsFixed(1)} mile trip.';
  }

  /// Clears hero miles + lock-screen banners even if stop was a no-op.
  Future<void> _forceIdleUi() async {
    tracking = false;
    liveMiles = 0;
    _stopLiveMilesPoll();
    await _lockScreen.clearAll();
    unawaited(_publishHomeWidget());
    _safeNotify();
  }

  @override
  Future<void> startTracking({
    bool background = false,
    bool autoStarted = false,
  }) async {
    if (tracking || _tracker.isTracking) {
      error = null;
      return;
    }
    if (_stopInFlight) {
      error = 'Still finishing the previous trip — try again in a moment.';
      _safeNotify();
      return;
    }

    final useBackground = background || autoStarted || _premium.isPremium;
    final permError = useBackground
        ? await _tracker.requestBackgroundPermission()
        : await _tracker.requestForegroundPermission();
    if (permError != null) {
      error = permError;
      _safeNotify();
      return;
    }

    // Manual start: stop idle auto-watch so we don't double-start.
    if (!autoStarted && _autoDetect.isMonitoring) {
      await _autoDetect.stopMonitoring();
    }

    await _tracker.start(
      background: useBackground,
      autoStarted: autoStarted,
      batteryMode: _battery.mode,
    );
    tracking = true;
    liveMiles = 0;
    error = null;

    if (_shouldAutoStopThisTrip(autoStarted: autoStarted)) {
      _autoDetect.pauseForActiveTrip();
    }

    _safeNotify();

    await _lockScreen.publishImmediate(
      tracking: true,
      miles: 0,
      isAuto: autoStarted,
    );
    unawaited(_publishHomeWidget());
    _pollLiveMiles();

    await _syncAutoDetectMonitoring();
  }

  bool _shouldAutoStopThisTrip({required bool autoStarted}) {
    if (!autoStopEnabled) return false;
    if (autoStarted) return true;
    return _premium.autoDetectEnabled;
  }

  @override
  void _pollLiveMiles() {
    _liveMilesTimer?.cancel();
    if (!tracking || !_tracker.isTracking) {
      if (tracking && !_tracker.isTracking) {
        // Tracker died under us — force idle so UI doesn't stick on last total.
        unawaited(_forceIdleUi());
      }
      return;
    }
    liveMiles = _tracker.currentMiles;
    _safeNotify();
    unawaited(
      _lockScreen.publish(
        tracking: true,
        miles: liveMiles,
        isAuto: _tracker.isAutoStarted,
      ),
    );
    unawaited(_publishHomeWidget());
    _liveMilesTimer = Timer(const Duration(milliseconds: 500), _pollLiveMiles);
  }

  @override
  void _stopLiveMilesPoll() {
    _liveMilesTimer?.cancel();
    _liveMilesTimer = null;
  }

  /// Stable key for a GPS session so we never save the same drive twice.
  String _sessionKey(DateTime? startedAt, double miles) {
    final start = startedAt?.toUtc().millisecondsSinceEpoch ?? 0;
    final mi = (miles * 100).round(); // 0.01 mi
    return '$start|$mi';
  }

  bool _isDuplicateOfRecent({
    required double miles,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    final key = _sessionKey(startedAt, miles);
    if (_lastClosedSessionKey == key &&
        _lastClosedSessionAt != null &&
        DateTime.now().difference(_lastClosedSessionAt!) <
            const Duration(minutes: 10)) {
      return true;
    }

    for (final t in trips) {
      final tStart = t.startedAtDate;
      if (startedAt != null && tStart != null) {
        final gap = startedAt.difference(tStart).abs();
        if (gap <= const Duration(minutes: 2) &&
            (t.miles - miles).abs() < 0.2) {
          return true;
        }
      }
      final created = t.createdAtDate;
      if (created != null &&
          DateTime.now().difference(created) < const Duration(minutes: 4) &&
          (t.miles - miles).abs() < 0.15) {
        return true;
      }
      // Overlapping end times (auto-save then manual stop seconds later).
      final tEnd = t.endedAtDate;
      if (endedAt != null && tEnd != null) {
        final endGap = endedAt.difference(tEnd).abs();
        if (endGap <= const Duration(minutes: 3) &&
            (t.miles - miles).abs() < 0.2) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<Trip?> stopTracking({
    double tips = 0,
    String notes = '',
    String source = 'gps',
  }) async {
    // Re-entrancy: auto-end + manual stop / double notification taps.
    if (_stopInFlight) {
      await _lockScreen.clearAll();
      return null;
    }
    if (!tracking && !_tracker.isTracking) {
      await _forceIdleUi();
      return null;
    }
    _stopInFlight = true;

    try {
      final wasAuto = _tracker.isAutoStarted;
      final sessionStart = _tracker.startedAt;

      // 1) Stop GPS + clear UI *before* network save so the hero total resets
      // even if map-match / Supabase is slow (this was the double-log UX bug).
      final result = await _tracker.stop();
      tracking = false;
      liveMiles = 0;
      _stopLiveMilesPoll();
      await _lockScreen.clearAll();
      unawaited(_publishHomeWidget());
      _safeNotify();

      if (_premium.autoDetectEnabled) {
        _autoDetect.resumeAfterTrip();
        // Don't await full re-arm until after save — keeps UI snappy.
        unawaited(_syncAutoDetectMonitoring());
      } else {
        _autoDetect.resumeAfterTrip();
      }

      final minMiles = wasAuto ? 0.25 : 0.1;
      if (result.miles < minMiles) {
        _lastClosedSessionKey = _sessionKey(result.startedAt ?? sessionStart, result.miles);
        _lastClosedSessionAt = DateTime.now();
        // Extra clear after short delay (iOS can re-show last banner).
        unawaited(Future<void>.delayed(const Duration(milliseconds: 400), () {
          return _lockScreen.clearAll();
        }));
        return null;
      }

      if (_isDuplicateOfRecent(
        miles: result.miles,
        startedAt: result.startedAt ?? sessionStart,
        endedAt: result.endedAt,
      )) {
        lastAutoDetectMessage =
            'Already saved ${result.miles.toStringAsFixed(1)} mi — skipped duplicate';
        _safeNotify();
        await _lockScreen.clearAll();
        return null;
      }

      final today = DateFormat('yyyy-MM-dd').format(
        (result.endedAt ?? DateTime.now()).toLocal(),
      );
      final refined = await _mapMatch.refine(
        points: result.route,
        gpsMiles: result.miles,
      );
      final path = refined.route.length >= 2 ? refined.route : result.route;

      // Second dedupe pass after map-match (miles may shift slightly).
      if (_isDuplicateOfRecent(
        miles: refined.miles,
        startedAt: result.startedAt ?? sessionStart,
        endedAt: result.endedAt,
      )) {
        lastAutoDetectMessage =
            'Already saved — skipped duplicate (${refined.miles.toStringAsFixed(1)} mi)';
        _safeNotify();
        await _lockScreen.clearAll();
        return null;
      }

      final trip = await saveTrip(
        date: today,
        miles: refined.miles,
        tips: tips,
        notes: notes,
        source: wasAuto ? 'autodetect' : source,
        isBusiness: true,
        startLat: path.isNotEmpty ? path.first.lat : result.start?.lat,
        startLng: path.isNotEmpty ? path.first.lng : result.start?.lng,
        endLat: path.isNotEmpty ? path.last.lat : result.end?.lat,
        endLng: path.isNotEmpty ? path.last.lng : result.end?.lng,
        route: path,
        startedAt: result.startedAt ?? sessionStart,
        endedAt: result.endedAt,
      );

      _lastClosedSessionKey =
          _sessionKey(result.startedAt ?? sessionStart, refined.miles);
      _lastClosedSessionAt = DateTime.now();

      if (wasAuto) {
        final prompt = await _usage.recordAutoTrip(isPremium: isPremium);
        if (prompt != null) {
          pendingFunnelPrompt = prompt;
        }
        if (!isPremium && !_usage.hasFreeAutoTripsRemaining) {
          await _premium.setAutoDetect(false);
          await _syncAutoDetectMonitoring();
        }
        _safeNotify();
      }

      // Kill any re-posted banners after save/refresh.
      await _lockScreen.clearAll();
      unawaited(Future<void>.delayed(const Duration(seconds: 1), () {
        return _lockScreen.clearAll();
      }));

      return trip;
    } finally {
      _stopInFlight = false;
      // Absolute guarantee: never leave hero in "tracking" after stop returns.
      if (tracking && !_tracker.isTracking) {
        tracking = false;
        liveMiles = 0;
        _stopLiveMilesPoll();
        _safeNotify();
      }
    }
  }

  @override
  void _onTrackerPosition(Position position) {
    if (!tracking || !_tracker.isTracking) return;
    if (!_shouldAutoStopThisTrip(autoStarted: _tracker.isAutoStarted)) return;
    if (!_autoDetect.isTripActive) {
      _autoDetect.pauseForActiveTrip();
    }
    _autoDetect.evaluateActiveTrip(position);
  }

  /// Called when app returns to foreground — clear stuck UI / banners.
  Future<void> onAppResumed() async {
    if (!tracking || !_tracker.isTracking) {
      await _forceIdleUi();
    } else {
      // Still tracking — refresh lock screen quietly.
      await _lockScreen.publish(
        tracking: true,
        miles: liveMiles,
        isAuto: _tracker.isAutoStarted,
        alert: false,
      );
    }
    // Soft reconnect after long dormancy.
    if (SupabaseConfig.isConfigured) {
      unawaited(refresh());
    }
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openAppSettings();
  }
}
