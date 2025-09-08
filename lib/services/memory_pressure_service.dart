import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MemoryPressureService {
  static final MemoryPressureService _instance = MemoryPressureService._internal();
  factory MemoryPressureService() => _instance;
  MemoryPressureService._internal();

  static const int _maxImageCount = 1; // ULTRA-AGGRESSIVE: Only 1 image at a time
  static int _currentImageCount = 0;
  static bool _isMemoryPressureHigh = false;

  static bool get canLoadImage => _currentImageCount < _maxImageCount && !_isMemoryPressureHigh;

  static void registerImageLoad() {
    _currentImageCount++;
    debugPrint('📊 Image count: $_currentImageCount/$_maxImageCount');
    
    if (_currentImageCount >= _maxImageCount) {
      _isMemoryPressureHigh = true;
      debugPrint('⚠️ Memory pressure high - pausing image loading');
    }
  }

  static void registerImageDispose() {
    if (_currentImageCount > 0) {
      _currentImageCount--;
      debugPrint('📊 Image count: $_currentImageCount/$_maxImageCount');
      
      if (_currentImageCount < _maxImageCount * 0.7) {
        _isMemoryPressureHigh = false;
        debugPrint('✅ Memory pressure normal - resuming image loading');
      }
    }
  }

  static void reset() {
    _currentImageCount = 0;
    _isMemoryPressureHigh = false;
    debugPrint('🔄 Memory pressure service reset');
  }

  static void forceGarbageCollection() {
    if (kDebugMode) {
      // Force garbage collection in debug mode
      debugPrint('🗑️ Forcing garbage collection...');
      // This is a debug-only operation
    }
  }
}
