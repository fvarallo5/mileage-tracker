import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/geo_point.dart';

/// Result of attempting to snap a GPS trace to the road network.
class MapMatchResult {
  final double miles;
  final List<GeoPoint> route;
  final bool matched;
  final String reason;
  final double? confidence;

  const MapMatchResult({
    required this.miles,
    required this.route,
    required this.matched,
    this.reason = '',
    this.confidence,
  });

  /// Keep GPS miles + a storage-sized route.
  factory MapMatchResult.gps(
    double miles,
    List<GeoPoint> route, {
    String reason = 'fallback',
    double? confidence,
  }) {
    return MapMatchResult(
      miles: miles,
      route: route,
      matched: false,
      reason: reason,
      confidence: confidence,
    );
  }
}

/// End-of-trip road snap via OSRM Match API.
///
/// Improves reported miles when GPS wanders. Falls back to raw GPS miles
/// when offline, disabled, or the match looks untrustworthy.
class MapMatchService extends ChangeNotifier {
  static const _enabledKey = 'map_match_enabled';
  static const _metersPerMile = 1609.344;
  static const _storageMaxPoints = 40;
  static const _gpsRadiusM = 40;
  static const _minConfidence = 0.25;
  static const _minGpsMilesForRatio = 0.3;
  static const _minMatchRatio = 0.5;
  static const _maxMatchRatio = 2.0;

  bool enabled = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    notifyListeners();
  }

  /// Snap [points] to roads. Always returns a storage-sized route (~40 pts).
  Future<MapMatchResult> refine({
    required List<GeoPoint> points,
    required double gpsMiles,
    http.Client? client,
  }) async {
    final stored = GeoPoint.sparsify(points, maxPoints: _storageMaxPoints);
    MapMatchResult gps(String reason, {double? confidence}) =>
        MapMatchResult.gps(gpsMiles, stored, reason: reason, confidence: confidence);

    if (!enabled) return gps('disabled');
    if (points.length < 2 || gpsMiles < 0.05) return gps('too_short');

    final sample =
        GeoPoint.sparsify(points, maxPoints: AppConfig.mapMatchMaxPoints);
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;

    try {
      final body = await _fetchMatch(sample, httpClient);
      if (body == null) return gps('http');

      final parsed = parseOsrmMatch(body);
      if (parsed == null) return gps('parse');

      return acceptMatch(
        matchedMiles: parsed.miles,
        matchedRoute: parsed.route,
        confidence: parsed.confidence ?? 0,
        gpsMiles: gpsMiles,
        gpsRoute: stored,
      );
    } catch (e, st) {
      debugPrint('MapMatchService.refine: $e\n$st');
      return gps('error');
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  Future<Map<String, dynamic>?> _fetchMatch(
    List<GeoPoint> points,
    http.Client client,
  ) async {
    final coords = points.map((p) => '${p.lng},${p.lat}').join(';');
    final radiuses =
        List.filled(points.length, '$_gpsRadiusM').join(';');
    final base = AppConfig.osrmBaseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/match/v1/driving/$coords').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'gaps': 'ignore',
        'tidy': 'false',
        'radiuses': radiuses,
      },
    );

    final response = await client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(AppConfig.mapMatchTimeout);

    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  /// Parse OSRM Match JSON into miles + geometry. Exposed for unit tests.
  static ({double miles, List<GeoPoint> route, double? confidence})?
      parseOsrmMatch(Map<String, dynamic> body) {
    if (body['code']?.toString() case final code? when code != 'Ok') {
      return null;
    }

    final matchings = body['matchings'];
    if (matchings is! List || matchings.isEmpty) return null;

    var totalMeters = 0.0;
    var confSum = 0.0;
    var confCount = 0;
    final coords = <GeoPoint>[];

    for (final raw in matchings) {
      if (raw is! Map) continue;
      totalMeters += (raw['distance'] as num?)?.toDouble() ?? 0;

      final conf = (raw['confidence'] as num?)?.toDouble();
      if (conf != null) {
        confSum += conf;
        confCount++;
      }

      final list = raw['geometry'] is Map
          ? (raw['geometry'] as Map)['coordinates']
          : null;
      if (list is! List) continue;
      for (final c in list) {
        if (c is List && c.length >= 2) {
          coords.add(
            GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          );
        }
      }
    }

    if (totalMeters <= 0) return null;
    return (
      miles: totalMeters / _metersPerMile,
      route: coords,
      confidence: confCount > 0 ? confSum / confCount : null,
    );
  }

  /// Whether matched miles replace GPS. Exposed for unit tests.
  static MapMatchResult acceptMatch({
    required double matchedMiles,
    required List<GeoPoint> matchedRoute,
    required double confidence,
    required double gpsMiles,
    required List<GeoPoint> gpsRoute,
  }) {
    MapMatchResult reject(String reason) => MapMatchResult.gps(
          gpsMiles,
          gpsRoute,
          reason: reason,
          confidence: confidence,
        );

    if (matchedMiles <= 0) return reject('zero_distance');
    if (confidence < _minConfidence) return reject('low_confidence');

    // Reject wild snaps (wrong road / tunnel jump) for non-trivial trips.
    if (gpsMiles >= _minGpsMilesForRatio) {
      final ratio = matchedMiles / gpsMiles;
      if (ratio < _minMatchRatio || ratio > _maxMatchRatio) {
        return reject('ratio');
      }
    }

    final route = matchedRoute.length >= 2
        ? GeoPoint.sparsify(matchedRoute, maxPoints: _storageMaxPoints)
        : gpsRoute;

    return MapMatchResult(
      miles: matchedMiles,
      route: route,
      matched: true,
      reason: 'ok',
      confidence: confidence,
    );
  }
}
