class Trip {
  final int? id;
  final String date;
  final double miles;
  final double tips;
  final String notes;
  final String source;
  final String? createdAt;

  const Trip({
    this.id,
    required this.date,
    required this.miles,
    this.tips = 0,
    this.notes = '',
    this.source = 'manual',
    this.createdAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as int?,
      date: json['date'] as String,
      miles: (json['miles'] as num).toDouble(),
      tips: (json['tips'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      createdAt: json['created_at'] as String?,
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