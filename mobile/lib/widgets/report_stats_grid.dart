import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/period_report.dart';
import '../theme/app_theme.dart';
import 'stat_card.dart';

final _currency = NumberFormat.currency(symbol: '\$');

class ReportStatsGrid extends StatelessWidget {
  final PeriodReport report;

  const ReportStatsGrid({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.55,
      children: [
        StatCard(
          label: 'Total Miles',
          value: report.totalMiles.toStringAsFixed(1),
          valueColor: AppColors.accent,
          icon: Icons.route,
        ),
        StatCard(
          label: 'Total Tips',
          value: _currency.format(report.totalTips),
          valueColor: AppColors.green,
          icon: Icons.payments_outlined,
        ),
        StatCard(
          label: 'Mileage Expense',
          value: _currency.format(report.mileageExpense),
          valueColor: AppColors.amber,
          icon: Icons.local_gas_station_outlined,
        ),
        StatCard(
          label: 'Earnings / Mile',
          value: _currency.format(report.earningsPerMile),
          valueColor: AppColors.green,
          icon: Icons.trending_up,
        ),
        StatCard(
          label: 'Net Earnings',
          value: _currency.format(report.netEarnings),
          valueColor: report.netEarnings >= 0 ? AppColors.green : AppColors.red,
          icon: Icons.account_balance_wallet_outlined,
        ),
        StatCard(
          label: 'Trips',
          value: report.tripCount.toString(),
          icon: Icons.local_shipping_outlined,
        ),
      ],
    );
  }
}