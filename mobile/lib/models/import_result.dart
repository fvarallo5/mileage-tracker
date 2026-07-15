class ImportPreviewRow {
  final String date;
  final double miles;
  final double tips;
  final String notes;
  final String source;
  final int line;

  const ImportPreviewRow({
    required this.date,
    required this.miles,
    required this.tips,
    required this.notes,
    required this.source,
    required this.line,
  });

  factory ImportPreviewRow.fromJson(Map<String, dynamic> json) {
    return ImportPreviewRow(
      date: json['date'] as String,
      miles: (json['miles'] as num).toDouble(),
      tips: (json['tips'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
      source: json['source'] as String? ?? 'generic',
      line: json['line'] as int? ?? 0,
    );
  }
}

class ImportResult {
  final String platform;
  final int importedCount;
  final int skippedCount;
  final int errorCount;
  final List<ImportPreviewRow> preview;
  final List<String> errors;

  const ImportResult({
    required this.platform,
    required this.importedCount,
    required this.skippedCount,
    required this.errorCount,
    this.preview = const [],
    this.errors = const [],
  });

  factory ImportResult.fromJson(Map<String, dynamic> json, {bool isPreview = false}) {
    final previewList = (json['preview'] as List?) ?? [];
    final errorList = (json['errors'] as List?) ?? [];

    return ImportResult(
      platform: json['platform'] as String? ?? 'generic',
      importedCount: json['imported_count'] as int? ?? previewList.length,
      skippedCount: json['skipped_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? errorList.length,
      preview: previewList
          .map((e) => ImportPreviewRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      errors: errorList
          .map((e) => e is Map ? 'Line ${e['line']}: ${e['error']}' : e.toString())
          .toList(),
    );
  }
}

class ImportFormats {
  final Map<String, dynamic> instructions;
  final Map<String, String> sampleCsv;

  const ImportFormats({required this.instructions, required this.sampleCsv});

  factory ImportFormats.fromJson(Map<String, dynamic> json) {
    return ImportFormats(
      instructions: json['instructions'] as Map<String, dynamic>,
      sampleCsv: (json['sample_csv'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
  }
}