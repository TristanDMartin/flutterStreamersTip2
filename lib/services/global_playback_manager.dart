import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Enhanced Global Playback Manager - Single source of truth for video playback
///
/// Combines best features from:
/// - GlobalPlaybackCoordinator (blocking, streams, owner tracking)
/// - GlobalPlaybackManager (simple API, tab switch handling)
///
/// Features:
/// - ✅ Exactly one video plays at a time
/// - ✅ Nestable blocking for navigation
/// - ✅ Real-time state updates via streams
/// - ✅ Owner/tab tracking
/// - ✅ Proper cleanup and disposal
/// - ✅ Prevents audio bleeding
class GlobalPlaybackManager {
  static GlobalPlaybackManager? _instance;
  static GlobalPlaybackManager get instance =>
      _instance ??= GlobalPlaybackManager._();

  GlobalPlaybackManager._();

  // ============================================
  // STATE MANAGEMENT
  // ============================================

  /// Currently active video ID
  String? _activeVideoId;

  /// Currently active owner (tab ID, view name, etc.)
  String? _activeOwner;

  /// Pool of video controllers keyed by video ID
  final Map<String, VideoPlayerController> _controllerPool = {};

  /// Owner tracking: videoId -> owner mapping
  final Map<String, String> _controllerOwners = {};

  /// Mute state tracking: videoId -> isMuted
  final Map<String, bool> _muteStates = {};

  /// Disposal tracking: videoId -> isDisposed
  final Map<String, bool> _disposedControllers = {};

  /// Whether we're in a paused state (tab switching, etc.)
  bool _isPaused = false;

  // ============================================
  // BLOCKING SYSTEM (from Coordinator)
  // ============================================

  /// Block level for nestable blocking (0 = unblocked, >0 = blocked)
  int _blockLevel = 0;

  /// Reason for current block
  String? _blockReason;

  // ============================================
  // STREAMS (from Coordinator)
  // ============================================

  /// Stream controller for active video changes
  final StreamController<String?> _activeVideoController =
      StreamController<String?>.broadcast();

  /// Stream controller for active owner changes
  final StreamController<String?> _activeOwnerController =
      StreamController<String?>.broadcast();

  /// Stream controller for blocked state changes
  final StreamController<bool> _playbackBlockedController =
      StreamController<bool>.broadcast();

  // ============================================
  // GETTERS
  // ============================================

  /// Get the currently active video ID
  String? get activeVideoId => _activeVideoId;

  /// Get the currently active owner
  String? get activeOwner => _activeOwner;

  /// Check if a video ID is currently active
  bool isActive(String videoId) => _activeVideoId == videoId;

  /// Check if we're in a paused state
  bool get isPaused => _isPaused;

  /// Check if playback is blocked
  bool get isPlaybackBlocked => _blockLevel > 0;

  /// Get current block level
  int get blockLevel => _blockLevel;

  /// Get current block reason
  String? get blockReason => _blockReason;

  /// Check if a controller is safe to use (not disposed and valid)
  bool _isControllerSafe(String videoId, VideoPlayerController controller) {
    // Check if already marked as disposed
    if (_disposedControllers[videoId] == true) {
      return false;
    }

    // Check if controller is valid
    return controller.value.isInitialized && !controller.value.hasError;
  }

  // ============================================
  // STREAMS
  // ============================================

  /// Stream of active video ID changes
  Stream<String?> get activeVideoStream => _activeVideoController.stream;

  /// Stream of active owner changes
  Stream<String?> get activeOwnerStream => _activeOwnerController.stream;

  /// Stream of blocked state changes
  Stream<bool> get playbackBlockedStream => _playbackBlockedController.stream;

  // ============================================
  // CORE METHODS
  // ============================================

