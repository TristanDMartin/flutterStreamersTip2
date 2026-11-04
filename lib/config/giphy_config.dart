import 'package:flutter/foundation.dart';

/// Giphy API configuration for GIF support.
///
/// PRODUCTION: Always provide GIPHY_API_KEY via --dart-define.
/// The fallback key is Giphy's public beta key and is DEBUG-ONLY.
/// It has rate limits and should NEVER be used in production.
///
/// Usage:
///   flutter run --dart-define=GIPHY_API_KEY=your_production_key
///   flutter build apk --dart-define=GIPHY_API_KEY=your_production_key
class GiphyConfig {
  /// Production Giphy API key (passed via --dart-define=GIPHY_API_KEY=...)
  static const String apiKey = String.fromEnvironment('GIPHY_API_KEY');

  /// DEBUG-ONLY fallback using Giphy's public beta key.
  /// NEVER used in release builds. Has severe rate limits.
  static const String _debugFallbackKey = String.fromEnvironment(
    'GIPHY_FALLBACK_API_KEY',
    defaultValue: kDebugMode ? 'dc6zaTOxFJmzC' : '',
  );

  /// Returns the best available Giphy API key.
  /// In production, returns empty string if GIPHY_API_KEY not provided.
  /// In debug, falls back to public beta key (rate-limited).
  static String get bestApiKey {
    if (apiKey.isNotEmpty) {
      return apiKey;
    }
    // Debug-only fallback
    if (kDebugMode && _debugFallbackKey.isNotEmpty) {
      return _debugFallbackKey;
    }
    // Production without key: GIF features will be disabled
    return '';
  }

  /// Whether Giphy features are available
  static bool get isAvailable => bestApiKey.isNotEmpty;
}
