import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../screens/premium_sheet.dart';
import '../services/battery_mode.dart';
import '../theme/app_theme.dart';
import '../utils/premium_permission_flow.dart';

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

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: state.autoDetectMonitoring
              ? AppColors.green.withValues(alpha: 0.4)
              : p.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.radar_rounded,
                color: state.autoDetectMonitoring ? AppColors.green : AppColors.accent,
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
              if (state.autoDetectMonitoring)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar_rounded, color: AppColors.green, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Watching',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.isPremium)
            const Text(
              'Pro · unlimited auto trips',
              style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600),
            )
          else
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Auto-detect trips', style: TextStyle(color: p.text)),
            subtitle: Text(
              state.isPremium
                  ? 'Starts when you drive. Stops after you park. Unlimited.'
                  : 'Starts when you drive ~9+ mph. Free: $freeLimit/month.',
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
          if (state.trackingInBackground || state.trackingIsAuto)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                state.trackingIsAuto
                    ? 'Auto-detected trip in progress'
                    : 'Tracking in background',
                style: const TextStyle(
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
