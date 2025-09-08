import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'music_library_service.dart';

enum VideoFilter {
  none('None', ''),
  vintage('Vintage', 'curves=vintage'),
  blackWhite('B&W', 'hue=s=0'),
  sepia('Sepia', 'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131'),
  cool('Cool', 'colorbalance=rs=0.3:gs=-0.3:bs=0.3'),
  warm('Warm', 'colorbalance=rs=-0.3:gs=0.3:bs=-0.3'),
  bright('Bright', 'eq=brightness=0.2'),
  dark('Dark', 'eq=brightness=-0.2'),
  blur('Blur', 'boxblur=2:1'),
  sharpen('Sharpen', 'unsharp=5:5:0.8:3:3:0.4'),
  contrast('High Contrast', 'eq=contrast=1.5'),
  saturation('High Saturation', 'eq=saturation=1.5'),
  ;

  const VideoFilter(this.displayName, this.ffmpegFilter);
  final String displayName;
  final String ffmpegFilter;
}

class VideoProcessingResult {
  final bool success;
  final String? outputPath;
  final String? error;
  final Duration? duration;
  final int? fileSize;

  VideoProcessingResult({
    required this.success,
    this.outputPath,
    this.error,
    this.duration,
    this.fileSize,
  });
}

class VideoProcessingProgress {
  final double progress; // 0.0 to 1.0
  final String message;
  final int? timeInMs;

  VideoProcessingProgress({
    required this.progress,
    required this.message,
    this.timeInMs,
  });
}

class VideoProcessingService {
  static final VideoProcessingService _instance = VideoProcessingService._internal();
  factory VideoProcessingService() => _instance;
  VideoProcessingService._internal();

  final StreamController<VideoProcessingProgress> _progressController = 
      StreamController<VideoProcessingProgress>.broadcast();
  
  Stream<VideoProcessingProgress> get progressStream => _progressController.stream;

  /// Trim video to specified start and end times
  Future<VideoProcessingResult> trimVideo({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
    String? outputPath,
  }) async {
    try {
      outputPath ??= await _generateOutputPath(inputPath, 'trimmed');
      
      // Simulate processing time
      _progressController.add(VideoProcessingProgress(
        progress: 0.0,
        message: 'Starting video trimming...',
      ));
      
      // Simulate progress
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        _progressController.add(VideoProcessingProgress(
          progress: i / 10.0,
          message: 'Trimming video... ${(i * 10)}%',
        ));
      }
      
      // Copy the file (placeholder for FFmpeg implementation)
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);
      await inputFile.copy(outputPath);
      
      _progressController.add(VideoProcessingProgress(
        progress: 1.0,
        message: 'Video trimming completed!',
      ));
      
