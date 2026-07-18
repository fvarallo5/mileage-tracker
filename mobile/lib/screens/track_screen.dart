import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/premium_permission_flow.dart';
import '../widgets/premium_card.dart';
import '../widgets/section_header.dart';
import '../widgets/track_stats_section.dart';
import '../widgets/tracking_hero.dart';

class TrackScreen extends StatelessWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.loading && state.summary == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: state.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
            children: [
              if (state.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.card),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: AppColors.red, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(state.error!, style: const TextStyle(color: AppColors.red, fontSize: 13))),
                    ],
                  ),
                ),
              if (state.lastAutoDetectMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.card),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar_rounded, color: AppColors.green, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          state.lastAutoDetectMessage!,
                          style: const TextStyle(color: AppColors.green, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              PremiumCard(state: state),
              TrackingHero(
                state: state,
                onStart: () => PremiumPermissionFlow.startManualTrip(context, state),
                onStop: () => _stopTrip(context, state),
              ),
              if (state.summary != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(title: 'This Week', subtitle: state.summary!.weekly.label),
                TrackStatsSection(report: state.summary!.weekly),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _stopTrip(BuildContext context, AppState state) async {
    final tipsController = TextEditingController();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (ctx) {
                final p = ThemePalette.of(ctx);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.card),
                  decoration: BoxDecoration(
                    color: p.surface3,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        state.liveMiles.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                      Text('miles', style: TextStyle(color: p.textMuted)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: tipsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tips / Earnings (\$)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save Trip')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final tips = double.tryParse(tipsController.text) ?? 0;
    final trip = await state.stopTracking(tips: tips, notes: notesController.text);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trip != null
            ? 'Saved ${trip.miles.toStringAsFixed(1)} mi trip'
            : 'Trip too short to save'),
      ),
    );
  }
}