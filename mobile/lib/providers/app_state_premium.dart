part of 'app_state.dart';

/// Billing, Pro entitlement, auto-detect, battery, and power gates.
mixin AppStatePremium on AppStateBase {
  Future<void> setBatteryMode(BatteryMode mode) async {
    await _battery.setMode(mode);
    await _autoDetect.applyMode(mode);
    // Hot-swap GPS sampling if a trip is already running.
    if (tracking) {
      await _tracker.applyBatteryMode(mode);
    }
    _safeNotify();
  }

  Future<void> setWorkHoursEnabled(bool enabled) async {
    await _workHours.setEnabled(enabled);
    _ensureWorkHoursTimer();
    await _syncAutoDetectMonitoring();
    _safeNotify();
  }

  Future<void> setWorkHoursStart(int minutes) async {
    await _workHours.setStartMinutes(minutes);
    await _syncAutoDetectMonitoring();
    _safeNotify();
  }

  Future<void> setWorkHoursEnd(int minutes) async {
    await _workHours.setEndMinutes(minutes);
    await _syncAutoDetectMonitoring();
    _safeNotify();
  }

  Future<void> setWorkHoursDay(int dayIndex, bool active) async {
    await _workHours.setDayActive(dayIndex, active);
    await _syncAutoDetectMonitoring();
    _safeNotify();
  }

  @override
  void _ensureWorkHoursTimer() {
    _workHoursTimer?.cancel();
    if (!_workHours.enabled || !_premium.autoDetectEnabled) {
      _workHoursTimer = null;
      return;
    }
    // Re-evaluate at the top of each minute so shift start/end apply promptly.
    _workHoursTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_syncAutoDetectMonitoring());
    });
  }

  Future<void> setCarBluetoothGate(bool enabled) async {
    await _carBluetooth.setGateEnabled(enabled);
    if (enabled && !_carBluetooth.hasPermission) {
      lastAutoDetectMessage =
          'Bluetooth permission is required for the car Bluetooth gate.';
    } else if (enabled && _carBluetooth.connected) {
      lastAutoDetectMessage =
          'Car Bluetooth connected — auto-detect can watch.';
    } else if (enabled) {
      lastAutoDetectMessage =
          'Car Bluetooth gate on — GPS watching sleeps until the car connects.';
    }
    await _syncAutoDetectMonitoring();
    _safeNotify();
  }

  Future<void> setChargingGate(bool enabled) async {
    await _chargingGate.setGateEnabled(enabled);
    if (enabled && _chargingGate.isPluggedIn) {
      lastAutoDetectMessage = 'Charger connected — auto-detect can watch.';
    } else if (enabled) {
      lastAutoDetectMessage =
          'Charger gate on — GPS watching sleeps until you plug in.';
    }
    await _syncAutoDetectMonitoring();
    _safeNotify();
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
    _safeNotify();
  }

  @override
  void _onPowerGateChanged() {
    // Car BT or activity flipped — start or stop idle GPS watch.
    unawaited(_syncAutoDetectMonitoring());
  }

  Future<String> purchasePremium({bool? annual}) async {
    final message = await _billing.purchasePremium(annual: annual);
    _safeNotify();
    return message;
  }

  Future<String> restorePurchases() async {
    final message = await _billing.restorePurchases();
    _safeNotify();
    return message;
  }

  void consumeFunnelPrompt() {
    pendingFunnelPrompt = null;
  }

  Future<String> unlockPremiumForDevelopment() async {
    await _billing.unlockForDevelopment();
    _safeNotify();
    if (_entitlements.lastSyncError != null) {
      return 'Pro unlocked locally. Cloud sync: ${_entitlements.lastSyncError}';
    }
    return 'Pro unlocked for development testing (synced to account).';
  }

  Future<void> disableAutoDetect() async {
    await _premium.setAutoDetect(false);
    _ensureWorkHoursTimer();
    await _syncAutoDetectMonitoring();
    _safeNotify();
  }

  Future<String?> enableAutoDetect() async {
    if (!canUseAutoDetect) {
      return 'Free auto-detect limit reached (${AppConfig.freeAutoTripsPerMonth}/month). Upgrade to Pro for unlimited.';
    }

    final permError = await _tracker.requestBackgroundPermission();
    if (permError != null) return permError;

    await _premium.setAutoDetect(true);
    _ensureWorkHoursTimer();
    await _syncAutoDetectMonitoring();
    _safeNotify();
    return null;
  }

  @override
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
        _safeNotify();
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
    _safeNotify();
  }

  @override
  Future<void> _handleAutoTripStarted() async {
    if (tracking || _tracker.isTracking || _stopInFlight) {
      // Auto-detect thought a drive started while a trip was already live.
      _autoDetect.cancelPendingStart(detail: 'Trip already active');
      return;
    }

    if (!canUseAutoDetect) {
      lastAutoDetectMessage =
          'Auto-detect paused — free monthly limit reached.';
      _autoDetect.cancelPendingStart(detail: 'Free limit reached');
      await _premium.setAutoDetect(false);
      await _syncAutoDetectMonitoring();
      _safeNotify();
      return;
    }

    if (!_workHours.allowsAutoDetectWatch) {
      lastAutoDetectMessage = 'Outside work hours — auto-start skipped';
      _autoDetect.cancelPendingStart(detail: 'Outside work hours');
      _safeNotify();
      return;
    }

    if (!connected) {
      lastAutoDetectMessage =
          'Drive detected, but you\'re offline. Connect to save auto trips.';
      // Stay ready to try again after cooldown.
      _autoDetect.cancelPendingStart(detail: 'Offline — try again soon');
      _safeNotify();
      return;
    }

    lastAutoDetectMessage = 'Drive confirmed — starting trip';
    _safeNotify();

    // Stop idle watch; active trip GPS is owned by TripTracker.
    // startTracking arms parked auto-stop when the setting is on.
    await _autoDetect.stopMonitoring();
    await startTracking(background: true, autoStarted: true);

    if (tracking) {
      lastAutoDetectMessage = 'Auto trip in progress';
    } else {
      // Start failed — don't leave auto-detect stuck in "trip active".
      lastAutoDetectMessage = error ?? 'Could not start auto trip GPS';
      _autoDetect.resumeAfterTrip();
      await _syncAutoDetectMonitoring();
    }
    _safeNotify();
  }

  @override
  Future<void> _handleAutoTripEnded() async {
    // Manual trips with auto-stop enabled also end here; wasAuto is false then.
    if (!tracking || _stopInFlight) return;
    if (!autoStopEnabled) return;
    if (!_tracker.isAutoStarted && !_premium.autoDetectEnabled) return;

    final milesSnapshot = liveMiles > 0 ? liveMiles : _tracker.currentMiles;
    final wasAuto = _tracker.isAutoStarted;
    final trip = await stopTracking(
      tips: 0,
      notes: wasAuto ? 'Auto-detected trip' : 'Auto-stopped trip',
      source: wasAuto ? 'autodetect' : 'gps',
    );
    // Usage is recorded inside stopTracking for auto-sourced trips.
    if (trip != null) {
      final left = _usage.remainingFreeAutoTrips;
      if (wasAuto) {
        lastAutoDetectMessage = isPremium
            ? 'Auto-saved ${trip.miles.toStringAsFixed(1)} mi'
            : 'Auto-saved ${trip.miles.toStringAsFixed(1)} mi · $left free left this month';
        if (!isPremium && !_usage.hasFreeAutoTripsRemaining) {
          lastAutoDetectMessage =
              'Auto-saved ${trip.miles.toStringAsFixed(1)} mi · free limit reached';
        }
      } else {
        lastAutoDetectMessage =
            'Auto-stopped ${trip.miles.toStringAsFixed(1)} mi trip';
      }
    } else {
      lastAutoDetectMessage = milesSnapshot < 0.25
          ? 'Skipped short hop (${milesSnapshot.toStringAsFixed(2)} mi) — not saved'
          : 'Trip too short to save (${milesSnapshot.toStringAsFixed(2)} mi)';
    }
    _safeNotify();
  }
}
