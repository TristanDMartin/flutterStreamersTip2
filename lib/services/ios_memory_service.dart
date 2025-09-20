import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IOSMemoryService {
  static final IOSMemoryService _instance = IOSMemoryService._internal();
  factory IOSMemoryService() => _instance;
  IOSMemoryService._internal();

  // More conservative memory management for iOS
  static const int _maxImageCount = 2; // Allow 2 images for better UX on iOS
  static const int _maxAvatarCount = 3; // Allow 3 avatars for better UX on iOS
  static int _currentImageCount = 0;
  static int _currentAvatarCount = 0;
  static bool _isMemoryPressureHigh = false;
  static bool _isAvatarPressureHigh = false;
  static bool _isIOS = false;

  static void initialize() {
    _isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    debugPrint('🍎 IOSMemoryService initialized - iOS: $_isIOS');
  }

  static bool get canLoadImage {
    if (_isIOS) {
      return _currentImageCount < _maxImageCount && !_isMemoryPressureHigh;
    }
    // Fallback to ultra-aggressive for Android
    return _currentImageCount < 1 && !_isMemoryPressureHigh;
  }

  static bool get canLoadAvatar {
    if (_isIOS) {
      return _currentAvatarCount < _maxAvatarCount && !_isAvatarPressureHigh;
    }
    // Fallback to ultra-aggressive for Android
    return _currentAvatarCount < 2 && !_isAvatarPressureHigh;
  }

  static void registerImageLoad() {
    _currentImageCount++;
    debugPrint('📊 Image count: $_currentImageCount/${_isIOS ? _maxImageCount : 1}');
    
    if (_currentImageCount >= (_isIOS ? _maxImageCount : 1)) {
      _isMemoryPressureHigh = true;
      debugPrint('⚠️ Image memory pressure high - pausing image loading');
      _forceMemoryCleanup();
    }
  }

  static void registerAvatarLoad() {
    _currentAvatarCount++;
    debugPrint('📊 Avatar count: $_currentAvatarCount/${_isIOS ? _maxAvatarCount : 2}');
    
    if (_currentAvatarCount >= (_isIOS ? _maxAvatarCount : 2)) {
      _isAvatarPressureHigh = true;
      debugPrint('⚠️ Avatar memory pressure high - pausing avatar loading');
      _forceMemoryCleanup();
    }
  }

  static void registerImageDispose() {
    if (_currentImageCount > 0) {
      _currentImageCount--;
      debugPrint('📊 Image count: $_currentImageCount/${_isIOS ? _maxImageCount : 1}');
      
      if (_currentImageCount < (_isIOS ? _maxImageCount * 0.5 : 0.5)) {
        _isMemoryPressureHigh = false;
        debugPrint('✅ Image memory pressure normal - resuming image loading');
      }
    }
  }

  static void registerAvatarDispose() {
    if (_currentAvatarCount > 0) {
      _currentAvatarCount--;
      debugPrint('📊 Avatar count: $_currentAvatarCount/${_isIOS ? _maxAvatarCount : 2}');
      
      if (_currentAvatarCount < (_isIOS ? _maxAvatarCount * 0.5 : 1)) {
        _isAvatarPressureHigh = false;
        debugPrint('✅ Avatar memory pressure normal - resuming avatar loading');
      }
    }
  }

  static void _forceMemoryCleanup() {
    try {
      debugPrint('🗑️ Forcing memory cleanup...');
      
      if (_isIOS) {
        // More gentle cleanup for iOS
        _clearCachesGently();
      } else {
        // Aggressive cleanup for Android
        _clearCachesAggressively();
      }
      
    } catch (e) {
      debugPrint('⚠️ Memory cleanup failed: $e');
    }
  }

  static void _clearCachesGently() {
    try {
      // Gentle cleanup for iOS
      debugPrint('🧹 Gentle cache cleanup for iOS...');
      
      // Clear some caches but not all
      if (_currentImageCount > 1) {
        _currentImageCount = 1;
      }
      if (_currentAvatarCount > 2) {
        _currentAvatarCount = 2;
      }
      
      _isMemoryPressureHigh = false;
      _isAvatarPressureHigh = false;
      
    } catch (e) {
      debugPrint('⚠️ Gentle cleanup failed: $e');
    }
  }

  static void _clearCachesAggressively() {
    try {
      // Aggressive cleanup for Android
      debugPrint('🧹 Aggressive cache cleanup for Android...');
      
      _currentImageCount = 0;
      _currentAvatarCount = 0;
      _isMemoryPressureHigh = false;
      _isAvatarPressureHigh = false;
      
      // Force garbage collection
      SystemChannels.platform.invokeMethod('System.gc');
      
    } catch (e) {
      debugPrint('⚠️ Aggressive cleanup failed: $e');
    }
  }

  static void reset() {
    _currentImageCount = 0;
    _currentAvatarCount = 0;
    _isMemoryPressureHigh = false;
    _isAvatarPressureHigh = false;
    debugPrint('🔄 Memory service reset');
    _forceMemoryCleanup();
  }

  static Map<String, dynamic> getMemoryStats() {
    return {
      'platform': _isIOS ? 'iOS' : 'Android',
      'imageCount': _currentImageCount,
      'avatarCount': _currentAvatarCount,
      'imagePressureHigh': _isMemoryPressureHigh,
      'avatarPressureHigh': _isAvatarPressureHigh,
      'canLoadImage': canLoadImage,
      'canLoadAvatar': canLoadAvatar,
      'maxImages': _isIOS ? _maxImageCount : 1,
      'maxAvatars': _isIOS ? _maxAvatarCount : 2,
    };
  }
}
