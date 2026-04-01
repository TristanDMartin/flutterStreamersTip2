import 'dart:io';
import 'package:video_player/video_player.dart';
import '../models/home_video.dart';
import 'video_controller_registry.dart';
import 'production_logging_service.dart';
import 'global_playback_manager.dart';
import 'video_upload_service.dart';

/// Unified Video Service - Consolidates all video-related operations
///
/// Merges functionality from:
/// - VideoUploadService
/// - VideoProcessingService
/// - VideoPerformanceService
/// - VideoPreloaderService
/// - VideoThumbnailService
class UnifiedVideoService {
  static final UnifiedVideoService _instance = UnifiedVideoService._internal();
  factory UnifiedVideoService() => _instance;
  UnifiedVideoService._internal();

  final VideoControllerRegistry _controllerRegistry = VideoControllerRegistry();
  final ProductionLoggingService _logger = ProductionLoggingService();
  final VideoUploadService _uploadService = VideoUploadService();

  Future<Map<String, dynamic>> uploadVideo({
    required File videoFile,
    required String userId,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      _logger.info('Starting video upload process', tag: 'UnifiedVideoService');
      final result = await _uploadService.uploadVideo(
        videoFile: videoFile,
        caption: caption,
        hashtags: hashtags,
        privacy: privacy,
        allowComments: allowComments,
        additionalMetadata: additionalMetadata,
      );
      if (!result.success) {
        throw Exception(result.error ?? 'Upload failed');
      }
      _logger.info('Video upload completed successfully',
          tag: 'UnifiedVideoService');
      return {
        'videoUrl': result.videoUrl,
        'thumbnailUrl': result.thumbnailUrl,
        'success': true,
      };
    } catch (e) {
      _logger.error('Video upload failed',
          tag: 'UnifiedVideoService', error: e);
      rethrow;
    }
  }

  // Video controller management
  Future<VideoPlayerController?> getController(
      String videoId, String videoUrl) async {
    return _controllerRegistry.getController(videoId);
  }

  void releaseController(String videoId) {
    _controllerRegistry.dispose(videoId);
  }

  void pauseAllVideos({String? reason}) {
    // 🔊 AUDIO FIX: Use GlobalPlaybackManager for pausing all videos
    GlobalPlaybackManager.instance
        .block(reason: reason ?? 'unified_video_service_pause');
  }

  // Video preloading
  Future<void> preloadVideos(List<HomeVideo> videos, int currentIndex) async {
    try {
      _logger.info('Preloading videos starting from index $currentIndex',
          tag: 'UnifiedVideoService');

      // Preload current, previous, and next videos
      final startIndex = (currentIndex - 1).clamp(0, videos.length - 1);
      final endIndex = (currentIndex + 1).clamp(0, videos.length - 1);

      for (int i = startIndex; i <= endIndex; i++) {
        if (i < videos.length) {
          final video = videos[i];
          _controllerRegistry.getController(video.id);
        }
      }

      _logger.info('Video preloading completed', tag: 'UnifiedVideoService');
    } catch (e) {
      _logger.error('Video preloading failed',
          tag: 'UnifiedVideoService', error: e);
    }
  }

  // Video performance tracking
  void trackVideoLoad(String videoId, Duration loadTime) {
    _logger.info('Video load tracked: $videoId in ${loadTime.inMilliseconds}ms',
        tag: 'UnifiedVideoService');
  }

  void trackVideoPlay(String videoId) {
    _logger.info('Video play tracked: $videoId', tag: 'UnifiedVideoService');
  }

  void trackVideoPause(String videoId) {
    _logger.info('Video pause tracked: $videoId', tag: 'UnifiedVideoService');
  }

  // Cleanup and disposal
  void dispose() {
    _controllerRegistry.cleanupAll();
    _logger.info('UnifiedVideoService disposed', tag: 'UnifiedVideoService');
  }
}
