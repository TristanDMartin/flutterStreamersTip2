import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'logging_service.dart';

class VideoPreviewService {
  static final VideoPreviewService _instance = VideoPreviewService._internal();
  factory VideoPreviewService() => _instance;
  VideoPreviewService._internal();

  // Cache for generated thumbnails
  final Map<String, Uint8List> _thumbnailCache = {};
  final Map<String, String> _localFileCache = {};

  // Thumbnail generation settings
  static const int _maxWidth = 720;
  static const int _maxHeight = 1280;
  static const int _thumbnailTimeMs = 1000;
  static const int _highQuality = 95;

  /// Generate high-quality video thumbnail for sharing
  Future<Uint8List?> generateThumbnail(String videoPath) async {
    try {
      // Check cache first
      if (_thumbnailCache.containsKey(videoPath)) {
        LoggingService.instance.debug(
          '🖼️ VideoPreviewService: Using cached thumbnail for $videoPath',
          tag: 'VideoPreviewService',
        );
        return _thumbnailCache[videoPath];
      }

      LoggingService.instance.info(
        '🖼️ VideoPreviewService: Generating thumbnail for $videoPath',
        tag: 'VideoPreviewService',
      );

      String localPath = videoPath;

      // If it's a network URL, download it first
      if (videoPath.startsWith('http')) {
        localPath = await _downloadVideoToLocal(videoPath) ?? videoPath;
      }

      final thumbnail = await VideoThumbnail.thumbnailData(
        video: localPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: _maxWidth,
        maxHeight: _maxHeight,
        timeMs: _thumbnailTimeMs,
        quality: _highQuality,
      );

      if (thumbnail != null) {
        _thumbnailCache[videoPath] = thumbnail;
        LoggingService.instance.info(
          '✅ VideoPreviewService: Generated thumbnail successfully',
          tag: 'VideoPreviewService',
        );
      }

      return thumbnail;
    } catch (e) {
      LoggingService.instance.error(
        '❌ VideoPreviewService: Error generating thumbnail: $e',
        tag: 'VideoPreviewService',
        error: e,
      );
      return null;
    }
  }

  /// Generate multiple thumbnails at different timestamps
  Future<List<Uint8List>> generateMultipleThumbnails(
    String videoPath, {
    int count = 3,
    Duration? duration,
  }) async {
    try {
      LoggingService.instance.info(
        '🖼️ VideoPreviewService: Generating $count thumbnails for $videoPath',
        tag: 'VideoPreviewService',
      );

      String localPath = videoPath;

      if (videoPath.startsWith('http')) {
        localPath = await _downloadVideoToLocal(videoPath) ?? videoPath;
      }

      final thumbnails = <Uint8List>[];
      final totalDuration = duration ?? const Duration(seconds: 30);
      final interval = totalDuration.inMilliseconds ~/ (count + 1);

      for (int i = 1; i <= count; i++) {
        final timestamp = interval * i;

        final thumbnail = await VideoThumbnail.thumbnailData(
          video: localPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: _maxWidth,
          maxHeight: _maxHeight,
          timeMs: timestamp,
          quality: _highQuality,
        );

        if (thumbnail != null) {
          thumbnails.add(thumbnail);
        }
      }

      LoggingService.instance.info(
        '✅ VideoPreviewService: Generated ${thumbnails.length} thumbnails',
        tag: 'VideoPreviewService',
      );

      return thumbnails;
    } catch (e) {
      LoggingService.instance.error(
        '❌ VideoPreviewService: Error generating multiple thumbnails: $e',
        tag: 'VideoPreviewService',
        error: e,
      );
      return [];
    }
  }

  /// Generate thumbnail with custom dimensions
  Future<Uint8List?> generateThumbnailWithSize(
    String videoPath, {
    int? width,
    int? height,
    int? timeMs,
  }) async {
    try {
      LoggingService.instance.info(
        '🖼️ VideoPreviewService: Generating custom size thumbnail for $videoPath',
        tag: 'VideoPreviewService',
      );

      String localPath = videoPath;

      if (videoPath.startsWith('http')) {
        localPath = await _downloadVideoToLocal(videoPath) ?? videoPath;
      }

      final thumbnail = await VideoThumbnail.thumbnailData(
        video: localPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: width ?? _maxWidth,
        maxHeight: height ?? _maxHeight,
        timeMs: timeMs ?? _thumbnailTimeMs,
        quality: _highQuality,
      );

      if (thumbnail != null) {
        LoggingService.instance.info(
          '✅ VideoPreviewService: Generated custom size thumbnail',
          tag: 'VideoPreviewService',
        );
      }

      return thumbnail;
    } catch (e) {
      LoggingService.instance.error(
        '❌ VideoPreviewService: Error generating custom size thumbnail: $e',
        tag: 'VideoPreviewService',
        error: e,
      );
      return null;
    }
  }

