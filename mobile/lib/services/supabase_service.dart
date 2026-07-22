import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/import_formats.dart';
import '../models/entitlement.dart';
import '../models/import_result.dart';
import '../models/period_report.dart';
import '../models/trip.dart';
import 'csv_importer.dart';
import 'entitlement_service.dart';
import 'report_service.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Supabase-backed data layer for trips, settings, and imports.
class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> initialize() async {}

  Future<bool> healthCheck() async {
    try {
      if (_client.auth.currentSession == null) return false;
      await _client.from('settings').select('mileage_rate').limit(1).maybeSingle();
      return true;
    } catch (_) {
      return false;
    }
  }

  String? get _userId => _client.auth.currentUser?.id;

  Future<List<Trip>> getTrips({int? limit}) async {
    var query = _client
        .from('trips')
        .select()
        .order('date', ascending: false)
        .order('id', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final rows = await query;
    return (rows as List).map((e) => _tripFromRow(e as Map<String, dynamic>)).toList();
  }

  Future<Trip> createTrip({
    required String date,
    required double miles,
    double tips = 0,
    String notes = '',
    String source = 'manual',
    bool isBusiness = true,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    List<List<double>> route = const [],
  }) async {
    final userId = _userId;
    if (userId == null) throw ApiException('Not signed in');

    final payload = <String, dynamic>{
      'user_id': userId,
      'date': date,
      'miles': miles,
      'tips': tips,
      'notes': notes,
      'source': source,
      'is_business': isBusiness,
    };
    if (startLat != null) payload['start_lat'] = startLat;
    if (startLng != null) payload['start_lng'] = startLng;
    if (endLat != null) payload['end_lat'] = endLat;
    if (endLng != null) payload['end_lng'] = endLng;
    if (route.isNotEmpty) payload['route'] = route;

    try {
      final row = await _client.from('trips').insert(payload).select().single();
      return _tripFromRow(row);
    } catch (_) {
      // Newer columns may not be migrated yet — fall back to core fields.
      final row = await _client.from('trips').insert({
        'user_id': userId,
        'date': date,
        'miles': miles,
        'tips': tips,
        'notes': notes,
        'source': source,
      }).select().single();
      return _tripFromRow(row).copyWith(isBusiness: isBusiness);
    }
  }

  Future<Trip> updateTrip(
    int id, {
    required String date,
    required double miles,
    double tips = 0,
    String notes = '',
    bool isBusiness = true,
  }) async {
    try {
      final row = await _client.from('trips').update({
        'date': date,
        'miles': miles,
        'tips': tips,
        'notes': notes,
        'is_business': isBusiness,
      }).eq('id', id).select().single();
      return _tripFromRow(row);
    } catch (_) {
      final row = await _client.from('trips').update({
        'date': date,
        'miles': miles,
        'tips': tips,
        'notes': notes,
      }).eq('id', id).select().single();
      return _tripFromRow(row).copyWith(isBusiness: isBusiness);
    }
  }

  /// Quick purpose toggle without rewriting the whole trip.
  Future<Trip> setTripBusiness(int id, bool isBusiness) async {
    try {
      final row = await _client
          .from('trips')
          .update({'is_business': isBusiness})
          .eq('id', id)
          .select()
          .single();
      return _tripFromRow(row);
    } catch (e) {
      throw ApiException(
        'Could not update trip purpose. Run migration 003_trip_business.sql in Supabase.',
      );
    }
  }

  Future<void> deleteTrip(int id) async {
    await _client.from('trips').delete().eq('id', id);
  }

  Future<ReportSummary> getReportSummary() async {
    final trips = await getTrips();
    return ReportService.buildSummary(trips);
  }

  Future<List<PeriodReport>> getReports(String period, {int count = 8}) async {
    final trips = await getTrips();
    return ReportService.buildHistory(trips, period, count: count);
  }

  Future<double> getMileageRate() async {
    final userId = _userId;
    if (userId == null) throw ApiException('Not signed in');

    final row = await _client
        .from('settings')
        .select('mileage_rate')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return 0.70;
    return (row['mileage_rate'] as num).toDouble();
  }

  Future<double> setMileageRate(double rate) async {
    final userId = _userId;
    if (userId == null) throw ApiException('Not signed in');

    final row = await _client.from('settings').upsert({
      'user_id': userId,
      'mileage_rate': rate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select('mileage_rate').single();

    return (row['mileage_rate'] as num).toDouble();
  }

  Future<Entitlement?> fetchEntitlement() async {
    final userId = _userId;
    if (userId == null) throw EntitlementSyncException('Not signed in');

    try {
      final row = await _client
          .from('entitlements')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return Entitlement.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (_isMissingEntitlementsTable(e)) {
        throw EntitlementSyncException(
          'Entitlements table missing. Run supabase/migrations/004_entitlements.sql',
        );
      }
      throw EntitlementSyncException(e.message);
    }
  }

  Future<Entitlement> upsertEntitlement(Entitlement entitlement) async {
    final userId = _userId;
    if (userId == null) throw EntitlementSyncException('Not signed in');

    try {
      final row = await _client
          .from('entitlements')
          .upsert(entitlement.toUpsertPayload(userId))
          .select()
          .single();
      return Entitlement.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (_isMissingEntitlementsTable(e)) {
        throw EntitlementSyncException(
          'Entitlements table missing. Run supabase/migrations/004_entitlements.sql',
        );
      }
      throw EntitlementSyncException(e.message);
    }
  }

  bool _isMissingEntitlementsTable(PostgrestException e) {
    final m = e.message.toLowerCase();
    return m.contains('entitlements') &&
        (m.contains('does not exist') ||
            m.contains('schema cache') ||
            m.contains('could not find'));
  }

  Future<ImportFormats> getImportFormats() async {
    return ImportFormatsData.formats;
  }

  Future<ImportResult> previewImport({
    required String csv,
    required String platform,
    double defaultMiles = 0,
  }) async {
    final result = CsvImporter.parseTripCsv(csv, platform: platform, defaultMiles: defaultMiles);
    return ImportResult(
      platform: result.platform,
      importedCount: result.trips.length,
      skippedCount: 0,
      errorCount: result.errors.length,
      preview: result.trips.map(ImportPreviewRow.fromJson).toList(),
      errors: result.errors
          .map((e) => 'Line ${e['line']}: ${e['error']}')
          .toList(),
    );
  }

  Future<ImportResult> importTrips({
    required String csv,
    required String platform,
    double defaultMiles = 0,
  }) async {
    final userId = _userId;
    if (userId == null) throw ApiException('Not signed in');

    final parsed = CsvImporter.parseTripCsv(csv, platform: platform, defaultMiles: defaultMiles);
    final existing = await getTrips();
    var importedCount = 0;
    var skippedCount = 0;

    for (final trip in parsed.trips) {
      final miles = (trip['miles'] as num).toDouble();
      final tips = (trip['tips'] as num).toDouble();
      final date = trip['date'] as String;
      final source = trip['source'] as String;

      final isDuplicate = existing.any((t) =>
          t.date == date &&
          t.source == source &&
          (t.miles - miles).abs() < 0.05 &&
          (t.tips - tips).abs() < 0.01);

      if (isDuplicate) {
        skippedCount++;
        continue;
      }

      try {
        await _client.from('trips').insert({
          'user_id': userId,
          'date': date,
          'miles': miles,
          'tips': tips,
          'notes': trip['notes'],
          'source': source,
          'is_business': true,
        });
      } catch (_) {
        await _client.from('trips').insert({
          'user_id': userId,
          'date': date,
          'miles': miles,
          'tips': tips,
          'notes': trip['notes'],
          'source': source,
        });
      }
      importedCount++;
    }

    return ImportResult(
      platform: parsed.platform,
      importedCount: importedCount,
      skippedCount: skippedCount,
      errorCount: parsed.errors.length,
      errors: parsed.errors
          .map((e) => 'Line ${e['line']}: ${e['error']}')
          .toList(),
    );
  }

  Trip _tripFromRow(Map<String, dynamic> row) {
    return Trip.fromJson({
      'id': (row['id'] as num).toInt(),
      'date': row['date'] as String,
      'miles': row['miles'],
      'tips': row['tips'],
      'notes': row['notes'],
      'source': row['source'],
      'is_business': row['is_business'] ?? true,
      'created_at': row['created_at'],
      'start_lat': row['start_lat'],
      'start_lng': row['start_lng'],
      'end_lat': row['end_lat'],
      'end_lng': row['end_lng'],
      'route': row['route'],
    });
  }
}