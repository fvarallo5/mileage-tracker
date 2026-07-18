import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_tracker/models/trip.dart';
import 'package:mileage_tracker/services/report_service.dart';

void main() {
  test('reports exclude personal miles from totals', () {
    final trips = [
      const Trip(date: '2026-07-01', miles: 10, tips: 20, isBusiness: true),
      const Trip(date: '2026-07-01', miles: 50, tips: 0, isBusiness: false),
      const Trip(date: '2026-07-02', miles: 5, tips: 10, isBusiness: true),
    ];

    final summary = ReportService.buildSummary(
      trips,
      referenceDate: '2026-07-15',
    );

    expect(summary.monthly.totalMiles, 15);
    expect(summary.monthly.tripCount, 2);
    expect(summary.monthly.totalTips, 30);
  });
}
