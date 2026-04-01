import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import '../models/home_video.dart';
import '../constants/playback_owners.dart';
import '../utils/video_health_gate.dart';

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

  /// 🔥 CRITICAL FIX: Track controllers currently being initialized to prevent disposal during init
  final Set<String> _initializingControllers = {};

  /// 🔥 PHASE 1 FIX: Cooldown tracking for two-stage eviction (videoId -> expiration time)
  final Map<String, DateTime> _cooldownUntil = {};

  /// 🔥 PHASE 1 FIX: Pin set for current + next 2 videos (protected from disposal)
  final Set<String> _pinnedVideoIds = {};

  /// Cooldown period before hard disposal (seconds)
  static const int cooldownSeconds = 3;

  /// 🔥 PHASE 2.3: Controllers currently attached to a VideoPlayerViewOptimized (videoId -> controller hashCode)
  final Map<String, int> _attachedControllers = {};

  /// 🔥 PHASE 2.3: When each controller was registered (videoId -> creation time)
  final Map<String, DateTime> _controllerCreatedAt = {};

  /// 🔥 PHASE 2.3: Don't dispose a controller until this many seconds after registration
  static const int disposalEligibilityTtlSeconds = 5;

  /// 🔥 PRODUCTION-GRADE: Pending focus requests (videoId -> owner)
  /// Used for TikTok-style first video autoplay - queues focus requests before controller is ready
  final Map<String, String> _pendingFocusRequests = {};

  /// Last preload request center index to avoid redundant churn during rebuilds.
  int? _lastPreloadCenterIndex;

  /// Last preload request video id at the center index.
  String? _lastPreloadCenterVideoId;

  /// Timestamp of the last preload request.
  DateTime? _lastPreloadRequestedAt;

  /// 🔥 INSTANT PLAYBACK: Mark a controller as initializing
  void markControllerInitializing(String videoId) {
    _initializingControllers.add(videoId);
    log('🔄 PlaybackManager: Marked controller as initializing: $videoId');
  }

  /// 🔥 PHASE 2.3: Mark controller as attached to a view (protects from disposal)
  void markControllerAttached(String videoId, int controllerId) {
    _attachedControllers[videoId] = controllerId;
    log('📌 PlaybackManager: Controller attached videoId=$videoId controllerId=$controllerId');
  }

  /// 🔥 PHASE 2.3: Mark controller as detached from view (eligible for disposal after cooldown)
  void markControllerDetached(String videoId) {
    if (_attachedControllers.remove(videoId) != null) {
      log('📌 PlaybackManager: Controller detached videoId=$videoId');
    }
  }

  /// Whether we're in a paused state (tab switching, etc.)
  bool _isPaused = false;

  /// Activation epoch to cancel stale async work
  int _activationEpoch = 0;

  /// 🔥 FIX: Track which controller is currently being played to prevent double audio
  VideoPlayerController? _currentlyPlayingController;

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
  // 🔥 TIKTOK-STYLE: Keep exactly 3 controllers (prev/current/next).
  // This reduces Surface churn on Android and prevents “black screen on swipe back”.
  static const int poolRadius = 2;
  static const int recoveryTimeoutMs = 5000;
  static const int maxControllerPoolSize = 5;

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

  /// 🔥 FIX: Extra protection check to ensure active video is never disposed
  /// This prevents auto-pause after many playbacks
  bool _isActiveVideo(String videoId) {
    // Check if this is the active video
    if (_activeVideoId == videoId) return true;

    // Check if this video's controller is currently playing
    final controller = _controllerPool[videoId];
    if (controller != null && _isControllerSafe(videoId, controller)) {
      try {
        final value = controller.value;
        if (value.isInitialized && value.isPlaying) {
          // If controller is playing, treat it as active to prevent disposal
          return true;
        }
      } catch (e) {
        // If we can't check, err on the side of caution - don't dispose
        log('⚠️ PlaybackManager: Error checking if video is active: $e');
        return true; // Don't dispose if we can't verify
      }
    }

    return false;
  }

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

  /// No evict active, no evict attached, only past TTL. No exceptions.
  bool _canEvict(String id, VideoPlayerController controller, DateTime now) {
    if (id == _activeVideoId) return false;
    if (_attachedControllers[id] == controller.hashCode) return false;
    if (_initializingControllers.contains(id)) return false;
    final createdAt = _controllerCreatedAt[id];
    if (createdAt != null &&
        now.difference(createdAt) <
            Duration(seconds: disposalEligibilityTtlSeconds)) {
      return false;
    }
    return true;
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

    // 🧹 Clear any stale global blocks when explicitly switching owners
    if (_blockLevel > 0) {
      log('🎯 PlaybackManager: Clearing stale block (level: $_blockLevel, reason: $_blockReason) when switching owner to $owner');
      _blockLevel = 0;
      _blockReason = null;
      _playbackBlockedController.add(false);
    }

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

    log('✅ PlaybackManager: Active owner set to: $owner (blockLevel: $_blockLevel)');
  }

  /// Force unblock completely (sets block level to 0)
  /// Use this when you need to ensure playback is unblocked (e.g., PlayerScreen opening)
  void forceUnblock() {
    if (_blockLevel > 0) {
      log('🔓 PlaybackManager: FORCE UNBLOCKING (was level: $_blockLevel, reason: $_blockReason)');
      _blockLevel = 0;
      _blockReason = null;
      _playbackBlockedController.add(false);
      log('✅ PlaybackManager: FORCE UNBLOCKED - ready for playback');
    }
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

    // 🔥 INSTANT PLAYBACK: Auto-set active owner if null (instead of blocking)
    // This prevents canPlay() from blocking playback unnecessarily
    if (_activeOwner == null) {
      log('🔧 PlaybackManager: Active owner is null, auto-setting to $owner for instant playback');
      setActiveOwner(owner);
      return true; // Now can play after auto-setting
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
  /// Routes to switchActiveTo for atomic focus switching.
  void activate(String videoId, {String? owner}) {
    // Schedule async work without blocking
    switchActiveTo(videoId, owner ?? _activeOwner ?? 'home').catchError((e) {
      log('⚠️ PlaybackManager: Error in activate: $e');
    });
  }

  Future<void> _ensurePlayingUnmuted(VideoPlayerController controller) async {
    final targetVideoId = _activeVideoId;
    if (targetVideoId == null || _controllerPool[targetVideoId] != controller) {
      return;
    }
    try {
      if (_currentlyPlayingController != null &&
          !identical(_currentlyPlayingController, controller)) {
        await _safePauseAndMute(_currentlyPlayingController!);
        _currentlyPlayingController = null;
      }
      final value = controller.value;
      final bool initialized = value.isInitialized;
      final bool hasError = value.hasError;
      final bool isPlayingBefore = value.isPlaying;
      log('GPM PLAY id=$targetVideoId initialized=$initialized hasError=$hasError '
          'isPlayingBefore=$isPlayingBefore');
      if (!initialized || hasError) return;
      _currentlyPlayingController = controller;
      if (value.isPlaying && value.position > Duration.zero) {
        if (_activeVideoId == targetVideoId &&
            _controllerPool[targetVideoId] == controller) {
          await controller.setVolume(1.0);
          log('🔊 PlaybackManager: Video already playing - unmuted immediately');
        }
        return;
      }
      if (!value.isPlaying) {
        await controller.play();
        try {
          final isPlayingAfter = controller.value.isPlaying;
          log('GPM PLAY id=$targetVideoId isPlayingAfter=$isPlayingAfter');
        } catch (_) {}
        log('▶️ PlaybackManager: Started playing video');
      }
      await controller.setVolume(0.0);
      await Future.delayed(const Duration(milliseconds: 50));
      if (_activeVideoId != targetVideoId ||
          _controllerPool[targetVideoId] != controller) {
        try {
          await controller.setVolume(0.0);
        } catch (_) {}
        return;
      }
      var probe = controller.value;
      var ready = probe.isInitialized &&
          !probe.hasError &&
          probe.isPlaying &&
          !probe.isBuffering &&
          probe.position >= const Duration(milliseconds: 30);
      if (ready) {
        await controller.setVolume(1.0);
        log('🔊 PlaybackManager: Unmuted video after 50ms (instant)');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 50));
      if (_activeVideoId != targetVideoId ||
          _controllerPool[targetVideoId] != controller) {
        try {
          await controller.setVolume(0.0);
        } catch (_) {}
        return;
      }
      probe = controller.value;
      ready = probe.isInitialized &&
          !probe.hasError &&
          probe.isPlaying &&
          !probe.isBuffering;
      if (ready) {
        await controller.setVolume(1.0);
        log('🔊 PlaybackManager: Unmuted video after 100ms (fast)');
        return;
      }
      final finalProbe = controller.value;
      if (finalProbe.isInitialized &&
          !finalProbe.hasError &&
          finalProbe.isPlaying) {
        await controller.setVolume(1.0);
        log('🔊 PlaybackManager: Unmuted video after 100ms (optimistic)');
      }
    } catch (e) {
      log('⚠️ PlaybackManager: Error ensuring play/unmute: $e');
      if (_currentlyPlayingController == controller) {
        _currentlyPlayingController = null;
      }
    }
  }

  Future<void> _safePauseAndMute(VideoPlayerController controller) async {
    try {
      await controller.pause();
    } catch (_) {}
    try {
      await controller.setVolume(0.0);
    } catch (_) {}
  }

  Future<void> _muteAllExcept(String keepVideoId) async {
    final entries = List<MapEntry<String, VideoPlayerController>>.from(
      _controllerPool.entries,
    );
    for (final entry in entries) {
      final id = entry.key;
      final controller = entry.value;
      if (!_isControllerSafe(id, controller)) continue;

      if (id == keepVideoId) {
        // Keep target muted until we explicitly unmute/play it, but avoid pausing
        // to prevent unnecessary restarts.
        try {
          await controller.setVolume(0.0);
        } catch (_) {}
        _muteStates[id] = true;
        continue;
      }

      await _safePauseAndMute(controller);
      _muteStates[id] = true;
    }
  }

  /// Atomic switch: pause/mute old, ensure new, dispose old (throttled), play new.
  Future<void> switchActiveTo(String newVideoId, String owner) async {
    final int myEpoch = ++_activationEpoch;
    log('GPM switch start id=$newVideoId owner=$owner epoch=$myEpoch');

    if (_blockLevel == 0 && _activeOwner != owner) {
      log('🎯 PlaybackManager: Switching active owner from $_activeOwner to $owner');
      setActiveOwner(owner);
    }

    if (!canPlay(owner)) {
      final c = _controllerPool[newVideoId];
      if (c != null && _isControllerSafe(newVideoId, c)) {
        try {
          await c.setVolume(0.0);
          await c.pause();
          _muteStates[newVideoId] = true;
        } catch (_) {}
      }
      log('🚫 PlaybackManager: switchActiveTo denied for owner $owner');
      return;
    }

    final controller = _controllerPool[newVideoId];
    if (controller == null || !_isControllerSafe(newVideoId, controller)) {
      _activeVideoId = newVideoId;
      _controllerOwners[newVideoId] = owner;
      if (_activeOwner != owner) {
        _activeOwner = owner;
        _activeOwnerController.add(_activeOwner);
      }
      _activeVideoController.add(_activeVideoId);
      log('GPM focus-queued id=$newVideoId (missing/unsafe in switchActiveTo)');
      _pendingFocusRequests[newVideoId] = owner;
      return;
    }

    if (_activeVideoId == newVideoId &&
        _controllerOwners[newVideoId] == owner) {
      await _muteAllExcept(newVideoId);
      if (myEpoch != _activationEpoch) {
        log('GPM switch abort id=$newVideoId epoch=$myEpoch (stale after mute)');
        return;
      }
      await _ensurePlayingUnmuted(controller);
      return;
    }

    await _muteAllExcept(newVideoId);
    if (myEpoch != _activationEpoch) {
      log('GPM switch abort id=$newVideoId epoch=$myEpoch (stale after muteAll)');
      return;
    }

    final previousPlaying = _currentlyPlayingController;
    if (previousPlaying != null && !identical(previousPlaying, controller)) {
      await _safePauseAndMute(previousPlaying);
      _currentlyPlayingController = null;
    } else {
      _currentlyPlayingController = null;
    }
    await Future.delayed(const Duration(milliseconds: 80));

    if (myEpoch != _activationEpoch) {
      log('GPM switch abort id=$newVideoId epoch=$myEpoch (stale after 80ms)');
      return;
    }

    _activeVideoId = newVideoId;
    _controllerOwners[newVideoId] = owner;
    _activeVideoController.add(_activeVideoId);

    if (!_isControllerSafe(newVideoId, controller)) {
      log('⚠️ PlaybackManager: Controller became unsafe for $newVideoId after mute-all');
      return;
    }

    await _ensurePlayingUnmuted(controller);
    log('GPM switch end id=$newVideoId epoch=$myEpoch');
  }

  /// Request focus for a specific video (pause all others)
  /// Alias for activate() with owner tracking
  /// 🔥 INSTANT PLAYBACK: Auto-sets active owner if null to prevent blocking
  Future<void> requestFocus(String videoId, String owner) async {
    log('🎯 PlaybackManager: Requesting focus for $videoId from $owner');

    // 🔥 INSTANT PLAYBACK: Auto-set active owner if null (prevents canPlay() blocking)
    if (_activeOwner == null) {
      log('🔧 PlaybackManager: Active owner is null, auto-setting to $owner for instant playback');
      setActiveOwner(owner);
    } else if (_blockLevel == 0 && _activeOwner != owner) {
      log('🎯 PlaybackManager: requestFocus switching owner from $_activeOwner to $owner');
      setActiveOwner(owner);
    }

    // 🔥 SINGLE ACTIVE OWNER: Check if owner can play before requesting focus
    if (!canPlay(owner)) {
      log('🚫 PlaybackManager: Owner $owner cannot play, not requesting focus (activeOwner: $_activeOwner, blockLevel: $_blockLevel)');
      // Still pause all videos to prevent audio bleeding
      pauseAll();
      return;
    }

    final controller = _controllerPool[videoId];
    if (controller == null || !_isControllerSafe(videoId, controller)) {
      _activeVideoId = videoId;
      _controllerOwners[videoId] = owner;
      if (_activeOwner != owner) {
        _activeOwner = owner;
        _activeOwnerController.add(_activeOwner);
      }
      _activeVideoController.add(_activeVideoId);
      log('GPM focus-queued id=$videoId owner=$owner (pooled? false safe? false)');
      _pendingFocusRequests[videoId] = owner;
      return;
    }

    log('GPM focus id=$videoId owner=$owner pooled? true safe? true');
    await _muteAllExcept(videoId);
    await switchActiveTo(videoId, owner);
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
    _currentlyPlayingController = null;

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
    _logControllerEvent('REGISTER_CONTROLLER', videoId,
        controllerId: controller.hashCode, reason: 'explicit_register');

    // 🔥 INSTANT PLAYBACK: Mark controller as no longer initializing
    _initializingControllers.remove(videoId);
    // Cancel any cooldown (controller is now active)
    _cooldownUntil.remove(videoId);

    // 🔥 PHASE 2.3: When view re-initializes, replace pool entry with view's new controller.
    // Never dispose the view's controller (incoming); unregister old so pool gets the new one.
    final oldController = _controllerPool[videoId];
    if (oldController != null && !identical(oldController, controller)) {
      final oldAttached =
          _attachedControllers[videoId] == oldController.hashCode;
      if (oldAttached) {
        unregisterController(videoId);
        log('📌 PlaybackManager: Replaced attached controller for $videoId with view\'s new controller');
      } else {
        if (_isControllerSafe(videoId, oldController)) {
          try {
            oldController.setVolume(0.0);
            oldController.pause();
          } catch (e) {
            log('⚠️ PlaybackManager: Error pausing old controller: $e');
          }
        }
        _controllerPool.remove(videoId);
        _controllerOwners.remove(videoId);
        _muteStates.remove(videoId);
        _disposedControllers[videoId] = true;
        _attachedControllers.remove(videoId);
        _controllerCreatedAt.remove(videoId);
        if (_currentlyPlayingController == oldController) {
          _currentlyPlayingController = null;
        }
        try {
          oldController.dispose();
          log('🗑️ PlaybackManager: Disposed old controller for $videoId');
        } catch (e) {
          log('⚠️ PlaybackManager: Error disposing old controller: $e');
        }
      }
    }

    // Clear stale disposal tracking when reusing an ID
    _disposedControllers.remove(videoId);

    // 🔥 CRITICAL MEMORY FIX: Enforce maximum pool size to prevent MediaCodec NO_MEMORY errors
    // With pool size = 1, dispose ALL other controllers when adding a new one
    if (_controllerPool.length >= maxControllerPoolSize &&
        !_controllerPool.containsKey(videoId)) {
      log('⚠️ PlaybackManager: Pool size limit reached ($_controllerPool.length/$maxControllerPoolSize), disposing ALL non-active controllers before adding new one');
      // 🔥 CRITICAL: Dispose ALL non-active controllers immediately to prevent OOM
      final controllersToDispose = <String>[];
      final nowForRegister = DateTime.now();
      for (final entry in _controllerPool.entries) {
        final id = entry.key;
        if (_canEvict(id, entry.value, nowForRegister)) {
          controllersToDispose.add(id);
        }
      }
      for (final id in controllersToDispose) {
        log('🗑️ PlaybackManager: Evicting controller $id to prevent OOM');
        unregisterController(id);
      }
    }

    _controllerPool[videoId] = controller;
    _controllerCreatedAt[videoId] = DateTime.now();

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

    _applyPendingFocusIfExists(videoId).catchError((e) {
      log('⚠️ PlaybackManager: Error applying pending focus: $e');
    });
  }

  /// 🔥 PRODUCTION-GRADE: Set desired focus for a video (queues if controller not ready)
  ///
  /// **Purpose:**
  /// Enables TikTok-style first video autoplay by queuing focus requests before controller is ready.
  /// When controller is registered, pending focus is automatically applied.
  ///
  /// **Behavior:**
  /// - If controller exists and is ready: applies focus immediately
  /// - If controller doesn't exist: queues as pending, applies when controller registers
  /// - Replaces any existing pending focus for the same videoId
  ///
  /// **Parameters:**
  /// - [videoId]: The video ID to focus
  /// - [owner]: The owner key (e.g., 'home/forYou')
  ///
  /// **Usage:**
  /// Call this immediately when you want a video to autoplay, even before controller exists.
  /// Typically called from HomeView when feed loads, before first video controller is created.
  void setDesiredFocus(String videoId, String owner) {
    log('🎯 PlaybackManager: Setting desired focus for $videoId (owner: $owner)');

    // Check if controller already exists and is ready
    final controller = _controllerPool[videoId];
    if (controller != null && _isControllerSafe(videoId, controller)) {
      try {
        if (controller.value.isInitialized && !controller.value.hasError) {
          log('✅ PlaybackManager: Controller exists and is ready, applying focus immediately for $videoId');
          // Controller is ready - apply focus immediately
          requestFocus(videoId, owner).catchError((e) {
            log('⚠️ PlaybackManager: Error applying immediate focus: $e');
          });
          // Clear any pending request (if it existed)
          _pendingFocusRequests.remove(videoId);
          return;
        }
      } catch (e) {
        log('⚠️ PlaybackManager: Error checking controller state: $e');
        // Controller exists but not safe - queue as pending
      }
    }

    // Controller doesn't exist or isn't ready - queue as pending
    _pendingFocusRequests[videoId] = owner;
    log('⏳ PlaybackManager: Controller not ready for $videoId, queued focus request (owner: $owner)');
    log('📊 PlaybackManager: Pending focus requests: ${_pendingFocusRequests.length}');
  }

  /// Apply pending focus after controller is initialized (wait/retry so focus is not applied too early).
  /// Called from registerController(); runs async so registration is not blocked.
  Future<void> _applyPendingFocusIfExists(
    String videoId, {
    int retries = 0,
  }) async {
    // Hard cap — a controller that never initialises should not loop forever.
    const int maxRetries = 20;
    if (retries >= maxRetries) {
      log('GPM focus-apply id=$videoId gave up after $maxRetries retries');
      _pendingFocusRequests.remove(videoId);
      return;
    }

    final pendingOwner = _pendingFocusRequests[videoId];
    if (pendingOwner == null) return;

    final controller = _controllerPool[videoId];
    if (controller == null) {
      _pendingFocusRequests.remove(videoId);
      return;
    }

    const int maxWaitMs = 1000;
    const int stepMs = 50;
    final int steps = maxWaitMs ~/ stepMs;
    for (int i = 0; i < steps; i++) {
      try {
        if (_isControllerSafe(videoId, controller) &&
            controller.value.isInitialized &&
            !controller.value.hasError) {
          break;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: stepMs));
    }

    try {
      if (!_isControllerSafe(videoId, controller) ||
          !controller.value.isInitialized ||
          controller.value.hasError) {
        log('GPM focus-apply id=$videoId deferred (not ready after ${maxWaitMs}ms), retry ${retries + 1}/$maxRetries');
        Future.delayed(const Duration(milliseconds: 300), () {
          _applyPendingFocusIfExists(videoId, retries: retries + 1)
              .catchError((e) {
            log('⚠️ PlaybackManager: Error in deferred pending focus: $e');
          });
        });
        return;
      }
    } catch (_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _applyPendingFocusIfExists(videoId, retries: retries + 1)
            .catchError((e) {
          log('⚠️ PlaybackManager: Error in deferred pending focus: $e');
        });
      });
      return;
    }

    _pendingFocusRequests.remove(videoId);
    log('GPM focus-apply id=$videoId owner=$pendingOwner (ready after wait)');
    await switchActiveTo(videoId, pendingOwner);
  }

  /// Clear pending focus request for a video (e.g., when user scrolls away or tab changes)
  void clearDesiredFocus(String videoId) {
    if (_pendingFocusRequests.remove(videoId) != null) {
      log('🗑️ PlaybackManager: Cleared pending focus request for $videoId');
    }
  }

  void clearDesiredFocusForOwner(String owner, {String? exceptVideoId}) {
    final toRemove = _pendingFocusRequests.entries
        .where((entry) => entry.value == owner && entry.key != exceptVideoId)
        .map((entry) => entry.key)
        .toList();

    for (final videoId in toRemove) {
      _pendingFocusRequests.remove(videoId);
    }

    if (toRemove.isNotEmpty) {
      log('🗑️ PlaybackManager: Cleared ${toRemove.length} pending focus requests for owner $owner');
    }
  }

  /// Clear all pending focus requests (e.g., when feed changes or tab switches)
  void clearAllDesiredFocus() {
    final count = _pendingFocusRequests.length;
    _pendingFocusRequests.clear();
    if (count > 0) {
      log('🗑️ PlaybackManager: Cleared all pending focus requests ($count)');
    }
  }

  /// Unregister a controller for a video ID.
  /// 🔥 PHASE 2.3: Only disposes if controller is not attached (view may still hold reference).
  /// 🔥 AUDIO FIX: Mute and pause before remove so off-screen controllers never bleed audio.
  void unregisterController(String videoId) {
    log('🗑️ PlaybackManager: Unregistering controller for video $videoId');
    final controller = _controllerPool[videoId];
    if (controller != null && _isControllerSafe(videoId, controller)) {
      try {
        controller.setVolume(0.0);
        controller.pause();
      } catch (_) {}
    }
    final isAttached = controller != null &&
        _attachedControllers[videoId] == controller.hashCode;
    _attachedControllers.remove(videoId);
    _controllerCreatedAt.remove(videoId);
    if (_activeVideoId == videoId) {
      _activeVideoId = null;
      _activeVideoController.add(null);
      if (controller != null && _currentlyPlayingController == controller) {
        _currentlyPlayingController = null;
      }
    }
    _controllerPool.remove(videoId);
    _controllerOwners.remove(videoId);
    _muteStates.remove(videoId);
    if (controller != null && !isAttached) {
      try {
        if (_isControllerSafe(videoId, controller)) {
          controller.dispose();
          _disposedControllers[videoId] = true;
          log('🗑️ PlaybackManager: Disposed controller for video $videoId');
        } else {
          log('⚠️ PlaybackManager: Controller for video $videoId already disposed or invalid');
        }
      } catch (e) {
        log('❌ PlaybackManager: Error disposing controller for video $videoId: $e');
      }
    } else if (controller != null && isAttached) {
      log('📌 PlaybackManager: Controller still attached, skipping dispose (view will dispose): $videoId');
    }
  }

  /// Dispose all controllers and clear state (for tab switches).
  /// 🔥 PHASE 2.3: Skips controllers still attached (view will dispose them).
  void disposeAll() {
    log('🚨 PlaybackManager: Disposing all controllers');
    for (final entry in _controllerPool.entries) {
      final videoId = entry.key;
      final controller = entry.value;
      final isAttached = _attachedControllers[videoId] == controller.hashCode;
      if (isAttached) {
        log('📌 PlaybackManager: Skipping attached controller for $videoId');
        continue;
      }
      try {
        if (_isControllerSafe(videoId, controller)) {
          controller.dispose();
          _disposedControllers[videoId] = true;
          log('🗑️ PlaybackManager: Disposed controller for video $videoId');
        } else {
          log('⚠️ PlaybackManager: Controller for video $videoId already disposed or invalid');
        }
      } catch (e) {
        log('❌ PlaybackManager: Error disposing controller for video $videoId: $e');
      }
    }
    _controllerPool.clear();
    _controllerOwners.clear();
    _muteStates.clear();
    _disposedControllers.clear();
    _attachedControllers.clear();
    _controllerCreatedAt.clear();
    // Clear maps that grow without bound during long sessions.
    _indexToVideoId.clear();
    _videoIdToIndex.clear();
    _lastKnownPositions.clear();
    _pendingFocusRequests.clear();
    _cooldownUntil.clear();
    _pinnedVideoIds.clear();
    _initializingControllers.clear();
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

  /// Idempotent: return existing controller if present and safe; else create, init, register.
  /// Only manager creates VideoPlayerControllers (stops ExoPlayer/MediaCodec churn).
  Future<VideoPlayerController?> getOrCreateController(
    String videoId,
    String url, {
    String? owner,
  }) async {
    final existing = _controllerPool[videoId];
    if (existing != null && _isControllerSafe(videoId, existing)) {
      try {
        if (existing.value.isInitialized && !existing.value.hasError) {
          log('✅ PlaybackManager: getOrCreateController reusing existing: $videoId');
          return existing;
        }
      } catch (_) {}
    }
    if (existing != null && !_isControllerSafe(videoId, existing)) {
      _controllerPool.remove(videoId);
      try {
        await existing.dispose();
      } catch (_) {}
    }
    if (_initializingControllers.contains(videoId)) {
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        final pooled = _controllerPool[videoId];
        if (pooled != null && _isControllerSafe(videoId, pooled)) {
          try {
            if (pooled.value.isInitialized && !pooled.value.hasError) {
              log('✅ PlaybackManager: getOrCreateController adopted after wait: $videoId');
              return pooled;
            }
          } catch (_) {}
        }
        if (!_initializingControllers.contains(videoId)) break;
      }
    }
    if (url.isEmpty) return null;
    Uri uri;
    try {
      uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.hasAuthority) return null;
    } catch (_) {
      return null;
    }
    _initializingControllers.add(videoId);
    VideoPlayerController? created;
    try {
      created = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      _controllerPool[videoId] = created;
      await created.initialize().timeout(
            const Duration(seconds: 8),
            onTimeout: () =>
                throw TimeoutException('getOrCreateController init 8s'),
          );
      registerController(videoId, created, owner: owner ?? 'home/feed');
      log('✅ PlaybackManager: getOrCreateController created and registered: $videoId');
      return created;
    } catch (e) {
      log('❌ PlaybackManager: getOrCreateController failed $videoId: $e');
      _controllerPool.remove(videoId);
      if (created != null) {
        try {
          await created.dispose();
        } catch (_) {}
      }
      return null;
    } finally {
      _initializingControllers.remove(videoId);
    }
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
  // PHASE 1: CONTROLLER LIFECYCLE INSTRUMENTATION
  // ============================================

  /// Log controller lifecycle event
  void _logControllerEvent(
    String event,
    String videoId, {
    int? controllerId,
    String? reason,
  }) {
    final controller = _controllerPool[videoId];
    final controllerIdStr = controllerId?.toString() ??
        controller?.hashCode.toString() ??
        'unknown';
    final isPinned = _pinnedVideoIds.contains(videoId) ? 'pinned' : 'unpinned';
    final isInitializing =
        _initializingControllers.contains(videoId) ? 'initializing' : 'ready';
    final inCooldown =
        _cooldownUntil.containsKey(videoId) ? 'cooldown' : 'active';

    log('🎬 CONTROLLER_LIFECYCLE: event=$event videoId=$videoId '
        'controllerId=$controllerIdStr $isPinned $isInitializing $inCooldown '
        'reason=${reason ?? "N/A"}');

    // Log pool snapshot after mutations
    if (event.contains('CREATE') ||
        event.contains('DISPOSE') ||
        event.contains('ACQUIRE') ||
        event.contains('RELEASE') ||
        event.contains('COOLDOWN')) {
      _logPoolSnapshot(reason: event);
    }
  }

  /// Log current pool state snapshot
  void _logPoolSnapshot({String? reason}) {
    final snapshot = _controllerPool.keys.map((videoId) {
      final isPinned = _pinnedVideoIds.contains(videoId) ? 'P' : '-';
      final isInit = _initializingControllers.contains(videoId) ? 'I' : '-';
      final cooldown = _cooldownUntil.containsKey(videoId) ? 'C' : '-';
      return '$videoId:$isPinned$isInit$cooldown';
    }).join(', ');
    log('📊 POOL_SNAPSHOT: size=${_controllerPool.length} pinned=${_pinnedVideoIds.length} '
        'init=${_initializingControllers.length} cooldown=${_cooldownUntil.length} '
        'reason=${reason ?? "periodic"} [$snapshot]');
  }

  // ============================================
  // PHASE 1: PIN SET MANAGEMENT
  // ============================================

  /// Update pin set for the active window around the current video.
  void _updatePinSet(
    int currentIndex, {
    int backwardRadius = 2,
    int forwardRadius = 2,
  }) {
    _pinnedVideoIds.clear();
    for (int offset = -backwardRadius; offset <= forwardRadius; offset++) {
      final index = currentIndex + offset;
      final videoId = _indexToVideoId[index];
      if (videoId != null && _controllerPool.containsKey(videoId)) {
        _pinnedVideoIds.add(videoId);
        _logControllerEvent('PIN_SET', videoId,
            reason: 'index=$index offset=$offset');
      }
    }

    _logPoolSnapshot(reason: 'pin_set_update');
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

    restoreCurrentFeedFocus();
  }

  void restoreCurrentFeedFocus() {
    if (_currentFeedIndex != null) {
      log('📺 PlaybackManager: Current index is $_currentFeedIndex');
      final videoId = _indexToVideoId[_currentFeedIndex];
      if (videoId != null) {
        clearDesiredFocusForOwner(PlaybackOwners.home, exceptVideoId: videoId);
        log('🎵 PlaybackManager: Restoring focus for video $videoId at index $_currentFeedIndex');
        setDesiredFocus(videoId, PlaybackOwners.home);
      }
    }
  }

  /// Called when user leaves HomeView
  /// ✅ FIX #1: Non-blocking - just pause and save position
  /// Reserve block()/unblock() for global situations like camera, heavy modals, etc.
  void onLeaveHomeView() {
    log('🚪 PlaybackManager: Leaving HomeView');
    _saveCurrentPosition();
    clearDesiredFocusForOwner(PlaybackOwners.home);
    pauseAll();
    // ❌ REMOVED: block(reason: 'leftHomeView');
    // We just pause when leaving HomeView; blocking is for camera/modals.
  }

  void _syncFeedIndexMapping(int index, String videoId) {
    final previousVideoAtIndex = _indexToVideoId[index];
    if (previousVideoAtIndex != null && previousVideoAtIndex != videoId) {
      _videoIdToIndex.remove(previousVideoAtIndex);
      clearDesiredFocus(previousVideoAtIndex);
      log('🧹 PlaybackManager: Cleared stale feed mapping index=$index oldVideo=$previousVideoAtIndex');
    }

    final previousIndexForVideo = _videoIdToIndex[videoId];
    if (previousIndexForVideo != null && previousIndexForVideo != index) {
      _indexToVideoId.remove(previousIndexForVideo);
      log('🧹 PlaybackManager: Removed stale reverse mapping video=$videoId oldIndex=$previousIndexForVideo');
    }

    _indexToVideoId[index] = videoId;
    _videoIdToIndex[videoId] = index;
  }

  /// Called when visible index changes in vertical feed.
  /// Mutes all videos first (await) then ensures controller exists and queues focus.
  Future<void> onVisibleIndexChanged(int newIndex, HomeVideo video) async {
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
      final previousIndex = _currentFeedIndex;
      final previousVideoId =
          previousIndex != null ? _indexToVideoId[previousIndex] : null;
      if (_currentFeedIndex != null) {
        _savePositionForIndex(_currentFeedIndex!);
      }
      _currentFeedIndex = newIndex;
      _syncFeedIndexMapping(newIndex, video.id);
      if (previousVideoId != null && previousVideoId != video.id) {
        clearDesiredFocus(previousVideoId);
      }
    } catch (e) {
      log('❌ PlaybackManager: Error updating index mappings: $e');
      return;
    }
    final String targetVideoId = video.id;
    clearDesiredFocusForOwner(PlaybackOwners.home, exceptVideoId: targetVideoId);
    await _muteAllExcept(targetVideoId).catchError((_) {});
    setDesiredFocus(targetVideoId, PlaybackOwners.home);
    final healthResult = await VideoHealthGate.instance.resolvePlayableSource(
      targetVideoId,
      fallbackUrl: video.videoURL.isNotEmpty ? video.videoURL : null,
    );
    if (healthResult is Unplayable) {
      log('⚠️ PlaybackManager: Video $targetVideoId unplayable: ${healthResult.reason}');
      return;
    }
    final playableUrl = (healthResult as Playable).url;
    getOrCreateController(
      targetVideoId,
      playableUrl,
      owner: PlaybackOwners.home,
    ).catchError((e) {
      log('⚠️ PlaybackManager: getOrCreateController failed for $targetVideoId: $e');
      return null;
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
  /// 🔥 FIX: Optimized for faster initialization - reduced timeout and better error handling
  Future<void> ensureControllerReady(int index, HomeVideo video) async {
    // 🔒 SAFETY: Validate inputs - return early instead of throwing to prevent crashes
    if (index < 0) {
      log('⚠️ PlaybackManager: Invalid index $index, returning early');
      return;
    }

    if (video.id.isEmpty || video.videoURL.isEmpty) {
      log('⚠️ PlaybackManager: Invalid video object: id=${video.id}, url=${video.videoURL}, returning early');
      return;
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
        // Controller might be unhealthy, continue to create new one
      }
    }

    // 🔥 CRITICAL FIX: Check if already initializing to prevent duplicate initialization
    if (_initializingControllers.contains(videoId)) {
      log('⚠️ PlaybackManager: Controller for $videoId is already being initialized, waiting...');
      // Wait a bit and check again
      await Future.delayed(const Duration(milliseconds: 100));
      final existingController = _controllerPool[videoId];
      if (existingController != null &&
          _isControllerSafe(videoId, existingController)) {
        try {
          if (existingController.value.isInitialized &&
              !existingController.value.hasError) {
            log('✅ PlaybackManager: Controller became ready during wait');
            return;
          }
        } catch (e) {
          // Continue to create new one
        }
      }
    }

    // Controller missing or unhealthy - resolve playable URL first, then create
    log('🔄 PlaybackManager: Ensuring controller for index $index, video $videoId');
    final healthResult = await VideoHealthGate.instance.resolvePlayableSource(
      videoId,
      fallbackUrl: video.videoURL.isNotEmpty ? video.videoURL : null,
    );
    if (healthResult is Unplayable) {
      log('⚠️ PlaybackManager: Video $videoId unplayable: ${healthResult.reason}');
      return;
    }
    final playableUrl = (healthResult as Playable).url;
    try {
      controller = await getOrCreateController(
        videoId,
        playableUrl,
        owner: PlaybackOwners.home,
      );
      if (controller == null) return;
      _syncFeedIndexMapping(index, videoId);

      // Seek to last position if available
      final lastPos = _lastKnownPositions[index];
      if (lastPos != null && lastPos > Duration.zero) {
        try {
          await controller.seekTo(lastPos).timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              log('⏱️ PlaybackManager: Seek timeout for $videoId');
            },
          );
          log('⏪ PlaybackManager: Seeked to last position ${lastPos.inSeconds}s');
        } catch (e) {
          log('⚠️ PlaybackManager: Error seeking to last position: $e');
          // Continue anyway - video will start from beginning
        }
      }

      log('✅ PlaybackManager: Controller ready for index $index');
    } catch (e, stackTrace) {
      log('❌ PlaybackManager: Error creating controller: $e');
      log('Stack trace: $stackTrace');
    }
  }

  /// Preload controllers around given index
  /// 🔒 SAFETY: Defers disposal to avoid disposing controllers during widget build
  /// 🔥 FIX SLOW LOADING: Preloads videos in background (non-blocking) for instant UI response
  void preloadAround(
    int index,
    List<HomeVideo> videos, {
    int direction = 0,
  }) {
    // 🔒 SAFETY: Validate inputs
    if (videos.isEmpty) {
      log('⚠️ PlaybackManager: Videos list is empty, skipping preload');
      return;
    }
    if (index < 0) {
      log('⚠️ PlaybackManager: Invalid index $index for preloadAround');
      return;
    }
    if (index >= videos.length) {
      log('⚠️ PlaybackManager: Index $index out of bounds (videos.length: ${videos.length})');
      return;
    }

    final centerVideoId = videos[index].id;
    final now = DateTime.now();
    final lastRequestAt = _lastPreloadRequestedAt;
    final isDuplicateBurst =
        _lastPreloadCenterIndex == index &&
        _lastPreloadCenterVideoId == centerVideoId &&
        lastRequestAt != null &&
        now.difference(lastRequestAt) < const Duration(milliseconds: 180);
    if (isDuplicateBurst) {
      return;
    }
    _lastPreloadCenterIndex = index;
    _lastPreloadCenterVideoId = centerVideoId;
    _lastPreloadRequestedAt = now;

    final int backwardRadius;
    final int forwardRadius;
    if (direction > 0) {
      backwardRadius = 1;
      forwardRadius = 3;
    } else if (direction < 0) {
      backwardRadius = 3;
      forwardRadius = 1;
    } else {
      backwardRadius = 2;
      forwardRadius = 2;
    }

    // 🔥 PHASE 1 FIX: Update pin set before preloading.
    _updatePinSet(
      index,
      backwardRadius: backwardRadius,
      forwardRadius: forwardRadius,
    );

    // 🔥 FIX: Wrap in try-catch to prevent crashes during rapid swiping
    try {
      // Bias warming toward the user's swipe direction so the next likely
      // landing video is ready without over-churning the controller pool.
      final Set<int> preloadIndices = <int>{};
      for (int offset = -backwardRadius; offset <= forwardRadius; offset++) {
        preloadIndices.add(index + offset);
      }

      for (final n in preloadIndices) {
        // 🔒 SAFETY: Double-check bounds before accessing
        if (n >= 0 && n < videos.length) {
          try {
            final video = videos[n];

            // 🔒 SAFETY: Validate video object before preloading
            if (video.id.isEmpty || video.videoURL.isEmpty) {
              log('⚠️ PlaybackManager: Invalid video at index $n, skipping preload');
              continue;
            }

            final videoId = video.id;
            _syncFeedIndexMapping(n, videoId);

            // 🔥 FIX SLOW LOADING: All videos preload in background (fire-and-forget)
            // VideoPlayer widget shows video immediately when controller is ready
            if (!_controllerPool.containsKey(videoId)) {
              // Next videos - preload in background (fire-and-forget)
              log('🔄 PlaybackManager: Preloading next video controller for index $n (video: $videoId)');
              ensureControllerReady(n, video).catchError((e, stackTrace) {
                log('⚠️ PlaybackManager: Error preloading next video index $n: $e');
                log('Stack trace: $stackTrace');
              });
            } else {
              // Check if existing controller is initialized
              final existingController = _controllerPool[videoId];
              if (existingController != null &&
                  _isControllerSafe(videoId, existingController)) {
                try {
                  if (!existingController.value.isInitialized) {
                    // Controller exists but not initialized - ensure it's ready
                    log('🔄 PlaybackManager: Re-initializing controller for index $n (video: $videoId)');
                    ensureControllerReady(n, video).catchError((e, stackTrace) {
                      log('⚠️ PlaybackManager: Error re-initializing index $n: $e');
                    });
                  } else {
                    log('✅ PlaybackManager: Controller already ready for index $n');
                  }
                } catch (_) {
                  // Controller might be disposed - reinitialize
                  log('🔄 PlaybackManager: Controller unsafe, re-initializing for index $n');
                  ensureControllerReady(n, video).catchError((e, stackTrace) {
                    log('⚠️ PlaybackManager: Error re-initializing index $n: $e');
                  });
                }
              } else {
                log('✅ PlaybackManager: Controller already exists for index $n, skipping preload');
              }
            }
          } catch (e, stackTrace) {
            log('❌ PlaybackManager: Error processing preload index $n: $e');
            log('Stack trace: $stackTrace');
            // Continue with next index
          }
        }
      }
    } catch (e, stackTrace) {
      log('❌ PlaybackManager: Critical error in preloadAround: $e');
      log('Stack trace: $stackTrace');
      // Don't crash - just log
    }

    // 🔥 TIKTOK-STYLE: Don't dispose controllers during preloading
    // Wait until after controllers are fully initialized before cleanup
    // Cleanup happens deferred to avoid disposing controllers that are still initializing

    // 🔥 TIKTOK-STYLE: Only enforce pool limit AFTER preloading completes
    // Don't dispose controllers that are in the preload window (current + next 2)
    // This ensures instant playback when swiping
    // Cleanup will happen deferred after initialization completes

    // 🔒 SAFETY: Defer cleanup to next frame AND wait for initialization to complete
    // This ensures preloaded controllers aren't disposed before they're ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        try {
          // Only dispose controllers that are:
          // 1. Far from current index (beyond poolRadius)
          // 2. Fully initialized (not still initializing)
          // 3. Not active or next videos
          if (_controllerPool.length > maxControllerPoolSize) {
            log('⚠️ PlaybackManager: Pool size (${_controllerPool.length}) > limit ($maxControllerPoolSize), cleaning up far controllers');
            disposeFarControllers(index);
          }
        } catch (e) {
          log('❌ PlaybackManager: Error disposing far controllers (deferred): $e');
        }
      });
    });
  }

  /// 🔥 PHASE 1 FIX: Two-stage eviction (cooldown then disposal)
  /// Dispose controllers far from current index with cooldown protection
  /// 🔒 SAFETY: Only disposes controllers that are definitely not in use
  /// 🔥 CRITICAL MEMORY FIX: Also enforces maximum pool size
  void disposeFarControllers(int index) {
    // 🔥 PHASE 1: Update pin set first (protects current + next 2)
    _updatePinSet(index);

    // 🔥 FIX: Wrap entire method in try-catch to prevent crashes
    try {
      final now = DateTime.now();
      final toDispose = <String>[];

      // 🔥 STEP 1: Clean up stale/disposed controllers first
      final staleControllers = <String>[];
      try {
        for (final entry in _controllerPool.entries) {
          try {
            final videoId = entry.key;
            final controller = entry.value;
            if (!_isControllerSafe(videoId, controller)) {
              staleControllers.add(videoId);
            }
          } catch (e) {
            log('⚠️ PlaybackManager: Error checking controller safety: $e');
            // Continue with next entry
          }
        }
      } catch (e, stackTrace) {
        log('❌ PlaybackManager: Error cleaning stale controllers: $e');
        log('Stack trace: $stackTrace');
        // Continue anyway
      }

      // Clean up stale controllers
      for (final videoId in staleControllers) {
        try {
          _logControllerEvent('DISPOSE_REQUESTED', videoId,
              reason: 'stale_controller');
          _controllerPool.remove(videoId);
          _controllerOwners.remove(videoId);
          _muteStates.remove(videoId);
          _disposedControllers[videoId] = true;
          _pinnedVideoIds.remove(videoId);
          _cooldownUntil.remove(videoId);
          _attachedControllers.remove(videoId);
          _controllerCreatedAt.remove(videoId);
          final videoIndex = _videoIdToIndex[videoId];
          if (videoIndex != null) {
            _videoIdToIndex.remove(videoId);
            _indexToVideoId.remove(videoIndex);
            _lastKnownPositions.remove(videoIndex);
          }
          _logControllerEvent('DISPOSED', videoId, reason: 'stale');
        } catch (e) {
          log('⚠️ PlaybackManager: Error cleaning stale controller $videoId: $e');
        }
      }

      // 🔥 PHASE 1 FIX: STEP 2: Two-stage eviction - Stage A: Mark for cooldown
      try {
        for (final entry in _controllerPool.entries) {
          try {
            final videoId = entry.key;
            final videoIndex = _videoIdToIndex[videoId];

            // 🔥 GUARD: Never dispose pinned, active, or initializing controllers
            if (_pinnedVideoIds.contains(videoId) ||
                videoId == _activeVideoId ||
                _isActiveVideo(videoId) ||
                _initializingControllers.contains(videoId)) {
              // Cancel cooldown if video came back into protected zone
              if (_cooldownUntil.containsKey(videoId)) {
                _cooldownUntil.remove(videoId);
                _logControllerEvent('COOLDOWN_CANCELLED', videoId,
                    reason: 'protected_zone');
              }
              continue;
            }
            // 🔥 PHASE 2.3: Never dispose controller currently attached to a view
            final attachedId = _attachedControllers[videoId];
            if (attachedId != null && attachedId == entry.value.hashCode) {
              if (_cooldownUntil.containsKey(videoId)) {
                _cooldownUntil.remove(videoId);
                _logControllerEvent('COOLDOWN_CANCELLED', videoId,
                    reason: 'attached');
              }
              continue;
            }
            // 🔥 PHASE 2.3: Don't dispose within TTL of registration (reduces surface churn on scroll-back)
            final createdAt = _controllerCreatedAt[videoId];
            if (createdAt != null &&
                now.difference(createdAt) <
                    Duration(seconds: disposalEligibilityTtlSeconds)) {
              if (!_cooldownUntil.containsKey(videoId)) {
                _cooldownUntil[videoId] = createdAt
                    .add(Duration(seconds: disposalEligibilityTtlSeconds));
                _logControllerEvent('START_COOLDOWN', videoId,
                    reason: 'within_ttl');
              }
              continue;
            }

            // Check if outside radius
            if (videoIndex != null && (videoIndex - index).abs() > poolRadius) {
              final controller = entry.value;
              if (!_isControllerSafe(videoId, controller)) continue;

              try {
                // Only mark for cooldown if controller is initialized and ready
                if (controller.value.isInitialized &&
                    !controller.value.hasError) {
                  // Check if already in cooldown
                  if (_cooldownUntil.containsKey(videoId)) {
                    // Check if cooldown expired
                    final cooldownExpiry = _cooldownUntil[videoId]!;
                    if (now.isAfter(cooldownExpiry)) {
                      // Cooldown expired - mark for disposal
                      toDispose.add(videoId);
                    }
                  } else {
                    // Start cooldown (soft eviction)
                    _cooldownUntil[videoId] =
                        now.add(Duration(seconds: cooldownSeconds));
                    _logControllerEvent('START_COOLDOWN', videoId,
                        reason:
                            'outside_radius index=$videoIndex current=$index');
                  }
                }
              } catch (_) {
                // Skip if controller check fails
              }
            } else if (videoIndex == null) {
              // No index mapping - start cooldown if initialized
              final controller = entry.value;
              if (_attachedControllers[videoId] == controller.hashCode) {
                continue;
              }
              final createdAt = _controllerCreatedAt[videoId];
              if (createdAt != null &&
                  now.difference(createdAt) <
                      Duration(seconds: disposalEligibilityTtlSeconds)) {
                if (!_cooldownUntil.containsKey(videoId)) {
                  _cooldownUntil[videoId] = createdAt
                      .add(Duration(seconds: disposalEligibilityTtlSeconds));
                  _logControllerEvent('START_COOLDOWN', videoId,
                      reason: 'no_index_within_ttl');
                }
                continue;
              }
              if (_isControllerSafe(videoId, controller)) {
                try {
                  if (controller.value.isInitialized &&
                      !controller.value.hasError) {
                    if (!_cooldownUntil.containsKey(videoId)) {
                      _cooldownUntil[videoId] =
                          now.add(Duration(seconds: cooldownSeconds));
                      _logControllerEvent('START_COOLDOWN', videoId,
                          reason: 'no_index_mapping');
                    } else {
                      final cooldownExpiry = _cooldownUntil[videoId]!;
                      if (now.isAfter(cooldownExpiry)) {
                        toDispose.add(videoId);
                      }
                    }
                  }
                } catch (_) {
                  // Skip if controller check fails
                }
              }
            }
          } catch (e) {
            log('⚠️ PlaybackManager: Error processing controller entry: $e');
            // Continue with next entry
          }
        }

        // 🔥 PHASE 1 FIX: STEP 3: Stage B - Hard eviction (rate limited: max 1 per cycle)
        if (toDispose.isNotEmpty &&
            _controllerPool.length > maxControllerPoolSize) {
          // Sort by distance (furthest first)
          toDispose.sort((a, b) {
            final indexA = _videoIdToIndex[a];
            final indexB = _videoIdToIndex[b];
            if (indexA == null) return 1;
            if (indexB == null) return -1;
            final distA = (indexA - index).abs();
            final distB = (indexB - index).abs();
            return distB.compareTo(distA); // Furthest first
          });

          // Dispose only the furthest one (rate limit to prevent spikes)
          final videoIdToDispose = toDispose.first;
          final controller = _controllerPool.remove(videoIdToDispose);
          if (controller != null) {
            final bool isAttached =
                _attachedControllers[videoIdToDispose] == controller.hashCode;
            final createdAt = _controllerCreatedAt[videoIdToDispose];
            final bool withinTtl = createdAt != null &&
                now.difference(createdAt) <
                    Duration(seconds: disposalEligibilityTtlSeconds);
            if (isAttached || withinTtl) {
              _controllerPool[videoIdToDispose] = controller;
            } else {
              _logControllerEvent('DISPOSE_REQUESTED', videoIdToDispose,
                  reason: 'cooldown_expired_furthest');
              try {
                _controllerOwners.remove(videoIdToDispose);
                _muteStates.remove(videoIdToDispose);
                _disposedControllers[videoIdToDispose] = true;
                _pinnedVideoIds.remove(videoIdToDispose);
                _cooldownUntil.remove(videoIdToDispose);
                _attachedControllers.remove(videoIdToDispose);
                _controllerCreatedAt.remove(videoIdToDispose);
                final videoIndex = _videoIdToIndex[videoIdToDispose];
                if (videoIndex != null) {
                  _videoIdToIndex.remove(videoIdToDispose);
                  _indexToVideoId.remove(videoIndex);
                  _lastKnownPositions.remove(videoIndex);
                }
                if (_isControllerSafe(videoIdToDispose, controller)) {
                  controller.dispose();
                }
                _logControllerEvent('DISPOSED', videoIdToDispose,
                    reason: 'cooldown_expired');
              } catch (e) {
                log('❌ PlaybackManager: Error disposing controller $videoIdToDispose: $e');
              }
            }
          }
        }

        // 🔥 PHASE 1 FIX: STEP 4: If pool still too large, mark more for cooldown
        if (_controllerPool.length > maxControllerPoolSize) {
          final readyEntries = _controllerPool.entries.where((e) {
            if (_pinnedVideoIds.contains(e.key) ||
                e.key == _activeVideoId ||
                _isActiveVideo(e.key) ||
                _initializingControllers.contains(e.key)) {
              return false;
            }
            try {
              return _isControllerSafe(e.key, e.value) &&
                  e.value.value.isInitialized &&
                  !e.value.value.hasError;
            } catch (_) {
              return false;
            }
          }).toList();

          readyEntries.sort((a, b) {
            final indexA = _videoIdToIndex[a.key];
            final indexB = _videoIdToIndex[b.key];
            if (indexA == null) return 1;
            if (indexB == null) return -1;
            final distA = (indexA - index).abs();
            final distB = (indexB - index).abs();
            return distB.compareTo(distA); // Furthest first
          });

          // Mark furthest ready entries for cooldown
          final excessCount = _controllerPool.length - maxControllerPoolSize;
          for (final entry in readyEntries.take(excessCount)) {
            if (!_cooldownUntil.containsKey(entry.key)) {
              _cooldownUntil[entry.key] =
                  now.add(Duration(seconds: cooldownSeconds));
              _logControllerEvent('START_COOLDOWN', entry.key,
                  reason:
                      'pool_size_limit distance=${_videoIdToIndex[entry.key] != null ? (_videoIdToIndex[entry.key]! - index).abs() : "unknown"}');
            }
          }
        }
      } catch (e, stackTrace) {
        log('❌ PlaybackManager: Error in two-stage eviction: $e');
        log('Stack trace: $stackTrace');
      }
    } catch (e, stackTrace) {
      log('❌ PlaybackManager: Critical error in disposeFarControllers: $e');
      log('Stack trace: $stackTrace');
      // Don't crash - just log
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
