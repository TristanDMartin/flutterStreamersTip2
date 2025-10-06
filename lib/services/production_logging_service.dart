import 'dart:developer';
import 'package:flutter/foundation.dart';

/// Production-ready logging service with conditional logging levels
class ProductionLoggingService {
  static final ProductionLoggingService _instance =
      ProductionLoggingService._internal();
  factory ProductionLoggingService() => _instance;
  ProductionLoggingService._internal();

  // Log levels
  static const int _debugLevel = 0;
  static const int _infoLevel = 1;
  static const int _warnLevel = 2;
  static const int _errorLevel = 3;

  // Current log level (set to error in production)
  static int _currentLogLevel = kDebugMode ? _debugLevel : _errorLevel;

  /// Set log level for different environments
  static void setLogLevel(int level) {
    _currentLogLevel = level;
  }

  /// Debug logging (only in debug mode)
  void debug(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= _debugLevel) {
      _log('DEBUG', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Info logging
  void info(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= _infoLevel) {
      _log('INFO', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Warning logging
  void warn(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= _warnLevel) {
      _log('WARN', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Error logging (always shown)
  void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= _errorLevel) {
      _log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Internal logging method
  void _log(String level, String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag]' : '';
    final errorStr = error != null ? ' | Error: $error' : '';
    final stackStr = stackTrace != null ? ' | Stack: $stackTrace' : '';

    final logMessage = '$timestamp $level$tagStr: $message$errorStr$stackStr';

    if (kDebugMode) {
      debugPrint(logMessage);
    } else {
      // In production, use developer log for better performance
      log(logMessage, level: _getLogLevel(level));
    }
  }

  /// Convert string level to developer log level
  int _getLogLevel(String level) {
    switch (level) {
      case 'DEBUG':
        return 500;
      case 'INFO':
        return 800;
      case 'WARN':
        return 900;
      case 'ERROR':
        return 1000;
      default:
        return 800;
    }
  }

  /// Performance logging for video operations
  void logVideoOperation(String operation, String videoId,
      {Duration? duration, bool success = true}) {
    final status = success ? 'SUCCESS' : 'FAILED';
    final durationStr =
        duration != null ? ' (${duration.inMilliseconds}ms)' : '';

    info('Video $operation: $videoId - $status$durationStr',
        tag: 'VideoPerformance');
  }

  /// Memory usage logging
  void logMemoryUsage(String operation, {int? controllerCount, int? memoryMB}) {
    final controllerStr =
        controllerCount != null ? 'Controllers: $controllerCount' : '';
    final memoryStr = memoryMB != null ? 'Memory: ${memoryMB}MB' : '';
    final details =
        [controllerStr, memoryStr].where((s) => s.isNotEmpty).join(' | ');

    info('Memory $operation: $details', tag: 'MemoryManagement');
  }

  /// Error tracking for production monitoring
  void trackError(String errorType, String context,
      {Object? error, Map<String, dynamic>? metadata}) {
    final metadataStr = metadata != null ? ' | Metadata: $metadata' : '';
    this.error('$errorType in $context$metadataStr',
        error: error, tag: 'ErrorTracking');
  }
}
