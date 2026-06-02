import 'package:flutter/foundation.dart';

/// Platform-specific watchdog timings for feed video cells.
class VideoCellWatchdogTokens {
  const VideoCellWatchdogTokens._();

  static int firstFrameTimeoutMs({required TargetPlatform platform}) {
    return platform == TargetPlatform.android ? 900 : 600;
  }
}
