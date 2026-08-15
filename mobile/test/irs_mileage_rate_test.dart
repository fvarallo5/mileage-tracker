import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_tracker/services/irs_mileage_rate.dart';

void main() {
  group('IrsMileageRate 2026 mid-year', () {
    test('H1 2026 is 72.5¢', () {
      expect(IrsMileageRate.rateForDateString('2026-01-01'), 0.725);
      expect(IrsMileageRate.rateForDateString('2026-06-30'), 0.725);
      expect(IrsMileageRate.rateForDate(DateTime(2026, 3, 15)), 0.725);
    });

    test('H2 2026 is 76¢', () {
      expect(IrsMileageRate.rateForDateString('2026-07-01'), 0.76);
      expect(IrsMileageRate.rateForDateString('2026-08-04'), 0.76);
      expect(IrsMileageRate.rateForDateString('2026-12-31'), 0.76);
    });

    test('rateForYear uses year-end rate when mid-year change', () {
      expect(IrsMileageRate.rateForYear(2026), 0.76);
      expect(IrsMileageRate.rateForYear(2025), 0.70);
    });

    test('periodsForYear lists both 2026 windows', () {
      final ps = IrsMileageRate.periodsForYear(2026);
      expect(ps.length, 2);
      expect(ps.first.rate, 0.725);
      expect(ps.last.rate, 0.76);
    });

    test('prior years unchanged', () {
      expect(IrsMileageRate.rateForDateString('2025-12-31'), 0.70);
      expect(IrsMileageRate.rateForDateString('2024-06-01'), 0.67);
    });

    test('centsLabel formats half-cents', () {
      expect(IrsMileageRate.centsLabel(0.725), '72.5¢/mi');
      expect(IrsMileageRate.centsLabel(0.76), '76¢/mi');
    });
  });
}
