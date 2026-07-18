import 'geo_point.dart';

class Trip {
  final int? id;
  final String date;
  final double miles;
  final double tips;
  final String notes;
  final String source;
  final String? createdAt;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final List<GeoPoint> route;

  const Trip({
    this.id,
    required this.date,
    required this.miles,
    this.tips = 0,
    this.notes = '',
    this.source = 'manual',
    this.createdAt,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.route = const [],
  });

  bool get hasMapGeometry =>
      route.length >= 2 ||
      (startLat != null && startLng != null && endLat != null && endLng != null);

  List<GeoPoint> get mapPoints {
    if (route.length >= 2) return route;
    if (startLat != null && startLng != null && endLat != null && endLng != null) {
      return [GeoPoint(startLat!, startLng!), GeoPoint(endLat!, endLng!)];
    }
    return const [];
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    final routeRaw = json['route'];
    List<GeoPoint> route = const [];
    if (routeRaw is List) {
      route = routeRaw.map(GeoPoint.fromJson).toList();
    }

    return Trip(
      id: json['id'] as int?,
      date: json['date'] as String,
      miles: (json['miles'] as num).toDouble(),
      tips: (json['tips'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      createdAt: json['created_at'] as String?,
      startLat: (json['start_lat'] as num?)?.toDouble(),
      startLng: (json['start_lng'] as num?)?.toDouble(),
      endLat: (json['end_lat'] as num?)?.toDouble(),
      endLng: (json['end_lng'] as num?)?.toDouble(),
      route: route,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'date': date,
        'miles': miles,
        'tips': tips,
        'notes': notes,
        'source': source,
      };

  String get sourceLabel => switch (source) {
        'uber' => 'Uber',
        'doordash' => 'DoorDash',
        'lyft' => 'Lyft',
        'instacart' => 'Instacart',
        'gps' => 'GPS',
        'autodetect' => 'Auto',
        _ => 'Manual',
      };

  double get earningsPerMile => miles > 0 ? tips / miles : 0;
}
