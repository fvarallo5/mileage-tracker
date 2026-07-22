import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/usage_meter.dart';
import 'premium_sheet.dart';

/// Soft funnel moments: first trip celebration or "5 left" upsell.
Future<void> showFunnelPromptSheet(
  BuildContext context,
  FunnelPrompt prompt,
) async {
  if (prompt == FunnelPrompt.hardLimitReached) return;
  await showAppBottomSheet(
    context,
    _FunnelPromptContent(prompt: prompt),
  );
}

class _FunnelPromptContent extends StatelessWidget {
  final FunnelPrompt prompt;

  const _FunnelPromptContent({required this.prompt});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final used = state.usage.autoTripsThisMonth;
    final limit = state.usage.freeLimit;
    final left = state.usage.remainingFreeAutoTrips;

    final isFirst = prompt == FunnelPrompt.firstTrip;
    final title = isFirst ? 'First auto trip saved' : 'Only $left free trips left';
    final subtitle = isFirst
        ? 'Auto-detect is working. Free includes ${AppConfig.freeAutoTripsPerMonth} auto trips/month.'
        : 'Most drivers who run full shifts upgrade before a busy week.';

    return AppBottomSheet(
      title: title,
      subtitle: subtitle,
      children: [
        UsageMeter(used: used, limit: limit),
        const SizedBox(height: AppSpacing.lg),
        if (isFirst)
          Text(
            'You still have $left free auto trips this month. '
            'Manual trips are always unlimited.',
            style: TextStyle(color: p.textMuted, height: 1.4, fontSize: 14),
          )
        else
          Text(
            'Upgrade to Pro for unlimited auto-detect and background GPS — '
            'less than a coffee a month on annual.',
            style: TextStyle(color: p.textMuted, height: 1.4, fontSize: 14),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (!isFirst) ...[
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showPremiumSheet(context, preferAnnual: true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('View Pro'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isFirst ? 'Got it' : 'Not now'),
        ),
      ],
    );
  }
}
