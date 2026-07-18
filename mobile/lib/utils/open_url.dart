import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Opens [url] in an external browser/app if possible.
Future<bool> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openPrivacyPolicy() => openUrl(AppConfig.privacyPolicyUrl);

Future<bool> openSupportEmail() => openUrl('mailto:${AppConfig.supportEmail}');
