import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Memory monitoring
  Timer? _memoryTimer;
  final List<MemorySnapshot> _memoryHistory = [];
  static const int _maxMemoryHistory = 50;

  // Video performance tracking
  final Map<String, VideoPerformanceMetrics> _videoMetrics = {};
  final Map<String, DateTime> _videoLoadTimes = {};

  // Performance thresholds
  static const int _memoryWarningThreshold = 200; // MB
  static const int _memoryCriticalThreshold = 300; // MB
  static const Duration _videoLoadTimeout = Duration(seconds: 10);

  /// Initialize performance monitoring
  void initialize() {
    if (kDebugMode) {
      _startMemoryMonitoring();
      _logPerformanceInfo('Performance monitoring initialized');
    }
  }

  /// Start monitoring memory usage
  void _startMemoryMonitoring() {
    _memoryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _recordMemorySnapshot();
    });
  }

  /// Record current memory usage
  void _recordMemorySnapshot() {
    try {
      final memoryUsage = _getCurrentMemoryUsage();
      final snapshot = MemorySnapshot(
        timestamp: DateTime.now(),
        usedMemory: memoryUsage,
        freeMemory: _getFreeMemory(),
      );

      _memoryHistory.add(snapshot);
      
      // Keep only recent history
      if (_memoryHistory.length > _maxMemoryHistory) {
        _memoryHistory.removeAt(0);
      }

      // Check for memory warnings
      _checkMemoryThresholds(memoryUsage);
    } catch (e) {
      _logPerformanceError('Error recording memory snapshot: $e');
    }
  }

  /// Get current memory usage in MB
  int _getCurrentMemoryUsage() {
    try {
      // This is a simplified approach - in production you might want to use
      // platform-specific memory monitoring
      return 100; // Placeholder
    } catch (e) {
      return 0;
    }
  }

  /// Get free memory in MB
  int _getFreeMemory() {
    try {
      // This is a simplified approach - in production you might want to use
      // platform-specific memory monitoring
      return 200; // Placeholder
    } catch (e) {
      return 0;
    }
  }

  /// Check memory thresholds and trigger cleanup if needed
  void _checkMemoryThresholds(int usedMemory) {
    if (usedMemory > _memoryCriticalThreshold) {
      _logPerformanceWarning('Critical memory usage: ${usedMemory}MB');
      _triggerMemoryCleanup();
    } else if (usedMemory > _memoryWarningThreshold) {
      _logPerformanceWarning('High memory usage: ${usedMemory}MB');
      _triggerLightCleanup();
    }
  }

  /// Trigger aggressive memory cleanup
  void _triggerMemoryCleanup() {
    _logPerformanceInfo('Triggering aggressive memory cleanup');
    
    // Clear video metrics for old videos
    _cleanupOldVideoMetrics();
    
    // Clear memory history
    if (_memoryHistory.length > 10) {
      _memoryHistory.removeRange(0, _memoryHistory.length - 10);
    }
    
    // Force garbage collection
    _forceGarbageCollection();
  }

  /// Trigger light memory cleanup
  void _triggerLightCleanup() {
    _logPerformanceInfo('Triggering light memory cleanup');
    
    // Clear old video metrics
    _cleanupOldVideoMetrics();
  }

  /// Clean up old video performance metrics
  void _cleanupOldVideoMetrics() {
    final cutoffTime = DateTime.now().subtract(const Duration(minutes: 30));
    _videoMetrics.removeWhere((key, value) => 
      value.lastAccessed.isBefore(cutoffTime));
  }

  /// Force garbage collection
  void _forceGarbageCollection() {
    // This is a simplified approach - in production you might want to use
    // platform-specific garbage collection triggers
    _logPerformanceInfo('Forcing garbage collection');
  }

  /// Track video loading performance
  void startVideoLoad(String videoId) {
    _videoLoadTimes[videoId] = DateTime.now();
    _logPerformanceInfo('Started loading video: $videoId');
  }

  /// Complete video loading performance tracking
  void completeVideoLoad(String videoId, {bool success = true}) {
    final startTime = _videoLoadTimes.remove(videoId);
    if (startTime == null) return;

    final loadDuration = DateTime.now().difference(startTime);
    
    _videoMetrics[videoId] = VideoPerformanceMetrics(
      videoId: videoId,
      loadDuration: loadDuration,
      success: success,
      lastAccessed: DateTime.now(),
    );

    _logPerformanceInfo('Video load completed: $videoId in ${loadDuration.inMilliseconds}ms');
    
    // Check for slow loading
    if (loadDuration > _videoLoadTimeout) {
      _logPerformanceWarning('Slow video load: $videoId took ${loadDuration.inSeconds}s');
    }
  }

  /// Track video playback performance
  void trackVideoPlayback(String videoId, PlaybackEvent event) {
    final metrics = _videoMetrics[videoId];
    if (metrics == null) return;

    metrics.lastAccessed = DateTime.now();
    
    switch (event) {
      case PlaybackEvent.play:
        metrics.playCount++;
        break;
      case PlaybackEvent.pause:
        metrics.pauseCount++;
        break;
      case PlaybackEvent.seek:
        metrics.seekCount++;
        break;
      case PlaybackEvent.error:
        metrics.errorCount++;
        break;
    }
  }

  /// Get performance summary
  PerformanceSummary getPerformanceSummary() {
    final totalVideos = _videoMetrics.length;
    final successfulLoads = _videoMetrics.values.where((m) => m.success).length;
    final averageLoadTime = _videoMetrics.values
        .where((m) => m.success)
        .map((m) => m.loadDuration.inMilliseconds)
        .fold(0, (a, b) => a + b) / 
        (successfulLoads > 0 ? successfulLoads : 1);

    final currentMemory = _memoryHistory.isNotEmpty 
        ? _memoryHistory.last.usedMemory 
        : 0;

    return PerformanceSummary(
      totalVideos: totalVideos,
      successfulLoads: successfulLoads,
      averageLoadTime: Duration(milliseconds: averageLoadTime.round()),
      currentMemoryUsage: currentMemory,
      memoryHistory: List.from(_memoryHistory),
    );
  }

  /// Log performance information
  void _logPerformanceInfo(String message) {
    if (kDebugMode) {
      print('📊 Performance: $message');
    }
  }

  /// Log performance warning
  void _logPerformanceWarning(String message) {
    if (kDebugMode) {
      print('⚠️ Performance Warning: $message');
    }
  }

  /// Log performance error
  void _logPerformanceError(String message) {
    if (kDebugMode) {
      print('❌ Performance Error: $message');
    }
  }

  /// Dispose resources
  void dispose() {
    _memoryTimer?.cancel();
    _memoryHistory.clear();
    _videoMetrics.clear();
    _videoLoadTimes.clear();
  }
}

