import 'dart:developer';
import 'package:video_player/video_player.dart';

/// Service for managing a pool of video controllers for efficient memory usage
class VideoControllerPoolService {
  static final VideoControllerPoolService _instance = VideoControllerPoolService._internal();
  factory VideoControllerPoolService() => _instance;
  VideoControllerPoolService._internal();

  // Controller pool configuration
  static const int _maxControllers = 4; // Current, next, prev, standby

  // Controller pool state
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, DateTime> _controllerTimestamps = {};
  final Map<String, bool> _preparingControllers = {};
  final Set<String> _activeControllers = {};

  /// Prepare a controller for a video
  Future<void> prepareController(String videoId, String videoUrl) async {
    try {
      // Check if already exists
      if (_controllers.containsKey(videoId)) {
        return;
      }

      // Check pool capacity
      if (_controllers.length >= _maxControllers) {
        await _evictOldestController();
      }

      log('🎬 Preparing controller for: $videoId');
      _preparingControllers[videoId] = true;

      // Create and initialize controller
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize controller
      await controller.initialize();
      
      // Set to lowest quality for fast start
      await _setLowestQuality(controller);

      // Add to pool
      _controllers[videoId] = controller;
      _controllerTimestamps[videoId] = DateTime.now();
      _preparingControllers.remove(videoId);

      log('✅ Controller prepared: $videoId');
    } catch (e) {
      log('❌ Error preparing controller for $videoId: $e');
      _preparingControllers.remove(videoId);
      rethrow;
    }
  }

  /// Get controller for video (creates if not exists)
  Future<VideoPlayerController?> getController(String videoId, String videoUrl) async {
    try {
      // Return existing controller
      if (_controllers.containsKey(videoId)) {
        _activeControllers.add(videoId);
        return _controllers[videoId];
      }

      // Prepare new controller
      await prepareController(videoId, videoUrl);
      _activeControllers.add(videoId);
      return _controllers[videoId];
    } catch (e) {
      log('❌ Error getting controller for $videoId: $e');
      return null;
    }
  }

  /// Release controller (mark as inactive)
  void releaseController(String videoId) {
    _activeControllers.remove(videoId);
    log('🔓 Released controller: $videoId');
  }

  /// Evict controllers outside the current window
  Future<void> evictOutsideWindow({
    required int center,
    required int radius,
  }) async {
    try {
      final videoIds = _controllers.keys.toList();
      final evictCandidates = <String>[];

      for (final videoId in videoIds) {
        // Parse video index from ID (assuming sequential IDs)
        final videoIndex = int.tryParse(videoId) ?? 0;
        final distance = (videoIndex - center).abs();

        // Evict if outside window and not active
        if (distance > radius && !_activeControllers.contains(videoId)) {
          evictCandidates.add(videoId);
        }
      }

      // Evict candidates
      for (final videoId in evictCandidates) {
        await _evictController(videoId);
      }

      if (evictCandidates.isNotEmpty) {
        log('🗑️ Evicted ${evictCandidates.length} controllers outside window');
      }
    } catch (e) {
      log('❌ Error evicting controllers: $e');
    }
  }

  /// Evict the oldest controller
  Future<void> _evictOldestController() async {
    try {
      if (_controllers.isEmpty) return;

      // Find oldest inactive controller
      String? oldestVideoId;
      DateTime? oldestTimestamp;

      for (final entry in _controllerTimestamps.entries) {
        final videoId = entry.key;
        final timestamp = entry.value;

        // Skip active controllers
        if (_activeControllers.contains(videoId)) continue;

        if (oldestTimestamp == null || timestamp.isBefore(oldestTimestamp)) {
          oldestTimestamp = timestamp;
          oldestVideoId = videoId;
        }
      }

      if (oldestVideoId != null) {
        await _evictController(oldestVideoId);
      }
    } catch (e) {
      log('❌ Error evicting oldest controller: $e');
    }
  }

  /// Evict a specific controller
  Future<void> _evictController(String videoId) async {
    try {
      final controller = _controllers.remove(videoId);
      _controllerTimestamps.remove(videoId);
      _activeControllers.remove(videoId);
      _preparingControllers.remove(videoId);

      if (controller != null) {
        await controller.dispose();
        log('🗑️ Evicted controller: $videoId');
      }
    } catch (e) {
      log('❌ Error evicting controller $videoId: $e');
    }
  }

  /// Cancel preparation of a controller
  Future<void> cancelPreparation(String videoId) async {
    try {
      _preparingControllers.remove(videoId);
      
      // If controller was created but not yet added to pool, dispose it
      final controller = _controllers.remove(videoId);
      if (controller != null) {
        await controller.dispose();
      }
      
      log('❌ Cancelled controller preparation: $videoId');
    } catch (e) {
      log('❌ Error cancelling controller preparation: $e');
    }
  }

  /// Set controller to lowest quality for fast start
  Future<void> _setLowestQuality(VideoPlayerController controller) async {
    try {
      // For HLS, this would set the lowest quality track
      // For now, just ensure the controller is ready
      if (controller.value.isInitialized) {
        // Set volume to 0 for autoplay compliance
        await controller.setVolume(0.0);
        log('🔇 Set controller to muted for autoplay');
      }
    } catch (e) {
      log('❌ Error setting lowest quality: $e');
    }
  }

  /// Get controller pool statistics
  Map<String, dynamic> getPoolStats() {
    return {
      'totalControllers': _controllers.length,
      'activeControllers': _activeControllers.length,
      'preparingControllers': _preparingControllers.length,
      'maxControllers': _maxControllers,
      'controllerIds': _controllers.keys.toList(),
      'activeIds': _activeControllers.toList(),
    };
  }

  /// Dispose all controllers
  Future<void> dispose() async {
    try {
      for (final controller in _controllers.values) {
        await controller.dispose();
      }
      
      _controllers.clear();
      _controllerTimestamps.clear();
      _preparingControllers.clear();
      _activeControllers.clear();
      
      log('🧹 Disposed all controllers');
    } catch (e) {
      log('❌ Error disposing controllers: $e');
    }
  }
}
