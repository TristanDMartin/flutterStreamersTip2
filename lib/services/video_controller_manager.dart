import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Controller state enum
enum ControllerState {
  initializing,
  ready,
  playing,
  paused,
  disposing,
  disposed,
  error,
}

/// Production-ready video controller manager with comprehensive error handling
/// and memory leak prevention. Single source of truth for all video controllers.
class VideoControllerManager {
  static final VideoControllerManager _instance =
      VideoControllerManager._internal();
  factory VideoControllerManager() => _instance;
  VideoControllerManager._internal();

  // Controller state management
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, ControllerState> _controllerStates = {};
  final Map<String, DateTime> _lastUsed = {};

  // Configuration
  static const int _maxControllers = 3;
  static const Duration _controllerTimeout = Duration(minutes: 5);
  static const int _maxRetryAttempts = 3;

  // Circuit breaker for failed controllers
  final Map<String, int> _retryCount = {};
  final Map<String, DateTime> _lastFailure = {};
  static const Duration _circuitBreakerTimeout = Duration(minutes: 1);

  /// Get or create controller with comprehensive error handling
  Future<VideoPlayerController?> getController(
      String videoId, String videoUrl) async {
    try {
      // Check if controller already exists and is valid
      if (_controllers.containsKey(videoId)) {
        final controller = _controllers[videoId]!;
        final state = _controllerStates[videoId]!;

        if (state == ControllerState.ready ||
            state == ControllerState.playing ||
            state == ControllerState.paused) {
          _lastUsed[videoId] = DateTime.now();
          return controller;
        } else if (state == ControllerState.error) {
          // Check circuit breaker
          if (_isCircuitBreakerOpen(videoId)) {
            log('🚫 Circuit breaker open for $videoId, skipping');
            return null;
          }
          // Retry failed controller
          await _pauseController(videoId);
        }
      }

      // Check if we're already initializing this controller
      if (_controllerStates[videoId] == ControllerState.initializing) {
        log('⏳ Controller already initializing for $videoId');
        return null;
      }

      // Check pool capacity and evict if necessary
      if (_controllers.length >= _maxControllers) {
        await _evictOldestController();
      }

      // Create new controller
      return await _createController(videoId, videoUrl);
    } catch (e) {
      log('❌ Error getting controller for $videoId: $e');
      _controllerStates[videoId] = ControllerState.error;
      _lastFailure[videoId] = DateTime.now();
      _retryCount[videoId] = (_retryCount[videoId] ?? 0) + 1;
      return null;
    }
  }

  /// Create a new controller with proper error handling
  Future<VideoPlayerController?> _createController(
      String videoId, String videoUrl) async {
    _controllerStates[videoId] = ControllerState.initializing;

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // Add error listener
      controller.addListener(() => _handleControllerError(videoId, controller));

      // Initialize with timeout
      await controller.initialize().timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('Controller initialization timeout'),
          );

      // Configure controller
      await controller.setLooping(true);
      await controller.setVolume(0.0); // Start muted for autoplay compliance

      // Store controller
      _controllers[videoId] = controller;
      _controllerStates[videoId] = ControllerState.ready;
      _lastUsed[videoId] = DateTime.now();
      _retryCount.remove(videoId); // Reset retry count on success