/// Memory snapshot data class
class MemorySnapshot {
  final DateTime timestamp;
  final int usedMemory; // MB
  final int freeMemory; // MB

  MemorySnapshot({
    required this.timestamp,
    required this.usedMemory,
    required this.freeMemory,
  });
}

/// Video performance metrics
class VideoPerformanceMetrics {
  final String videoId;
  final Duration loadDuration;
  final bool success;
  DateTime lastAccessed;
  int playCount = 0;
  int pauseCount = 0;
  int seekCount = 0;
  int errorCount = 0;

  VideoPerformanceMetrics({
    required this.videoId,
    required this.loadDuration,
    required this.success,
    required this.lastAccessed,
  });
}

/// Playback events
enum PlaybackEvent {
  play,
  pause,
  seek,
  error,
}

/// Performance summary
class PerformanceSummary {
  final int totalVideos;
  final int successfulLoads;
  final Duration averageLoadTime;
  final int currentMemoryUsage;
  final List<MemorySnapshot> memoryHistory;

  PerformanceSummary({
    required this.totalVideos,
    required this.successfulLoads,
    required this.averageLoadTime,
    required this.currentMemoryUsage,
    required this.memoryHistory,
  });

  double get successRate => totalVideos > 0 ? successfulLoads / totalVideos : 0.0;
  bool get isMemoryHealthy => currentMemoryUsage < 200;
}
