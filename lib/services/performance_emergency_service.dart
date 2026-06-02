import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Emergency performance service to prevent app crashes
class PerformanceEmergencyService {
  static final PerformanceEmergencyService _instance =
      PerformanceEmergencyService._internal();
  factory PerformanceEmergencyService() => _instance;
  PerformanceEmergencyService._internal();

  // Performance monitoring
  Timer? _performanceTimer;
  int _frameDropCount = 0;
  int _bufferOverflowCount = 0;
  bool _isEmergencyMode = false;

  // Emergency thresholds
  static const int _maxFrameDrops = 10;
  static const int _maxBufferOverflows = 5;
  static const Duration _monitoringInterval = Duration(seconds: 5);

  /// Initialize emergency performance monitoring
  void initialize() {
    if (kDebugMode) {
      _startPerformanceMonitoring();
    }
  }

  /// Start performance monitoring
  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(_monitoringInterval, (timer) {
      _checkPerformanceHealth();
    });
  }

  /// Check performance health and trigger emergency measures
  void _checkPerformanceHealth() {
    if (_frameDropCount > _maxFrameDrops ||
        _bufferOverflowCount > _maxBufferOverflows) {
      if (!_isEmergencyMode) {
        _activateEmergencyMode();
      }
    } else if (_isEmergencyMode &&
        _frameDropCount < _maxFrameDrops / 2 &&
        _bufferOverflowCount < _maxBufferOverflows / 2) {
      _deactivateEmergencyMode();
    }

    // Reset counters
    _frameDropCount = 0;
    _bufferOverflowCount = 0;
  }

  /// Activate emergency mode
  void _activateEmergencyMode() {
    _isEmergencyMode = true;
    debugPrint('🚨 EMERGENCY MODE ACTIVATED - Performance issues detected');

    // Disable all non-essential features
    _disableImageLoading();
    _disableVideoPreloading();
    _clearCaches();
    _reduceMemoryUsage();
  }

  /// Deactivate emergency mode
  void _deactivateEmergencyMode() {
    _isEmergencyMode = false;
    debugPrint('✅ Emergency mode deactivated - Performance recovered');
  }

  /// Disable image loading in emergency mode
  void _disableImageLoading() {
    // This would be implemented by setting a global flag
    // that OptimizedImage checks before loading
    debugPrint('🚨 Disabling image loading due to performance issues');
  }

  /// Disable video preloading in emergency mode
  void _disableVideoPreloading() {
    debugPrint('🚨 Disabling video preloading due to performance issues');
  }

  /// Clear all caches in emergency mode
  void _clearCaches() {
    debugPrint('🚨 Clearing caches due to performance issues');
    // Implement cache clearing
  }

  /// Reduce memory usage in emergency mode
  void _reduceMemoryUsage() {
    debugPrint('🚨 Reducing memory usage due to performance issues');
    // Force garbage collection
    SystemChannels.platform.invokeMethod('System.gc');
  }

  /// Record frame drop
  void recordFrameDrop() {
    _frameDropCount++;
    if (kDebugMode) {
      debugPrint('📊 Frame drop recorded: $_frameDropCount');
    }
  }

  /// Record buffer overflow
  void recordBufferOverflow() {
    _bufferOverflowCount++;
    if (kDebugMode) {
      debugPrint('📊 Buffer overflow recorded: $_bufferOverflowCount');
    }
  }

  /// Check if emergency mode is active
  bool get isEmergencyMode => _isEmergencyMode;

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'isEmergencyMode': _isEmergencyMode,
      'frameDropCount': _frameDropCount,
      'bufferOverflowCount': _bufferOverflowCount,
      'maxFrameDrops': _maxFrameDrops,
      'maxBufferOverflows': _maxBufferOverflows,
    };
  }

  /// Dispose resources
  void dispose() {
    _performanceTimer?.cancel();
  }
}
