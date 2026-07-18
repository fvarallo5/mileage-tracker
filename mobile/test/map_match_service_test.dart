import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_tracker/models/geo_point.dart';
import 'package:mileage_tracker/services/map_match_service.dart';

void main() {
  group('GeoPoint.sparsify', () {
    test('keeps short paths intact', () {
      final pts = [const GeoPoint(1, 2), const GeoPoint(3, 4)];
      expect(GeoPoint.sparsify(pts), pts);
    });

    test('keeps endpoints when downsampling', () {
      final pts = [
        for (var i = 0; i < 100; i++) GeoPoint(i.toDouble(), i.toDouble()),
      ];
      final sparse = GeoPoint.sparsify(pts, maxPoints: 10);
      expect(sparse.length, 10);
      expect(sparse.first.lat, 0);
      expect(sparse.last.lat, 99);
    });
  });

  group('parseOsrmMatch', () {
    test('sums matching distances and reads geojson', () {
      final body = {
        'code': 'Ok',
        'matchings': [
          {
            'confidence': 0.9,
            'distance': 1609.344, // 1 mile
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [-73.9857, 40.7484],
                [-73.9800, 40.7500],
              ],
            },
          },
        ],
      };

      final parsed = MapMatchService.parseOsrmMatch(body);
      expect(parsed, isNotNull);
      expect(parsed!.miles, closeTo(1.0, 0.001));
      expect(parsed.confidence, closeTo(0.9, 0.001));
      expect(parsed.route.length, 2);
      expect(parsed.route.first.lat, closeTo(40.7484, 0.0001));
      expect(parsed.route.first.lng, closeTo(-73.9857, 0.0001));
    });

    test('returns null when code is not Ok', () {
      expect(
        MapMatchService.parseOsrmMatch({'code': 'NoMatch', 'matchings': []}),
        isNull,
      );
    });

    test('returns null when distance is zero', () {
      expect(
        MapMatchService.parseOsrmMatch({
          'code': 'Ok',
          'matchings': [
            {'confidence': 1.0, 'distance': 0, 'geometry': {}},
          ],
        }),
        isNull,
      );
    });
  });

  group('acceptMatch', () {
    final gpsRoute = [
      const GeoPoint(40.0, -73.0),
      const GeoPoint(40.01, -73.01),
    ];
    final matchedRoute = [
      const GeoPoint(40.0, -73.0),
      const GeoPoint(40.005, -73.005),
      const GeoPoint(40.01, -73.01),
    ];

    test('accepts high-confidence nearby match', () {
      final r = MapMatchService.acceptMatch(
        matchedMiles: 5.1,
        matchedRoute: matchedRoute,
        confidence: 0.85,
        gpsMiles: 5.0,
        gpsRoute: gpsRoute,
      );
      expect(r.matched, isTrue);
      expect(r.miles, closeTo(5.1, 0.001));
      expect(r.route.length, greaterThanOrEqualTo(2));
    });

    test('rejects low confidence', () {
      final r = MapMatchService.acceptMatch(
        matchedMiles: 5.0,
        matchedRoute: matchedRoute,
        confidence: 0.1,
        gpsMiles: 5.0,
        gpsRoute: gpsRoute,
      );
      expect(r.matched, isFalse);
      expect(r.miles, 5.0);
      expect(r.reason, 'low_confidence');
    });

    test('rejects wild ratio vs GPS', () {
      final r = MapMatchService.acceptMatch(
        matchedMiles: 20.0,
        matchedRoute: matchedRoute,
        confidence: 0.9,
        gpsMiles: 5.0,
        gpsRoute: gpsRoute,
      );
      expect(r.matched, isFalse);
      expect(r.miles, 5.0);
      expect(r.reason, 'ratio');
    });
  });
}
