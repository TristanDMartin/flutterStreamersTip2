import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';

class ImagePreloadService {
  static final ImagePreloadService _instance = ImagePreloadService._internal();
  factory ImagePreloadService() => _instance;
  ImagePreloadService._internal();

  static final CacheManager _cacheManager = CacheManager(
    Config(
      'preload_images',
      stalePeriod: const Duration(hours: 24),
      maxNrOfCacheObjects: 20,
      repo: JsonCacheInfoRepository(databaseName: 'preload_images'),
      fileService: HttpFileService(),
    ),
  );

  static final Set<String> _preloadedUrls = <String>{};
  static final Set<String> _preloadingUrls = <String>{};

  /// Preload critical images for better UX
  static Future<void> preloadCriticalImages() async {
    const criticalImages = [
      'https://via.placeholder.com/60x60/9248D2/FFFFFF?text=Gaming',
      'https://via.placeholder.com/60x60/1670DE/FFFFFF?text=Streaming',
      'https://via.placeholder.com/60x60/4CAF50/FFFFFF?text=Esports',
      'https://via.placeholder.com/300x200/9248D2/FFFFFF?text=Gaming',
      'https://via.placeholder.com/300x200/1670DE/FFFFFF?text=Streaming',
      'https://via.placeholder.com/300x200/4CAF50/FFFFFF?text=Esports',
    ];

    for (final url in criticalImages) {
      if (!_preloadedUrls.contains(url) && !_preloadingUrls.contains(url)) {
        _preloadingUrls.add(url);
        _preloadImage(url);
      }
    }
  }

  /// Preload a specific image
  static Future<void> preloadImage(String url) async {
    if (_preloadedUrls.contains(url) || _preloadingUrls.contains(url)) {
      return;
    }

    _preloadingUrls.add(url);
    await _preloadImage(url);
  }

  /// Internal method to preload an image
  static Future<void> _preloadImage(String url) async {
    try {
      await _cacheManager.getSingleFile(url);
      _preloadedUrls.add(url);
      _preloadingUrls.remove(url);
      debugPrint('✅ Preloaded image: $url');
    } catch (e) {
      _preloadingUrls.remove(url);
      debugPrint('⚠️ Failed to preload image: $url - $e');
    }
  }

  /// Check if an image is preloaded
  static bool isPreloaded(String url) {
    return _preloadedUrls.contains(url);
  }

  /// Get preload status
  static Map<String, dynamic> getPreloadStatus() {
    return {
      'preloadedCount': _preloadedUrls.length,
      'preloadingCount': _preloadingUrls.length,
      'preloadedUrls': _preloadedUrls.toList(),
      'preloadingUrls': _preloadingUrls.toList(),
    };
  }

  /// Clear preloaded images
  static Future<void> clearPreloadedImages() async {
    _preloadedUrls.clear();
    _preloadingUrls.clear();
    await _cacheManager.emptyCache();
    debugPrint('🧹 Cleared all preloaded images');
  }

  /// Get cache manager for optimized image loading
  static CacheManager get cacheManager => _cacheManager;
}
