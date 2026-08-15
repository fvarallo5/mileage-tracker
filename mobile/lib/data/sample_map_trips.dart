import '../models/geo_point.dart';
import '../models/trip.dart';

/// Built-in sample GPS routes so the trip map is reviewable without a real drive.
/// Used only when the user has no trips with stored geometry.
class SampleMapTrips {
  SampleMapTrips._();

  /// North Jersey / NYC-metro style segments (lat,lng).
  static List<Trip> asTrips() {
    final t1 = _route(
      date: '2026-08-01',
      miles: 12.4,
      tips: 28.50,
      notes: 'Sample · Airport run',
      source: 'gps',
      points: const [
        GeoPoint(40.6892, -74.1745), // EWR area
        GeoPoint(40.7128, -74.1200),
        GeoPoint(40.7350, -74.0800),
        GeoPoint(40.7484, -74.0500),
        GeoPoint(40.7589, -73.9851), // Midtown
      ],
    );
    final t2 = _route(
      date: '2026-08-02',
      miles: 8.1,
      tips: 19.00,
      notes: 'Sample · Dinner delivery',
      source: 'autodetect',
      points: const [
        GeoPoint(40.7357, -74.1724), // Newark
        GeoPoint(40.7420, -74.1400),
        GeoPoint(40.7505, -74.1000),
        GeoPoint(40.7600, -74.0600),
        GeoPoint(40.7794, -74.0230), // Hoboken / Weehawken
      ],
    );
    final t3 = _route(
      date: '2026-08-03',
      miles: 15.6,
      tips: 34.25,
      notes: 'Sample · Multi-stop',
      source: 'gps',
      points: const [
        GeoPoint(40.7282, -74.0776),
        GeoPoint(40.7000, -74.0500),
        GeoPoint(40.6782, -74.0440), // Bayonne direction
        GeoPoint(40.6500, -74.0200),
        GeoPoint(40.6413, -74.0781), // Staten Island approach
        GeoPoint(40.6500, -74.1200),
        GeoPoint(40.6892, -74.1745),
      ],
    );
    return [t1, t2, t3];
  }

  static Trip _route({
    required String date,
    required double miles,
    required double tips,
    required String notes,
    required String source,
    required List<GeoPoint> points,
  }) {
    return Trip(
      date: date,
      miles: miles,
      tips: tips,
      notes: notes,
      source: source,
      isBusiness: true,
      startLat: points.first.lat,
      startLng: points.first.lng,
      endLat: points.last.lat,
      endLng: points.last.lng,
      route: points,
    );
  }
}
