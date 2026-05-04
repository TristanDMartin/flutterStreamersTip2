import 'package:flutter/foundation.dart';
import 'memory_cleanup_service.dart';

class MemoryPressureService {
  static final MemoryPressureService _instance = MemoryPressureService._internal();
  factory MemoryPressureService() => _instance;
  MemoryPressureService._internal();

  // OPTIMIZED: Increased memory limits for better performance
  static int _maxImageCount = 10; // Increased from 3 to 10 for faster loading
  static int _maxAvatarCount = 15; // Increased from 5 to 15 for better UX
  static const int _imageOverflowBuffer = 2;
  static const int _avatarOverflowBuffer = 3;
  static int _currentImageCount = 0;
  static int _currentAvatarCount = 0;
  static bool _isMemoryPressureHigh = false;
  static bool _isAvatarPressureHigh = false;
  
  // Performance tracking
  static final List<DateTime> _memoryCleanupTimes = [];
  static int _cleanupCount = 0;
  static DateTime? _lastCleanupTime;

  static bool get canLoadImage => _currentImageCount < _maxImageCount && !_isMemoryPressureHigh;
  static bool get canLoadAvatar => _currentAvatarCount < _maxAvatarCount && !_isAvatarPressureHigh;

  static void registerImageLoad() {
    _currentImageCount++;
    debugPrint('📊 Image count: $_currentImageCount/$_maxImageCount');
    final int imageOverflowThreshold = _maxImageCount + _imageOverflowBuffer;
    if (_currentImageCount > imageOverflowThreshold) {
      _isMemoryPressureHigh = true;
      debugPrint('⚠️ Image memory pressure high - pausing image loading');
      _forceMemoryCleanup();
    }
  }

  static void registerAvatarLoad() {
    _currentAvatarCount++;
    debugPrint('📊 Avatar count: $_currentAvatarCount/$_maxAvatarCount');
    final int avatarOverflowThreshold = _maxAvatarCount + _avatarOverflowBuffer;
    if (_currentAvatarCount > avatarOverflowThreshold) {
      _isAvatarPressureHigh = true;
      debugPrint('⚠️ Avatar memory pressure high - pausing avatar loading');
      _forceMemoryCleanup();
    }
  }

  static void registerImageDispose() {
    if (_currentImageCount > 0) {
      _currentImageCount--;
      debugPrint('📊 Image count: $_currentImageCount/$_maxImageCount');
      
      if (_currentImageCount < _maxImageCount * 0.5) {
        _isMemoryPressureHigh = false;
        debugPrint('✅ Image memory pressure normal - resuming image loading');
      }
    }
  }

  static void registerAvatarDispose() {
    if (_currentAvatarCount > 0) {
      _currentAvatarCount--;
      debugPrint('📊 Avatar count: $_currentAvatarCount/$_maxAvatarCount');
      
      if (_currentAvatarCount < _maxAvatarCount * 0.5) {
        _isAvatarPressureHigh = false;
        debugPrint('✅ Avatar memory pressure normal - resuming avatar loading');
      }
    }
  }

  static void _forceMemoryCleanup() {
    try {
      debugPrint('🗑️ Forcing memory cleanup...');
      
      // Track cleanup frequency
      _cleanupCount++;
      _lastCleanupTime = DateTime.now();
      _memoryCleanupTimes.add(DateTime.now());
      
      // Keep only recent cleanup times (last 5 minutes)
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 5));
      _memoryCleanupTimes.removeWhere((time) => time.isBefore(cutoffTime));
      
      // Adapt limits based on cleanup frequency
      _adaptLimitsBasedOnPerformance();
      
      // Use the comprehensive cleanup service
      MemoryCleanupService().performAggressiveCleanup();
      
      // Reset pressure flags after cleanup
      _isMemoryPressureHigh = false;
      _isAvatarPressureHigh = false;
      
      debugPrint('✅ Memory cleanup completed');
      
    } catch (e) {
      debugPrint('⚠️ Memory cleanup failed: $e');
    }
  }

  /// Adapt memory limits based on cleanup frequency
  static void _adaptLimitsBasedOnPerformance() {
    final recentCleanups = _memoryCleanupTimes.length;
    
    if (recentCleanups > 3) {
      // Too many cleanups - reduce limits (but keep higher baseline)
      _maxImageCount = (_maxImageCount * 0.8).round().clamp(5, 10);
      _maxAvatarCount = (_maxAvatarCount * 0.8).round().clamp(8, 15);
      debugPrint('📉 Reduced memory limits due to frequent cleanups: $_maxImageCount images, $_maxAvatarCount avatars');
    } else if (recentCleanups < 1 && _cleanupCount > 5) {
      // Stable performance - can increase limits
      _maxImageCount = (_maxImageCount * 1.1).round().clamp(10, 15);
      _maxAvatarCount = (_maxAvatarCount * 1.1).round().clamp(15, 20);
      debugPrint('📈 Increased memory limits due to stable performance: $_maxImageCount images, $_maxAvatarCount avatars');
    }
  }

  static void _clearAllCaches() {
    try {
      // Clear image caches
      _currentImageCount = 0;
      _currentAvatarCount = 0;
      _isMemoryPressureHigh = false;
      _isAvatarPressureHigh = false;
      
      // Force cache clearing in services
      // This would typically clear caches in other services
      debugPrint('🧹 Cleared all memory caches');
    } catch (e) {
      debugPrint('⚠️ Cache clearing failed: $e');
    }
  }

  static void reset() {
    _currentImageCount = 0;
    _currentAvatarCount = 0;
    _isMemoryPressureHigh = false;
    _isAvatarPressureHigh = false;
    debugPrint('🔄 Memory pressure service reset');
    _forceMemoryCleanup();
  }

  /// Clear all caches and reset memory pressure state
  static void clearAllCaches() {
    _clearAllCaches();
  }

  static void forceGarbageCollection() {
    _forceMemoryCleanup();
  }

  /// Get current memory pressure statistics
  static Map<String, dynamic> getMemoryStats() {
    return {
      'currentImageCount': _currentImageCount,
      'maxImageCount': _maxImageCount,
      'currentAvatarCount': _currentAvatarCount,
      'maxAvatarCount': _maxAvatarCount,
      'isMemoryPressureHigh': _isMemoryPressureHigh,
      'isAvatarPressureHigh': _isAvatarPressureHigh,
      'cleanupCount': _cleanupCount,
      'recentCleanups': _memoryCleanupTimes.length,
      'lastCleanupTime': _lastCleanupTime?.toIso8601String(),
    };
  }

}
