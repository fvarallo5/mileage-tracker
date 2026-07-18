import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/period_report.dart';
import '../providers/app_state.dart';
import '../services/irs_mileage_rate.dart';
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
        final p = context.palette;
        final taxYear = IrsMileageRate.currentYear;

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: state.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            children: [
              // Tax export package
              Container(
                padding: const EdgeInsets.all(AppSpacing.card),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_zip_outlined, color: AppColors.accent, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Tax package',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: p.text,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Business miles only (personal trips excluded). TurboTax-ready log '
                      'and Schedule C summary for $taxYear.',
                      style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.35),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: state.trips.isEmpty
                          ? null
                          : () => _exportTax(context, state, taxYear),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text('Export $taxYear tax package'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    if (taxYear > 2024) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: state.trips.isEmpty
                            ? null
                            : () => _exportTax(context, state, taxYear - 1),
                        icon: const Icon(Icons.history, size: 18),
                        label: Text('Export ${taxYear - 1} tax package'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

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
                        AppColors.accent.withValues(alpha: p.isLight ? 0.08 : 0.35),
                        p.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: p.border),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current period',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current.label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: p.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${current.startDate} – ${current.endDate}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: p.textMuted,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ReportStatsGrid(report: current),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'IRS rate: ${IrsMileageRate.centsLabel(current.mileageRate)} '
                        '(per-trip rates applied for multi-year ranges)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: p.textMuted,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: current.tripCount == 0
                            ? null
                            : () => _exportPeriod(context, state, current),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share this period'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const SectionHeader(title: 'History'),
              ...state.reportHistory.map(
                (r) => _HistoryTile(
                  report: r,
                  onExport: () => _exportPeriod(context, state, r),
                ),
              ),
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

  Future<void> _exportTax(BuildContext context, AppState state, int year) async {
    try {
      await state.exportTaxPackage(year: year);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportPeriod(
    BuildContext context,
    AppState state,
    PeriodReport report,
  ) async {
    try {
      await state.exportPeriodReport(report);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

class _HistoryTile extends StatelessWidget {
  final PeriodReport report;
  final VoidCallback onExport;

  const _HistoryTile({required this.report, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final netPositive = report.netEarnings >= 0;
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.card, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.card,
              0,
              AppSpacing.card,
              AppSpacing.card,
            ),
            leading: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: netPositive ? AppColors.green : AppColors.red,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text(
              report.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    color: p.text,
                  ),
            ),
            subtitle: Text(
              '${report.totalMiles.toStringAsFixed(1)} mi · ${_currency.format(report.totalTips)} tips',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
            children: [
              _row(context, 'Mileage expense', _currency.format(report.mileageExpense), AppColors.amber),
              _row(context, 'Earnings / mile', _currency.format(report.earningsPerMile), AppColors.green),
              _row(
                context,
                'Net earnings',
                _currency.format(report.netEarnings),
                netPositive ? AppColors.green : AppColors.red,
              ),
              _row(context, 'Trips', report.tripCount.toString(), p.text),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: report.tripCount == 0 ? null : onExport,
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share CSV'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color color) {
    final p = ThemePalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: p.textMuted, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
        ],
      ),
    );
  }
}
