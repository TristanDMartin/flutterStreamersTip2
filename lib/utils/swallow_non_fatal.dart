import 'package:flutter/foundation.dart';

import '../services/production_logging_service.dart';

final ProductionLoggingService _nonFatalLog = ProductionLoggingService();

/// Logs expected failures without crashing (dispose races, parse guards, etc.).
void swallowNonFatal(
  String context,
  Object error, [
  StackTrace? stackTrace,
]) {
  if (kDebugMode) {
    _nonFatalLog.debug(
      context,
      tag: 'NonFatal',
      error: error,
      stackTrace: stackTrace,
    );
  } else {
    _nonFatalLog.warn(
      context,
      tag: 'NonFatal',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
