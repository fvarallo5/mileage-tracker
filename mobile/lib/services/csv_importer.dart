class CsvParseResult {
  final String platform;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> errors;

  const CsvParseResult({
    required this.platform,
    required this.trips,
    required this.errors,
  });
}

class CsvImporter {
  static const _platforms = ['uber', 'doordash', 'lyft', 'instacart', 'generic'];

  static const _columnAliases = {
    'date': [
      'date', 'trip date', 'trip request time', 'pickup time', 'dropoff time',
      'delivery date', 'completed at', 'timestamp', 'start time', 'end time', 'time',
    ],
    'miles': [
      'miles', 'distance', 'trip distance', 'distance (miles)', 'delivery distance',
      'mileage', 'total distance', 'distance mi',
    ],
    'tips': [
      'tips', 'tip', 'tip amount', 'earnings', 'driver earnings', 'total pay',
      'total earnings', 'dasher pay', 'net pay', 'payout', 'fare', 'trip fare',
      'amount', 'pay',
    ],
    'notes': [
      'notes', 'description', 'store name', 'restaurant', 'product type',
      'service type', 'trip id', 'delivery', 'type',
    ],
  };

  static const _platformHints = {
    'uber': ['uber', 'trip request', 'trip fare', 'rider'],
    'doordash': ['doordash', 'dasher', 'delivery pay', 'store name'],
    'lyft': ['lyft', 'ride', 'passenger'],
    'instacart': ['instacart', 'batch', 'shop'],
  };

  static CsvParseResult parseTripCsv(
    String csvText, {
    String platform = 'generic',
    double defaultMiles = 0,
  }) {
    final parsed = _parseCsv(csvText);
    final headers = parsed.headers;
    final rows = parsed.rows;
    final detected = _detectPlatform(headers, platform);
    final columns = _mapColumns(headers, detected);

    if (columns['date'] == null) {
      throw FormatException(
        'Could not find a date column. Headers found: ${headers.join(', ')}. '
        'Expected columns like "Date", "Trip Request Time", or "Delivery Date".',
      );
    }

    final trips = <Map<String, dynamic>>[];
    final errors = <Map<String, dynamic>>[];

    for (var i = 0; i < rows.length; i++) {
      final lineNum = i + 2;
      final row = rows[i];
      try {
        final date = _parseDate(row[columns['date']!] ?? '');
        if (date == null) {
          errors.add({'line': lineNum, 'error': 'Invalid or missing date'});
          continue;
        }

        var miles = columns['miles'] != null ? _parseMiles(row[columns['miles']!]) : null;
        if (miles == null && defaultMiles > 0) miles = defaultMiles;
        if (miles == null || miles <= 0) {
          errors.add({
            'line': lineNum,
            'error': 'Missing miles/distance — set a default miles value for earnings-only exports',
          });
          continue;
        }

        final tips = columns['tips'] != null ? _parseMoney(row[columns['tips']!]) : 0.0;
        var notes = columns['notes'] != null ? (row[columns['notes']!] ?? '').trim() : '';
        if (notes.isEmpty) notes = 'Imported from $detected';

        trips.add({
          'date': date,
          'miles': _round2(miles),
          'tips': _round2(tips),
          'notes': notes,
          'source': detected,
          'line': lineNum,
        });
      } catch (e) {
        errors.add({'line': lineNum, 'error': e.toString()});
      }
    }

    return CsvParseResult(platform: detected, trips: trips, errors: errors);
  }

  static _CsvTable _parseCsv(String text) {
    final lines = text
        .replaceFirst('\uFEFF', '')
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 2) {
      throw FormatException('CSV must have a header row and at least one data row');
    }

