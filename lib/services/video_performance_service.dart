import 'dart:async';
import 'dart:developer';
import 'package:video_player/video_player.dart';

/// Service to manage video performance and prevent memory leaks
class VideoPerformanceService {
  static final VideoPerformanceService _instance = VideoPerformanceService._internal();
  factory VideoPerformanceService() => _instance;
  VideoPerformanceService._internal();

  // Track active controllers to prevent memory leaks
  final Map<String, VideoPlayerController> _activeControllers = {};
  final Map<String, DateTime> _controllerTimestamps = {};
  final Set<String> _disposingControllers = {};

  // Performance settings
  static const int _maxConcurrentControllers = 3;
  static const Duration _controllerTimeout = Duration(seconds: 30);

  /// Get or create a video controller with performance optimizations
  Future<VideoPlayerController?> getController(String videoId, String videoUrl) async {
    try {
      // Check if already exists and is valid
      if (_activeControllers.containsKey(videoId)) {
        final controller = _activeControllers[videoId]!;
        if (controller.value.isInitialized) {
          _controllerTimestamps[videoId] = DateTime.now();
          return controller;
        } else {
          // Remove invalid controller
          await _disposeController(videoId);
        }
      }

      // Check if we're at capacity
      if (_activeControllers.length >= _maxConcurrentControllers) {
        await _evictOldestController();
      }

      // Create new controller
      log('🎬 Creating video controller for: $videoId');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize with timeout
      await controller.initialize().timeout(
        _controllerTimeout,
        onTimeout: () {
          log('⏰ Video controller initialization timeout for: $videoId');
          throw TimeoutException('Video initialization timeout', _controllerTimeout);
        },
      );

      // Store controller
      _activeControllers[videoId] = controller;
      _controllerTimestamps[videoId] = DateTime.now();

      log('✅ Video controller created successfully: $videoId');
      return controller;
    } catch (e) {
      log('❌ Error creating video controller for $videoId: $e');
      return null;
    }
  }

  /// Dispose a video controller safely
  Future<void> disposeController(String videoId) async {
    await _disposeController(videoId);
  }

  /// Internal method to dispose controller
  Future<void> _disposeController(String videoId) async {
    if (_disposingControllers.contains(videoId)) {
      return; // Already disposing
    }

    _disposingControllers.add(videoId);

    try {
      final controller = _activeControllers.remove(videoId);
      if (controller != null) {
        log('🗑️ Disposing video controller: $videoId');
        
        // Pause and dispose safely
        if (controller.value.isInitialized) {
          await controller.pause();
        }
        await controller.dispose();
        
        _controllerTimestamps.remove(videoId);
        log('✅ Video controller disposed: $videoId');
      }
    } catch (e) {
      log('❌ Error disposing video controller $videoId: $e');
    } finally {
      _disposingControllers.remove(videoId);
    }
  }

  /// Evict the oldest controller to make room
  Future<void> _evictOldestController() async {
    if (_activeControllers.isEmpty) return;

    String? oldestId;
    DateTime? oldestTime;

    for (final entry in _controllerTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestId = entry.key;
      }
    }

    if (oldestId != null) {
      log('🔄 Evicting oldest video controller: $oldestId');
      await _disposeController(oldestId);
    }
  }

  /// Clean up all controllers
  Future<void> disposeAll() async {
    log('🧹 Disposing all video controllers');
    
    final controllerIds = List<String>.from(_activeControllers.keys);
    for (final videoId in controllerIds) {
      await _disposeController(videoId);
    }
  }

  /// Get performance stats
  Map<String, dynamic> getPerformanceStats() {
    return {
      'activeControllers': _activeControllers.length,
      'maxControllers': _maxConcurrentControllers,
      'disposingControllers': _disposingControllers.length,
      'controllerIds': _activeControllers.keys.toList(),
    };
  }
}
