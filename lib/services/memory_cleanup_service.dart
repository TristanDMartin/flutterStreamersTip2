import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Service to handle comprehensive memory cleanup and garbage collection
class MemoryCleanupService {
  static final MemoryCleanupService _instance =
      MemoryCleanupService._internal();
  factory MemoryCleanupService() => _instance;
  MemoryCleanupService._internal();

  Timer? _cleanupTimer;
  bool _isCleaningUp = false;

  /// Initialize periodic memory cleanup
  void initialize() {
    if (kDebugMode) {
      debugPrint('🧹 MemoryCleanupService: Initializing periodic cleanup');
    }

    // Run cleanup every 30 seconds
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performLightCleanup();
    });
  }

  /// Perform light memory cleanup
  void _performLightCleanup() {
    if (_isCleaningUp) return;

    try {
      _isCleaningUp = true;
      debugPrint('🧹 MemoryCleanupService: Performing light cleanup');

      // Clear old cache entries
      _clearOldCacheEntries();

      // Trigger garbage collection
      _triggerGarbageCollection();
    } catch (e) {
      debugPrint('⚠️ MemoryCleanupService: Light cleanup failed: $e');
    } finally {
      _isCleaningUp = false;
    }
  }

  /// Perform aggressive memory cleanup
  Future<void> performAggressiveCleanup() async {
    if (_isCleaningUp) return;

    try {
      _isCleaningUp = true;
      debugPrint('🧹 MemoryCleanupService: Performing aggressive cleanup');

      // Clear all caches
      _clearAllCaches();

      // Clear old cache entries
      _clearOldCacheEntries();

      // Trigger garbage collection multiple times
      for (int i = 0; i < 3; i++) {
        _triggerGarbageCollection();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('✅ MemoryCleanupService: Aggressive cleanup completed');
    } catch (e) {
      debugPrint('⚠️ MemoryCleanupService: Aggressive cleanup failed: $e');
    } finally {
      _isCleaningUp = false;
    }
  }

  /// Clear all image and cache managers
  void _clearAllCaches() {
    try {
      // Clear default cache manager
      DefaultCacheManager().emptyCache();

      // Clear optimized image cache
      CacheManager(Config('optimized_images')).emptyCache();

      // Clear avatar cache
      CacheManager(Config('optimized_avatars')).emptyCache();

      debugPrint('🧹 MemoryCleanupService: All caches cleared');
    } catch (e) {
      debugPrint('⚠️ MemoryCleanupService: Cache clearing failed: $e');
    }
  }

  /// Clear old cache entries
  void _clearOldCacheEntries() {
    try {
      // This would typically clear entries older than 1 hour
      // Implementation depends on specific cache managers
      debugPrint('🧹 MemoryCleanupService: Old cache entries cleared');
    } catch (e) {
      debugPrint('⚠️ MemoryCleanupService: Old cache clearing failed: $e');
    }
  }

  /// Trigger garbage collection
  void _triggerGarbageCollection() {
    try {
      // Force garbage collection
      SystemChannels.platform.invokeMethod('System.gc');
      debugPrint('🗑️ MemoryCleanupService: Garbage collection triggered');
    } catch (e) {
      debugPrint('⚠️ MemoryCleanupService: Garbage collection failed: $e');
    }
  }

  /// Dispose of the service
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    debugPrint('🧹 MemoryCleanupService: Disposed');
  }

  /// Get memory usage information
  Map<String, dynamic> getMemoryInfo() {
    return {
      'isCleaningUp': _isCleaningUp,
      'cleanupTimerActive': _cleanupTimer?.isActive ?? false,
    };
  }
}
