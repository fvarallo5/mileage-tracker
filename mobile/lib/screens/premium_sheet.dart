import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/billing_config.dart';
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
        final annual = billing.preferAnnual;

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
            _PlanOption(
              selected: annual,
              badge: 'Best value',
              title: 'Annual',
              price: billing.loadingProducts ? '…' : billing.annualPriceLabel,
              detail: billing.annualPerMonthLabel,
              onTap: () => billing.setPreferAnnual(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PlanOption(
              selected: !annual,
              title: 'Monthly',
              price: billing.loadingProducts ? '…' : billing.monthlyPriceLabel,
              detail: 'Billed monthly',
              onTap: () => billing.setPreferAnnual(false),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              BillingConfig.trialDetailLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: AppColors.green,
                  ),
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
                  : Text(
                      'Start ${BillingConfig.trialDays}-day free trial',
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              annual
                  ? 'Then ${billing.annualPriceLabel}'
                  : 'Then ${billing.monthlyPriceLabel}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
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
                    ? (billing.selectedProduct != null
                        ? 'Store OK · products loaded'
                        : 'Store connected but products not found yet.')
                    : 'Store unavailable — use debug unlock offline.',
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

class _PlanOption extends StatelessWidget {
  final bool selected;
  final String? badge;
  final String title;
  final String price;
  final String detail;
  final VoidCallback onTap;

  const _PlanOption({
    required this.selected,
    this.badge,
    required this.title,
    required this.price,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.card),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.amber.withValues(alpha: p.isLight ? 0.12 : 0.14)
                : p.surface3,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.amber : p.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.amber : p.textMuted,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amber,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.amber : p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
