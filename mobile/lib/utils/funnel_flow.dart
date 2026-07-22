import 'package:flutter/material.dart';

import '../providers/app_state.dart';
import '../screens/funnel_prompt_sheet.dart';
import '../screens/limit_reached_sheet.dart';
import '../services/usage_service.dart';

/// Shows free→Pro funnel sheets with a max of one upgrade modal per day
/// (hard limit always shows when it fires).
class FunnelFlow {
  static Future<void> present(
    BuildContext context,
    AppState state,
    FunnelPrompt prompt,
  ) async {
    if (!context.mounted || state.isPremium) return;

    if (prompt == FunnelPrompt.hardLimitReached) {
      await state.usage.markUpgradeModalShownToday();
      if (!context.mounted) return;
      await showLimitReachedSheet(context);
      return;
    }

    // Soft prompts respect the once-per-day cap.
    final allowed = await state.usage.canShowUpgradeModalToday();
    if (!allowed) {
      // First-trip is value, not a hard sell — still show if blocked? Allow first trip always.
      if (prompt != FunnelPrompt.firstTrip) return;
    } else if (prompt == FunnelPrompt.softNearLimit) {
      await state.usage.markUpgradeModalShownToday();
    }

    if (!context.mounted) return;
    await showFunnelPromptSheet(context, prompt);
  }
}
