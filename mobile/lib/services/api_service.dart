import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/import_result.dart';
import '../models/period_report.dart';
import '../models/trip.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  String _baseUrl = ApiConfig.defaultBaseUrl();

  String get baseUrl => _baseUrl;

  Future<void> loadSavedBaseUrl() async {
    if (!ApiConfig.allowCustomApiUrl) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ApiConfig.prefsKey());
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.prefsKey(), _baseUrl);
  }

  Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(Uri.parse('${_baseUrl.replaceAll('/api', '')}/api/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Trip>> getTrips({int? limit}) async {
    final uri = Uri.parse('$_baseUrl/trips').replace(
      queryParameters: limit != null ? {'limit': '$limit'} : null,
    );
    final res = await _get(uri);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Trip> createTrip({
    required String date,
    required double miles,
    double tips = 0,
    String notes = '',
    String source = 'manual',
  }) async {
    final res = await _post(
      Uri.parse('$_baseUrl/trips'),
      {'date': date, 'miles': miles, 'tips': tips, 'notes': notes, 'source': source},
    );
    return Trip.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Trip> updateTrip(
    int id, {
    required String date,
    required double miles,
    double tips = 0,
    String notes = '',
  }) async {
    final res = await _put(
      Uri.parse('$_baseUrl/trips/$id'),
      {'date': date, 'miles': miles, 'tips': tips, 'notes': notes},
    );
    return Trip.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteTrip(int id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/trips/$id'));
    if (res.statusCode != 204) {
      throw ApiException(_parseError(res));
    }
  }

  Future<ReportSummary> getReportSummary() async {
    final res = await _get(Uri.parse('$_baseUrl/reports/summary'));
    return ReportSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<PeriodReport>> getReports(String period, {int count = 8}) async {
    final uri = Uri.parse('$_baseUrl/reports/$period').replace(
      queryParameters: {'count': '$count'},
    );
    final res = await _get(uri);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final reports = data['reports'] as List;
    return reports
        .map((e) => PeriodReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<double> getMileageRate() async {
    final res = await _get(Uri.parse('$_baseUrl/settings'));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return double.parse(data['mileage_rate'] as String);
  }

  Future<ImportFormats> getImportFormats() async {
    final res = await _get(Uri.parse('$_baseUrl/trips/import/formats'));
    return ImportFormats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ImportResult> previewImport({
    required String csv,
    required String platform,
    double defaultMiles = 0,
  }) async {
    final res = await _post(
      Uri.parse('$_baseUrl/trips/import/preview'),
      {'csv': csv, 'platform': platform, 'default_miles': defaultMiles},
    );
    return ImportResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>, isPreview: true);
  }

  Future<ImportResult> importTrips({
    required String csv,
    required String platform,
    double defaultMiles = 0,
  }) async {
    final res = await _post(
      Uri.parse('$_baseUrl/trips/import'),
      {'csv': csv, 'platform': platform, 'default_miles': defaultMiles},
    );
    return ImportResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<double> setMileageRate(double rate) async {
    final res = await _put(
      Uri.parse('$_baseUrl/settings/mileage-rate'),
      {'rate': rate},
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['mileage_rate'] as num).toDouble();
  }

  Future<http.Response> _get(Uri uri) async {
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) throw ApiException(_parseError(res));
    return res;
  }

  Future<http.Response> _post(Uri uri, Map<String, dynamic> body) async {
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) throw ApiException(_parseError(res));
    return res;
  }

  Future<http.Response> _put(Uri uri, Map<String, dynamic> body) async {
    final res = await http
        .put(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) throw ApiException(_parseError(res));
    return res;
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  String _parseError(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['error'] as String? ?? 'Request failed (${res.statusCode})';
    } catch (_) {
      return 'Request failed (${res.statusCode})';
    }
  }
}