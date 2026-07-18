/// IRS standard mileage rates (business) — dollars per mile.
///
/// Source: IRS annual notices. Update when IRS publishes the next year's rate
/// (usually December). Unknown future years use the latest published rate.
class IrsMileageRate {
  IrsMileageRate._();

  /// Business standard mileage rate by calendar year.
  static const Map<int, double> byYear = {
    2020: 0.575,
    2021: 0.56,
    2022: 0.625,
    2023: 0.655,
    2024: 0.67,
    2025: 0.70,
    2026: 0.725, // IRS: 72.5¢/mi for 2026
  };

  static int get currentYear => DateTime.now().year;

  /// Rate for the current calendar year.
  static double get current => rateForYear(currentYear);

  static String get currentLabel =>
      'IRS $currentYear · ${centsLabel(current)}';

  /// Rate in effect for a given calendar year.
  static double rateForYear(int year) {
    if (byYear.containsKey(year)) return byYear[year]!;
    final years = byYear.keys.toList()..sort();
    if (year < years.first) return byYear[years.first]!;
    return byYear[years.last]!;
  }

  /// Rate for a trip date string `YYYY-MM-DD`.
  static double rateForDateString(String date) {
    final year = int.tryParse(date.length >= 4 ? date.substring(0, 4) : '') ??
        currentYear;
    return rateForYear(year);
  }

  static String centsLabel(double rate) {
    final cents = rate * 100;
    if (cents == cents.roundToDouble()) {
      return '${cents.round()}¢/mi';
    }
    return '${cents.toStringAsFixed(1)}¢/mi';
  }

  static bool isKnownYear(int year) => byYear.containsKey(year);
}
