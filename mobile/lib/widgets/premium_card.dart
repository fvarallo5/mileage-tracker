import 'package:flutter/material.dart';

import '../providers/app_state.dart';
import '../screens/premium_sheet.dart';
import '../theme/app_theme.dart';
import '../utils/premium_permission_flow.dart';

class PremiumCard extends StatelessWidget {
  final AppState state;

  const PremiumCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isPremium) {
      return _PremiumActiveCard(state: state);
    }
    return _PremiumUpsellCard(onUpgrade: () => showPremiumSheet(context));
  }
}

class _PremiumUpsellCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _PremiumUpsellCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.amber.withValues(alpha: 0.18),
            AppColors.surface2,
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
                child: const Icon(Icons.workspace_premium_rounded, color: AppColors.amber, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Premium — hands-free mileage',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Background GPS keeps tracking while you drive for Uber or DoorDash. Auto-detect starts and saves trips automatically.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onUpgrade,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('View Premium'),
          ),
        ],
      ),
    );
  }
}

class _PremiumActiveCard extends StatelessWidget {
  final AppState state;

  const _PremiumActiveCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.amber, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Premium active',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
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
                      Text('Watching', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-detect trips'),
            subtitle: const Text(
              'Starts when you drive ~9+ mph for 30s. Stops after ~3 min parked.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            value: state.autoDetectEnabled,
            onChanged: (enabled) => PremiumPermissionFlow.setAutoDetect(context, state, enabled),
          ),
          if (state.trackingInBackground || state.trackingIsAuto)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                state.trackingIsAuto ? 'Auto-detected trip in progress' : 'Tracking in background',
                style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}