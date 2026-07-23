import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_tracker/models/saved_place.dart';
import 'package:mileage_tracker/services/places_service.dart';

void main() {
  test('haversine near zero for same point', () {
    expect(SavedPlace.haversineMeters(30, -90, 30, -90), closeTo(0, 0.01));
  });

  test('contains uses radius', () {
    const home = SavedPlace(
      id: '1',
      name: 'Home',
      lat: 30.0,
      lng: -90.0,
      radiusMeters: 100,
      mode: PlaceMode.exclude,
    );
    expect(home.contains(30.0, -90.0), isTrue);
    // ~1 km north
    expect(home.contains(30.009, -90.0), isFalse);
  });

  test('classify prefers personal over business when both match', () {
    final svc = PlacesService();
    svc.places = [
      const SavedPlace(
        id: 'p',
        name: 'Home',
        lat: 30,
        lng: -90,
        radiusMeters: 200,
        mode: PlaceMode.personal,
      ),
      const SavedPlace(
        id: 'b',
        name: 'Warehouse',
        lat: 30,
        lng: -90,
        radiusMeters: 200,
        mode: PlaceMode.business,
      ),
    ];
    expect(svc.classifyIsBusiness(30, -90), isFalse);
  });

  test('blocksAutoStart only for exclude mode', () {
    final svc = PlacesService();
    svc.places = [
      const SavedPlace(
        id: 'h',
        name: 'Home',
        lat: 30,
        lng: -90,
        mode: PlaceMode.exclude,
      ),
    ];
    expect(svc.blocksAutoStart(30, -90)?.name, 'Home');
    expect(svc.blocksAutoStart(40, -100), isNull);
  });
}
