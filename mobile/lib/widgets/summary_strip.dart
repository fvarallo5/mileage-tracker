import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/period_report.dart';
import '../theme/app_theme.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

class SummaryStrip extends StatelessWidget {
  final PeriodReport? weekly;
  final PeriodReport? monthly;
  final PeriodReport? annual;

  const SummaryStrip({
    super.key,
    this.weekly,
    this.monthly,
    this.annual,
  });

  @override
  Widget build(BuildContext context) {
    if (weekly == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              label: 'Week',
              value: '${weekly!.totalMiles.toStringAsFixed(0)} mi',
              sub: '${_currency.format(weekly!.earningsPerMile)}/mi',
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _MiniStat(
              label: 'Month',
              value: _currency.format(monthly?.totalTips ?? 0),
              sub: '${monthly?.tripCount ?? 0} trips',
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _MiniStat(
              label: 'YTD',
              value: '${annual?.totalMiles.toStringAsFixed(0) ?? '0'} mi',
              sub: '${_currency.format(annual?.mileageExpense ?? 0)} expense',
              color: AppColors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
          ),
          Text(sub, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}