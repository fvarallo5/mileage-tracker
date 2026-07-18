import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mileage_tracker/services/autodetect_service.dart';

Position _pos({
  required double lat,
  required double lng,
  required DateTime time,
  double speed = -1,
  double accuracy = 10,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: time,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 1,
  );
}

void main() {
  test('estimateSpeedMps uses reported speed when valid', () {
    final now = DateTime.now();
    final p = _pos(lat: 0, lng: 0, time: now, speed: 10);
    expect(AutoDetectService.estimateSpeedMps(p, null), 10);
  });

  test('estimateSpeedMps derives speed when device reports 0 but position moved', () {
    final t0 = DateTime.utc(2026, 7, 1, 12, 0, 0);
    final t1 = t0.add(const Duration(seconds: 10));
    // ~111 m north in 10s ≈ 11 m/s
    final prev = _pos(lat: 0, lng: 0, time: t0, speed: 0);
    final curr = _pos(lat: 0.001, lng: 0, time: t1, speed: 0);
    final speed = AutoDetectService.estimateSpeedMps(curr, prev);
    expect(speed, greaterThan(8));
    expect(speed, lessThan(15));
  });

  test('mpsToMph converts correctly', () {
    expect(AutoDetectService.mpsToMph(4.0), closeTo(8.95, 0.1));
  });
}
