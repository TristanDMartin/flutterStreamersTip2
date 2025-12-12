import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import '../services/logging_service.dart';

class VideoProcessingService {
  static final VideoProcessingService _instance =
      VideoProcessingService._internal();
  factory VideoProcessingService() => _instance;
  VideoProcessingService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Video editing state
  final Map<String, VideoEditState> _editStates = {};
  final Map<String, List<VideoEditAction>> _editHistory = {};

  /// Get video duration in seconds
  Future<Duration> getVideoDuration(File videoFile) async {
    try {
      LoggingService.instance.debug(
          'Getting video duration for: ${videoFile.path}',
          tag: 'VideoProcessingService');

      // Create VideoPlayerController to get duration
      final controller = VideoPlayerController.file(videoFile);

      try {
        // Initialize the controller
        await controller.initialize();

        // Get the duration
        final duration = controller.value.duration;

        LoggingService.instance.debug(
            'Video duration: ${duration.inSeconds} seconds',
            tag: 'VideoProcessingService');

        return duration;
      } finally {
        // Always dispose the controller
        await controller.dispose();
      }
    } catch (e) {
      LoggingService.instance.error('Error getting video duration',
          tag: 'VideoProcessingService', error: e);
      // Return a default duration if extraction fails
      return const Duration(seconds: 30);
    }
  }

