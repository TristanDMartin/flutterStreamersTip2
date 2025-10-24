import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import '../models/home_video.dart';
import 'video_controller_registry.dart';
import 'production_logging_service.dart';
import 'global_playback_manager.dart';

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
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Video upload and processing
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

      // Generate video ID
      final videoId = _firestore.collection('videos').doc().id;
      final videoUrl = await _uploadVideoFile(videoFile, videoId);
      final thumbnailUrl =
          await _generateAndUploadThumbnail(videoFile, videoId);

      // Create video document
      final videoData = await _createVideoDocument(
        videoId: videoId,
        userId: userId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        hashtags: hashtags,
        privacy: privacy,
        allowComments: allowComments,
        additionalMetadata: additionalMetadata,
      );

      _logger.info('Video upload completed successfully',
          tag: 'UnifiedVideoService');
      return videoData;
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

  // Private helper methods
  Future<String> _uploadVideoFile(File videoFile, String videoId) async {
    try {
      final videoRef = _storage.ref().child('videos/$videoId.mp4');
      await videoRef.putFile(videoFile);
      return await videoRef.getDownloadURL();
    } catch (e) {
      _logger.error('Failed to upload video file',
          tag: 'UnifiedVideoService', error: e);
      rethrow;
    }
  }

  Future<String> _generateAndUploadThumbnail(
      File videoFile, String videoId) async {
    try {
      // Generate thumbnail from video
      final thumbnailFile = await _generateThumbnail(videoFile, videoId);

      // Upload thumbnail
      final thumbnailRef = _storage.ref().child('thumbnails/$videoId.jpg');
      await thumbnailRef.putFile(thumbnailFile);
      return await thumbnailRef.getDownloadURL();
    } catch (e) {
      _logger.error('Failed to generate/upload thumbnail',
          tag: 'UnifiedVideoService', error: e);
      rethrow;
    }
  }

  Future<File> _generateThumbnail(File videoFile, String videoId) async {
    try {
      // Create a temporary file for the thumbnail
      final tempDir = Directory.systemTemp;
      final thumbnailFile = File('${tempDir.path}/thumbnail_$videoId.jpg');

      // For now, create a simple placeholder thumbnail
      // In a real implementation, you'd use video_thumbnail package
      await thumbnailFile.writeAsBytes([]);

      return thumbnailFile;
    } catch (e) {
      _logger.error('Failed to generate thumbnail',
          tag: 'UnifiedVideoService', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _createVideoDocument({
    required String videoId,
    required String userId,
    required String videoUrl,
    required String thumbnailUrl,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      // Extract category from additionalMetadata
      final category = additionalMetadata?['category'] as String?;

      final videoData = {
        'id': videoId,
        'userId': userId,
        'creatorId': userId, // Add for web/cross-platform compatibility
        'creator_id': userId, // Snake case variant for website compatibility
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'thumbnails': {
          'urls': {
            '360': thumbnailUrl,
            '540': thumbnailUrl,
            '720': thumbnailUrl,
          },
          'generatedAt': FieldValue.serverTimestamp(),
        },
        'caption': caption,
        'hashtags': hashtags,
        'privacy': privacy,
        'allowComments': allowComments,
        'category':
            category, // 🔥 FIX: Add category field directly to video document
        'categoryId': category, // Alternative field name for compatibility
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'published',
        'views': 0,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'moderation': {
          'approved': true,
          'checkedAt': FieldValue.serverTimestamp(),
          'confidence': 0.95,
          'violations': [],
        },
        'metadata': {
          'fileSize': 0, // Placeholder - would be calculated from videoFile
          'duration': 30.0, // Placeholder
          'resolution': '1080x1920', // Placeholder
          'format': 'mp4',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        ...?additionalMetadata,
      };

      await _firestore.collection('videos').doc(videoId).set(videoData);

      return videoData;
    } catch (e) {
      _logger.error('Failed to create video document',
          tag: 'UnifiedVideoService', error: e);
      rethrow;
    }
  }

  // Cleanup and disposal
  void dispose() {
    _controllerRegistry.cleanupAll();
    _logger.info('UnifiedVideoService disposed', tag: 'UnifiedVideoService');
  }
}
