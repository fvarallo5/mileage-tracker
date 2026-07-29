/// Snapshot of a Terms + Privacy acceptance record.
class LegalAcceptance {
  final String termsVersion;
  final String privacyVersion;
  final DateTime acceptedAt;
  final String? platform;
  final String? appVersion;

  const LegalAcceptance({
    required this.termsVersion,
    required this.privacyVersion,
    required this.acceptedAt,
    this.platform,
    this.appVersion,
  });

  factory LegalAcceptance.fromJson(Map<String, dynamic> json) {
    final at = json['accepted_at'] as String?;
    return LegalAcceptance(
      termsVersion: json['terms_version'] as String? ?? '',
      privacyVersion: json['privacy_version'] as String? ?? '',
      acceptedAt: at != null
          ? (DateTime.tryParse(at)?.toUtc() ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      platform: json['platform'] as String?,
      appVersion: json['app_version'] as String?,
    );
  }

  Map<String, dynamic> toUpsertPayload(String userId) {
    return {
      'user_id': userId,
      'terms_version': termsVersion,
      'privacy_version': privacyVersion,
      'accepted_at': acceptedAt.toUtc().toIso8601String(),
      'platform': platform,
      'app_version': appVersion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toEventPayload(String userId) {
    return {
      'user_id': userId,
      'terms_version': termsVersion,
      'privacy_version': privacyVersion,
      'accepted_at': acceptedAt.toUtc().toIso8601String(),
      'platform': platform,
      'app_version': appVersion,
    };
  }
}
