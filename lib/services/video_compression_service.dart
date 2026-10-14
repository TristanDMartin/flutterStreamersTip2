import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart' as compress;

class VideoCompressionResult {
  const VideoCompressionResult({
    required this.success,
    this.compressedFile,
    this.originalSize,
    this.compressedSize,
    this.compressionRatio,
    this.error,
  });

  final bool success;
  final File? compressedFile;
  final int? originalSize;
  final int? compressedSize;
  final double? compressionRatio;
  final String? error;
}

class ThumbnailExtractionResult {
  const ThumbnailExtractionResult({
    required this.success,
    this.thumbnailFile,
    this.error,
  });

  final bool success;
  final File? thumbnailFile;
  final String? error;
}

class VideoCompressionService {
  static final VideoCompressionService _instance =
      VideoCompressionService._internal();
  factory VideoCompressionService() => _instance;
  VideoCompressionService._internal();

  /// Compress video with quality control
  Future<VideoCompressionResult> compressVideo(
    File videoFile, {
    compress.VideoQuality quality = compress.VideoQuality.MediumQuality,
    bool deleteOrigin = false,
    void Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint('📹 Starting video compression...');
      final originalSize = await videoFile.length();
      debugPrint('Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      final subscription = compress.VideoCompress.compressProgress$.subscribe(
        (progress) => onProgress?.call(progress / 100),
      );

      final info = await compress.VideoCompress.compressVideo(
        videoFile.path,
        quality: quality,
        deleteOrigin: deleteOrigin,
        includeAudio: true,
      );

      subscription.unsubscribe();

      if (info == null || info.file == null) {
        return const VideoCompressionResult(
          success: false,
          error: 'Compression failed: no output file',
        );
      }

      final compressedSize = await info.file!.length();
      final ratio = (originalSize - compressedSize) / originalSize;

      debugPrint('Compressed size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('Compression ratio: ${(ratio * 100).toStringAsFixed(1)}%');

      return VideoCompressionResult(
        success: true,
        compressedFile: info.file!,
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: ratio,
      );
    } catch (e) {
      debugPrint('❌ Compression error: $e');
      return VideoCompressionResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Extract thumbnail from video at specified time
  Future<ThumbnailExtractionResult> extractThumbnail(
    File videoFile, {
    Duration? timeMs,
    int quality = 100,
  }) async {
    try {
      debugPrint('🖼️ Extracting thumbnail from video...');

      final thumbnailFile = await compress.VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: quality,
        position: timeMs?.inMilliseconds ?? 0,
      );

      if (thumbnailFile == null) {
        return const ThumbnailExtractionResult(
          success: false,
          error: 'Failed to extract thumbnail',
        );
      }

      debugPrint('✅ Thumbnail extracted: ${thumbnailFile.path}');

      return ThumbnailExtractionResult(
        success: true,
        thumbnailFile: thumbnailFile,
      );
    } catch (e) {
      debugPrint('❌ Thumbnail extraction error: $e');
      return ThumbnailExtractionResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Generate multiple thumbnails at different timestamps
  Future<List<File>> generateThumbnailGrid(
    File videoFile, {
    int count = 6,
    int quality = 80,
  }) async {
    try {
      debugPrint('🎬 Generating $count thumbnails...');

      final duration = await _getVideoDuration(videoFile);
      final interval = duration.inMilliseconds ~/ (count + 1);

      final thumbnails = <File>[];
      for (int i = 1; i <= count; i++) {
        final timeMs = interval * i;
        final result = await extractThumbnail(
          videoFile,
          timeMs: Duration(milliseconds: timeMs),
          quality: quality,
        );

        if (result.success && result.thumbnailFile != null) {
          thumbnails.add(result.thumbnailFile!);
        }
      }

      debugPrint('✅ Generated ${thumbnails.length} thumbnails');
      return thumbnails;
    } catch (e) {
      debugPrint('❌ Thumbnail grid generation error: $e');
      return [];
    }
  }

  Future<Duration> _getVideoDuration(File videoFile) async {
    try {
      final info = await compress.VideoCompress.getMediaInfo(videoFile.path);
      final duration = info.duration;
      if (duration == null) return Duration.zero;
      return Duration(milliseconds: duration.toInt());
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Cancel ongoing compression
  Future<void> cancelCompression() async {
    await compress.VideoCompress.cancelCompression();
  }

  /// Delete cache files
  Future<void> deleteAllCache() async {
    await compress.VideoCompress.deleteAllCache();
  }
}