  /// Activate a specific video (pause all others, play this one)
  /// Only works if not blocked
  void activate(String videoId, {String? owner}) {
    log('🎵 PlaybackManager: Activating video $videoId (owner: $owner)');

    // Don't activate if blocked
    if (_blockLevel > 0) {
      log('🚫 PlaybackManager: Activation BLOCKED (level: $_blockLevel) - reason: $_blockReason');
      return;
    }

    if (_activeVideoId == videoId) {
      log('🎵 PlaybackManager: Video $videoId already active');
      return;
    }

    // Pause all videos first
    pauseAll();

    // Set new active video and owner
    _activeVideoId = videoId;
    if (owner != null) {
      _activeOwner = owner;
      _activeOwnerController.add(_activeOwner);
    }
    _activeVideoController.add(_activeVideoId);

    // Play the new video
    final controller = _controllerPool[videoId];
    if (controller != null) {
      try {
        // 🔒 SAFETY: Check if controller is safe to use
        if (_isControllerSafe(videoId, controller)) {
          controller.setVolume(1.0); // Unmute
          _muteStates[videoId] = false;
          controller.play();
          log('🎵 PlaybackManager: Playing video $videoId');
        } else {
          log('⚠️ PlaybackManager: Controller for video $videoId is not safe to use');
        }
      } catch (e) {
        log('❌ PlaybackManager: Error playing video $videoId: $e');
      }
    } else {
      log('⚠️ PlaybackManager: No controller found for video $videoId');
    }
  }

  /// Request focus for a specific video (pause all others)
  /// Alias for activate() with owner tracking
  Future<void> requestFocus(String videoId, String owner) async {
    log('🎯 PlaybackManager: Requesting focus for $videoId from $owner');
    activate(videoId, owner: owner);
  }

  /// Pause all videos and mute them
  void pauseAll() {
    log('⏸️ PlaybackManager: Pausing all videos');

    for (final entry in _controllerPool.entries) {
      final controller = entry.value;
      try {
        // 🔒 SAFETY: Check if controller is safe to use
        if (_isControllerSafe(entry.key, controller)) {
          controller.setVolume(0.0); // Mute
          _muteStates[entry.key] = true;
          controller.pause();
          log('⏸️ PlaybackManager: Paused video ${entry.key}');
        } else {
          log('⚠️ PlaybackManager: Controller for video ${entry.key} is not safe to use');
        }
      } catch (e) {
        log('❌ PlaybackManager: Error pausing video ${entry.key}: $e');
      }
    }
  }

  // ============================================
  // BLOCKING SYSTEM (from Coordinator)
  // ============================================

  /// Block playback (nestable)
  /// Call this when navigating away or during tab switches
  void block({String? reason}) {
    _blockLevel++;
    _blockReason = reason ?? 'manual_block';

    log('🚫 PlaybackManager: BLOCKED (level: $_blockLevel) - reason: $_blockReason');

    // Pause all videos when blocking
    pauseAll();

    // Notify listeners
    _playbackBlockedController.add(true);
  }

  /// Unblock playback (nestable)
  /// Call this when returning from navigation or finishing tab switch
  void unblock() {
    if (_blockLevel > 0) {
      _blockLevel--;

      log('✅ PlaybackManager: UNBLOCKED (level: $_blockLevel)');

      if (_blockLevel == 0) {
        _blockReason = null;
        _playbackBlockedController.add(false);
        log('🎯 PlaybackManager: FULLY UNBLOCKED - ready for playback');
      }
    } else {
      log('⚠️ PlaybackManager: unblock() called but blockLevel is already 0');
    }
  }

  // ============================================
  // CONTROLLER MANAGEMENT
  // ============================================

  /// Register a controller for a video ID
  void registerController(String videoId, VideoPlayerController controller,
      {String? owner}) {
    log('📝 PlaybackManager: Registering controller for video $videoId (owner: $owner)');
    _controllerPool[videoId] = controller;
    _muteStates[videoId] = true; // Start muted

    if (owner != null) {
      _controllerOwners[videoId] = owner;
    }
  }

  /// Unregister a controller for a video ID
  void unregisterController(String videoId) {
    log('🗑️ PlaybackManager: Unregistering controller for video $videoId');

    // If this was the active video, clear it
    if (_activeVideoId == videoId) {
      _activeVideoId = null;
      _activeVideoController.add(null);

      // Clear owner if it was this video's owner
      final owner = _controllerOwners[videoId];
      if (owner == _activeOwner) {
        _activeOwner = null;
        _activeOwnerController.add(null);
      }
    }

    final controller = _controllerPool.remove(videoId);
    _controllerOwners.remove(videoId);
    _muteStates.remove(videoId);

    if (controller != null) {
      try {
        // 🔒 SAFETY: Check if controller is safe to dispose
        if (_isControllerSafe(videoId, controller)) {
          controller.dispose();
          _disposedControllers[videoId] = true; // Mark as disposed
          log('🗑️ PlaybackManager: Disposed controller for video $videoId');
        } else {
          log('⚠️ PlaybackManager: Controller for video $videoId already disposed or invalid');
        }
      } catch (e) {
        log('❌ PlaybackManager: Error disposing controller for video $videoId: $e');
      }
    }
  }

