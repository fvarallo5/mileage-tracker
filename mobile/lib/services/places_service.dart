import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_place.dart';

/// Favorite places for auto-detect skip and end-of-trip purpose.
class PlacesService extends ChangeNotifier {
  static const _key = 'saved_places_v1';

  List<SavedPlace> places = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      places = [];
      notifyListeners();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      places = list
          .map((e) => SavedPlace.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      places = [];
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(places.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> add(SavedPlace place) async {
    places = [...places, place];
    await _persist();
    notifyListeners();
  }

  Future<void> update(SavedPlace place) async {
    places = places.map((p) => p.id == place.id ? place : p).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    places = places.where((p) => p.id != id).toList();
    await _persist();
    notifyListeners();
  }

  SavedPlace? nearestMatching(
    double lat,
    double lng, {
    PlaceMode? mode,
  }) {
    SavedPlace? best;
    var bestDist = double.infinity;
    for (final p in places) {
      if (mode != null && p.mode != mode) continue;
      final d = p.distanceMeters(lat, lng);
      if (d <= p.radiusMeters && d < bestDist) {
        best = p;
        bestDist = d;
      }
    }
    return best;
  }

  /// Block auto-start when near an exclude place (e.g. home driveway).
  SavedPlace? blocksAutoStart(double lat, double lng) {
    return nearestMatching(lat, lng, mode: PlaceMode.exclude);
  }

  /// Purpose from end location: true=business, false=personal, null=no match.
  bool? classifyIsBusiness(double lat, double lng) {
    final personal = nearestMatching(lat, lng, mode: PlaceMode.personal);
    if (personal != null) return false;
    final business = nearestMatching(lat, lng, mode: PlaceMode.business);
    if (business != null) return true;
    return null;
  }
}
