import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../screens/premium_sheet.dart';
import '../services/autodetect_service.dart';
import '../services/battery_mode.dart';
import '../theme/app_theme.dart';
import '../utils/premium_permission_flow.dart';
import 'usage_meter.dart';

class PremiumCard extends StatelessWidget {
  final AppState state;

  const PremiumCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AutoDetectCard(state: state),
        if (!state.isPremium) ...[
          const SizedBox(height: AppSpacing.md),
          _ProUpsellCard(onUpgrade: () => showPremiumSheet(context)),
        ],
      ],
    );
  }
}

class _AutoDetectCard extends StatelessWidget {
  final AppState state;

  const _AutoDetectCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final freeLeft = state.usage.remainingFreeAutoTrips;
    final freeLimit = state.usage.freeLimit;
    final used = state.usage.autoTripsThisMonth;
    final waitingOnGate = state.isWaitingOnPowerGate;
    final active = state.autoDetectEnabled &&
        (state.autoDetectMonitoring || state.trackingIsAuto || waitingOnGate);
    final phaseColor = waitingOnGate ? AppColors.amber : _phaseColor(state);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: active ? phaseColor.withValues(alpha: 0.45) : p.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.radar_rounded,
                color: active ? phaseColor : AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Auto-detect',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: phaseColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: phaseColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _phaseChipLabel(state),
                    style: TextStyle(
                      color: phaseColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (state.autoDetectEnabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.trackingIsAuto
                  ? 'Trip in progress · ${state.liveMiles.toStringAsFixed(1)} mi'
                  : waitingOnGate
                      ? (state.powerGateWaitLabel ?? 'Waiting…')
                      : state.autoDetectStatusLabel,
              style: TextStyle(
                color: p.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (waitingOnGate)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'GPS watching is asleep to save battery.',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              )
            else if (state.autoDetectStatusDetail != null && !state.trackingIsAuto)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  state.autoDetectStatusDetail!,
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ),
            if (state.carBluetoothGateEnabled && state.carBluetoothConnected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_connected, size: 14, color: AppColors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.carBluetooth.deviceName ?? 'Car Bluetooth connected',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (state.activityGateEnabled && state.activityInVehicle)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car_filled, size: 14, color: AppColors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.activityRecognition.activityLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (state.isPremium)
            const Text(
              'Pro · unlimited auto trips',
              style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600),
            )
          else ...[
            Text(
              freeLeft > 0
                  ? 'Free · $freeLeft of $freeLimit auto trips left this month'
                  : 'Free limit reached ($used/$freeLimit this month)',
              style: TextStyle(
                color: freeLeft > 0 ? p.textMuted : AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            UsageMeter(used: used, limit: freeLimit, compact: true),
            if (freeLeft > 0 && freeLeft <= 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Only $freeLeft free auto trips left — upgrade for unlimited.',
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Auto-detect trips', style: TextStyle(color: p.text)),
            subtitle: Text(
              state.isPremium
                  ? 'Starts after sustained driving. Ends after you park. Unlimited.'
                  : 'Starts ~9+ mph after motion + distance check. Free: $freeLimit/month.',
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
            value: state.autoDetectEnabled,
            onChanged: (enabled) =>
                PremiumPermissionFlow.setAutoDetect(context, state, enabled),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Battery mode',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          SegmentedButton<BatteryMode>(
            segments: [
              for (final mode in BatteryMode.values)
                ButtonSegment(
                  value: mode,
                  label: Text(mode.label.split(' ').first, style: const TextStyle(fontSize: 11)),
                  tooltip: mode.description,
                ),
            ],
            selected: {state.batteryMode},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) state.setBatteryMode(set.first);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (state.trackingInBackground && !state.trackingIsAuto)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Manual tracking in background',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _phaseColor(AppState state) {
    if (state.trackingIsAuto) return AppColors.green;
    return switch (state.autoDetectPhase) {
      AutoDetectPhase.confirmingStart => AppColors.amber,
      AutoDetectPhase.confirmingStop => AppColors.amber,
      AutoDetectPhase.tripActive => AppColors.green,
      AutoDetectPhase.watching => AppColors.green,
      AutoDetectPhase.off => AppColors.accent,
    };
  }

  String _phaseChipLabel(AppState state) {
    if (state.trackingIsAuto) {
      return switch (state.autoDetectPhase) {
        AutoDetectPhase.confirmingStop => 'Parking…',
        _ => 'On trip',
      };
    }
    if (state.isWaitingOnPowerGate) {
      if (!state.carBluetooth.allowsAutoDetectWatch) return 'Car BT';
      if (!state.activityRecognition.allowsAutoDetectWatch) return 'Motion';
      return 'Wait';
    }
    return switch (state.autoDetectPhase) {
      AutoDetectPhase.confirmingStart => 'Starting…',
      AutoDetectPhase.watching => 'Watching',
      AutoDetectPhase.tripActive => 'On trip',
      AutoDetectPhase.confirmingStop => 'Parking…',
      AutoDetectPhase.off => 'On',
    };
  }
}

class _ProUpsellCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _ProUpsellCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.amber.withValues(alpha: p.isLight ? 0.12 : 0.18),
            p.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.amber,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'TrekTrack Pro',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Unlimited auto-detect, background GPS all shift, and accounting export later. Free includes ${AppConfig.freeAutoTripsPerMonth} auto trips/month.',
            style: TextStyle(
              color: p.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onUpgrade,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('View Pro'),
          ),
        ],
      ),
    );
  }
}
