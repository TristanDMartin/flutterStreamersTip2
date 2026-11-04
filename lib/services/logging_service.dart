import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();

  LoggingService._();

  // Log levels
  static const String _levelDebug = 'DEBUG';
  static const String _levelInfo = 'INFO';
  static const String _levelWarning = 'WARNING';
  static const String _levelError = 'ERROR';

  void debug(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelDebug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void info(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelInfo, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void warning(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelWarning, message,
        tag: tag, error: error, stackTrace: stackTrace);
  }

  void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelError, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void _log(String level, String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag]' : '';
    final errorStr = error != null ? ' | Error: $error' : '';
    final stackStr = stackTrace != null ? ' | Stack: $stackTrace' : '';

    final logMessage = '$timestamp [$level]$tagStr $message$errorStr$stackStr';

    if (kDebugMode) {
      debugPrint(logMessage);
    }

    // Forward all logs to Crashlytics for production monitoring
    try {
      FirebaseCrashlytics.instance.log(logMessage);
      // Record errors with stack traces to Crashlytics
      if (level == _levelError && error != null) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
          fatal: false,
        );
      }
    } catch (e) {
      // Fail silently if Crashlytics is not initialized
      if (kDebugMode) {
        debugPrint('Failed to log to Crashlytics: $e');
      }
    }
  }
}
