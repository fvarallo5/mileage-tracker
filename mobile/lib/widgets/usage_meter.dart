import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Free-tier auto-trip usage bar (e.g. 12 / 30).
class UsageMeter extends StatelessWidget {
  final int used;
  final int limit;
  final bool compact;

  const UsageMeter({
    super.key,
    required this.used,
    required this.limit,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final safeLimit = limit <= 0 ? AppConfig.freeAutoTripsPerMonth : limit;
    final fraction = (used / safeLimit).clamp(0.0, 1.0);
    final left = (safeLimit - used).clamp(0, safeLimit);
    final warning = left <= 5;
    final barColor = left == 0
        ? AppColors.red
        : warning
            ? AppColors.amber
            : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                left == 0
                    ? 'Free limit reached ($used/$safeLimit this month)'
                    : 'Free · $left of $safeLimit auto trips left',
                style: TextStyle(
                  color: left == 0 || warning ? barColor : p.textMuted,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$used/$safeLimit',
              style: TextStyle(
                color: p.textMuted,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 6 : 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: compact ? 5 : 7,
            backgroundColor: p.surface3,
            color: barColor,
          ),
        ),
      ],
    );
  }
}
