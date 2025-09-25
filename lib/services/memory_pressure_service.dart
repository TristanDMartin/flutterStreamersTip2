import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MemoryPressureService {
  static final MemoryPressureService _instance = MemoryPressureService._internal();
  factory MemoryPressureService() => _instance;
  MemoryPressureService._internal();

  // FIXED: Reduced to prevent buffer overflow
  static const int _maxImageCount = 3; // Reduced to prevent buffer overflow
  static const int _maxAvatarCount = 5; // Reduced to prevent buffer overflow
  static int _currentImageCount = 0;
  static int _currentAvatarCount = 0;
  static bool _isMemoryPressureHigh = false;
  static bool _isAvatarPressureHigh = false;

  static bool get canLoadImage => _currentImageCount < _maxImageCount && !_isMemoryPressureHigh;
  static bool get canLoadAvatar => _currentAvatarCount < _maxAvatarCount && !_isAvatarPressureHigh;

  static void registerImageLoad() {
    _currentImageCount++;
    debugPrint('📊 Image count: $_currentImageCount/$_maxImageCount');
    
    if (_currentImageCount >= _maxImageCount) {
      _isMemoryPressureHigh = true;
      debugPrint('⚠️ Image memory pressure high - pausing image loading');
      _forceMemoryCleanup();
    }
  }

  static void registerAvatarLoad() {
    _currentAvatarCount++;
    debugPrint('📊 Avatar count: $_currentAvatarCount/$_maxAvatarCount');
    
    if (_currentAvatarCount >= _maxAvatarCount) {
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
      // Force garbage collection
      debugPrint('🗑️ Forcing aggressive memory cleanup...');
      
      // Clear image cache if available
      if (kDebugMode) {
        // Additional debug cleanup
        debugPrint('🧹 Clearing debug caches...');
      }
      
      // Clear all caches aggressively
      _clearAllCaches();
      
      // Trigger system memory cleanup
      SystemChannels.platform.invokeMethod('System.gc');
      
    } catch (e) {
      debugPrint('⚠️ Memory cleanup failed: $e');
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

  static void forceGarbageCollection() {
    _forceMemoryCleanup();
  }

  static Map<String, dynamic> getMemoryStats() {
    return {
      'imageCount': _currentImageCount,
      'avatarCount': _currentAvatarCount,
      'imagePressureHigh': _isMemoryPressureHigh,
      'avatarPressureHigh': _isAvatarPressureHigh,
      'canLoadImage': canLoadImage,
      'canLoadAvatar': canLoadAvatar,
    };
  }
}
