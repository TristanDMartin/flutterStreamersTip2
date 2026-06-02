import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global status / navigation chrome — call once after [WidgetsFlutterBinding].
abstract final class STSystemUi {
  STSystemUi._();

  /// Dark nav bar + transparent status bar; tune per‑route with [AnnotatedRegion] if needed.
  static void configureDefault() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
}
