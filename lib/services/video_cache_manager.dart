import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';

class VideoCacheManager extends ChangeNotifier {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  static VideoCacheManager get shared => _instance;
  
  final Map<String, VideoPlayerController> _assetCache = {};
  final Set<String> _preloadingURLs = {};
  final int _maxCacheSize = 10; // Maximum number of cached items
  
  VideoCacheManager._internal() {
    // Setup memory warning observer (Flutter handles this automatically)
  }
  
  Future<VideoPlayerController?> getPlayerItem(String videoURL) async {
    // Check if we have a cached controller
    if (_assetCache.containsKey(videoURL)) {
      print('📦 Using cached asset for: $videoURL');
      return _assetCache[videoURL];
    }
    
    // Create new player controller
    return await createPlayerController(videoURL);
  }
  
  Future<VideoPlayerController?> createPlayerController(String videoURL) async {
    VideoPlayerController? controller;
    
    try {
      // Try to load video from assets first (for sample videos)
      if (videoURL.startsWith('assets/')) {
        controller = VideoPlayerController.asset(videoURL);
      } else if (videoURL.startsWith('http')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(videoURL));
      } else if (videoURL.startsWith('file://')) {
        controller = VideoPlayerController.file(File(videoURL.replaceFirst('file://', '')));
      } else {
        print('❌ Invalid video URL: $videoURL');
        return null;
      }
      
      // Initialize the controller
      await controller.initialize();
      
      // Cache the controller for future use
      await cacheController(controller, videoURL);
      
      print('✅ Created and cached controller for: $videoURL');
      return controller;
      
    } catch (error) {
      print('❌ Error creating player controller for $videoURL: $error');
      
      // Try fallback URLs for sample videos
      if (videoURL.contains('sample') || videoURL.contains('test')) {
        return await tryFallbackURLs(videoURL);
      }
      
      return null;
    }
  }
  
  Future<VideoPlayerController?> tryFallbackURLs(String originalURL) async {
    final fallbackURLs = [
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4'
    ];
    
    for (final fallbackURL in fallbackURLs) {
      try {
        final controller = VideoPlayerController.networkUrl(Uri.parse(fallbackURL));
        await controller.initialize();
        
        // Cache the fallback controller with original URL key
        await cacheController(controller, originalURL);
        
        print('✅ Used fallback URL for $originalURL: $fallbackURL');
        return controller;
        
      } catch (error) {
        print('⚠️ Fallback URL failed: $fallbackURL');
        continue;
      }
    }
    
    print('❌ All fallback URLs failed for: $originalURL');
    return null;
  }
  
  Future<void> cacheController(VideoPlayerController controller, String videoURL) async {
    // Add to cache
    _assetCache[videoURL] = controller;
    
    // Manage cache size
    if (_assetCache.length > _maxCacheSize) {
      evictOldestItems();
    }
    
    print('📦 Cached controller for: $videoURL (Total: ${_assetCache.length})');
    notifyListeners();
  }
  
  void evictOldestItems() {
    // Simple LRU: remove first item (oldest)
    if (_assetCache.isNotEmpty) {
      final firstKey = _assetCache.keys.first;
      final controller = _assetCache.remove(firstKey);
      controller?.dispose();
      print('🗑️ Evicted cached controller: $firstKey');
    }
  }
  
  void clearCacheOnMemoryWarning() {
    for (var controller in _assetCache.values) {
      controller.dispose();
    }
    _assetCache.clear();
    print('🧹 Cleared video cache due to memory warning');
    notifyListeners();
  }
  
  void preloadVideo(String videoURL) {
    // Check if already preloading
    if (isPreloading(videoURL)) return;
    
    // Mark as preloading
    _preloadingURLs.add(videoURL);
    
    // Create controller in background
    createPlayerController(videoURL).then((controller) {
      // Remove from preloading set when done
      _preloadingURLs.remove(videoURL);
    });
  }
  
  bool isPreloading(String videoURL) {
    return _preloadingURLs.contains(videoURL);
  }
  
  void clearCache() {
    for (var controller in _assetCache.values) {
      controller.dispose();
    }
    _assetCache.clear();
    print('🧹 Manually cleared video cache');
    notifyListeners();
  }
  
  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
