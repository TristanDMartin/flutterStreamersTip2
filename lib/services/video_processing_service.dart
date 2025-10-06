import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
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
      // For now, return a placeholder duration
      // In production, use ffmpeg or video_player to get actual duration
      return const Duration(seconds: 60);
    } catch (e) {
      LoggingService.instance.error('Error getting video duration',
          tag: 'VideoProcessingService', error: e);
      return const Duration(seconds: 0);
    }
  }

  /// Trim video to specified start and end times
  Future<File> trimVideo({
    required File inputFile,
    required Duration startTime,
    required Duration endTime,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      // Create output file
      final tempDir = await getTemporaryDirectory();
      final outputFile = File('${tempDir.path}/trimmed_$videoId.mp4');

      // Simulate video trimming (in production, use FFmpeg)
      await _simulateVideoProcessing(
          outputFile, startTime, endTime, onProgress);

      onProgress?.call(1.0);
      LoggingService.instance
          .debug('Video trimmed successfully', tag: 'VideoProcessingService');

      return outputFile;
    } catch (e) {
      LoggingService.instance.error('Error trimming video',
          tag: 'VideoProcessingService', error: e);
      rethrow;
    }
  }

  /// Apply audio effects (volume, mute, etc.)
  Future<File> applyAudioEffects({
    required File inputFile,
    required AudioEffects effects,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      final tempDir = await getTemporaryDirectory();
      final outputFile = File('${tempDir.path}/audio_$videoId.mp4');

      // Simulate audio processing
      await _simulateAudioProcessing(outputFile, effects, onProgress);

      onProgress?.call(1.0);
      return outputFile;
    } catch (e) {
      LoggingService.instance.error('Error applying audio effects',
          tag: 'VideoProcessingService', error: e);
      rethrow;
    }
  }

  /// Apply visual effects and filters
  Future<File> applyVisualEffects({
    required File inputFile,
    required List<VisualEffect> effects,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      final tempDir = await getTemporaryDirectory();
      final outputFile = File('${tempDir.path}/effects_$videoId.mp4');

      // Simulate visual effects processing
      await _simulateVisualProcessing(outputFile, effects, onProgress);

      onProgress?.call(1.0);
      return outputFile;
    } catch (e) {
      LoggingService.instance.error('Error applying visual effects',
          tag: 'VideoProcessingService', error: e);
      rethrow;
    }
  }

  /// Add text overlay to video
  Future<File> addTextOverlay({
    required File inputFile,
    required List<TextOverlay> textOverlays,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      final tempDir = await getTemporaryDirectory();
      final outputFile = File('${tempDir.path}/text_$videoId.mp4');

      // Simulate text overlay processing
      await _simulateTextProcessing(outputFile, textOverlays, onProgress);

      onProgress?.call(1.0);
      return outputFile;
    } catch (e) {
      LoggingService.instance.error('Error adding text overlay',
          tag: 'VideoProcessingService', error: e);
      rethrow;
    }
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

      // Create a proper video-style thumbnail
      final image = img.Image(width: 320, height: 240);
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Created image canvas ${image.width}x${image.height}',
          tag: 'VideoProcessingService');

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
      final iconSize = 30;

      // Draw a play triangle with some transparency effect
      for (int y = centerY - iconSize ~/ 2; y < centerY + iconSize ~/ 2; y++) {
        for (int x = centerX - iconSize ~/ 2;
            x < centerX + iconSize ~/ 2;
            x++) {
          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final dx = x - centerX;
            final dy = y - centerY;
            // Create a more defined triangle
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

      await thumbnailFile.writeAsBytes(img.encodeJpg(image));
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail saved successfully. File size: ${await thumbnailFile.length()} bytes',
          tag: 'VideoProcessingService');
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail file exists: ${await thumbnailFile.exists()}',
          tag: 'VideoProcessingService');

      return thumbnailFile;
    } catch (e) {
      LoggingService.instance.error('Error generating thumbnail',
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

      await thumbnailRef.putFile(thumbnail);
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail uploaded successfully',
          tag: 'VideoProcessingService');

      final thumbnailUrl = await thumbnailRef.getDownloadURL();
      LoggingService.instance.info(
          '🎬 VideoProcessingService: Thumbnail download URL: $thumbnailUrl',
          tag: 'VideoProcessingService');

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

  // Private helper methods for simulation
  Future<void> _simulateVideoProcessing(File outputFile, Duration start,
      Duration end, Function(double)? onProgress) async {
    // Simulate processing time
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress?.call(0.1 + (i * 0.08));
    }

    // Create a dummy output file
    await outputFile.writeAsString('trimmed_video_content');
  }

  Future<void> _simulateAudioProcessing(File outputFile, AudioEffects effects,
      Function(double)? onProgress) async {
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress?.call(0.1 + (i * 0.1));
    }

    await outputFile.writeAsString('audio_processed_video');
  }

  Future<void> _simulateVisualProcessing(File outputFile,
      List<VisualEffect> effects, Function(double)? onProgress) async {
    for (int i = 0; i < 12; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress?.call(0.1 + (i * 0.07));
    }

    await outputFile.writeAsString('visual_effects_applied');
  }

  Future<void> _simulateTextProcessing(File outputFile,
      List<TextOverlay> textOverlays, Function(double)? onProgress) async {
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress?.call(0.1 + (i * 0.15));
    }

    await outputFile.writeAsString('text_overlay_added');
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
