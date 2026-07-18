import 'geo_point.dart';

class Trip {
  final int? id;
  final String date;
  final double miles;
  final double tips;
  final String notes;
  final String source;
  final bool isBusiness;
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
    this.isBusiness = true,
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

  String get purposeLabel => isBusiness ? 'Business' : 'Personal';

  Trip copyWith({
    int? id,
    String? date,
    double? miles,
    double? tips,
    String? notes,
    String? source,
    bool? isBusiness,
    String? createdAt,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    List<GeoPoint>? route,
  }) {
    return Trip(
      id: id ?? this.id,
      date: date ?? this.date,
      miles: miles ?? this.miles,
      tips: tips ?? this.tips,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      isBusiness: isBusiness ?? this.isBusiness,
      createdAt: createdAt ?? this.createdAt,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      route: route ?? this.route,
    );
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
      isBusiness: json['is_business'] as bool? ?? true,
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
        'is_business': isBusiness,
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
