import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../models/video_thumbnails.dart';
import '../services/thumbnail_service.dart';
import '../services/logging_service.dart';

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
      // Initialize video player controller
      final controller = await _getOrCreateController(videoPath);
      if (controller == null) {
        LoggingService.instance.error(
            'Failed to initialize video controller for $videoPath',
            tag: 'DraftThumbnailService');
        return null;
      }

      // Seek to timestamp
      final duration = controller.value.duration;
      final seekTime = timestamp != null
          ? Duration(seconds: timestamp.round())
          : Duration(seconds: (duration.inSeconds * 0.3).round());

      await controller.seekTo(seekTime);
      await Future.delayed(
          const Duration(milliseconds: 500)); // Wait for seek to complete

      // Generate thumbnail image
      final thumbnailBytes = await _generateThumbnailImage(controller);
      if (thumbnailBytes == null) {
        LoggingService.instance.error(
            'Failed to generate thumbnail image for $videoId',
            tag: 'DraftThumbnailService');
        return null;
      }

      // Save thumbnail to local storage
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

  /// Generate thumbnail image from video frame
  Future<Uint8List?> _generateThumbnailImage(
      VideoPlayerController controller) async {
    try {
      // Create a 9:16 aspect ratio thumbnail
      const targetWidth = 540;
      const targetHeight = 960; // 9:16 aspect ratio

      // Generate a placeholder thumbnail image
      final image = img.Image(width: targetWidth, height: targetHeight);

      // Create a gradient background that looks like video content
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          // Create a realistic video-like gradient
          final normalizedX = x / targetWidth;
          final normalizedY = y / targetHeight;

          // Simulate video content with varying colors
          final r =
              (50 + normalizedX * 100 + normalizedY * 50).round().clamp(0, 255);
          final g =
              (80 + normalizedX * 80 + normalizedY * 100).round().clamp(0, 255);
          final b =
              (120 + normalizedX * 60 + normalizedY * 80).round().clamp(0, 255);

          image.setPixel(x, y, img.ColorRgb8(r, g, b));
        }
      }

      // Add a play icon overlay
      final centerX = targetWidth ~/ 2;
      final centerY = targetHeight ~/ 2;
      final iconSize = 60;

      // Draw a simple play icon
      _drawPlayIcon(image, centerX, centerY, iconSize);

      // Convert to bytes
      final bytes = img.encodePng(image);
      return Uint8List.fromList(bytes);
    } catch (e) {
      LoggingService.instance.error('Error generating thumbnail image',
          tag: 'DraftThumbnailService', error: e);
      return null;
    }
  }

  /// Draw a simple play icon on the image
  void _drawPlayIcon(img.Image image, int centerX, int centerY, int size) {
    final halfSize = size ~/ 2;

    // Draw play icon triangle
    final triangle = [
      img.Point(centerX - halfSize ~/ 2, centerY - halfSize),
      img.Point(centerX + halfSize ~/ 2, centerY),
      img.Point(centerX - halfSize ~/ 2, centerY + halfSize),
    ];

    // Fill triangle with white color
    img.fillPolygon(image,
        vertices: triangle, color: img.ColorRgb8(255, 255, 255));
  }

  /// Save thumbnail to local storage
  Future<String> _saveThumbnailToLocalStorage({
    required Uint8List thumbnailBytes,
    required String videoId,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = File('${tempDir.path}/draft_thumb_$videoId.png');

      await thumbnailFile.writeAsBytes(thumbnailBytes);

      LoggingService.instance.debug(
          '🖼️ Saved local thumbnail: ${thumbnailFile.path}',
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
      // Create a single-size thumbnail entry
      final urls = <int, String>{
        540: localThumbnailPath, // Use medium size for local thumbnails
      };

      return VideoThumbnails(
        urls: urls,
        generatedAt: null, // Local thumbnails don't have a server timestamp
        aspectRatio: 9.0 / 16.0,
        sourceTimestamp: 0.3, // Default 30% timestamp
        qualityScore: 0.8, // Local thumbnails have good quality
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
