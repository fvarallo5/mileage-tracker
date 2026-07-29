import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trip.dart';
import 'irs_mileage_rate.dart';

/// Full personal-data export (portability), separate from tax packages.
class DataExportService {
  static final _currency = NumberFormat('0.00');
  static const _bom = '\uFEFF';

  /// Share a complete trip log CSV for the signed-in user.
  static Future<void> shareAllTrips(List<Trip> trips) async {
    final sorted = List<Trip>.from(trips)
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        if (d != 0) return d;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final name = 'TrekTrack_AllTrips_$stamp.csv';
    final path = '${dir.path}/$name';

    await File(path).writeAsString(_bom + _csv(sorted));

    final businessMi = sorted
        .where((t) => t.isBusiness)
        .fold<double>(0, (s, t) => s + t.miles);
    final personalMi = sorted
        .where((t) => !t.isBusiness)
        .fold<double>(0, (s, t) => s + t.miles);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'text/csv', name: name)],
        subject: 'TrekTrack data export',
        text:
            'Your TrekTrack trip export ($stamp).\n'
            '${sorted.length} trips · '
            'Business ${businessMi.toStringAsFixed(1)} mi · '
            'Personal ${personalMi.toStringAsFixed(1)} mi.\n'
            'This is a full data download, not a tax package.',
      ),
    );
  }

  static String _csv(List<Trip> trips) {
    final buf = StringBuffer();
    buf.writeln(
      'Date,'
      'Classification,'
      'Miles,'
      'Purpose,'
      'Source,'
      'Tips/Earnings (USD),'
      'IRS Rate (USD per mi),'
      'Mileage Deduction (USD),'
      'Start Latitude,'
      'Start Longitude,'
      'End Latitude,'
      'End Longitude,'
      'Recorded At,'
      'Trip ID',
    );
    for (final t in trips) {
      final rate = IrsMileageRate.rateForDateString(t.date);
      final deduction = t.isBusiness ? t.miles * rate : 0.0;
      buf.writeln(
        [
          t.date,
          t.isBusiness ? 'Business' : 'Personal',
          t.miles.toStringAsFixed(2),
          _esc(t.notes.trim().isEmpty
              ? (t.isBusiness ? 'Business travel' : 'Personal')
              : t.notes.trim()),
          _esc(t.sourceLabel),
          _currency.format(t.tips),
          rate.toStringAsFixed(3),
          _currency.format(deduction),
          t.startLat?.toStringAsFixed(6) ?? '',
          t.startLng?.toStringAsFixed(6) ?? '',
          t.endLat?.toStringAsFixed(6) ?? '',
          t.endLng?.toStringAsFixed(6) ?? '',
          _esc(t.createdAt ?? ''),
          t.id?.toString() ?? '',
        ].join(','),
      );
    }
    if (trips.isEmpty) {
      buf.writeln(
        ',,,,No trips exported,,,,,,,,',
      );
    }
    return buf.toString();
  }

  static String _esc(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }
}
