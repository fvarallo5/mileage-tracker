import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/period_report.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/report_stats_grid.dart';
import '../widgets/section_header.dart';

final _currency = NumberFormat.currency(symbol: '\$');

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final current = _currentReport(state);

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: state.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'weekly', label: Text('Weekly')),
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ButtonSegment(value: 'annual', label: Text('Annual')),
                ],
                selected: {state.reportPeriod},
                onSelectionChanged: (s) => state.setReportPeriod(s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (current != null) ...[
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accentDark.withValues(alpha: 0.35),
                        AppColors.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Period', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(current.label, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '${current.startDate} – ${current.endDate}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ReportStatsGrid(report: current),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'IRS rate: ${_currency.format(current.mileageRate)}/mi',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const SectionHeader(title: 'History'),
              ...state.reportHistory.map((r) => _HistoryTile(report: r)),
            ],
          ),
        );
      },
    );
  }

  PeriodReport? _currentReport(AppState state) {
    final summary = state.summary;
    if (summary == null) return null;
    return switch (state.reportPeriod) {
      'monthly' => summary.monthly,
      'annual' => summary.annual,
      _ => summary.weekly,
    };
  }
}

class _HistoryTile extends StatelessWidget {
  final PeriodReport report;

  const _HistoryTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final netPositive = report.netEarnings >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.card, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.card, 0, AppSpacing.card, AppSpacing.card),
            leading: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: netPositive ? AppColors.green : AppColors.red,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text(report.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
            subtitle: Text(
              '${report.totalMiles.toStringAsFixed(1)} mi · ${_currency.format(report.totalTips)} tips',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
            children: [
              _row('Mileage expense', _currency.format(report.mileageExpense), AppColors.amber),
              _row('Earnings / mile', _currency.format(report.earningsPerMile), AppColors.green),
              _row('Net earnings', _currency.format(report.netEarnings), netPositive ? AppColors.green : AppColors.red),
              _row('Trips', report.tripCount.toString(), AppColors.text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
        ],
      ),
    );
  }
}