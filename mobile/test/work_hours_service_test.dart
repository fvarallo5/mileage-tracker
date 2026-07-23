import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_tracker/services/work_hours_service.dart';

void main() {
  test('disabled schedule always allows watch', () {
    final wh = WorkHoursService()..enabled = false;
    expect(wh.isWithinSchedule(DateTime(2026, 7, 20, 3, 0)), isTrue);
  });

  test('weekday window includes middle of day', () {
    final wh = WorkHoursService()
      ..enabled = true
      ..startMinutes = 8 * 60
      ..endMinutes = 18 * 60
      ..daysActive = [true, true, true, true, true, false, false];
    // Monday Jul 20 2026
    expect(wh.isWithinSchedule(DateTime(2026, 7, 20, 12, 0)), isTrue);
    expect(wh.isWithinSchedule(DateTime(2026, 7, 20, 7, 59)), isFalse);
    expect(wh.isWithinSchedule(DateTime(2026, 7, 20, 18, 0)), isFalse);
  });

  test('weekend excluded when only weekdays active', () {
    final wh = WorkHoursService()
      ..enabled = true
      ..startMinutes = 8 * 60
      ..endMinutes = 18 * 60
      ..daysActive = [true, true, true, true, true, false, false];
    // Saturday Jul 25 2026
    expect(wh.isWithinSchedule(DateTime(2026, 7, 25, 12, 0)), isFalse);
  });

  test('overnight window', () {
    final wh = WorkHoursService()
      ..enabled = true
      ..startMinutes = 22 * 60
      ..endMinutes = 6 * 60
      ..daysActive = List.filled(7, true);
    expect(wh.isWithinSchedule(DateTime(2026, 7, 20, 23, 0)), isTrue);
    expect(wh.isWithinSchedule(DateTime(2026, 7, 20, 3, 0)), isTrue);
    expect(wh.isWithinSchedule(DateTime(2026, 7, 20, 12, 0)), isFalse);
  });

  test('formatMinutes', () {
    expect(WorkHoursService.formatMinutes(0), '12:00 AM');
    expect(WorkHoursService.formatMinutes(8 * 60 + 30), '8:30 AM');
    expect(WorkHoursService.formatMinutes(18 * 60), '6:00 PM');
  });
}
