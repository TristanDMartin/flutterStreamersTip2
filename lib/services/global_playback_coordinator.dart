import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Global Playback Coordinator - Single source of truth for audio playback
///
/// Ensures only one video/audio source plays at any time in the app.
/// Handles tab switching, route changes, and modal overlays.
class GlobalPlaybackCoordinator {
  static final GlobalPlaybackCoordinator _instance =
      GlobalPlaybackCoordinator._internal();
  factory GlobalPlaybackCoordinator() => _instance;
  GlobalPlaybackCoordinator._internal();

  // State management
  String? _activeOwner;
  String? _activeVideoId;
  final Map<String, VideoPlayerController> _registeredControllers = {};
  final Map<String, String> _controllerOwners = {}; // videoId -> owner
  bool _isPlaybackBlocked = false;
  String? _blockReason;

  // Stream controllers for real-time updates
  final StreamController<String?> _activeOwnerController =
      StreamController<String?>.broadcast();
  final StreamController<bool> _playbackBlockedController =
      StreamController<bool>.broadcast();
  final StreamController<String?> _activeVideoIdController =
      StreamController<String?>.broadcast();

  // Getters
  String? get activeOwner => _activeOwner;
  String? get activeVideoId => _activeVideoId;
  bool get isPlaybackBlocked => _isPlaybackBlocked;
  String? get blockReason => _blockReason;

  // Streams for listening to changes
  Stream<String?> get activeOwnerStream => _activeOwnerController.stream;
  Stream<bool> get playbackBlockedStream => _playbackBlockedController.stream;
  Stream<String?> get activeVideoIdStream => _activeVideoIdController.stream;

  /// Register a video controller with the coordinator
  void registerController(
      String videoId, VideoPlayerController controller, String owner) {
    _registeredControllers[videoId] = controller;
    _controllerOwners[videoId] = owner;

    if (kDebugMode) {
      debugPrint(
          '🎵 PlaybackCoordinator: Registered $videoId for owner $owner');
    }
  }

  /// Unregister a video controller
  void unregisterController(String videoId) {
    _registeredControllers.remove(videoId);
    _controllerOwners.remove(videoId);

    // If this was the active controller, clear it
    if (_activeVideoId == videoId) {
      _clearActiveFocus();
    }

    if (kDebugMode) {
      debugPrint('🎵 PlaybackCoordinator: Unregistered $videoId');
    }
  }

  /// Request focus for a specific video
  /// This will pause all other videos and grant focus to the requester
  Future<void> requestFocus(String videoId, String owner) async {
    if (kDebugMode) {
      debugPrint(
          '🎵 PlaybackCoordinator: Requesting focus for $videoId from $owner');
    }

    // Don't allow focus if playback is blocked
    if (_isPlaybackBlocked) {
      if (kDebugMode) {
        debugPrint('🎵 PlaybackCoordinator: Focus blocked - $blockReason');
      }
      return;
    }

    // Pause all other controllers
    await _pauseAllExcept(videoId);

    // Set active focus
    _activeOwner = owner;
    _activeVideoId = videoId;

    // Notify listeners
    _activeOwnerController.add(_activeOwner);
    _activeVideoIdController.add(_activeVideoId);

    if (kDebugMode) {
      debugPrint(
          '🎵 PlaybackCoordinator: Focus granted to $videoId from $owner');
    }
  }

  /// Relinquish focus (typically when a video goes offscreen)
  void relinquishFocus(String videoId) {
    if (_activeVideoId == videoId) {
      if (kDebugMode) {
        debugPrint('🎵 PlaybackCoordinator: Relinquishing focus for $videoId');
      }
      _clearActiveFocus();
    }
  }

  /// Pause all videos
  Future<void> pauseAll({String? reason}) async {
    if (kDebugMode) {
      debugPrint(
          '🎵 PlaybackCoordinator: Pausing all videos - reason: ${reason ?? "unknown"}');
    }

    _isPlaybackBlocked = true;
    _blockReason = reason;
    _playbackBlockedController.add(true);

    await _pauseAllControllers();
    _clearActiveFocus();
  }