  Future<File> _resizeAndCropThumbnail(
    File source,
    int targetWidth,
    int targetHeight,
  ) async {
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return source;

      final targetAspect = targetWidth / targetHeight;
      final currentAspect = decoded.width / decoded.height;

      img.Image cropped;
      if (currentAspect > targetAspect) {
        // Too wide: crop width
        final newWidth = (decoded.height * targetAspect).round();
        final x = ((decoded.width - newWidth) / 2).round();
        cropped = img.copyCrop(decoded,
            x: x, y: 0, width: newWidth, height: decoded.height);
      } else {
        // Too tall: crop height
        final newHeight = (decoded.width / targetAspect).round();
        final y = ((decoded.height - newHeight) / 2).round();
        cropped = img.copyCrop(decoded,
            x: 0, y: y, width: decoded.width, height: newHeight);
      }

      final resized =
          img.copyResize(cropped, width: targetWidth, height: targetHeight);
      final outputBytes = img.encodeJpg(resized, quality: 90);
      await source.writeAsBytes(outputBytes, flush: true);
      return source;
    } catch (_) {
      return source;
    }
  }

  /// Trim video to specified start and end times
  ///
  /// **NOTE:** Video trimming is not yet implemented. FFmpeg integration required.
  /// This method currently throws an UnimplementedError with instructions.
  Future<File> trimVideo({
    required File inputFile,
    required Duration startTime,
    required Duration endTime,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    LoggingService.instance.warning(
        'Video trimming attempted but not implemented. FFmpeg required.',
        tag: 'VideoProcessingService');

    // Clear error message for user
    throw UnimplementedError(
        'Video trimming is not yet available. This feature requires FFmpeg integration and will be available in a future update. For now, please use the full video length.');
  }

  /// Apply audio effects (volume, mute, etc.)
  ///
  /// **NOTE:** Audio effects are not yet implemented. FFmpeg integration required.
  Future<File> applyAudioEffects({
    required File inputFile,
    required AudioEffects effects,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    LoggingService.instance.warning(
        'Audio effects attempted but not implemented. FFmpeg required.',
        tag: 'VideoProcessingService');

    throw UnimplementedError(
        'Audio effects are not yet available. This feature requires FFmpeg integration and will be available in a future update.');
  }

  /// Apply visual effects and filters
  ///
  /// **NOTE:** Visual effects are not yet implemented. FFmpeg integration required.
  Future<File> applyVisualEffects({
    required File inputFile,
    required List<VisualEffect> effects,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    LoggingService.instance.warning(
        'Visual effects attempted but not implemented. FFmpeg required.',
        tag: 'VideoProcessingService');

    throw UnimplementedError(
        'Visual effects and filters are not yet available. This feature requires FFmpeg integration and will be available in a future update.');
  }

  /// Add text overlay to video
  ///
  /// **NOTE:** Text overlays are not yet implemented. FFmpeg integration required.
  Future<File> addTextOverlay({
    required File inputFile,
    required List<TextOverlay> textOverlays,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    LoggingService.instance.warning(
        'Text overlay attempted but not implemented. FFmpeg required.',
        tag: 'VideoProcessingService');

    throw UnimplementedError(
        'Text overlays are not yet available. This feature requires FFmpeg integration and will be available in a future update.');
  }

  /// Generate thumbnail from video
  Future<File> generateThumbnail({
    required File videoFile,
    required Duration timestamp,
    required String videoId,
  }) async {
    try {
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Starting thumbnail generation for video $videoId',
          tag: 'VideoProcessingService');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Video file path: ${videoFile.path}',
          tag: 'VideoProcessingService');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Video file exists: ${await videoFile.exists()}',
          tag: 'VideoProcessingService');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Video file size: ${await videoFile.length()} bytes',
          tag: 'VideoProcessingService');

      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = File('${tempDir.path}/thumb_$videoId.jpg');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail will be saved to: ${thumbnailFile.path}',
          tag: 'VideoProcessingService');

      // 🔥 FIX: Try video_thumbnail package first, fallback to generated thumbnail
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Attempting to extract thumbnail from video',
          tag: 'VideoProcessingService');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Video file path: ${videoFile.path}',
          tag: 'VideoProcessingService');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail path: ${thumbnailFile.path}',
          tag: 'VideoProcessingService');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Time in milliseconds: ${timestamp.inMilliseconds}',
          tag: 'VideoProcessingService');

      try {
        const targetWidth = 720;
        const targetHeight = 1280;
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoFile.path,
          thumbnailPath: thumbnailFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: targetWidth,
          maxHeight: targetHeight,
          timeMs: timestamp.inMilliseconds,
          quality: 90,
        );

        LoggingService.instance.info(
            '🎬 VideoProcessingService: VideoThumbnail.thumbnailFile returned: $thumbnailPath',
            tag: 'VideoProcessingService');

        if (thumbnailPath != null) {
          final generatedFile = File(thumbnailPath);
          if (await generatedFile.exists()) {
            final resized = await _resizeAndCropThumbnail(
              generatedFile,
              targetWidth,
              targetHeight,
            );
            final fileSize = await resized.length();
            LoggingService.instance.info(
                '🎬 VideoProcessingService: Thumbnail generated successfully: ${resized.path} (${fileSize} bytes)',
                tag: 'VideoProcessingService');

            if (fileSize > 0) {
              return resized;
            } else {
              LoggingService.instance.warning(
                  '🎬 VideoProcessingService: Generated thumbnail is empty, creating fallback',
                  tag: 'VideoProcessingService');
            }
          } else {
            LoggingService.instance.warning(
                '🎬 VideoProcessingService: Generated thumbnail file does not exist, creating fallback',
                tag: 'VideoProcessingService');
          }
        } else {
          LoggingService.instance.warning(
              '🎬 VideoProcessingService: VideoThumbnail returned null, creating fallback',
              tag: 'VideoProcessingService');
        }
      } catch (e) {
        LoggingService.instance.warning(
            '🎬 VideoProcessingService: VideoThumbnail failed: $e, creating fallback',
            tag: 'VideoProcessingService');
      }

      // Create fallback thumbnail if video extraction fails
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Creating fallback thumbnail',
          tag: 'VideoProcessingService');
      return await _createFallbackThumbnail(videoId, thumbnailFile);
    } catch (e) {
      LoggingService.instance.error('Error generating thumbnail',
          tag: 'VideoProcessingService', error: e);
      // Return fallback thumbnail on error
      final tempDir = await getTemporaryDirectory();
      final fallbackFile = File('${tempDir.path}/thumb_$videoId.jpg');
      return await _createFallbackThumbnail(videoId, fallbackFile);
    }
  }

  /// Create fallback thumbnail when video extraction fails
  Future<File> _createFallbackThumbnail(
      String videoId, File thumbnailFile) async {
    try {
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Creating fallback thumbnail for video $videoId',
          tag: 'VideoProcessingService');

      // Create a proper video-style thumbnail
      final image = img.Image(width: 720, height: 1280);

      // Create a solid dark background (no gradients)
      final solidColor = img.ColorRgb8(45, 45, 45); // Dark grey
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          image.setPixel(x, y, solidColor);
        }
      }

      // Add a subtle play icon overlay
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      const iconSize = 72;

      for (int y = centerY - iconSize ~/ 2; y < centerY + iconSize ~/ 2; y++) {
        for (int x = centerX - iconSize ~/ 2;
            x < centerX + iconSize ~/ 2;
            x++) {
          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final dx = x - centerX;
            final dy = y - centerY;
            if (dx > -dy && dx < dy && dy > 0 && dx.abs() < iconSize ~/ 2) {
              image.setPixel(x, y, img.ColorRgb8(255, 255, 255));
            }
          }
        }
      }

      // Add a subtle border
      for (int x = 0; x < image.width; x++) {
        image.setPixel(x, 0, img.ColorRgb8(200, 200, 200));
        image.setPixel(x, image.height - 1, img.ColorRgb8(200, 200, 200));
      }
      for (int y = 0; y < image.height; y++) {
        image.setPixel(0, y, img.ColorRgb8(200, 200, 200));
        image.setPixel(image.width - 1, y, img.ColorRgb8(200, 200, 200));
      }

      // Ensure the thumbnail file exists
      await thumbnailFile.create(recursive: true);
      await thumbnailFile.writeAsBytes(img.encodeJpg(image));

      final fileSize = await thumbnailFile.length();
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Fallback thumbnail saved successfully. File size: $fileSize bytes',
          tag: 'VideoProcessingService');

      if (fileSize == 0) {
        throw Exception('Fallback thumbnail file is empty');
      }

      return thumbnailFile;
    } catch (e) {
      LoggingService.instance.error('Error creating fallback thumbnail',
          tag: 'VideoProcessingService', error: e);
      rethrow;
    }
  }

  /// Save video edit state
  void saveEditState(String videoId, VideoEditState state) {
    _editStates[videoId] = state;
  }

  /// Get video edit state
  VideoEditState? getEditState(String videoId) {
    return _editStates[videoId];
  }

  /// Add edit action to history
  void addEditAction(String videoId, VideoEditAction action) {
    _editHistory[videoId] ??= [];
    _editHistory[videoId]!.add(action);
  }

  /// Undo last edit action
  VideoEditAction? undoLastAction(String videoId) {
    final history = _editHistory[videoId];
    if (history != null && history.isNotEmpty) {
      return history.removeLast();
    }
    return null;
  }

  /// Clear edit history
  void clearEditHistory(String videoId) {
    _editHistory[videoId]?.clear();
  }

  /// Process video with all applied effects and generate thumbnail
  Future<VideoProcessingResult> processVideo({
    required File inputFile,
    required String videoId,
    required String userId,
  }) async {
    try {
      // Generate thumbnail
      final thumbnail = await generateThumbnail(
        videoFile: inputFile,
        timestamp: const Duration(seconds: 1),
        videoId: videoId,
      );

      // Upload thumbnail to Firebase Storage
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Uploading thumbnail to Firebase Storage',
          tag: 'VideoProcessingService');
      final thumbnailRef = _storage.ref().child('thumbnails/$videoId.jpg');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail storage path: thumbnails/$videoId.jpg',
          tag: 'VideoProcessingService');

      // Check if thumbnail file exists before uploading
      if (!await thumbnail.exists()) {
        throw Exception('Thumbnail file does not exist: ${thumbnail.path}');
      }

      final thumbnailSize = await thumbnail.length();
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail file size: $thumbnailSize bytes',
          tag: 'VideoProcessingService');

      await thumbnailRef.putFile(thumbnail);
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail uploaded successfully',
          tag: 'VideoProcessingService');

      final thumbnailUrl = await thumbnailRef.getDownloadURL();
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail download URL: $thumbnailUrl',
          tag: 'VideoProcessingService');

      if (thumbnailUrl.isEmpty) {
        throw Exception('Failed to get download URL for thumbnail');
      }

      return VideoProcessingResult(
        videoFile: inputFile,
        thumbnailFile: thumbnail,
        thumbnailUrl: thumbnailUrl,
        duration: await getVideoDuration(inputFile),
      );
    } catch (e) {
      LoggingService.instance.error('Error processing video',
          tag: 'VideoProcessingService', error: e);
      rethrow;
    }
  }
}

