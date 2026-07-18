import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trip.dart';
import 'irs_mileage_rate.dart';

/// Builds TurboTax / Schedule C friendly CSV packages from trip logs.
class TaxExportService {
  static final _currency = NumberFormat('0.00');

  /// Export a tax package for [year] (detailed log + Schedule C summary).
  static Future<void> shareTaxPackage({
    required List<Trip> trips,
    required int year,
  }) async {
    final yearTrips = trips
        .where((t) => t.isBusiness && t.date.startsWith('$year'))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final logPath = '${dir.path}/TrekTrack_MileageLog_$year.csv';
    final summaryPath = '${dir.path}/TrekTrack_ScheduleC_$year.csv';

    await File(logPath).writeAsString(_mileageLogCsv(yearTrips, year));
    await File(summaryPath).writeAsString(_scheduleCCsv(yearTrips, year));

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(logPath, mimeType: 'text/csv', name: 'TrekTrack_MileageLog_$year.csv'),
          XFile(summaryPath, mimeType: 'text/csv', name: 'TrekTrack_ScheduleC_$year.csv'),
        ],
        subject: 'TrekTrack tax package $year',
        text:
            'TrekTrack mileage package for tax year $year.\n'
            '• MileageLog — business miles only (personal trips excluded)\n'
            '• ScheduleC — standard mileage deduction summary for Schedule C\n'
            'Generated $stamp. Confirm rates with your tax pro.',
      ),
    );
  }

  /// Share a single period summary + trip detail for the selected report range.
  static Future<void> sharePeriodExport({
    required List<Trip> trips,
    required String startDate,
    required String endDate,
    required String label,
  }) async {
    final inRange = trips
        .where((t) =>
            t.isBusiness &&
            t.date.compareTo(startDate) >= 0 &&
            t.date.compareTo(endDate) <= 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final dir = await getTemporaryDirectory();
    final safe = label.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final path = '${dir.path}/TrekTrack_Report_$safe.csv';
    await File(path).writeAsString(_periodCsv(inRange, startDate, endDate, label));

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(path, mimeType: 'text/csv', name: 'TrekTrack_Report_$safe.csv'),
        ],
        subject: 'TrekTrack report — $label',
        text: 'Mileage report $startDate to $endDate from TrekTrack.',
      ),
    );
  }

  static String _mileageLogCsv(List<Trip> trips, int year) {
    final buf = StringBuffer();
    buf.writeln(
      'Date,Business Miles,Purpose,Source,Tips/Earnings (USD),'
      'IRS Rate (\$/mi),Mileage Deduction (USD)',
    );
    for (final t in trips) {
      final rate = IrsMileageRate.rateForDateString(t.date);
      final deduction = t.miles * rate;
      buf.writeln(
        [
          t.date,
          t.miles.toStringAsFixed(2),
          _csv(t.notes.isEmpty ? 'Business travel' : t.notes),
          t.sourceLabel,
          _currency.format(t.tips),
          rate.toStringAsFixed(3),
          _currency.format(deduction),
        ].join(','),
      );
    }
    if (trips.isEmpty) {
      buf.writeln('$year-01-01,0.00,No trips logged,,,${IrsMileageRate.rateForYear(year).toStringAsFixed(3)},0.00');
    }
    return buf.toString();
  }

  static String _scheduleCCsv(List<Trip> trips, int year) {
    final rate = IrsMileageRate.rateForYear(year);
    final miles = trips.fold<double>(0, (s, t) => s + t.miles);
    final tips = trips.fold<double>(0, (s, t) => s + t.tips);
    // Per-trip rates in case IRS mid-year changes are ever modeled.
    final deduction = trips.fold<double>(
      0,
      (s, t) => s + t.miles * IrsMileageRate.rateForDateString(t.date),
    );

    final buf = StringBuffer();
    buf.writeln('Field,Value,Notes');
    buf.writeln('Tax Year,$year,Calendar year for Schedule C');
    buf.writeln(
      'Vehicle Expense Method,Standard Mileage,'
      'Do not also deduct actual vehicle costs for the same miles',
    );
    buf.writeln(
      'Business Miles,${miles.toStringAsFixed(2)},'
      'Enter on Schedule C vehicle / car and truck expenses (standard mileage)',
    );
    buf.writeln(
      'IRS Standard Mileage Rate (\$_per_mi),${rate.toStringAsFixed(3)},'
      '${IrsMileageRate.centsLabel(rate)} IRS business rate for $year',
    );
    buf.writeln(
      'Standard Mileage Deduction (USD),${_currency.format(deduction)},'
      'Business miles × IRS rate — Schedule C deduction amount',
    );
    buf.writeln('Trip Count,${trips.length},Audit-ready trip log attached');
    buf.writeln(
      'Gross Tips/Earnings (USD),${_currency.format(tips)},'
      'From gig apps if logged — report income separately as required',
    );
    buf.writeln(
      'Prepared By,TrekTrack,'
      'For records / TurboTax upload. Verify with a tax professional.',
    );
    return buf.toString();
  }

  static String _periodCsv(
    List<Trip> trips,
    String start,
    String end,
    String label,
  ) {
    final miles = trips.fold<double>(0, (s, t) => s + t.miles);
    final tips = trips.fold<double>(0, (s, t) => s + t.tips);
    final deduction = trips.fold<double>(
      0,
      (s, t) => s + t.miles * IrsMileageRate.rateForDateString(t.date),
    );

    final buf = StringBuffer();
    buf.writeln('Report,$label');
    buf.writeln('Period,$start to $end');
    buf.writeln('Business Miles,${miles.toStringAsFixed(2)}');
    buf.writeln('Mileage Deduction (USD),${_currency.format(deduction)}');
    buf.writeln('Tips/Earnings (USD),${_currency.format(tips)}');
    buf.writeln('Trips,${trips.length}');
    buf.writeln('');
    buf.writeln('Date,Business Miles,Purpose,Source,Tips,Deduction');
    for (final t in trips) {
      final rate = IrsMileageRate.rateForDateString(t.date);
      buf.writeln(
        [
          t.date,
          t.miles.toStringAsFixed(2),
          _csv(t.notes.isEmpty ? 'Business travel' : t.notes),
          t.sourceLabel,
          _currency.format(t.tips),
          _currency.format(t.miles * rate),
        ].join(','),
      );
    }
    return buf.toString();
  }

  static String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }
}