  /// Resume playback (unblock)
  void resumePlayback() {
    if (kDebugMode) {
      debugPrint('🎵 PlaybackCoordinator: Resuming playback');
    }

    _isPlaybackBlocked = false;
    _blockReason = null;
    _playbackBlockedController.add(false);
  }

  /// Pause all videos except the specified one
  Future<void> pauseAllExcept(String owner) async {
    if (kDebugMode) {
      debugPrint('🎵 PlaybackCoordinator: Pausing all except owner $owner');
    }

    // Find controllers that don't belong to the specified owner
    final controllersToPause = <String>[];
    for (final entry in _controllerOwners.entries) {
      if (entry.value != owner) {
        controllersToPause.add(entry.key);
      }
    }

    // Pause those controllers
    for (final videoId in controllersToPause) {
      final controller = _registeredControllers[videoId];
      if (controller != null) {
        try {
          if (controller.value.isInitialized && !controller.value.hasError) {
            await controller.pause();
            await controller.setVolume(0.0);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('🎵 PlaybackCoordinator: Error pausing $videoId: $e');
          }
        }
      }
    }

    // Clear active focus if it's not from the specified owner
    if (_activeOwner != owner) {
      _clearActiveFocus();
    }
  }

  /// Handle route changes
  Future<void> onRouteChange(String? newOwner, bool isForeground) async {
    if (kDebugMode) {
      debugPrint(
          '🎵 PlaybackCoordinator: Route change - newOwner: $newOwner, isForeground: $isForeground');
    }

    if (!isForeground) {
      // Route is going away, pause all
      await pauseAll(reason: 'routeChange');
    } else {
      // Route is becoming foreground, resume playback
      resumePlayback();
    }
  }

  /// Check if a specific video can play
  bool canPlay(String videoId, String owner) {
    if (_isPlaybackBlocked) {
      return false;
    }

    // Only allow if this video has focus or no video has focus
    return _activeVideoId == null || _activeVideoId == videoId;
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'activeOwner': _activeOwner,
      'activeVideoId': _activeVideoId,
      'isPlaybackBlocked': _isPlaybackBlocked,
      'blockReason': _blockReason,
      'registeredControllers': _registeredControllers.keys.toList(),
      'controllerOwners': Map.from(_controllerOwners),
    };
  }

  /// Log current state for debugging
  void logCurrentState() {
    if (kDebugMode) {
      debugPrint('🎵 PlaybackCoordinator State:');
      debugPrint('  - Active Owner: $_activeOwner');
      debugPrint('  - Active Video ID: $_activeVideoId');
      debugPrint('  - Playback Blocked: $_isPlaybackBlocked');
      debugPrint('  - Block Reason: $_blockReason');
      debugPrint(
          '  - Registered Controllers: ${_registeredControllers.keys.toList()}');
      debugPrint('  - Controller Owners: $_controllerOwners');
    }
  }

  /// Pause all registered controllers
  Future<void> _pauseAllControllers() async {
    for (final entry in _registeredControllers.entries) {
      final controller = entry.value;
      try {
        if (controller.value.isInitialized && !controller.value.hasError) {
          await controller.pause();
          await controller.setVolume(0.0);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('🎵 PlaybackCoordinator: Error pausing ${entry.key}: $e');
        }
      }
    }
  }

  /// Pause all controllers except the specified one
  Future<void> _pauseAllExcept(String excludeVideoId) async {
    for (final entry in _registeredControllers.entries) {
      if (entry.key != excludeVideoId) {
        final controller = entry.value;
        try {
          if (controller.value.isInitialized && !controller.value.hasError) {
            await controller.pause();
            await controller.setVolume(0.0);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '🎵 PlaybackCoordinator: Error pausing ${entry.key}: $e');
          }
        }
      }
    }
  }

  /// Clear active focus
  void _clearActiveFocus() {
    _activeOwner = null;
    _activeVideoId = null;
    _activeOwnerController.add(null);
    _activeVideoIdController.add(null);
  }

  /// Dispose the coordinator
  void dispose() {
    _activeOwnerController.close();
    _playbackBlockedController.close();
    _activeVideoIdController.close();
    _registeredControllers.clear();
    _controllerOwners.clear();
  }
}
