import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/period_report.dart';
import '../theme/app_theme.dart';
import 'stat_card.dart';

final _currency = NumberFormat.currency(symbol: '\$');

/// Track-page stats: mileage metrics featured, earnings metrics de-emphasized.
class TrackStatsSection extends StatelessWidget {
  final PeriodReport report;

  const TrackStatsSection({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCard(
          label: 'Total Miles',
          value: report.totalMiles.toStringAsFixed(1),
          subtitle: 'mi driven this week',
          valueColor: AppColors.accent,
          icon: Icons.route,
          emphasis: StatEmphasis.featured,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Mileage Expense',
                value: _currency.format(report.mileageExpense),
                valueColor: AppColors.amber,
                icon: Icons.local_gas_station_outlined,
                emphasis: StatEmphasis.featured,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'Trips',
                value: report.tripCount.toString(),
                subtitle: 'logged',
                icon: Icons.local_shipping_outlined,
                emphasis: StatEmphasis.featured,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'EARNINGS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total Tips',
                value: _currency.format(report.totalTips),
                icon: Icons.payments_outlined,
                emphasis: StatEmphasis.muted,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: '\$/Mile',
                value: _currency.format(report.earningsPerMile),
                icon: Icons.trending_up,
                emphasis: StatEmphasis.muted,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: 'Net',
                value: _currency.format(report.netEarnings),
                icon: Icons.account_balance_wallet_outlined,
                emphasis: StatEmphasis.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}