// Data models
class VideoEditState {
  final String videoId;
  final File originalFile;
  final Duration startTime;
  final Duration endTime;
  final AudioEffects audioEffects;
  final List<VisualEffect> visualEffects;
  final List<TextOverlay> textOverlays;
  final bool isMuted;
  final double volume;

  VideoEditState({
    required this.videoId,
    required this.originalFile,
    required this.startTime,
    required this.endTime,
    required this.audioEffects,
    required this.visualEffects,
    required this.textOverlays,
    this.isMuted = false,
    this.volume = 1.0,
  });

  VideoEditState copyWith({
    Duration? startTime,
    Duration? endTime,
    AudioEffects? audioEffects,
    List<VisualEffect>? visualEffects,
    List<TextOverlay>? textOverlays,
    bool? isMuted,
    double? volume,
  }) {
    return VideoEditState(
      videoId: videoId,
      originalFile: originalFile,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      audioEffects: audioEffects ?? this.audioEffects,
      visualEffects: visualEffects ?? this.visualEffects,
      textOverlays: textOverlays ?? this.textOverlays,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
    );
  }
}

class VideoEditAction {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  VideoEditAction({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}

class AudioEffects {
  final double volume;
  final bool isMuted;
  final double fadeIn;
  final double fadeOut;
  final String? audioTrack;

  AudioEffects({
    this.volume = 1.0,
    this.isMuted = false,
    this.fadeIn = 0.0,
    this.fadeOut = 0.0,
    this.audioTrack,
  });
}

class VisualEffect {
  final String type;
  final Map<String, dynamic> parameters;
  final Duration startTime;
  final Duration endTime;

  VisualEffect({
    required this.type,
    required this.parameters,
    required this.startTime,
    required this.endTime,
  });
}

class TextOverlay {
  final String text;
  final double x;
  final double y;
  final String fontFamily;
  final double fontSize;
  final String color;
  final Duration startTime;
  final Duration endTime;
  final TextAlignment alignment;

  TextOverlay({
    required this.text,
    required this.x,
    required this.y,
    required this.fontFamily,
    required this.fontSize,
    required this.color,
    required this.startTime,
    required this.endTime,
    this.alignment = TextAlignment.center,
  });
}

enum TextAlignment { left, center, right }

class VideoProcessingResult {
  final File videoFile;
  final File thumbnailFile;
  final String thumbnailUrl;
  final Duration duration;

  VideoProcessingResult({
    required this.videoFile,
    required this.thumbnailFile,
    required this.thumbnailUrl,
    required this.duration,
  });
}
