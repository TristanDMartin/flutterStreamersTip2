import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_thumbnails.dart';
import '../services/thumbnail_service.dart';
import '../services/logging_service.dart';
import '../services/video_thumbnail_service.dart';

/// Service for generating local thumbnails for draft videos
class DraftThumbnailService {
  static final DraftThumbnailService _instance =
      DraftThumbnailService._internal();
  factory DraftThumbnailService() => _instance;
  DraftThumbnailService._internal();

  final ThumbnailService _thumbnailService = ThumbnailService();

  // Cache for local thumbnails
  final Map<String, String> _localThumbnailCache = {};

  // Cache for video controllers to avoid repeated initialization
  final Map<String, VideoPlayerController> _controllerCache = {};

  /// Generate a local thumbnail for a draft video
  Future<String?> generateLocalThumbnail({
    required String videoPath,
    required String videoId,
    double? customTimestamp,
  }) async {
    try {
      LoggingService.instance.info(
          '🖼️ Generating local thumbnail for draft video $videoId',
          tag: 'DraftThumbnailService');

      // Check cache first
      final cacheKey = '${videoPath}_${customTimestamp ?? 0.0}';
      if (_localThumbnailCache.containsKey(cacheKey)) {
        LoggingService.instance.debug(
            '🖼️ Using cached local thumbnail for $videoId',
            tag: 'DraftThumbnailService');
        return _localThumbnailCache[cacheKey];
      }

      // Generate new thumbnail
      final thumbnailPath = await _extractFrameFromVideo(
        videoPath: videoPath,
        videoId: videoId,
        timestamp: customTimestamp,
      );

      if (thumbnailPath != null) {
        _localThumbnailCache[cacheKey] = thumbnailPath;
        LoggingService.instance.info(
            '🖼️ Generated local thumbnail for $videoId: $thumbnailPath',
            tag: 'DraftThumbnailService');
        return thumbnailPath;
      }

      return null;
    } catch (e) {
      LoggingService.instance.error(
          'Error generating local thumbnail for $videoId',
          tag: 'DraftThumbnailService',
          error: e);
      return null;
    }
  }

  /// Extract a frame from video and save as thumbnail
  Future<String?> _extractFrameFromVideo({
    required String videoPath,
    required String videoId,
    double? timestamp,
  }) async {
    try {
      // Use VideoThumbnailService for high-quality thumbnail generation
      // Calculate timestamp in milliseconds (default to 1 second or 30% of video)
      int timeMs = 1000; // Default 1 second

      if (timestamp != null) {
        timeMs = (timestamp * 1000).round();
      } else {
        // Try to get video duration to use 30% timestamp
        try {
          final controller = await _getOrCreateController(videoPath);
          if (controller != null) {
            final duration = controller.value.duration;
            timeMs = (duration.inMilliseconds * 0.3).round();
          }
        } catch (e) {
          // If we can't get duration, use default 1 second
          LoggingService.instance.debug(
              'Could not get video duration, using default timestamp',
              tag: 'DraftThumbnailService');
        }
      }

      // Generate high-quality thumbnail using VideoThumbnailService
      // Use 720x1280 for high quality (shared between app and website)
      final thumbnailBytes =
          await VideoThumbnailService.generateHighQualityThumbnail(
        videoPath,
        maxWidth: 720,
        maxHeight: 1280,
        timeMs: timeMs,
      );

      if (thumbnailBytes == null) {
        LoggingService.instance.error(
            'Failed to generate high-quality thumbnail for $videoId',
            tag: 'DraftThumbnailService');
        return null;
      }

      // Save thumbnail to local storage as JPEG for better quality
      final thumbnailPath = await _saveThumbnailToLocalStorage(
        thumbnailBytes: thumbnailBytes,
        videoId: videoId,
      );

      return thumbnailPath;
    } catch (e) {
      LoggingService.instance.error('Error extracting frame from video',
          tag: 'DraftThumbnailService', error: e);
      return null;
    }
  }

  /// Get or create video player controller
  Future<VideoPlayerController?> _getOrCreateController(
      String videoPath) async {
    try {
      // Check cache first
      if (_controllerCache.containsKey(videoPath)) {
        final controller = _controllerCache[videoPath]!;
        if (controller.value.isInitialized) {
          return controller;
        }
      }

      // Create new controller
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();

      // Cache the controller
      _controllerCache[videoPath] = controller;

      return controller;
    } catch (e) {
      LoggingService.instance.error(
          'Error creating video controller for $videoPath',
          tag: 'DraftThumbnailService',
          error: e);
      return null;
    }
  }

