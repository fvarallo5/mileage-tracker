import 'dart:math' as math;

/// How a saved place affects auto-detect / trip purpose.
enum PlaceMode {
  /// Don't auto-start a trip while near this place (e.g. home).
  exclude,

  /// Trips that end here are marked personal.
  personal,

  /// Trips that end here are marked business.
  business,
}

/// A user-defined location used to gate auto-detect or classify trips.
class SavedPlace {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
  final PlaceMode mode;

  const SavedPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radiusMeters = 120,
    this.mode = PlaceMode.exclude,
  });

  String get modeLabel => switch (mode) {
        PlaceMode.exclude => 'Skip auto-start nearby',
        PlaceMode.personal => 'End nearby → personal',
        PlaceMode.business => 'End nearby → business',
      };

  bool contains(double latitude, double longitude) {
    return distanceMeters(latitude, longitude) <= radiusMeters;
  }

  double distanceMeters(double latitude, double longitude) {
    return haversineMeters(lat, lng, latitude, longitude);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius_m': radiusMeters,
        'mode': mode.name,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Place',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusMeters: (json['radius_m'] as num?)?.toDouble() ?? 120,
      mode: PlaceMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => PlaceMode.exclude,
      ),
    );
  }

  SavedPlace copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    double? radiusMeters,
    PlaceMode? mode,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      mode: mode ?? this.mode,
    );
  }

  /// Great-circle distance in meters.
  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }
}
