import 'dart:developer';
import 'package:video_player/video_player.dart';

/// Centralized Video Controller Registry - Single source of truth for all video controllers
///
/// All video controllers MUST be created via this registry.
/// Provides guaranteed safety checks and proper lifecycle management.
class VideoControllerRegistry {
  static final VideoControllerRegistry _instance =
      VideoControllerRegistry._internal();
  factory VideoControllerRegistry() => _instance;
  VideoControllerRegistry._internal();

  // Controller tracking
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _isVisible = {};
  final Map<String, bool> _isRegistered = {};

  /// Register a video controller - REQUIRED before any play/pause operations
  /// Returns true if registration successful, false if already registered
  bool register(String videoId, VideoPlayerController controller) {
    if (_isRegistered[videoId] == true) {
      log('⚠️ VideoControllerRegistry: Controller already registered for $videoId');
      return false;
    }

    _controllers[videoId] = controller;
    _isRegistered[videoId] = true;
    _isVisible[videoId] = false; // Start as hidden

    log('✅ VideoControllerRegistry: Registered controller for $videoId');
    return true;
  }

  /// Mark a video as visible (should be playing)
  void markVisible(String videoId) {
    if (!_isRegistered[videoId]!) {
      log('❌ VideoControllerRegistry: Cannot mark visible - not registered: $videoId');
      return;
    }

    _isVisible[videoId] = true;
    log('👁️ VideoControllerRegistry: Marked visible: $videoId');
  }

  /// Mark a video as hidden (should be paused)
  void markHidden(String videoId) {
    if (!_isRegistered[videoId]!) {
      log('❌ VideoControllerRegistry: Cannot mark hidden - not registered: $videoId');
      return;
    }

    _isVisible[videoId] = false;
    log('👁️ VideoControllerRegistry: Marked hidden: $videoId');
  }

  /// Check if controller is safe for play/pause operations
  bool isSafe(String videoId) {
    final isRegistered = _isRegistered[videoId] == true;
    final controller = _controllers[videoId];
    final isInitialized = controller?.value.isInitialized == true;
    final hasNoError = controller?.value.hasError != true;

    final isSafe = isRegistered && isInitialized && hasNoError;

    if (!isSafe) {
      log('⚠️ VideoControllerRegistry: Controller not safe for $videoId - registered: $isRegistered, initialized: $isInitialized, noError: $hasNoError');
    }

    return isSafe;
  }

  /// Get registered controller
  VideoPlayerController? getController(String videoId) {
    return _isRegistered[videoId] == true ? _controllers[videoId] : null;
  }

  /// Check if video is currently visible
  bool isVisible(String videoId) {
    return _isVisible[videoId] == true;
  }

  /// Dispose controller and remove from registry
  void dispose(String videoId) {
    final controller = _controllers[videoId];
    if (controller != null) {
      try {
        controller.dispose();
        log('🗑️ VideoControllerRegistry: Disposed controller for $videoId');
      } catch (e) {
        log('❌ VideoControllerRegistry: Error disposing controller for $videoId: $e');
      }
    }

    _controllers.remove(videoId);
    _isVisible.remove(videoId);
    _isRegistered.remove(videoId);
  }

  /// Get debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'registeredCount': _controllers.length,
      'visibleCount': _isVisible.values.where((v) => v).length,
      'controllers': _controllers.keys.toList(),
      'visible':
          _isVisible.entries.where((e) => e.value).map((e) => e.key).toList(),
    };
  }

  /// Cleanup all controllers (for testing)
  void cleanupAll() {
    final videoIds = _controllers.keys.toList();
    for (final videoId in videoIds) {
      dispose(videoId);
    }
    log('🧹 VideoControllerRegistry: Cleaned up all controllers');
  }
}
