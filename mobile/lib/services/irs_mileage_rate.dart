/// IRS standard mileage rates (business) — dollars per mile.
///
/// Source: IRS annual notices (and mid-year revisions when published).
/// Update when the IRS announces a new rate. Unknown future dates use the
/// latest published period rate.
class IrsMileageRate {
  IrsMileageRate._();

  /// Inclusive date ranges with the business rate in effect.
  /// Later entries win if ranges ever overlap (they should not).
  static const List<({String start, String end, double rate})> periods = [
    (start: '2020-01-01', end: '2020-12-31', rate: 0.575),
    (start: '2021-01-01', end: '2021-12-31', rate: 0.56),
    (start: '2022-01-01', end: '2022-12-31', rate: 0.625),
    (start: '2023-01-01', end: '2023-12-31', rate: 0.655),
    (start: '2024-01-01', end: '2024-12-31', rate: 0.67),
    (start: '2025-01-01', end: '2025-12-31', rate: 0.70),
    // 2026: mid-year revision (72.5¢ H1 → 76¢ H2).
    (start: '2026-01-01', end: '2026-06-30', rate: 0.725),
    (start: '2026-07-01', end: '2026-12-31', rate: 0.76),
  ];

  /// Convenience map: one rate per calendar year.
  /// Years with mid-year changes use the year-end (latest) rate.
  static Map<int, double> get byYear {
    final map = <int, double>{};
    for (final p in periods) {
      final year = int.parse(p.start.substring(0, 4));
      map[year] = p.rate; // last period in year overwrites → year-end rate
    }
    return map;
  }

  static int get currentYear => DateTime.now().year;

  /// Rate in effect today.
  static double get current => rateForDate(DateTime.now());

  static String get currentLabel {
    final y = currentYear;
    final yearPeriods = periodsForYear(y);
    if (yearPeriods.length > 1) {
      return 'IRS $y · ${centsLabel(current)} (in effect now)';
    }
    return 'IRS $y · ${centsLabel(current)}';
  }

  /// Human-readable breakdown for a tax year (e.g. settings / exports).
  static String yearRatesLabel(int year) {
    final ps = periodsForYear(year);
    if (ps.isEmpty) {
      return '${centsLabel(rateForYear(year))} for $year';
    }
    if (ps.length == 1) {
      return '${centsLabel(ps.first.rate)} for $year';
    }
    return ps
        .map((p) =>
            '${centsLabel(p.rate)} (${_shortUs(p.start)}–${_shortUs(p.end)})')
        .join('; ');
  }

  static List<({String start, String end, double rate})> periodsForYear(
    int year,
  ) {
    final prefix = '$year';
    return periods.where((p) => p.start.startsWith(prefix)).toList();
  }

  /// Rate for a given calendar year (year-end rate if mid-year change).
  static double rateForYear(int year) {
    final ps = periodsForYear(year);
    if (ps.isNotEmpty) return ps.last.rate;

    final years = periods.map((p) => int.parse(p.start.substring(0, 4))).toSet().toList()
      ..sort();
    if (year < years.first) return periods.first.rate;
    return periods.last.rate;
  }

  /// Rate in effect on a calendar date.
  static double rateForDate(DateTime date) {
    final key = _formatDate(date);
    return rateForDateString(key);
  }

  /// Rate for a trip date string `YYYY-MM-DD`.
  static double rateForDateString(String date) {
    final d = date.length >= 10 ? date.substring(0, 10) : date;
    for (final p in periods) {
      if (d.compareTo(p.start) >= 0 && d.compareTo(p.end) <= 0) {
        return p.rate;
      }
    }
    // Before first published period or after last → clamp.
    if (d.compareTo(periods.first.start) < 0) return periods.first.rate;
    return periods.last.rate;
  }

  static String centsLabel(double rate) {
    final cents = rate * 100;
    if (cents == cents.roundToDouble()) {
      return '${cents.round()}¢/mi';
    }
    return '${cents.toStringAsFixed(1)}¢/mi';
  }

  static bool isKnownYear(int year) => periodsForYear(year).isNotEmpty;

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// `YYYY-MM-DD` → `M/D/YYYY` short form for labels.
  static String _shortUs(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final y = parts[0];
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return '$m/$d/$y';
  }
}
