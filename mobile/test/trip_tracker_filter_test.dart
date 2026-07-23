import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mileage_tracker/services/trip_tracker.dart';

Position _pos({
  required double lat,
  required double lng,
  required DateTime time,
  double accuracy = 10,
  double speed = 10,
  bool mocked = false,
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
    isMocked: mocked,
  );
}

void main() {
  test('rejects poor accuracy', () {
    final p = _pos(
      lat: 1,
      lng: 1,
      time: DateTime.now(),
      accuracy: 80,
    );
    expect(TripTracker.isUsableTripFix(p), isFalse);
  });

  test('rejects zero coordinate null island', () {
    final p = _pos(lat: 0, lng: 0, time: DateTime.now());
    expect(TripTracker.isUsableTripFix(p), isFalse);
  });

  test('rejects mock locations', () {
    final p = _pos(lat: 30, lng: -90, time: DateTime.now(), mocked: true);
    expect(TripTracker.isUsableTripFix(p), isFalse);
  });

  test('accepts a good fix', () {
    final p = _pos(lat: 30.1, lng: -90.1, time: DateTime.now());
    expect(TripTracker.isUsableTripFix(p), isTrue);
  });

  test('shouldAcceptSegment rejects teleport speeds', () {
    expect(
      TripTracker.shouldAcceptSegment(
        meters: 500,
        dtMs: 1000,
        distanceFilter: 15,
      ),
      isFalse,
    );
  });

  test('shouldAcceptSegment rejects stationary multipath wander', () {
    expect(
      TripTracker.shouldAcceptSegment(
        meters: 8,
        dtMs: 2000,
        distanceFilter: 15,
        currentSpeedMps: 0.2,
      ),
      isFalse,
    );
  });

  test('shouldAcceptSegment accepts normal driving segment', () {
    expect(
      TripTracker.shouldAcceptSegment(
        meters: 40,
        dtMs: 3000,
        distanceFilter: 15,
        currentSpeedMps: 12,
      ),
      isTrue,
    );
  });
}
