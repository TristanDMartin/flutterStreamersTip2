import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import '../models/home_video.dart';
import '../constants/playback_owners.dart';

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
  // TIKTOK-STYLE INDEX-BASED TRACKING
  // ============================================

  /// Current feed index (for TikTok-style vertical feed)
  int? _currentFeedIndex;

  /// Last known playback positions per index
  final Map<int, Duration> _lastKnownPositions = {};

  /// Index to videoId mapping
  final Map<int, String> _indexToVideoId = {};

  /// VideoId to index mapping
  final Map<String, int> _videoIdToIndex = {};

  /// Configuration
  static const int poolRadius = 1; // previous, current, next
  static const int recoveryTimeoutMs = 5000;
  static const int maxControllerPoolSize =
      3; // 🔥 CRITICAL: Reduced from 5 to 3 to prevent OutOfMemoryErrors

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
  ///
  /// **Purpose:**
  /// Prevents crashes from accessing disposed VideoPlayerController instances.
  /// This is critical for preventing "Controller was disposed" errors.
  ///
  /// **Safety Checks:**
  /// 1. Checks if controller is already marked as disposed in tracking map
  /// 2. Attempts to access controller.value (throws if disposed)
  /// 3. Verifies controller is initialized and has no errors
  ///
  /// **Error Handling:**
  /// - If controller.value access throws, marks controller as disposed
  /// - Returns false for any unsafe controller
  /// - Logs warnings for debugging
  ///
  /// **Parameters:**
  /// - [videoId]: Video ID for tracking disposed controllers
  /// - [controller]: The VideoPlayerController to check
  ///
  /// **Returns:**
  /// - `true` if controller is safe to use (initialized, no errors, not disposed)
  /// - `false` if controller is disposed, uninitialized, or has errors
  ///
  /// **Usage:**
  /// Always call this before accessing controller.value or calling controller methods.
  bool _isControllerSafe(String videoId, VideoPlayerController controller) {
    // Check if already marked as disposed
    if (_disposedControllers[videoId] == true) {
      return false;
    }

    // 🔒 SAFETY: Try to access controller value - if it throws, controller is disposed
    try {
      // Check if controller is valid
      final value = controller.value;
      return value.isInitialized && !value.hasError;
    } catch (e) {
      // Controller is disposed - mark it and return false
      log('⚠️ PlaybackManager: Controller for video $videoId is disposed: $e');
      _disposedControllers[videoId] = true;
      return false;
    }
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
  // SINGLE ACTIVE OWNER MODEL
  // ============================================

  /// Set the active owner and pause/mute all non-active owners
  ///
  /// **Purpose:**
  /// Implements the "single active owner" model where only one view can play
  /// audio at a time. When switching views, this pauses and mutes all videos
  /// from other owners, then allows the new owner's videos to play.
  ///
  /// **Behavior:**
  /// 1. Pauses and mutes all videos from non-active owners
  /// 2. Sets the new active owner
  /// 3. Notifies listeners via activeOwnerStream
  ///
  /// **Parameters:**
  /// - [owner]: The owner key (e.g., 'home', 'discover', 'player', 'profile')
  void setActiveOwner(String owner) {
    log('🎯 PlaybackManager: Setting active owner to: $owner');

    // Pause and mute all videos from non-active owners
    final entries = List<MapEntry<String, VideoPlayerController>>.from(
        _controllerPool.entries);
    for (final entry in entries) {
      final videoId = entry.key;
      final controllerOwner = _controllerOwners[videoId];

      // 🔥 SINGLE ACTIVE OWNER: Check if this video belongs to a different owner
      // Use hierarchical matching: 'home/forYou' matches 'home', but 'discover' doesn't match 'home'
      final belongsToActiveOwner = controllerOwner != null &&
          (controllerOwner == owner || controllerOwner.startsWith('$owner/'));

      if (!belongsToActiveOwner) {
        try {
          if (_isControllerSafe(videoId, entry.value)) {
            entry.value.setVolume(0.0);
            _muteStates[videoId] = true;
            if (entry.value.value.isInitialized) {
              entry.value.pause();
            }
            log('⏸️ PlaybackManager: Paused and muted video $videoId (owner: $controllerOwner, activeOwner: $owner)');
          }
        } catch (e) {
          log('⚠️ PlaybackManager: Error pausing non-active owner video: $e');
        }
      }
    }

    // Set new active owner
    _activeOwner = owner;
    _activeOwnerController.add(_activeOwner);

    log('✅ PlaybackManager: Active owner set to: $owner');
  }

  /// Check if a specific owner can play audio
  ///
  /// **Purpose:**
  /// Returns true only if the given owner matches the active owner and playback
  /// is not blocked. This prevents non-active owners from playing audio.
  ///
  /// **Hierarchical Owners:**
  /// Supports hierarchical owners (e.g., 'home/forYou' matches 'home').
  /// If activeOwner is 'home', then 'home/forYou' and 'home/following' can play.
  ///
  /// **Parameters:**
  /// - [owner]: The owner key to check (e.g., 'home', 'home/forYou', 'discover')
  ///
  /// **Returns:**
  /// - `true` if owner matches active owner (or is a sub-owner) and playback is not blocked
  /// - `false` if owner doesn't match or playback is blocked
  bool canPlay(String owner) {
    if (_blockLevel > 0) {
      log('🚫 PlaybackManager: Owner $owner cannot play (blocked, level: $_blockLevel)');
      return false;
    }

    if (_activeOwner == null) {
      log('🚫 PlaybackManager: Owner $owner cannot play (no active owner set)');
      return false;
    }

    // Check exact match or hierarchical match (e.g., 'home/forYou' matches 'home')
    final ownerMatches =
        owner == _activeOwner || owner.startsWith('$_activeOwner/');
    if (!ownerMatches) {
      log('🚫 PlaybackManager: Owner $owner cannot play (activeOwner: $_activeOwner)');
      return false;
    }

    return true;
  }

  // ============================================
  // CORE METHODS
  // ============================================

  /// Activate a specific video (pause all others, play this one)
  ///
  /// This is the core method for video playback control. It ensures only one video
  /// plays at a time by pausing all other videos before activating the requested one.
  ///
  /// **Behavior:**
  /// - If playback is blocked (blockLevel > 0), the video is muted but not played
  /// - If the video is already active, ensures it's playing and unmuted
  /// - Otherwise, pauses all videos, sets this as active, and plays it
  ///
  /// **Audio Management:**
  /// - All other videos are muted and paused before activating new one
  /// - Prevents audio bleeding between videos
  /// - Updates mute state tracking for proper cleanup
  ///
  /// **Safety:**
  /// - Checks if controller is safe to use before operations
  /// - Handles disposed controllers gracefully
  /// - Updates active video streams for real-time listeners
  ///
  /// **Parameters:**
  /// - [videoId]: The ID of the video to activate
  /// - [owner]: Optional owner identifier (tab ID, view name) for tracking
  ///
  /// **Throws:** Nothing (all errors are caught and logged)
  void activate(String videoId, {String? owner}) {
    log('🎵 PlaybackManager: Activating video $videoId (owner: $owner)');

    // 🔥 SINGLE ACTIVE OWNER: Check if owner can play before activating
    if (owner != null && !canPlay(owner)) {
      log('🚫 PlaybackManager: Owner $owner cannot play (activeOwner: $_activeOwner, blockLevel: $_blockLevel)');
      // Mute and pause if owner is not active
      final controller = _controllerPool[videoId];
      if (controller != null && _isControllerSafe(videoId, controller)) {
        try {
          controller.setVolume(0.0);
          _muteStates[videoId] = true;
          if (controller.value.isInitialized) {
            controller.pause();
          }
          log('🔇 PlaybackManager: Muted and paused non-active owner video $videoId');
        } catch (e) {
          log('⚠️ PlaybackManager: Error muting non-active owner video: $e');
        }
      }
      return;
    }

    // Don't activate if blocked
    if (_blockLevel > 0) {
      log('🚫 PlaybackManager: Activation BLOCKED (level: $_blockLevel) - reason: $_blockReason');
      // 🔥 AUDIO FIX: Ensure this controller is muted if blocked
      final controller = _controllerPool[videoId];
      if (controller != null && _isControllerSafe(videoId, controller)) {
        try {
          controller.setVolume(0.0);
          _muteStates[videoId] = true;
          log('🔇 PlaybackManager: Muted blocked video $videoId');
        } catch (e) {
          log('⚠️ PlaybackManager: Error muting blocked video: $e');
        }
      }
      return;
    }

    if (_activeVideoId == videoId) {
      log('🎵 PlaybackManager: Video $videoId already active - checking if it should play');
      // Even if already active, check if it's actually playing
      // If user manually paused it, don't auto-resume
      final controller = _controllerPool[videoId];
      if (controller != null && _isControllerSafe(videoId, controller)) {
        try {
          // Only unmute and play if the controller is actually playing
          // If user manually paused, the controller should be paused and muted
          if (controller.value.isPlaying) {
            controller.setVolume(1.0);
            _muteStates[videoId] = false;
            log('🎵 PlaybackManager: Active video is playing - ensuring unmuted');
          } else {
            // Video is paused - keep it muted to prevent audio bleeding
            controller.setVolume(0.0);
            _muteStates[videoId] = true;
            log('🔇 PlaybackManager: Active video is paused - keeping muted');
          }
        } catch (e) {
          log('⚠️ PlaybackManager: Error checking active video state: $e');
        }
      }
      return;
    }

    // 🔊 AUDIO FIX: Pause all videos first (this mutes them too)
    // 🔥 CRITICAL: This must complete before playing new video to prevent audio bleeding
    pauseAll();

    // Set new active video (but NOT active owner - that's only set by setActiveOwner())
    _activeVideoId = videoId;
    // 🔥 SINGLE ACTIVE OWNER: Don't set _activeOwner here - only setActiveOwner() should do that
    // The owner parameter is just for tracking which owner this video belongs to
    if (owner != null) {
      _controllerOwners[videoId] = owner; // Track owner for this video
    }
    _activeVideoController.add(_activeVideoId);

    // Play the new video
    final controller = _controllerPool[videoId];
    if (controller != null) {
      try {
        // 🔒 SAFETY: Check if controller is safe to use
        if (_isControllerSafe(videoId, controller)) {
          try {
            // 🔥 AUDIO FIX: Ensure all other videos are muted before unmuting this one
            // Double-check that pauseAll() completed (all videos should be muted)
            // This prevents race conditions where old video might resume

            controller.setVolume(1.0); // Unmute
            _muteStates[videoId] = false;

            // ✅ FIX: Only play if not already playing to prevent restart
            if (!controller.value.isPlaying) {
              controller.play();
              log('🎵 PlaybackManager: Playing video $videoId');
            } else {
              log('🎵 PlaybackManager: Video $videoId already playing, skipping play() call');
            }
          } catch (e) {
            log('❌ PlaybackManager: Error playing video $videoId (controller disposed): $e');
            _disposedControllers[videoId] = true;
            _controllerPool.remove(videoId);
          }
        } else {
          log('⚠️ PlaybackManager: Controller for video $videoId is not safe to use');
        }
      } catch (e) {
        log('❌ PlaybackManager: Error accessing controller for video $videoId: $e');
        _disposedControllers[videoId] = true;
        _controllerPool.remove(videoId);
      }
    } else {
      log('⚠️ PlaybackManager: No controller found for video $videoId');
      log('🔄 PlaybackManager: VideoPlayerViewOptimized will reinitialize controller');
    }
  }

  /// Request focus for a specific video (pause all others)
  /// Alias for activate() with owner tracking
  /// 🔥 SINGLE ACTIVE OWNER: Checks canPlay() before activating
  Future<void> requestFocus(String videoId, String owner) async {
    log('🎯 PlaybackManager: Requesting focus for $videoId from $owner');

    // 🔥 SINGLE ACTIVE OWNER: Check if owner can play before requesting focus
    if (!canPlay(owner)) {
      log('🚫 PlaybackManager: Owner $owner cannot play, not requesting focus (activeOwner: $_activeOwner, blockLevel: $_blockLevel)');
      // Still pause all videos to prevent audio bleeding
      pauseAll();
      return;
    }

    // 🔥 AUDIO FIX: Validate controller exists before activating
    final controller = _controllerPool[videoId];
    if (controller == null || !_isControllerSafe(videoId, controller)) {
      log('⚠️ PlaybackManager: Controller not found or unsafe for $videoId');
      log('🔄 PlaybackManager: Controller will be reinitialized by VideoPlayerViewOptimized');
      // Don't fail silently - log the issue
      // VideoPlayerViewOptimized will detect and reinitialize via didUpdateWidget
      // Still pause all videos to prevent audio bleeding from other videos
      pauseAll();
      return;
    }

    activate(videoId, owner: owner);
  }

  /// Pause all videos and mute them
  ///
  /// 🔥 CRITICAL: This mutes ALL videos to prevent audio bleeding
  ///
  /// **Purpose:**
  /// Ensures no audio plays from any video controller, preventing audio bleeding
  /// when navigating between views or switching tabs.
  ///
  /// **Execution Order (Critical for Audio Fix):**
  /// 1. Mutes all controllers FIRST (prevents audio bleeding)
  /// 2. Then pauses all controllers (stops playback)
  /// 3. Updates mute state tracking
  ///
  /// **Safety:**
  /// - Creates a copy of controller pool to avoid modification during iteration
  /// - Checks if each controller is safe before operations
  /// - Handles disposed controllers gracefully
  /// - Removes disposed controllers from pool
  ///
  /// **Performance:**
  /// - Iterates through all registered controllers
  /// - Logs count of paused/muted videos for debugging
  ///
  /// **Usage:**
  /// Called before activating a new video, during tab switches, or when blocking playback.
  void pauseAll() {
    log('⏸️ PlaybackManager: Pausing and muting ALL videos');
    logTelemetry('pause_all', reason: 'pauseAll');

    int pausedCount = 0;
    int mutedCount = 0;

    // 🔥 AUDIO FIX: Create a copy of entries to avoid modification during iteration
    final entries = List<MapEntry<String, VideoPlayerController>>.from(
        _controllerPool.entries);

    for (final entry in entries) {
      final controller = entry.value;
      try {
        // 🔒 SAFETY: Check if controller is safe to use
        if (_isControllerSafe(entry.key, controller)) {
          try {
            // 🔊 AUDIO FIX: Mute FIRST to prevent audio bleeding (critical!)
            controller.setVolume(0.0);
            _muteStates[entry.key] = true;
            mutedCount++;

            // Then pause
            if (controller.value.isInitialized) {
              controller.pause();
              pausedCount++;
            }

            log('⏸️ PlaybackManager: Paused and muted video ${entry.key}');
          } catch (e) {
            log('❌ PlaybackManager: Error pausing video ${entry.key} (controller disposed): $e');
            _disposedControllers[entry.key] = true;
            _controllerPool.remove(entry.key);
          }
        } else {
          log('⚠️ PlaybackManager: Controller for video ${entry.key} is not safe to use');
        }
      } catch (e) {
        log('❌ PlaybackManager: Error pausing video ${entry.key}: $e');
      }
    }

    log('✅ PlaybackManager: Paused $pausedCount videos, muted $mutedCount videos');
  }

  // ============================================
  // BLOCKING SYSTEM (from Coordinator)
  // ============================================

  /// Block playback (nestable)
  ///
  /// Prevents any video from playing until unblocked. Supports nested blocking
  /// (e.g., camera view blocks, then modal blocks on top of that).
  ///
  /// **How Nesting Works:**
  /// - Each call increments blockLevel (1, 2, 3, ...)
  /// - Each unblock() decrements blockLevel
  /// - Playback only resumes when blockLevel reaches 0
  ///
  /// **Use Cases:**
  /// - Navigating to camera view (blockLevel = 1)
  /// - Opening modal over camera (blockLevel = 2)
  /// - Closing modal (blockLevel = 1)
  /// - Closing camera (blockLevel = 0, playback resumes)
  ///
  /// **Behavior:**
  /// - Immediately pauses all videos
  /// - Updates blocked state stream
  /// - Stores reason for debugging
  ///
  /// **Parameters:**
  /// - [reason]: Optional reason for blocking (e.g., 'camera', 'modal', 'tab_switch')
  ///
  /// **Example:**
  /// ```dart
  /// playbackManager.block(reason: 'camera');  // Level 1
  /// playbackManager.block(reason: 'modal');  // Level 2
  /// playbackManager.unblock();               // Level 1
  /// playbackManager.unblock();               // Level 0 (unblocked)
  /// ```
  void block({String? reason}) {
    _blockLevel++;
    _blockReason = reason ?? 'manual_block';

    log('🚫 PlaybackManager: BLOCKED (level: $_blockLevel) - reason: $_blockReason');
    logTelemetry('block', reason: _blockReason);

    // Pause all videos when blocking
    pauseAll();

    // Notify listeners
    _playbackBlockedController.add(true);
  }

  /// Unblock playback (nestable)
  ///
  /// Decrements the block level. Playback only resumes when blockLevel reaches 0.
  ///
  /// **How Nesting Works:**
  /// - Each block() increments blockLevel
  /// - Each unblock() decrements blockLevel
  /// - Playback resumes only when blockLevel == 0
  ///
  /// **Behavior:**
  /// - Decrements blockLevel (if > 0)
  /// - When blockLevel reaches 0, clears block reason and notifies listeners
  /// - Does nothing if already unblocked (blockLevel == 0)
  ///
  /// **Use Cases:**
  /// - Returning from camera view
  /// - Closing modals
  /// - Completing tab switches
  ///
  /// **Example:**
  /// ```dart
  /// playbackManager.block(reason: 'camera');  // Level 1
  /// playbackManager.block(reason: 'modal');   // Level 2
  /// playbackManager.unblock();                // Level 1 (still blocked)
  /// playbackManager.unblock();                // Level 0 (unblocked, playback can resume)
  /// ```
  void unblock() {
    if (_blockLevel > 0) {
      _blockLevel--;

      log('✅ PlaybackManager: UNBLOCKED (level: $_blockLevel)');
      logTelemetry('unblock');

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
  /// Register a controller for a video ID
  ///
  /// **Purpose:**
  /// Registers a VideoPlayerController with the playback manager so it can be
  /// controlled centrally. This enables the "only one video plays at a time" behavior.
  ///
  /// **Behavior:**
  /// - Adds controller to internal pool for centralized management
  /// - Tracks owner (tab/view) for debugging and cleanup
  /// - If playback is blocked, immediately mutes and pauses the controller
  /// - If playback is not blocked, ensures controller is muted initially
  ///
  /// **Audio Management:**
  /// - New controllers are always muted initially to prevent audio bleeding
  /// - If blocked, controller is muted and paused immediately
  /// - Mute state is tracked for proper cleanup
  ///
  /// **Safety:**
  /// - Checks if controller is safe before operations
  /// - Handles errors gracefully
  /// - Updates owner tracking for debugging
  ///
  /// **Parameters:**
  /// - [videoId]: Unique identifier for the video
  /// - [controller]: The VideoPlayerController instance to register
  /// - [owner]: Optional owner identifier (tab ID, view name) for tracking
  ///
  /// **Usage:**
  /// Call this when creating a new VideoPlayerController, typically in initState
  /// or when initializing a video player widget.
  ///
  /// **Example:**
  /// ```dart
  /// final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
  /// await controller.initialize();
  /// GlobalPlaybackManager.instance.registerController(
  ///   videoId,
  ///   controller,
  ///   owner: 'home/forYou',
  /// );
  /// ```
  void registerController(String videoId, VideoPlayerController controller,
      {String? owner}) {
    log('📝 PlaybackManager: Registering controller for video $videoId (owner: $owner)');

    // 🔥 CRITICAL MEMORY FIX: Enforce maximum pool size to prevent MediaCodec NO_MEMORY errors
    // If pool is full, dispose the oldest non-active controller BEFORE adding new one
    if (_controllerPool.length >= maxControllerPoolSize &&
        !_controllerPool.containsKey(videoId)) {
      log('⚠️ PlaybackManager: Pool size limit reached (${_controllerPool.length}), disposing oldest controllers before adding new one');
      _disposeOldestController();
      // Double-check after disposal
      if (_controllerPool.length >= maxControllerPoolSize) {
        log('⚠️ PlaybackManager: Pool still full after disposal, disposing more aggressively');
        _disposeOldestController();
      }
    }

    _controllerPool[videoId] = controller;

    // 🔥 AUDIO FIX: Always start muted and ensure muted if blocked
    try {
      if (_isControllerSafe(videoId, controller)) {
        controller.setVolume(0.0);
        _muteStates[videoId] = true;
        // Also pause if blocked
        if (_blockLevel > 0) {
          controller.pause();
          log('🔇 PlaybackManager: Registered controller is muted and paused (blocked)');
        } else {
          log('🔇 PlaybackManager: Registered controller is muted (will unmute on activate)');
        }
      }
    } catch (e) {
      log('⚠️ PlaybackManager: Error muting controller during registration: $e');
      _muteStates[videoId] = true; // Still mark as muted in state
    }

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

      // 🔥 SINGLE ACTIVE OWNER: Don't clear _activeOwner here - it should only be cleared
      // when the view itself is disposed, not when individual videos are unregistered.
      // The active owner persists across video changes within the same view.
      // Only clear if ALL videos for this owner are gone (handled by disposeControllersForOwner)
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

  /// Dispose controllers for a specific owner (e.g., when category feed closes)
  /// 🔥 CRITICAL MEMORY FIX: Prevents MediaCodec NO_MEMORY errors
  void disposeControllersForOwner(String owner) {
    log('🗑️ PlaybackManager: Disposing controllers for owner: $owner');

    final toDispose = <String>[];
    for (final entry in _controllerOwners.entries) {
      if (entry.value == owner) {
        toDispose.add(entry.key);
      }
    }

    // 🔥 SINGLE ACTIVE OWNER: If disposing all controllers for the active owner, clear active owner
    final isDisposingActiveOwner = _activeOwner != null &&
        (_activeOwner == owner || owner.startsWith('$_activeOwner/'));

    for (final videoId in toDispose) {
      log('🗑️ PlaybackManager: Disposing controller for video $videoId (owner: $owner)');
      unregisterController(videoId);
    }

    // Clear active owner if we disposed all controllers for it
    if (isDisposingActiveOwner) {
      // Check if there are any remaining controllers for this owner
      final hasRemainingControllers = _controllerOwners.values
          .any((o) => o == owner || o.startsWith('$owner/'));

      if (!hasRemainingControllers) {
        log('🗑️ PlaybackManager: All controllers for active owner $owner disposed, clearing active owner');
        _activeOwner = null;
        _activeOwnerController.add(null);
      }
    }

    log('✅ PlaybackManager: Disposed ${toDispose.length} controllers for owner: $owner');
  }

  /// Dispose the oldest non-active controller to make room
  /// 🔥 CRITICAL MEMORY FIX: Prevents MediaCodec NO_MEMORY errors
  void _disposeOldestController() {
    // 🔥 AGGRESSIVE CLEANUP: Dispose multiple controllers if pool is too large
    final targetSize = maxControllerPoolSize - 1; // Keep one slot free
    if (_controllerPool.length <= targetSize) {
      return; // Pool is already small enough
    }

    final toDispose = <String>[];
    final disposeCount = _controllerPool.length - targetSize;

    // Collect oldest non-active controllers
    for (final entry in _controllerPool.entries) {
      if (toDispose.length >= disposeCount) break;
      if (entry.key != _activeVideoId) {
        final controller = entry.value;
        if (_isControllerSafe(entry.key, controller)) {
          toDispose.add(entry.key);
        }
      }
    }

    // Dispose collected controllers
    for (final videoId in toDispose) {
      log('🗑️ PlaybackManager: Disposing oldest controller: $videoId (pool size: ${_controllerPool.length})');
      unregisterController(videoId);
      // Clean up index mappings
      final index = _videoIdToIndex[videoId];
      if (index != null) {
        _videoIdToIndex.remove(videoId);
        _indexToVideoId.remove(index);
        _lastKnownPositions.remove(index);
      }
    }

    log('✅ PlaybackManager: Disposed ${toDispose.length} controllers, pool size now: ${_controllerPool.length}');
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
  /// ⚠️ DEPRECATED: Use setActiveOwner() instead for proper single active owner model
  void resumeAfterTabSwitch() {
    log('▶️ PlaybackManager: Resuming after tab switch');
    _isPaused = false;

    // 🔥 SINGLE ACTIVE OWNER: Check if active video's owner can play before resuming
    if (_activeVideoId != null && _blockLevel == 0) {
      final videoOwner = _controllerOwners[_activeVideoId];
      if (videoOwner != null && !canPlay(videoOwner)) {
        log('🚫 PlaybackManager: Cannot resume - owner $videoOwner is not active (activeOwner: $_activeOwner)');
        return;
      }

      final controller = _controllerPool[_activeVideoId];
      if (controller != null &&
          _isControllerSafe(_activeVideoId!, controller)) {
        try {
          controller.setVolume(1.0);
          _muteStates[_activeVideoId!] = false;
          if (!controller.value.isPlaying) {
            controller.play();
            log('▶️ PlaybackManager: Resumed active video $_activeVideoId');
          } else {
            log('▶️ PlaybackManager: Active video $_activeVideoId already playing');
          }
        } catch (e) {
          log('⚠️ PlaybackManager: Error resuming active video: $e');
        }
      } else {
        log('⚠️ PlaybackManager: Active video controller not available, waiting for focus request');
      }
    } else {
      log('🎵 PlaybackManager: No active video or blocked, waiting for focus request');
    }
  }

  /// Get a controller for a video ID (if it exists in the pool)
  /// Get controller for a video ID
  /// 🔒 SAFETY: Returns null if controller is disposed or unsafe
  VideoPlayerController? getController(String videoId) {
    final controller = _controllerPool[videoId];
    if (controller == null) return null;

    // Check if controller is safe before returning
    if (!_isControllerSafe(videoId, controller)) {
      log('⚠️ PlaybackManager: Controller for $videoId is unsafe, removing from pool');
      _controllerPool.remove(videoId);
      _disposedControllers[videoId] = true;
      return null;
    }

    return controller;
  }

  /// Check if a controller exists and is safe to use
  bool hasController(String videoId) {
    final controller = _controllerPool[videoId];
    if (controller == null) return false;
    return _isControllerSafe(videoId, controller);
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

  // ============================================
  // TELEMETRY (lightweight)
  // ============================================

  void logTelemetry(String event,
      {String? videoId, String? owner, String? reason, double? volume}) {
    log('🎧 PlaybackTelemetry: event=$event '
        'video=$videoId owner=$owner '
        'blocked=$_blockLevel reason=${reason ?? _blockReason} '
        'volume=$volume');
  }

  // ============================================
  // TIKTOK-STYLE FEED MANAGEMENT
  // ============================================

  /// Called when user enters HomeView
  /// 🎯 SINGLE ACTIVE OWNER: Uses setActiveOwner instead of unblock
  void onEnterHomeView() {
    log('🏠 PlaybackManager: Entering HomeView');
    // 🎯 SINGLE ACTIVE OWNER: Set home as active owner (handles unblocking and pausing non-active owners)
    setActiveOwner(PlaybackOwners.home);

    // 🚀 TIKTOK-STYLE: Instantly request focus for current video (no delay)
    if (_currentFeedIndex != null) {
      log('📺 PlaybackManager: Current index is $_currentFeedIndex');
      final videoId = _indexToVideoId[_currentFeedIndex];
      if (videoId != null) {
        log('🎵 PlaybackManager: Requesting focus for video $videoId at index $_currentFeedIndex on HomeView entry');
        requestFocus(videoId, 'home/feed');
      }
    }
  }

  /// Called when user leaves HomeView
  void onLeaveHomeView() {
    log('🚪 PlaybackManager: Leaving HomeView');
    _saveCurrentPosition();
    pauseAll();
    block(reason: 'leftHomeView');
  }

  /// Called when visible index changes in vertical feed
  void onVisibleIndexChanged(int newIndex, HomeVideo video) {
    // 🔒 SAFETY: Validate inputs before processing
    if (newIndex < 0) {
      log('⚠️ PlaybackManager: Invalid index $newIndex, ignoring');
      return;
    }

    if (video.id.isEmpty || video.videoURL.isEmpty) {
      log('⚠️ PlaybackManager: Invalid video object, ignoring index change');
      return;
    }

    log('📺 PlaybackManager: Visible index changed to $newIndex (video: ${video.id})');

    try {
      // Save previous position
      if (_currentFeedIndex != null) {
        _savePositionForIndex(_currentFeedIndex!);
      }

      // Update current index and mappings
      _currentFeedIndex = newIndex;
      _indexToVideoId[newIndex] = video.id;
      _videoIdToIndex[video.id] = newIndex;
    } catch (e) {
      log('❌ PlaybackManager: Error updating index mappings: $e');
      return; // Exit early on error
    }

    // ✅ FIX: Removed immediate cleanup - causes freezes by disposing controllers during index change
    // Cleanup happens in preloadAround() after frame completes, which is safer

    // 🔥 CRITICAL AUDIO FIX: Pause and mute ALL videos FIRST (including manually paused ones)
    // This ensures no audio bleeding when switching videos
    pauseAll();

    // 🔥 ADDITIONAL SAFETY: Force mute all controllers again to catch any that might have been missed
    // This is a double-check to prevent audio bleeding
    final entries = List<MapEntry<String, VideoPlayerController>>.from(
        _controllerPool.entries);
    for (final entry in entries) {
      try {
        if (_isControllerSafe(entry.key, entry.value)) {
          entry.value.setVolume(0.0);
          _muteStates[entry.key] = true;
        }
      } catch (e) {
        log('⚠️ PlaybackManager: Error force-muting video ${entry.key}: $e');
      }
    }

    // Ensure controller is ready, then request focus (not direct play)
    // This lets VideoPlayerViewOptimized handle the actual playback to avoid duplicate play calls
    ensureControllerReady(newIndex, video).then((_) {
      try {
        // Seek to last position if available (before requesting focus)
        final controller = getControllerForIndex(newIndex);
        if (controller != null && _isControllerSafe(video.id, controller)) {
          try {
            final lastPos = _lastKnownPositions[newIndex];
            if (lastPos != null && lastPos > Duration.zero) {
              controller.seekTo(lastPos).catchError((e) {
                log('⚠️ PlaybackManager: Error seeking to last position: $e');
              });
            }
          } catch (e) {
            log('⚠️ PlaybackManager: Error seeking in onVisibleIndexChanged: $e');
          }
        }

        // Request focus instead of direct play - VideoPlayerViewOptimized will handle playback
        // This prevents duplicate play calls that cause video restart
        requestFocus(video.id, 'home/feed');
        log('🎯 PlaybackManager: Requested focus for video at index $newIndex');
      } catch (e) {
        log('❌ PlaybackManager: Error in controller ready callback: $e');
      }
    }).catchError((e, stackTrace) {
      log('❌ PlaybackManager: Error ensuring controller ready: $e');
      log('Stack trace: $stackTrace');
    });
  }

  /// Called when app lifecycle changes
  void onAppLifecycleChanged(AppLifecycleState state) {
    log('📱 PlaybackManager: App lifecycle changed to $state');

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveCurrentPosition();
      pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      if (_currentFeedIndex != null) {
        log('🔄 PlaybackManager: App resumed, will recover at index $_currentFeedIndex');
      }
    }
  }

  /// Ensure controller is ready for given index
  Future<void> ensureControllerReady(int index, HomeVideo video) async {
    // 🔒 SAFETY: Validate inputs
    if (index < 0) {
      throw ArgumentError('Index must be non-negative: $index');
    }

    if (video.id.isEmpty || video.videoURL.isEmpty) {
      throw ArgumentError(
          'Invalid video object: id=${video.id}, url=${video.videoURL}');
    }

    final videoId = video.id;
    var controller = _controllerPool[videoId];

    // If controller exists and is healthy, return
    if (controller != null && _isControllerSafe(videoId, controller)) {
      try {
        if (controller.value.isInitialized && !controller.value.hasError) {
          log('✅ PlaybackManager: Controller already ready for index $index');
          return;
        }
      } catch (e) {
        log('⚠️ PlaybackManager: Error checking controller state: $e');
      }
    }

    // Controller missing or unhealthy - create new one
    log('🔄 PlaybackManager: Creating controller for index $index, video $videoId');

    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(video.videoURL));
      await controller.initialize().timeout(
        Duration(milliseconds: recoveryTimeoutMs),
        onTimeout: () {
          log('⏱️ PlaybackManager: Controller initialization timeout');
          throw TimeoutException('Controller initialization timeout');
        },
      );

      registerController(videoId, controller, owner: 'home/feed');

      // Seek to last position if available
      final lastPos = _lastKnownPositions[index];
      if (lastPos != null && lastPos > Duration.zero) {
        await controller.seekTo(lastPos);
        log('⏪ PlaybackManager: Seeked to last position ${lastPos.inSeconds}s');
      }

      log('✅ PlaybackManager: Controller ready for index $index');
    } catch (e) {
      log('❌ PlaybackManager: Error creating controller: $e');
      rethrow;
    }
  }

  /// Preload controllers around given index
  /// 🔒 SAFETY: Defers disposal to avoid disposing controllers during widget build
  void preloadAround(int index, List<HomeVideo> videos) {
    // 🔒 SAFETY: Validate inputs
    if (videos.isEmpty) return;
    if (index < 0) {
      log('⚠️ PlaybackManager: Invalid index $index for preloadAround');
      return;
    }

    final neighbors = [index - 1, index, index + 1];

    for (final n in neighbors) {
      if (n >= 0 && n < videos.length) {
        final video = videos[n];

        // 🔒 SAFETY: Validate video object before preloading
        if (video.id.isEmpty || video.videoURL.isEmpty) {
          log('⚠️ PlaybackManager: Invalid video at index $n, skipping preload');
          continue;
        }

        final videoId = video.id;

        // Preload if not already loaded
        if (!_controllerPool.containsKey(videoId)) {
          log('🔄 PlaybackManager: Preloading controller for index $n');
          ensureControllerReady(n, video).catchError((e, stackTrace) {
            log('⚠️ PlaybackManager: Error preloading index $n: $e');
            log('Stack trace: $stackTrace');
          });
        }
      }
    }

    // 🔥 CRITICAL MEMORY FIX: Clean up controllers immediately AND defer additional cleanup
    // Immediate cleanup prevents accumulation during rapid scrolling
    try {
      disposeFarControllers(index);
    } catch (e) {
      log('❌ PlaybackManager: Error disposing far controllers (immediate): $e');
    }

    // 🔒 SAFETY: Defer additional cleanup to next frame to avoid disposing controllers
    // that are currently being built or used by widgets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Double-check cleanup after frame completes
        if (_controllerPool.length > maxControllerPoolSize) {
          log('⚠️ PlaybackManager: Pool still large after cleanup (${_controllerPool.length}), forcing cleanup');
          disposeFarControllers(index);
        }
      } catch (e) {
        log('❌ PlaybackManager: Error disposing far controllers (deferred): $e');
      }
    });
  }

  /// Dispose controllers far from current index
  /// 🔒 SAFETY: Only disposes controllers that are definitely not in use
  /// 🔥 CRITICAL MEMORY FIX: Also enforces maximum pool size
  void disposeFarControllers(int index) {
    final toDispose = <String>[];

    // 🔥 STEP 1: Clean up stale/disposed controllers first
    final staleControllers = <String>[];
    for (final entry in _controllerPool.entries) {
      final videoId = entry.key;
      final controller = entry.value;
      if (!_isControllerSafe(videoId, controller)) {
        staleControllers.add(videoId);
      }
    }
    for (final videoId in staleControllers) {
      log('🧹 PlaybackManager: Cleaning up stale controller: $videoId');
      _controllerPool.remove(videoId);
      _controllerOwners.remove(videoId);
      _muteStates.remove(videoId);
      _disposedControllers.remove(videoId);
      final videoIndex = _videoIdToIndex[videoId];
      if (videoIndex != null) {
        _videoIdToIndex.remove(videoId);
        _indexToVideoId.remove(videoIndex);
        _lastKnownPositions.remove(videoIndex);
      }
    }

    // 🔥 STEP 2: Dispose controllers far from current index
    for (final entry in _controllerPool.entries) {
      final videoId = entry.key;
      final videoIndex = _videoIdToIndex[videoId];

      // Only dispose if:
      // 1. Video is far from current index (beyond poolRadius)
      // 2. Video is NOT the active video (currently playing)
      // 3. Controller is safe to dispose
      if (videoIndex != null &&
          (videoIndex - index).abs() > poolRadius &&
          videoId != _activeVideoId) {
        final controller = entry.value;
        if (_isControllerSafe(videoId, controller)) {
          toDispose.add(videoId);
        }
      } else if (videoIndex == null) {
        // 🔥 FIX: Controller without index mapping should be disposed
        // This handles controllers that lost their index mapping
        if (videoId != _activeVideoId) {
          final controller = entry.value;
          if (_isControllerSafe(videoId, controller)) {
            toDispose.add(videoId);
            log('🗑️ PlaybackManager: Disposing controller without index mapping: $videoId');
          }
        }
      }
    }

    // 🔥 CRITICAL MEMORY FIX: Always enforce pool size limit aggressively
    if (_controllerPool.length > maxControllerPoolSize) {
      log('⚠️ PlaybackManager: Pool size (${_controllerPool.length}) exceeds limit ($maxControllerPoolSize), aggressive cleanup');
      final targetSize = maxControllerPoolSize;
      final excessCount = _controllerPool.length - targetSize;
      int disposedCount = toDispose.length;

      // Dispose excess controllers, prioritizing non-active ones
      for (final entry in _controllerPool.entries) {
        if (disposedCount >= excessCount) break;
        final videoId = entry.key;
        if (videoId != _activeVideoId && !toDispose.contains(videoId)) {
          final controller = entry.value;
          if (_isControllerSafe(videoId, controller)) {
            toDispose.add(videoId);
            disposedCount++;
          }
        }
      }
    }

    // 🔥 STEP 3: Dispose collected controllers
    for (final videoId in toDispose) {
      log('🗑️ PlaybackManager: Disposing controller for video $videoId (index: ${_videoIdToIndex[videoId]}, current: $index, pool size: ${_controllerPool.length})');
      unregisterController(videoId);
      // Clean up index mappings
      final videoIndex = _videoIdToIndex[videoId];
      if (videoIndex != null) {
        _videoIdToIndex.remove(videoId);
        _indexToVideoId.remove(videoIndex);
        _lastKnownPositions.remove(videoIndex);
      }
    }

    if (toDispose.isNotEmpty || staleControllers.isNotEmpty) {
      log('✅ PlaybackManager: Cleaned up ${toDispose.length} far controllers and ${staleControllers.length} stale controllers, pool size now: ${_controllerPool.length}');
    }
  }

  /// Get controller for index
  /// 🔒 SAFETY: Returns null if controller is disposed or unsafe
  VideoPlayerController? getControllerForIndex(int index) {
    final videoId = _indexToVideoId[index];
    if (videoId == null) return null;
    return getController(videoId); // Use safe getController method
  }

  /// Get current feed index
  int? get currentFeedIndex => _currentFeedIndex;

  /// Save current position
  void _saveCurrentPosition() {
    if (_currentFeedIndex == null) return;
    final controller = getControllerForIndex(_currentFeedIndex!);
    if (controller != null) {
      final videoId = _indexToVideoId[_currentFeedIndex!];
      if (videoId != null && _isControllerSafe(videoId, controller)) {
        try {
          if (controller.value.isInitialized) {
            _lastKnownPositions[_currentFeedIndex!] = controller.value.position;
            log('💾 PlaybackManager: Saved position ${controller.value.position.inSeconds}s for index $_currentFeedIndex');
          }
        } catch (e) {
          log('⚠️ PlaybackManager: Error saving current position: $e');
        }
      }
    }
  }

  /// Save position for specific index
  void _savePositionForIndex(int index) {
    final controller = getControllerForIndex(index);
    if (controller != null) {
      final videoId = _indexToVideoId[index];
      if (videoId != null && _isControllerSafe(videoId, controller)) {
        try {
          if (controller.value.isInitialized) {
            _lastKnownPositions[index] = controller.value.position;
          }
        } catch (e) {
          log('⚠️ PlaybackManager: Error saving position for index $index: $e');
        }
      }
    }
  }
}

/// Riverpod provider for the global playback manager
final globalPlaybackManagerProvider = Provider<GlobalPlaybackManager>((ref) {
  return GlobalPlaybackManager.instance;
});
