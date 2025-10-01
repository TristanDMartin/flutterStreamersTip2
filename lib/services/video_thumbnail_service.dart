import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class VideoThumbnailService {
  // TikTok-quality thumbnail settings
  static const int _maxWidth = 720; // High resolution for crisp thumbnails
  static const int _maxHeight = 1280; // High resolution for crisp thumbnails
  static const int _thumbnailTimeMs = 1000; // 1 second
  static const int _highQuality = 95; // High quality for crisp images
  
  // Cache for thumbnails
  static final Map<String, Uint8List> _thumbnailCache = {};
  static final Map<String, String> _localFileCache = {};

  /// Generates a thumbnail from a video file or network URL
  static Future<Uint8List?> generateThumbnail(String videoPath) async {
    // Check cache first
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }

    try {
      String localPath = videoPath;
      
      // If it's a network URL, download it first
      if (videoPath.startsWith('http')) {
        final downloadedPath = await _downloadVideoToLocal(videoPath);
        if (downloadedPath == null) return null;
        localPath = downloadedPath;
      }

      final thumbnail = await VideoThumbnail.thumbnailData(
        video: localPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: _maxWidth,
        maxHeight: _maxHeight,
        timeMs: _thumbnailTimeMs,
        quality: _highQuality,
      );

      // Cache the thumbnail
      if (thumbnail != null) {
        _thumbnailCache[videoPath] = thumbnail;
      }

      return thumbnail;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Downloads a video from network URL to local storage
  static Future<String?> _downloadVideoToLocal(String videoUrl) async {
    try {
      // Check if already downloaded
      if (_localFileCache.containsKey(videoUrl)) {
        final cachedPath = _localFileCache[videoUrl]!;
        if (await File(cachedPath).exists()) {
          return cachedPath;
        }
      }

      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(videoUrl).split('?').first;
        final localPath = path.join(tempDir.path, 'video_${DateTime.now().millisecondsSinceEpoch}_$fileName');
        
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Cache the local path
        _localFileCache[videoUrl] = localPath;
        
        return localPath;
      }
    } catch (e) {
      debugPrint('Error downloading video: $e');
    }
    return null;
  }

  /// Generates a thumbnail and saves it to a file
  static Future<String?> generateThumbnailFile(String videoPath) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: _maxWidth,
        maxHeight: _maxHeight,
        timeMs: _thumbnailTimeMs,
        quality: _highQuality,
      );
      return thumbnailPath;
    } catch (e) {
      debugPrint('Error generating thumbnail file: $e');
      return null;
    }
  }

  /// Generates multiple thumbnails at different time points
  static Future<List<Uint8List?>> generateMultipleThumbnails(
    String videoPath, {
    List<int> timePointsMs = const [500, 1000, 2000],
  }) async {
    final thumbnails = <Uint8List?>[];
    
    for (final timeMs in timePointsMs) {
      try {
        final thumbnail = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: _maxWidth,
          maxHeight: _maxHeight,
          timeMs: timeMs,
          quality: _highQuality,
        );
        thumbnails.add(thumbnail);
      } catch (e) {
        debugPrint('Error generating thumbnail at ${timeMs}ms: $e');
        thumbnails.add(null);
      }
    }
    
    return thumbnails;
  }

  /// Generates a TikTok-quality thumbnail with optimal settings
  static Future<Uint8List?> generateTikTokQualityThumbnail(
    String videoPath, {
    int? maxWidth,
    int? maxHeight,
    int? timeMs,
  }) async {
    try {
      String localPath = videoPath;
      
      // If it's a network URL, download it first
      if (videoPath.startsWith('http')) {
        final downloadedPath = await _downloadVideoToLocal(videoPath);
        if (downloadedPath == null) return null;
        localPath = downloadedPath;
      }

      final thumbnail = await VideoThumbnail.thumbnailData(
        video: localPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth ?? 720, // TikTok uses high resolution
        maxHeight: maxHeight ?? 1280, // TikTok uses high resolution
        timeMs: timeMs ?? _thumbnailTimeMs,
        quality: 95, // Maximum quality for crisp images
      );

      return thumbnail;
    } catch (e) {
      debugPrint('Error generating TikTok-quality thumbnail: $e');
      return null;
    }
  }

  /// Generates a thumbnail with custom dimensions
  static Future<Uint8List?> generateCustomThumbnail(
    String videoPath, {
    int? maxWidth,
    int? maxHeight,
    int? timeMs,
    int quality = 95, // Default to high quality
  }) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth ?? _maxWidth,
        maxHeight: maxHeight ?? _maxHeight,
        timeMs: timeMs ?? _thumbnailTimeMs,
        quality: quality,
      );
      return thumbnail;
    } catch (e) {
      debugPrint('Error generating custom thumbnail: $e');
      return null;
    }
  }

  /// Cleans up temporary thumbnail files
  static Future<void> cleanupThumbnail(String thumbnailPath) async {
    try {
      final file = File(thumbnailPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error cleaning up thumbnail: $e');
    }
  }

  /// Clears the thumbnail cache
  static void clearCache() {
    _thumbnailCache.clear();
    _localFileCache.clear();
  }

  /// Cleans up all cached files
  static Future<void> cleanupAllCachedFiles() async {
    try {
      for (final filePath in _localFileCache.values) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _localFileCache.clear();
      _thumbnailCache.clear();
    } catch (e) {
      debugPrint('Error cleaning up cached files: $e');
    }
  }

  /// Gets video duration in seconds
  static Future<int?> getVideoDuration(String videoPath) async {
    try {
      // Note: This is a workaround since video_thumbnail doesn't directly provide duration
      // In a real implementation, you might want to use a different package like video_player
      // or ffmpeg to get the actual duration
      await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1,
        maxHeight: 1,
        timeMs: 0,
        quality: 1,
      );
      return null;
    } catch (e) {
      debugPrint('Error getting video duration: $e');
      return null;
    }
  }
}