      return VideoProcessingResult(
        success: true,
        outputPath: outputPath,
        fileSize: await outputFile.length(),
      );
    } catch (e) {
      return VideoProcessingResult(
        success: false,
        error: 'Failed to trim video: $e',
      );
    }
  }

  /// Apply video filter effects
  Future<VideoProcessingResult> applyFilter({
    required String inputPath,
    required VideoFilter filter,
    String? outputPath,
  }) async {
    try {
      if (filter == VideoFilter.none) {
        return VideoProcessingResult(success: true, outputPath: inputPath);
      }
      
      outputPath ??= await _generateOutputPath(inputPath, 'filtered');
      
      // Simulate processing time
      _progressController.add(VideoProcessingProgress(
        progress: 0.0,
        message: 'Applying ${filter.displayName} filter...',
      ));
      
      // Simulate progress
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        _progressController.add(VideoProcessingProgress(
          progress: i / 10.0,
          message: 'Processing filter... ${(i * 10)}%',
        ));
      }
      
      // Copy the file (placeholder for FFmpeg implementation)
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);
      await inputFile.copy(outputPath);
      
      _progressController.add(VideoProcessingProgress(
        progress: 1.0,
        message: 'Filter applied successfully!',
      ));
      
      return VideoProcessingResult(
        success: true,
        outputPath: outputPath,
        fileSize: await outputFile.length(),
      );
    } catch (e) {
      return VideoProcessingResult(
        success: false,
        error: 'Failed to apply filter: $e',
      );
    }
  }

  /// Add text overlay to video
  Future<VideoProcessingResult> addTextOverlay({
    required String inputPath,
    required String text,
    required int x,
    required int y,
    String? fontColor,
    int? fontSize,
    String? outputPath,
  }) async {
    try {
      outputPath ??= await _generateOutputPath(inputPath, 'text_overlay');
      
      // Simulate processing time
      _progressController.add(VideoProcessingProgress(
        progress: 0.0,
        message: 'Adding text overlay...',
      ));
      
      // Simulate progress
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        _progressController.add(VideoProcessingProgress(
          progress: i / 10.0,
          message: 'Processing text overlay... ${(i * 10)}%',
        ));
      }
      
      // Copy the file (placeholder for FFmpeg implementation)
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);
      await inputFile.copy(outputPath);
      
      _progressController.add(VideoProcessingProgress(
        progress: 1.0,
        message: 'Text overlay added successfully!',
      ));
      
      return VideoProcessingResult(
        success: true,
        outputPath: outputPath,
        fileSize: await outputFile.length(),
      );
    } catch (e) {
      return VideoProcessingResult(
        success: false,
        error: 'Failed to add text overlay: $e',
      );
    }
  }

  /// Add background music to video
  Future<VideoProcessingResult> addBackgroundMusic({
    required String inputPath,
    required String musicPath,
    double? musicVolume,
    String? outputPath,
  }) async {
    try {
      outputPath ??= await _generateOutputPath(inputPath, 'with_music');
      
      // Simulate processing time
      _progressController.add(VideoProcessingProgress(
        progress: 0.0,
        message: 'Adding background music...',
      ));
      
      // Simulate progress
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        _progressController.add(VideoProcessingProgress(
          progress: i / 10.0,
          message: 'Mixing audio... ${(i * 10)}%',
        ));
      }
      
      // Copy the file (placeholder for FFmpeg implementation)
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);
      await inputFile.copy(outputPath);
      
      _progressController.add(VideoProcessingProgress(
        progress: 1.0,
        message: 'Background music added successfully!',
      ));
      
      return VideoProcessingResult(
        success: true,
        outputPath: outputPath,
        fileSize: await outputFile.length(),
      );
    } catch (e) {
      return VideoProcessingResult(
        success: false,
        error: 'Failed to add background music: $e',
      );
    }
  }

  /// Add background music from MusicTrack
  Future<VideoProcessingResult> addMusicTrack({
    required String inputPath,
    required dynamic musicTrack, // Using dynamic to avoid circular import
    double? musicVolume,
    String? outputPath,
  }) async {
    try {
      // Download the music track first
      final musicService = MusicLibraryService();
      final downloadedPath = await musicService.downloadTrack(musicTrack);
      
      if (downloadedPath == null) {
        return VideoProcessingResult(
          success: false,
          error: 'Failed to download music track',
        );
      }
      
      // Add the downloaded music to the video
      return await addBackgroundMusic(
        inputPath: inputPath,
        musicPath: downloadedPath,
        musicVolume: musicVolume,
        outputPath: outputPath,
      );
    } catch (e) {
      return VideoProcessingResult(
        success: false,
        error: 'Failed to add music track: $e',
      );
    }
  }

  /// Combine multiple video clips
  Future<VideoProcessingResult> combineVideos({
    required List<String> inputPaths,
    String? outputPath,
  }) async {
    try {
      outputPath ??= await _generateOutputPath(inputPaths.first, 'combined');
      
      // Simulate processing time
      _progressController.add(VideoProcessingProgress(
        progress: 0.0,
        message: 'Combining videos...',
      ));
      
      // Simulate progress
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        _progressController.add(VideoProcessingProgress(
          progress: i / 10.0,
          message: 'Merging clips... ${(i * 10)}%',
        ));
      }
      
      // For now, just copy the first file as a placeholder
      final inputFile = File(inputPaths.first);
      final outputFile = File(outputPath);
      await inputFile.copy(outputPath);
      
      _progressController.add(VideoProcessingProgress(
        progress: 1.0,
        message: 'Videos combined successfully!',
      ));
      
      return VideoProcessingResult(
        success: true,
        outputPath: outputPath,
        fileSize: await outputFile.length(),
      );
    } catch (e) {
      return VideoProcessingResult(
        success: false,
        error: 'Failed to combine videos: $e',
      );
    }
  }

  /// Resize video to specific dimensions
  Future<VideoProcessingResult> resizeVideo({
    required String inputPath,
    required int width,
    required int height,
    String? outputPath,
  }) async {
    try {
      outputPath ??= await _generateOutputPath(inputPath, 'resized');
      
      // Simulate processing time
      _progressController.add(VideoProcessingProgress(
        progress: 0.0,
        message: 'Resizing video...',
      ));
      
      // Simulate progress
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        _progressController.add(VideoProcessingProgress(
          progress: i / 10.0,
          message: 'Scaling video... ${(i * 10)}%',
        ));
      }
      
      // Copy the file (placeholder for FFmpeg implementation)
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);
      await inputFile.copy(outputPath);
      
      _progressController.add(VideoProcessingProgress(
        progress: 1.0,
        message: 'Video resized successfully!',
      ));
      
      return VideoProcessingResult(
        success: true,
        outputPath: outputPath,
        fileSize: await outputFile.length(),
      );
    } catch (e) {
      return VideoProcessingResult(
        success: false,
        error: 'Failed to resize video: $e',
      );
    }
  }

  /// Get video information
  Future<Map<String, dynamic>> getVideoInfo(String inputPath) async {
    try {
      final file = File(inputPath);
      if (await file.exists()) {
        final fileSize = await file.length();
        return {
          'duration': 0, // Would be calculated with FFmpeg
          'width': 0,    // Would be calculated with FFmpeg
          'height': 0,   // Would be calculated with FFmpeg
          'bitrate': 0,  // Would be calculated with FFmpeg
          'fps': 0,      // Would be calculated with FFmpeg
          'fileSize': fileSize,
        };
      } else {
        return {
          'error': 'File does not exist',
        };
      }
    } catch (e) {
      return {
        'error': 'Failed to get video info: $e',
      };
    }
  }

  /// Generate output path for processed video
  Future<String> _generateOutputPath(String inputPath, String suffix) async {
    final tempDir = await getTemporaryDirectory();
    final inputFile = File(inputPath);
    final fileName = path.basenameWithoutExtension(inputFile.path);
    final extension = path.extension(inputFile.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    return path.join(
      tempDir.path,
      '${fileName}_${suffix}_$timestamp$extension',
    );
  }

  /// Clean up temporary files
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      for (final file in files) {
        if (file is File && (file.path.contains('_trimmed_') || 
            file.path.contains('_filtered_') || 
            file.path.contains('_text_overlay_') ||
            file.path.contains('_with_music_') ||
            file.path.contains('_combined_') ||
            file.path.contains('_resized_'))) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error cleaning up temp files: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}