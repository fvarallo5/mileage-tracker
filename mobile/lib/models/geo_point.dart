/// Simple lat/lng without map package coupling.
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  List<double> toJson() => [lat, lng];

  factory GeoPoint.fromJson(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      return GeoPoint((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
    }
    if (raw is Map) {
      return GeoPoint(
        (raw['lat'] as num).toDouble(),
        (raw['lng'] as num? ?? raw['lon'] as num).toDouble(),
      );
    }
    throw FormatException('Invalid GeoPoint: $raw');
  }

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// Result of a finished GPS session (miles + path for map / audit).
class TripTrackResult {
  final double miles;
  final List<GeoPoint> route;

  const TripTrackResult({required this.miles, required this.route});

  GeoPoint? get start => route.isEmpty ? null : route.first;
  GeoPoint? get end => route.isEmpty ? null : route.last;

  /// Downsample for storage / map (keeps endpoints + evenly spaced midpoints).
  List<GeoPoint> sparseRoute({int maxPoints = 40}) {
    if (route.length <= maxPoints) return List.unmodifiable(route);
    if (maxPoints < 2) return [route.first, route.last];

    final out = <GeoPoint>[route.first];
    final step = (route.length - 1) / (maxPoints - 1);
    for (var i = 1; i < maxPoints - 1; i++) {
      out.add(route[(i * step).round()]);
    }
    out.add(route.last);
    return out;
  }
}
