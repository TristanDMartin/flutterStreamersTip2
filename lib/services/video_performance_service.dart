import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Service for optimizing video performance like TikTok
class VideoPerformanceService {
  static final VideoPerformanceService _instance = VideoPerformanceService._internal();
  factory VideoPerformanceService() => _instance;
  VideoPerformanceService._internal();

  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, bool> _videoPreloaded = {};
  final Map<String, Widget> _thumbnailCache = {};
  
  // CRITICAL: Disable preloading to prevent buffer overflow
  static const int _preloadCount = 0; // Disabled to prevent buffer overflow
  
  /// Preload video for instant playback - DISABLED to prevent buffer overflow
  Future<void> preloadVideo(String videoUrl, {String? thumbnailUrl}) async {
    // CRITICAL: Disabled to prevent ImageReader_JNI buffer overflow
    debugPrint('⚠️ Video preloading disabled to prevent buffer overflow');
    return;
    
    // DISABLED CODE:
    // if (_videoPreloaded[videoUrl] == true) return;
    // try {
    //   final controller = VideoPlayerController.networkUrl(
    //     Uri.parse(videoUrl),
    //     videoPlayerOptions: VideoPlayerOptions(
    //       mixWithOthers: true,
    //       allowBackgroundPlayback: false,
    //     ),
    //   );
    //   await controller.initialize();
    //   await controller.setLooping(true);
    //   await controller.setVolume(0);
    //   _videoControllers[videoUrl] = controller;
    //   _videoPreloaded[videoUrl] = true;
    //   Timer(const Duration(seconds: 15), () {
    //     disposeVideo(videoUrl);
    //   });
    // } catch (e) {
    //   debugPrint('Error preloading video: $e');
    // }
  }

  /// Prewarm video controller for instant play (TikTok style)
  Future<VideoPlayerController> prewarm(String id, String url) async {
    if (_videoControllers[url] != null) {
      return _videoControllers[url]!;
    }
    
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );
    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(0); // Start muted for autoplay compliance
    _videoControllers[url] = controller;
    _videoPreloaded[url] = true;
    return controller;
  }

  /// Get ready controller (warm start)
  VideoPlayerController? getReady(String url) => _videoControllers[url];
  
  
  /// Get preloaded video controller
  VideoPlayerController? getVideoController(String videoUrl) {
    return _videoControllers[videoUrl];
  }
  
  /// Alias for getVideoController
  VideoPlayerController? getController(String videoUrl) {
    return getVideoController(videoUrl);
  }
  
  /// Check if video is preloaded
  bool isVideoPreloaded(String videoUrl) {
    return _videoPreloaded[videoUrl] == true;
  }
  
  /// Preload multiple videos for smooth scrolling
  Future<void> preloadVideoBatch(List<String> videoUrls, {List<String>? thumbnailUrls}) async {
    final futures = <Future>[];
    
    for (int i = 0; i < videoUrls.length && i < _preloadCount; i++) {
      final videoUrl = videoUrls[i];
      final thumbnailUrl = thumbnailUrls != null && i < thumbnailUrls.length 
          ? thumbnailUrls[i] 
          : null;
      
      futures.add(preloadVideo(videoUrl, thumbnailUrl: thumbnailUrl));
    }
    
    await Future.wait(futures);
  }
  
  /// Dispose video controller
  void disposeVideo(String videoUrl) {
    final controller = _videoControllers[videoUrl];
    if (controller != null) {
      controller.dispose();
      _videoControllers.remove(videoUrl);
      _videoPreloaded[videoUrl] = false;
    }
  }
  
  /// Alias for disposeVideo
  void disposeController(String videoUrl) {
    disposeVideo(videoUrl);
  }
  
  /// Dispose all videos
  void disposeAll() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _videoPreloaded.clear();
    _thumbnailCache.clear();
  }
  
  /// Get optimized video player widget
  Widget getOptimizedVideoPlayer({
    required String videoUrl,
    required double width,
    required double height,
    bool autoPlay = true,
    bool looping = true,
    Widget? placeholder,
  }) {
    final controller = getVideoController(videoUrl);
    
    if (controller == null) {
      return placeholder ?? Container(
        width: width,
        height: height,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
  
  /// Get cached thumbnail widget - DISABLED to prevent buffer overflow
  Widget getCachedThumbnail({
    required String thumbnailUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    // CRITICAL: Disabled to prevent ImageReader_JNI buffer overflow
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.video_library, color: Colors.grey),
      ),
    );
    
    // DISABLED CODE:
    // return CachedNetworkImage(
    //   imageUrl: thumbnailUrl,
    //   width: width,
    //   height: height,
    //   fit: fit,
    //   placeholder: (context, url) => Container(
    //     width: width,
    //     height: height,
    //     color: Colors.grey[300],
    //     child: const Center(
    //       child: CircularProgressIndicator(strokeWidth: 2),
    //     ),
    //   ),
    //   errorWidget: (context, url, error) => Container(
    //     width: width,
    //     height: height,
    //     color: Colors.grey[300],
    //     child: const Icon(Icons.error),
    //   ),
    //   memCacheWidth: width.toInt(),
    //   memCacheHeight: height.toInt(),
    // );
  }
}

/// Navigation service for global context access
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}