    final delimiter = _detectDelimiter(lines.first);
    final headers = _parseCsvLine(lines.first, delimiter).map(_normalizeHeader).toList();
    final rows = lines.skip(1).map((line) {
      final values = _parseCsvLine(line, delimiter);
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i]] = i < values.length ? values[i] : '';
      }
      return row;
    }).toList();

    return _CsvTable(headers: headers, rows: rows);
  }

  static String _detectDelimiter(String headerLine) {
    final commas = ','.allMatches(headerLine).length;
    final tabs = '\t'.allMatches(headerLine).length;
    final semis = ';'.allMatches(headerLine).length;
    if (tabs >= commas && tabs >= semis) return '\t';
    if (semis > commas) return ';';
    return ',';
  }

  static List<String> _parseCsvLine(String line, String delimiter) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delimiter && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  static String _normalizeHeader(String h) =>
      h.trim().toLowerCase().replaceAll(RegExp(r'[_"]'), ' ').replaceAll(RegExp(r'\s+'), ' ');

  static String? _findColumn(List<String> headers, List<String> aliases) {
    for (final alias in aliases) {
      if (headers.contains(alias)) return alias;
    }
    for (final alias in aliases) {
      for (final h in headers) {
        if (h.contains(alias) || alias.contains(h)) return h;
      }
    }
    return null;
  }

  static String _detectPlatform(List<String> headers, String hint) {
    if (hint != 'generic' && _platforms.contains(hint)) return hint;
    final joined = headers.join(' ');
    for (final entry in _platformHints.entries) {
      if (entry.value.any(joined.contains)) return entry.key;
    }
    return 'generic';
  }

  static Map<String, String?> _mapColumns(List<String> headers, String platform) {
    final mapping = <String, String?>{};
    for (final entry in _columnAliases.entries) {
      mapping[entry.key] = _findColumn(headers, entry.value);
    }

    if (platform == 'uber') {
      mapping['date'] ??= _findColumn(headers, ['trip request time', 'pickup time']);
      mapping['miles'] ??= _findColumn(headers, ['trip distance', 'distance']);
      mapping['tips'] ??= _findColumn(headers, ['driver earnings', 'earnings', 'trip fare']);
    }
    if (platform == 'doordash') {
      mapping['date'] ??= _findColumn(headers, ['delivery date', 'completed at']);
      mapping['tips'] ??= _findColumn(headers, ['total pay', 'dasher pay', 'earnings']);
      mapping['notes'] ??= _findColumn(headers, ['store name', 'merchant']);
    }

    return mapping;
  }

  static double _parseMoney(dynamic value) {
    if (value == null || value.toString().isEmpty) return 0;
    final cleaned = value.toString().replaceAll(RegExp(r'[$,\s]'), '').replaceAll(RegExp(r'[()]'), '');
    final num = double.tryParse(cleaned);
    return num != null && num.isFinite ? (num < 0 ? 0 : num) : 0;
  }

  static double? _parseMiles(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    final str = value.toString().toLowerCase().trim();
    final kmMatch = RegExp(r'([\d.]+)\s*km').firstMatch(str);
    if (kmMatch != null) return double.parse(kmMatch.group(1)!) * 0.621371;

    final miMatch = RegExp(r'([\d.]+)\s*mi').firstMatch(str);
    if (miMatch != null) return double.parse(miMatch.group(1)!);

    final num = double.tryParse(str.replaceAll(RegExp(r'[^\d.]'), ''));
    return num != null && num.isFinite && num > 0 ? num : null;
  }

  static String? _parseDate(String value) {
    if (value.trim().isEmpty) return null;

    final iso = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(value.trim());
    if (iso != null) return iso.group(1);

    final us = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(value.trim());
    if (us != null) {
      var year = int.parse(us.group(3)!);
      if (year < 100) year += 2000;
      final month = us.group(1)!.padLeft(2, '0');
      final day = us.group(2)!.padLeft(2, '0');
      return '$year-$month-$day';
    }

    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) {
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }

    return null;
  }

  static double _round2(double n) => (n * 100).roundToDouble() / 100;
}

class _CsvTable {
  final List<String> headers;
  final List<Map<String, String>> rows;

  const _CsvTable({required this.headers, required this.rows});
}