  /// Dispose all controllers and clear state (for tab switches)
  void disposeAll() {
    log('🚨 PlaybackManager: Disposing all controllers');

    for (final entry in _controllerPool.entries) {
      try {
        final controller = entry.value;
        // 🔒 SAFETY: Check if controller is safe to dispose
        if (_isControllerSafe(entry.key, controller)) {
          controller.dispose();
          _disposedControllers[entry.key] = true; // Mark as disposed
          log('🗑️ PlaybackManager: Disposed controller for video ${entry.key}');
        } else {
          log('⚠️ PlaybackManager: Controller for video ${entry.key} already disposed or invalid');
        }
      } catch (e) {
        log('❌ PlaybackManager: Error disposing controller for video ${entry.key}: $e');
      }
    }

    _controllerPool.clear();
    _controllerOwners.clear();
    _muteStates.clear();
    _disposedControllers.clear();
    _activeVideoId = null;
    _activeOwner = null;
    _isPaused = false;

    // Notify listeners
    _activeVideoController.add(null);
    _activeOwnerController.add(null);

    log('✅ PlaybackManager: All controllers disposed and state cleared');
  }

  // ============================================
  // TAB SWITCH HANDLING
  // ============================================

  /// Pause all and set paused state (for tab switching)
  void pauseAllForTabSwitch() {
    log('🔄 PlaybackManager: Pausing all for tab switch');
    _isPaused = true;
    pauseAll();
  }

  /// Resume playback after tab switch
  void resumeAfterTabSwitch() {
    log('▶️ PlaybackManager: Resuming after tab switch');
    _isPaused = false;

    // First, try to resume the active video if we have one and not blocked
    if (_activeVideoId != null && _blockLevel == 0) {
      final controller = _controllerPool[_activeVideoId];
      if (controller != null) {
        try {
          // 🔒 SAFETY: Check if controller is safe to use
          if (_isControllerSafe(_activeVideoId!, controller)) {
            controller.setVolume(1.0);
            _muteStates[_activeVideoId!] = false;
            controller.play();
            log('▶️ PlaybackManager: Resumed active video $_activeVideoId');
            return; // Successfully resumed active video
          } else {
            log('⚠️ PlaybackManager: Active video controller $_activeVideoId is not valid');
          }
        } catch (e) {
          log('❌ PlaybackManager: Error resuming active video $_activeVideoId: $e');
        }
      }
    }

    // If active video couldn't be resumed, find any valid video to resume
    log('🔄 PlaybackManager: Active video failed, looking for any valid video to resume...');
    for (final entry in _controllerPool.entries) {
      final videoId = entry.key;
      final controller = entry.value;

      try {
        if (_isControllerSafe(videoId, controller) &&
            !controller.value.isPlaying) {
          // Found a valid paused video, resume it
          controller.setVolume(1.0);
          _muteStates[videoId] = false;
          controller.play();
          _activeVideoId = videoId; // Update active video
          log('▶️ PlaybackManager: Resumed fallback video $videoId');
          return;
        }
      } catch (e) {
        log('❌ PlaybackManager: Error resuming fallback video $videoId: $e');
      }
    }

    log('⚠️ PlaybackManager: No valid videos found to resume');
  }

  // ============================================
  // DEBUGGING
  // ============================================

  /// Get current state for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      'activeVideoId': _activeVideoId,
      'activeOwner': _activeOwner,
      'isPaused': _isPaused,
      'blockLevel': _blockLevel,
      'blockReason': _blockReason,
      'controllerCount': _controllerPool.length,
      'controllerKeys': _controllerPool.keys.toList(),
      'owners': _controllerOwners,
    };
  }

  /// Log current state for debugging
  void logCurrentState() {
    final info = getDebugInfo();
    log('🎵 PlaybackManager State: $info');
  }

  /// Clean up streams (call when app is closing)
  void dispose() {
    _activeVideoController.close();
    _activeOwnerController.close();
    _playbackBlockedController.close();
    disposeAll();
  }
}

/// Riverpod provider for the global playback manager
final globalPlaybackManagerProvider = Provider<GlobalPlaybackManager>((ref) {
  return GlobalPlaybackManager.instance;
});