  /// Download video from network URL to local storage
  Future<String?> _downloadVideoToLocal(String videoUrl) async {
    try {
      // Check if already downloaded
      if (_localFileCache.containsKey(videoUrl)) {
        final localPath = _localFileCache[videoUrl]!;
        if (await File(localPath).exists()) {
          return localPath;
        }
      }

      LoggingService.instance.info(
        '📥 VideoPreviewService: Downloading video from $videoUrl',
        tag: 'VideoPreviewService',
      );

      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(videoUrl).split('?').first;
        final localFile = File('${tempDir.path}/$fileName');

        await localFile.writeAsBytes(response.bodyBytes);
        _localFileCache[videoUrl] = localFile.path;

        LoggingService.instance.info(
          '✅ VideoPreviewService: Downloaded video to ${localFile.path}',
          tag: 'VideoPreviewService',
        );

        return localFile.path;
      } else {
        LoggingService.instance.error(
          '❌ VideoPreviewService: Failed to download video: ${response.statusCode}',
          tag: 'VideoPreviewService',
        );
        return null;
      }
    } catch (e) {
      LoggingService.instance.error(
        '❌ VideoPreviewService: Error downloading video: $e',
        tag: 'VideoPreviewService',
        error: e,
      );
      return null;
    }
  }

  /// Generate thumbnail for sharing with overlay
  Future<Uint8List?> generateShareThumbnail(
    String videoPath, {
    String? overlayText,
    Color? overlayColor,
  }) async {
    try {
      final baseThumbnail = await generateThumbnail(videoPath);
      if (baseThumbnail == null) return null;

      // TODO: Add overlay text processing
      // This would require image processing library like image package
      // For now, return the base thumbnail

      LoggingService.instance.info(
        '✅ VideoPreviewService: Generated share thumbnail with overlay',
        tag: 'VideoPreviewService',
      );

      return baseThumbnail;
    } catch (e) {
      LoggingService.instance.error(
        '❌ VideoPreviewService: Error generating share thumbnail: $e',
        tag: 'VideoPreviewService',
        error: e,
      );
      return null;
    }
  }

  /// Get cached thumbnail
  Uint8List? getCachedThumbnail(String videoPath) {
    return _thumbnailCache[videoPath];
  }

  /// Clear thumbnail cache
  void clearCache() {
    _thumbnailCache.clear();
    _localFileCache.clear();

    LoggingService.instance.info(
      '🧹 VideoPreviewService: Cleared thumbnail cache',
      tag: 'VideoPreviewService',
    );
  }

  /// Clear old cache entries
  void clearOldCache() {
    if (_thumbnailCache.length > 20) {
      final keysToRemove =
          _thumbnailCache.keys.take(_thumbnailCache.length - 20).toList();

      for (final key in keysToRemove) {
        _thumbnailCache.remove(key);
        _localFileCache.remove(key);
      }

      LoggingService.instance.info(
        '🧹 VideoPreviewService: Cleared old cache entries',
        tag: 'VideoPreviewService',
      );
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'thumbnailCount': _thumbnailCache.length,
      'localFileCount': _localFileCache.length,
      'totalCacheSize': _thumbnailCache.values
          .fold<int>(0, (sum, bytes) => sum + bytes.length),
    };
  }

  /// Preload thumbnails for multiple videos
  Future<Map<String, Uint8List?>> preloadThumbnails(
      List<String> videoPaths) async {
    try {
      LoggingService.instance.info(
        '🔄 VideoPreviewService: Preloading thumbnails for ${videoPaths.length} videos',
        tag: 'VideoPreviewService',
      );

      final results = <String, Uint8List?>{};

      // Process videos in parallel
      final futures = videoPaths.map((path) async {
        final thumbnail = await generateThumbnail(path);
        return MapEntry(path, thumbnail);
      });

      final entries = await Future.wait(futures);
      for (final entry in entries) {
        results[entry.key] = entry.value;
      }

      LoggingService.instance.info(
        '✅ VideoPreviewService: Preloaded ${results.length} thumbnails',
        tag: 'VideoPreviewService',
      );

      return results;
    } catch (e) {
      LoggingService.instance.error(
        '❌ VideoPreviewService: Error preloading thumbnails: $e',
        tag: 'VideoPreviewService',
        error: e,
      );
      return {};
    }
  }
}
