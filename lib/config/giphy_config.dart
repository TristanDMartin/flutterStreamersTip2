import 'package:flutter/foundation.dart';

/// Giphy keys via `--dart-define=GIPHY_API_KEY=...` for release builds.
class GiphyConfig {
  static const String apiKey = String.fromEnvironment('GIPHY_API_KEY');

  static const String fallbackApiKey = String.fromEnvironment(
    'GIPHY_FALLBACK_API_KEY',
    defaultValue: 'dc6zaTOxFJmzC',
  );

  static String get bestApiKey {
    if (apiKey.isNotEmpty) {
      return apiKey;
    }
    if (kDebugMode && fallbackApiKey.isNotEmpty) {
      return fallbackApiKey;
    }
    return '';
  }
}
