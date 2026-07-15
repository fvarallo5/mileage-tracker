import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_config.dart';

class ApiConfig {
  static const _prefsKey = 'api_base_url';

  static String defaultBaseUrl() {
    // Production App Store / Play Store builds
    if (AppConfig.isRelease) {
      return AppConfig.apiUrlOverride.isNotEmpty
          ? AppConfig.apiUrlOverride
          : AppConfig.productionApiUrl;
    }

    // Dev override from command line
    if (AppConfig.apiUrlOverride.isNotEmpty) return AppConfig.apiUrlOverride;

    if (kIsWeb) return 'http://localhost:3001/api';

    if (Platform.isAndroid) return 'http://10.0.2.2:3001/api';

    return 'http://localhost:3001/api';
  }

  static String prefsKey() => _prefsKey;

  /// Dev-only: allow changing API URL in settings.
  static bool get allowCustomApiUrl => !AppConfig.isRelease;
}