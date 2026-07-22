import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import 'premium_sheet.dart';

/// Hard wall when free auto-detect trips are exhausted.
Future<void> showLimitReachedSheet(BuildContext context) async {
  await showAppBottomSheet(
    context,
    const _LimitReachedContent(),
  );
}

class _LimitReachedContent extends StatelessWidget {
  const _LimitReachedContent();

  @override
  Widget build(BuildContext context) {
    final limit = AppConfig.freeAutoTripsPerMonth;
    final p = context.palette;

    return AppBottomSheet(
      title: 'Free auto-detect used up',
      subtitle: 'You used all $limit auto trips this month.',
      children: [
        Text(
          'Manual tracking and your trip history still work. '
          'Pro unlocks unlimited auto-detect and background GPS for full shifts.',
          style: TextStyle(color: p.textMuted, height: 1.4, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            showPremiumSheet(context, preferAnnual: true);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 52),
          ),
          child: Consumer<AppState>(
            builder: (context, state, _) {
              final label = state.billing.loadingProducts
                  ? 'Get Pro'
                  : 'Get Pro · ${state.billing.annualPriceLabel}';
              return Text(label, textAlign: TextAlign.center);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
            showPremiumSheet(context, preferAnnual: false);
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Consumer<AppState>(
            builder: (context, state, _) {
              return Text(
                state.billing.loadingProducts
                    ? 'See monthly plan'
                    : state.billing.monthlyPriceLabel,
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep using manual for free'),
        ),
      ],
    );
  }
}
