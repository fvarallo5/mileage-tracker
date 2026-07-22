import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';

Future<void> showPremiumSheet(
  BuildContext context, {
  bool? preferAnnual,
}) async {
  if (preferAnnual != null) {
    context.read<AppState>().billing.setPreferAnnual(preferAnnual);
  }
  await showAppBottomSheet(
    context,
    const _PremiumSheetContent(),
  );
}

class _PremiumSheetContent extends StatelessWidget {
  const _PremiumSheetContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final billing = state.billing;

        return AppBottomSheet(
          title: 'TrekTrack Pro',
          subtitle: 'Unlimited auto-detect. Built for full shifts.',
          children: [
            const _FeatureRow(
              icon: Icons.all_inclusive_rounded,
              title: 'Unlimited auto-detect',
              subtitle:
                  'Free includes ${AppConfig.freeAutoTripsPerMonth} auto trips/month. Pro never runs out mid-shift.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _FeatureRow(
              icon: Icons.gps_fixed_rounded,
              title: 'Background GPS all day',
              subtitle:
                  'Keep tracking when you switch to Uber, DoorDash, or Maps.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _FeatureRow(
              icon: Icons.battery_saver_outlined,
              title: 'Battery-smart modes',
              subtitle:
                  'Saver, balanced, or accuracy — tuned for full-time auto-detect.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _FeatureRow(
              icon: Icons.table_view_outlined,
              title: 'Tax package export',
              subtitle: 'Schedule C + TurboTax mileage CSVs from the Reports tab.',
            ),
            const SizedBox(height: AppSpacing.lg),
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
                        billing.loadingProducts ? 'Loading price…' : billing.priceLabel,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cancel anytime',
                        style: TextStyle(color: p.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (billing.lastError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                billing.lastError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: billing.purchasing || billing.loadingProducts
                  ? null
                  : () => _purchase(context, state),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: billing.purchasing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Subscribe to Pro'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: billing.restoring ? null : () => _restore(context, state),
              child: billing.restoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Text('Restore purchases'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => _devUnlock(context, state),
                child: const Text('Unlock for development (debug only)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                billing.storeAvailable
                    ? 'Store connected. Create products in App Store Connect / Play Console to test real purchases.'
                    : 'Store unavailable here — use the debug unlock to test Pro locally.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _purchase(BuildContext context, AppState state) async {
    final message = await state.purchasePremium();
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(BuildContext context, AppState state) async {
    final message = await state.restorePurchases();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (state.isPremium) Navigator.pop(context);
  }

  Future<void> _devUnlock(BuildContext context, AppState state) async {
    final message = await state.unlockPremiumForDevelopment();
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: ThemePalette.of(context).textMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
