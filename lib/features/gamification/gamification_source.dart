import 'package:flutter/foundation.dart';

/// Where a gamification event originated. Must match backend `source` field.
abstract final class GamificationEventSource {
  static const String iosApp = 'ios_app';
  static const String androidApp = 'android_app';
  static const String website = 'website';
  static const String desktop = 'desktop';
  static const String admin = 'admin';
  static const String tippyAi = 'tippy_ai';

  /// Resolves platform for mobile; web builds should pass [website] explicitly.
  static String get currentPlatform {
    if (kIsWeb) {
      return website;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return iosApp;
      case TargetPlatform.android:
        return androidApp;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return desktop;
      case TargetPlatform.fuchsia:
        return androidApp;
    }
  }
}
