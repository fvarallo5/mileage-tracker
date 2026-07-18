import '../models/period_report.dart';
import '../models/trip.dart';
import 'irs_mileage_rate.dart';

class ReportService {
  static ReportSummary buildSummary(List<Trip> trips, {String? referenceDate}) {
    final ref = referenceDate ?? _formatDate(DateTime.now());
    final displayRate = IrsMileageRate.rateForDateString(ref);
    return ReportSummary(
      referenceDate: ref,
      weekly: _buildPeriodReport(
        trips,
        'weekly',
        _weekLabel(_isoWeekStart(ref), _isoWeekEnd(ref)),
        _isoWeekStart(ref),
        _isoWeekEnd(ref),
        displayRate,
      ),
      monthly: _buildPeriodReport(
        trips,
        'monthly',
        _monthLabel(ref),
        _monthStart(ref),
        _monthEnd(ref),
        displayRate,
      ),
      annual: _buildPeriodReport(
        trips,
        'annual',
        _ytdLabel(ref),
        _yearStart(ref),
        ref,
        displayRate,
      ),
    );
  }

  static List<PeriodReport> buildHistory(
    List<Trip> trips,
    String period, {
    int count = 8,
    String? referenceDate,
  }) {
    final ref = referenceDate ?? _formatDate(DateTime.now());
    final reports = <PeriodReport>[];

    for (var i = 0; i < count; i++) {
      late String start;
      late String end;
      late String label;
      late String key;

      if (period == 'weekly') {
        final d = DateTime.parse('${ref}T12:00:00').subtract(Duration(days: i * 7));
        final dateStr = _formatDate(d);
        start = _isoWeekStart(dateStr);
        end = _isoWeekEnd(dateStr);
        label = _weekLabel(start, end);
        key = 'week-$start';
      } else if (period == 'monthly') {
        final d = DateTime.parse('${ref}T12:00:00');
        final shifted = DateTime(d.year, d.month - i, d.day);
        final dateStr = _formatDate(shifted);
        start = _monthStart(dateStr);
        end = _monthEnd(dateStr);
        label = _monthLabel(dateStr);
        key = 'month-${start.substring(0, 7)}';
      } else if (period == 'annual') {
        final refYear = DateTime.parse('${ref}T12:00:00').year;
        if (i == 0) {
          start = _yearStart(ref);
          end = ref;
          label = _ytdLabel(ref);
          key = 'ytd-$refYear';
        } else {
          final year = refYear - i;
          start = '$year-01-01';
          end = '$year-12-31';
          label = '$year';
          key = 'year-$year';
        }
      } else {
        throw ArgumentError('period must be weekly, monthly, or annual');
      }

      final displayRate = IrsMileageRate.rateForDateString(end);
      reports.add(_buildPeriodReport(trips, key, label, start, end, displayRate));
    }

    return reports;
  }

  static PeriodReport _buildPeriodReport(
    List<Trip> trips,
    String periodKey,
    String label,
    String startDate,
    String endDate,
    double displayRate,
  ) {
    final inRange =
        trips.where((t) => t.date.compareTo(startDate) >= 0 && t.date.compareTo(endDate) <= 0);
    final totalMiles = inRange.fold<double>(0, (sum, t) => sum + t.miles);
    final totalTips = inRange.fold<double>(0, (sum, t) => sum + t.tips);
    // Per-trip IRS rate (correct across year boundaries).
    final mileageExpense = inRange.fold<double>(
      0,
      (sum, t) => sum + t.miles * IrsMileageRate.rateForDateString(t.date),
    );
    final earningsPerMile = totalMiles > 0 ? totalTips / totalMiles : 0.0;

    return PeriodReport(
      period: periodKey,
      label: label,
      startDate: startDate,
      endDate: endDate,
      tripCount: inRange.length,
      totalMiles: _round2(totalMiles),
      totalTips: _round2(totalTips),
      mileageRate: displayRate,
      mileageExpense: _round2(mileageExpense),
      earningsPerMile: _round2(earningsPerMile),
      netEarnings: _round2(totalTips - mileageExpense),
    );
  }

  static double _round2(double n) => (n * 100).roundToDouble() / 100;

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _isoWeekStart(String date) {
    final d = DateTime.parse('${date}T12:00:00');
    final day = d.weekday;
    final diff = day == 7 ? -6 : 1 - day;
    return _formatDate(d.add(Duration(days: diff)));
  }

  static String _isoWeekEnd(String date) {
    final start = DateTime.parse('${_isoWeekStart(date)}T12:00:00');
    return _formatDate(start.add(const Duration(days: 6)));
  }

  static String _monthStart(String date) {
    final d = DateTime.parse('${date}T12:00:00');
    return _formatDate(DateTime(d.year, d.month, 1));
  }

  static String _monthEnd(String date) {
    final d = DateTime.parse('${date}T12:00:00');
    return _formatDate(DateTime(d.year, d.month + 1, 0));
  }

  static String _yearStart(String date) {
    final d = DateTime.parse('${date}T12:00:00');
    return _formatDate(DateTime(d.year, 1, 1));
  }

  static String _ytdLabel(String date) {
    final year = DateTime.parse('${date}T12:00:00').year;
    return 'YTD $year';
  }

  static String _weekLabel(String start, String end) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final s = DateTime.parse('${start}T12:00:00');
    final e = DateTime.parse('${end}T12:00:00');
    return 'Week of ${months[s.month - 1]} ${s.day} – ${months[e.month - 1]} ${e.day}';
  }

  static String _monthLabel(String date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final d = DateTime.parse('${date}T12:00:00');
    return '${months[d.month - 1]} ${d.year}';
  }
}
