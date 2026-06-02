import 'package:flutter/foundation.dart';

/// Debug-only logging. No output in release builds (unlike [print]).
void appLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