  /// Save thumbnail to local storage as JPEG for high quality
  Future<String> _saveThumbnailToLocalStorage({
    required Uint8List thumbnailBytes,
    required String videoId,
  }) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${documentsDir.path}/DraftThumbnails');

      // Create thumbnails directory if it doesn't exist
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }

      // Save as JPEG for better quality and smaller file size
      final thumbnailFile =
          File('${thumbnailsDir.path}/draft_thumb_$videoId.jpg');
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      LoggingService.instance.debug(
          '🖼️ Saved high-quality local thumbnail: ${thumbnailFile.path}',
          tag: 'DraftThumbnailService');

      return thumbnailFile.path;
    } catch (e) {
      LoggingService.instance.error('Error saving thumbnail to local storage',
          tag: 'DraftThumbnailService', error: e);
      rethrow;
    }
  }

  /// Create VideoThumbnails object with local thumbnail
  VideoThumbnails createLocalThumbnails({
    required String localThumbnailPath,
    required String videoId,
  }) {
    try {
      // Create multiple size entries for responsive loading
      // High quality 720x1280 for app and website sharing
      final urls = <int, String>{
        360: localThumbnailPath, // Small size for quick loading
        540: localThumbnailPath, // Medium size
        720: localThumbnailPath, // High quality for app/website
      };

      return VideoThumbnails(
        urls: urls,
        generatedAt: null, // Local thumbnails don't have a server timestamp
        aspectRatio: 9.0 / 16.0,
        sourceTimestamp: 0.3, // Default 30% timestamp
        qualityScore: 0.95, // High quality thumbnails
        isGenerating: false,
        errorMessage: null,
      );
    } catch (e) {
      LoggingService.instance.error('Error creating local thumbnails object',
          tag: 'DraftThumbnailService', error: e);
      return VideoThumbnailsFactory.error('Failed to create local thumbnails');
    }
  }

  /// Build a draft thumbnail widget with local preview
  Widget buildDraftThumbnail({
    required String videoPath,
    required String videoId,
    required double containerWidth,
    required double containerHeight,
    required double devicePixelRatio,
    VoidCallback? onTap,
    BorderRadius? borderRadius,
  }) {
    return FutureBuilder<String?>(
      future: generateLocalThumbnail(
        videoPath: videoPath,
        videoId: videoId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingThumbnail(
            containerWidth: containerWidth,
            containerHeight: containerHeight,
            borderRadius: borderRadius,
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorThumbnail(
            containerWidth: containerWidth,
            containerHeight: containerHeight,
            borderRadius: borderRadius,
            onTap: onTap,
          );
        }

        final localThumbnailPath = snapshot.data!;
        final thumbnails = createLocalThumbnails(
          localThumbnailPath: localThumbnailPath,
          videoId: videoId,
        );

        return _thumbnailService.buildResponsiveThumbnail(
          thumbnails: thumbnails,
          containerWidth: containerWidth,
          containerHeight: containerHeight,
          devicePixelRatio: devicePixelRatio,
          borderRadius: borderRadius,
          onTap: onTap,
        );
      },
    );
  }

  /// Build loading thumbnail widget
  Widget _buildLoadingThumbnail({
    required double containerWidth,
    required double containerHeight,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white54,
          strokeWidth: 2,
        ),
      ),
    );
  }

  /// Build error thumbnail widget
  Widget _buildErrorThumbnail({
    required double containerWidth,
    required double containerHeight,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: borderRadius,
        ),
        child: const Center(
          child: Icon(
            Icons.video_library_outlined,
            color: Colors.white54,
            size: 32,
          ),
        ),
      ),
    );
  }

  /// Clear cache for a specific video
  void clearCacheForVideo(String videoPath) {
    _localThumbnailCache.removeWhere((key, value) => key.contains(videoPath));

    // Dispose controller if cached
    final controller = _controllerCache.remove(videoPath);
    controller?.dispose();

    LoggingService.instance.debug('🖼️ Cleared cache for video: $videoPath',
        tag: 'DraftThumbnailService');
  }

  /// Clear all caches
  void clearAllCaches() {
    _localThumbnailCache.clear();

    // Dispose all controllers
    for (final controller in _controllerCache.values) {
      controller.dispose();
    }
    _controllerCache.clear();

    LoggingService.instance.debug('🖼️ Cleared all draft thumbnail caches',
        tag: 'DraftThumbnailService');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'localThumbnailCount': _localThumbnailCache.length,
      'controllerCount': _controllerCache.length,
    };
  }
}
