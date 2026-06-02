import 'package:flutter/foundation.dart';

import '../services/production_logging_service.dart';

/// Expected failures during controller pause/dispose (race with dispose).
void ignorePlaybackTeardownError(String context, Object error,
    [StackTrace? stackTrace]) {
  if (kDebugMode) {
    ProductionLoggingService().debug(
      'Playback teardown ($context)',
      tag: 'Playback',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
