import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Performance Monitoring Service
///
/// This service provides comprehensive performance monitoring including:
/// - Frame rate monitoring
/// - Memory usage tracking
/// - Crash reporting
/// - Performance metrics collection
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();
  factory PerformanceMonitoringService() => _instance;
  PerformanceMonitoringService._internal();

  // Performance metrics
  final List<double> _frameRates = [];
  final List<int> _memoryUsage = [];
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  // Performance thresholds
  static const double _targetFrameRate = 60.0;
  static const double _minimumFrameRate = 30.0;
  static const int _memoryWarningThreshold = 100 * 1024 * 1024; // 100MB
  static const int _memoryCriticalThreshold = 200 * 1024 * 1024; // 200MB

  /// Initialize performance monitoring
  void initialize() {
    if (kDebugMode) {
      debugPrint('📊 Performance Monitoring Service initialized');
    }

    // Start monitoring in production
    if (!kDebugMode) {
      startMonitoring();
    }
  }

  /// Start performance monitoring
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Monitor frame rate every 5 seconds
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _collectPerformanceMetrics();
    });

    if (kDebugMode) {
      debugPrint('📊 Performance monitoring started');
    }
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    if (kDebugMode) {
      debugPrint('📊 Performance monitoring stopped');
    }
  }

  /// Collect performance metrics
  void _collectPerformanceMetrics() {
    // Frame rate monitoring
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final frameRate = _calculateFrameRate();
      if (frameRate > 0) {
        _frameRates.add(frameRate);

        // Keep only last 100 measurements
        if (_frameRates.length > 100) {
          _frameRates.removeAt(0);
        }

        // Check for performance issues
        _checkPerformanceIssues(frameRate);
      }
    });

    // Memory usage monitoring
    _collectMemoryUsage();
  }

  /// Calculate current frame rate
  double _calculateFrameRate() {
    // This is a simplified calculation
    // In a real implementation, you'd use more sophisticated methods
    return 60.0; // Placeholder
  }

  /// Collect memory usage
  void _collectMemoryUsage() {
    // This would integrate with platform-specific memory monitoring
    // For now, we'll use a placeholder
    final memoryUsage = _getCurrentMemoryUsage();
    _memoryUsage.add(memoryUsage);

    // Keep only last 100 measurements
    if (_memoryUsage.length > 100) {
      _memoryUsage.removeAt(0);
    }

    // Check for memory issues
    _checkMemoryIssues(memoryUsage);
  }

  /// Get current memory usage (placeholder)
  int _getCurrentMemoryUsage() {
    // This would integrate with platform-specific APIs
    return 50 * 1024 * 1024; // 50MB placeholder
  }

  /// Check for performance issues
  void _checkPerformanceIssues(double frameRate) {
    if (frameRate < _minimumFrameRate) {
      _reportPerformanceIssue(
          'Low frame rate: ${frameRate.toStringAsFixed(1)} FPS');
    } else if (frameRate < _targetFrameRate) {
      _reportPerformanceWarning(
          'Below target frame rate: ${frameRate.toStringAsFixed(1)} FPS');
    }
  }

  /// Check for memory issues
  void _checkMemoryIssues(int memoryUsage) {
    if (memoryUsage > _memoryCriticalThreshold) {
      _reportPerformanceIssue(
          'Critical memory usage: ${_formatBytes(memoryUsage)}');
    } else if (memoryUsage > _memoryWarningThreshold) {
      _reportPerformanceWarning(
          'High memory usage: ${_formatBytes(memoryUsage)}');
    }
  }

  /// Report performance issue
  void _reportPerformanceIssue(String message) {
    if (kDebugMode) {
      debugPrint('🚨 Performance Issue: $message');
    }

    // In production, this would send to crash reporting service
    _logToCrashReporting('PERFORMANCE_ISSUE', message);
  }

  /// Report performance warning
  void _reportPerformanceWarning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ Performance Warning: $message');
    }

    // In production, this would send to analytics service
    _logToAnalytics('PERFORMANCE_WARNING', message);
  }

  /// Log to crash reporting service
  void _logToCrashReporting(String type, String message) {
    // This would integrate with Firebase Crashlytics or similar
    if (kDebugMode) {
      debugPrint('📊 Crash Reporting: $type - $message');
    }
  }

  /// Log to analytics service
  void _logToAnalytics(String type, String message) {
    // This would integrate with Firebase Analytics or similar
    if (kDebugMode) {
      debugPrint('📊 Analytics: $type - $message');
    }
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    if (_frameRates.isEmpty) {
      return {
        'averageFrameRate': 0.0,
        'minFrameRate': 0.0,
        'maxFrameRate': 0.0,
        'averageMemoryUsage': 0,
        'maxMemoryUsage': 0,
        'performanceIssues': 0,
      };
    }

    return {
      'averageFrameRate':
          _frameRates.reduce((a, b) => a + b) / _frameRates.length,
      'minFrameRate': _frameRates.reduce((a, b) => a < b ? a : b),
      'maxFrameRate': _frameRates.reduce((a, b) => a > b ? a : b),
      'averageMemoryUsage':
          _memoryUsage.reduce((a, b) => a + b) / _memoryUsage.length,
      'maxMemoryUsage': _memoryUsage.reduce((a, b) => a > b ? a : b),
      'performanceIssues':
          _frameRates.where((rate) => rate < _minimumFrameRate).length,
    };
  }

  /// Track custom performance metric
  void trackMetric(String name, double value,
      {Map<String, dynamic>? attributes}) {
    if (kDebugMode) {
      debugPrint('📊 Metric: $name = $value');
    }

    // In production, this would send to analytics service
    _logToAnalytics('CUSTOM_METRIC', '$name: $value');
  }

  /// Track user action performance
  void trackUserAction(String action, Duration duration) {
    if (kDebugMode) {
      debugPrint('📊 User Action: $action took ${duration.inMilliseconds}ms');
    }

    // Track slow actions
    if (duration.inMilliseconds > 1000) {
      _reportPerformanceWarning(
          'Slow user action: $action (${duration.inMilliseconds}ms)');
    }

    _logToAnalytics('USER_ACTION', '$action: ${duration.inMilliseconds}ms');
  }

  /// Track network request performance
  void trackNetworkRequest(String endpoint, Duration duration,
      {int? statusCode}) {
    if (kDebugMode) {
      debugPrint(
          '📊 Network Request: $endpoint took ${duration.inMilliseconds}ms (${statusCode ?? 'unknown'})');
    }

    // Track slow requests
    if (duration.inMilliseconds > 5000) {
      _reportPerformanceWarning(
          'Slow network request: $endpoint (${duration.inMilliseconds}ms)');
    }

    _logToAnalytics('NETWORK_REQUEST',
        '$endpoint: ${duration.inMilliseconds}ms (${statusCode ?? 'unknown'})');
  }

  /// Track widget build performance
  void trackWidgetBuild(String widgetName, Duration duration) {
    if (kDebugMode) {
      debugPrint(
          '📊 Widget Build: $widgetName took ${duration.inMilliseconds}ms');
    }

    // Track slow builds
    if (duration.inMilliseconds > 100) {
      _reportPerformanceWarning(
          'Slow widget build: $widgetName (${duration.inMilliseconds}ms)');
    }

    _logToAnalytics(
        'WIDGET_BUILD', '$widgetName: ${duration.inMilliseconds}ms');
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