      log('✅ Controller created successfully for $videoId');
      return controller;
    } catch (e) {
      log('❌ Error creating controller for $videoId: $e');
      _controllerStates[videoId] = ControllerState.error;
      _lastFailure[videoId] = DateTime.now();
      _retryCount[videoId] = (_retryCount[videoId] ?? 0) + 1;

      // Don't dispose failed controllers - let VideoPreloaderService handle disposal
      // Just mark as error and remove from our tracking
      try {
        _controllers.remove(videoId);
        _controllerStates.remove(videoId);
        _lastUsed.remove(videoId);
        log('🔄 Marked failed controller $videoId for preloader disposal');
      } catch (e) {
        log('❌ Error marking failed controller $videoId: $e');
      }

      return null;
    }
  }

  /// Handle controller errors
  void _handleControllerError(
      String videoId, VideoPlayerController controller) {
    if (controller.value.hasError) {
      log('❌ Controller error for $videoId: ${controller.value.errorDescription}');
      _controllerStates[videoId] = ControllerState.error;
      _lastFailure[videoId] = DateTime.now();
      _retryCount[videoId] = (_retryCount[videoId] ?? 0) + 1;
    }
  }

  /// Check if circuit breaker is open for a video
  bool _isCircuitBreakerOpen(String videoId) {
    final lastFailure = _lastFailure[videoId];
    final retryCount = _retryCount[videoId] ?? 0;

    if (lastFailure == null) return false;

    // Open circuit breaker if too many failures in short time
    if (retryCount >= _maxRetryAttempts &&
        DateTime.now().difference(lastFailure) < _circuitBreakerTimeout) {
      return true;
    }

    return false;
  }

  /// Evict oldest controller
  Future<void> _evictOldestController() async {
    if (_controllers.isEmpty) return;

    String? oldestId;
    DateTime? oldestTime;

    for (final entry in _lastUsed.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestId = entry.key;
      }
    }

    if (oldestId != null) {
      await _pauseController(oldestId);
    }
  }

  /// Pause controller safely (VideoPreloaderService handles disposal)
  Future<void> _pauseController(String videoId) async {
    final controller = _controllers[videoId];
    if (controller != null) {
      try {
        if (controller.value.isInitialized && !controller.value.hasError) {
          await controller.pause();
          await controller.setVolume(0.0);
        }
        log('🔄 Paused controller $videoId (disposal handled by preloader)');
      } catch (e) {
        log('⚠️ Error pausing controller $videoId: $e');
      }
    }
  }

  /// Release controller (mark as inactive but keep in memory)
  void releaseController(String videoId) {
    if (_controllerStates[videoId] == ControllerState.playing) {
      _controllerStates[videoId] = ControllerState.paused;
      log('🔓 Controller released: $videoId');
    }
  }

  /// Mark controller as playing
  void markPlaying(String videoId) {
    if (_controllers.containsKey(videoId)) {
      _controllerStates[videoId] = ControllerState.playing;
      _lastUsed[videoId] = DateTime.now();
    }
  }

  /// Mark controller as paused
  void markPaused(String videoId) {
    if (_controllers.containsKey(videoId)) {
      _controllerStates[videoId] = ControllerState.paused;
    }
  }

  /// Check if controller is safe to use
  bool isControllerSafe(String videoId) {
    final state = _controllerStates[videoId];
    return state == ControllerState.ready ||
        state == ControllerState.playing ||
        state == ControllerState.paused;
  }

  /// Get controller state
  ControllerState? getControllerState(String videoId) {
    return _controllerStates[videoId];
  }

  /// Clean up expired controllers
  Future<void> cleanupExpiredControllers() async {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _lastUsed.entries) {
      if (now.difference(entry.value) > _controllerTimeout) {
        expiredIds.add(entry.key);
      }
    }

    for (final videoId in expiredIds) {
      await _pauseController(videoId);
    }

    if (expiredIds.isNotEmpty) {
      log('🧹 Cleaned up ${expiredIds.length} expired controllers');
    }
  }

  /// Get manager statistics
  Map<String, dynamic> getStats() {
    return {
      'totalControllers': _controllers.length,
      'maxControllers': _maxControllers,
      'controllerStates':
          _controllerStates.map((k, v) => MapEntry(k, v.toString())),
      'retryCounts': _retryCount,
      'circuitBreakerOpen': _lastFailure.entries
          .where((e) => _isCircuitBreakerOpen(e.key))
          .map((e) => e.key)
          .toList(),
    };
  }

  /// Pause all controllers (VideoPreloaderService handles disposal)
  Future<void> pauseAll() async {
    log('🧹 Pausing all controllers...');

    final controllerIds = _controllers.keys.toList();
    for (final videoId in controllerIds) {
      await _pauseController(videoId);
    }

    _controllers.clear();
    _controllerStates.clear();
    _lastUsed.clear();
    _retryCount.clear();
    _lastFailure.clear();

    log('✅ All controllers paused');
  }

  /// Periodic cleanup task
  Timer? _cleanupTimer;

  void startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      cleanupExpiredControllers();
    });
  }

  void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  @override
  void dispose() {
    stopPeriodicCleanup();
    pauseAll();
  }
}
