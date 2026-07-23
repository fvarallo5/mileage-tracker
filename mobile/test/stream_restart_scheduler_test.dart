import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_tracker/utils/stream_restart_scheduler.dart';

void main() {
  test('schedules until maxAttempts then exhausts', () {
    final s = StreamRestartScheduler(maxAttempts: 2);
    var runs = 0;
    s.schedule(() => runs++);
    expect(s.attempts, 1);
    expect(s.exhausted, isFalse);
    s.schedule(() => runs++);
    expect(s.attempts, 2);
    expect(s.exhausted, isTrue);
    s.schedule(() => runs++);
    expect(s.attempts, 2);
    s.dispose();
  });

  test('reset clears attempts', () {
    final s = StreamRestartScheduler(maxAttempts: 1);
    s.schedule(() {});
    expect(s.exhausted, isTrue);
    s.reset();
    expect(s.exhausted, isFalse);
    expect(s.attempts, 0);
    s.dispose();
  });
}
