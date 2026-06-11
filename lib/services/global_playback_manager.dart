import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'playback_focus_coordinator.dart';
import 'playback_controller_pool.dart';
import 'playback_pool_policy.dart';
import 'playback_preload_order.dart';
import 'playback_feed_index_tracker.dart';
import 'playback_tab_lifecycle_coordinator.dart';
import 'playback_startup_warm_coordinator.dart';
import 'playback_eviction_coordinator.dart';
import 'playback_home_lifecycle_coordinator.dart';
import 'playback_controller_factory.dart';
import 'playback_pending_focus_coordinator.dart';
import 'playback_controller_registration_coordinator.dart';
import 'playback_focus_activation_coordinator.dart';
import 'playback_pause_all_coordinator.dart';
import 'playback_blocking_coordinator.dart';
import 'playback_visible_index_coordinator.dart';
import 'playback_active_owner_coordinator.dart';
import 'playback_dispose_pool_coordinator.dart';
import 'playback_app_resume_coordinator.dart';
import 'playback_ensure_ready_coordinator.dart';
import 'playback_loop_coordinator.dart';
import 'playback_volume_coordinator.dart';
import 'playback_recover_controller_coordinator.dart';
import 'playback_telemetry_coordinator.dart';
import 'playback_pool_cap_coordinator.dart';
import '../models/home_video.dart';
import '../constants/playback_owners.dart';
import '../utils/playback_teardown.dart';
import 'playback_warm_window_policy.dart';
import '../features/home/application/home_first_frame_gate.dart';
import '../utils/video_health_gate.dart';
import '../utils/secure_log.dart';
import '../utils/like_interaction_boundary.dart';

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

  /// Focus, blocking, and active-owner state.
  final PlaybackFocusCoordinator _focus = PlaybackFocusCoordinator();

  /// Controller pool — maps, attachment, cooldown, and eviction metadata.
  final PlaybackControllerPool _pool = PlaybackControllerPool();

  Map<String, VideoPlayerController> get _controllerPool => _pool.controllers;
  Map<String, String> get _controllerOwners => _pool.owners;
  Map<String, bool> get _disposedControllers => _pool.disposed;
  Set<String> get _initializingControllers => _pool.initializing;
  Map<String, DateTime> get _cooldownUntil => _pool.cooldownUntil;
  Set<String> get _pinnedVideoIds => _pool.pinnedVideoIds;

  /// Cooldown period before hard disposal — see [PlaybackPoolPolicy].
  static const int cooldownSeconds = PlaybackPoolPolicy.cooldownSeconds;

  /// Minimum controller age before disposal — see [PlaybackPoolPolicy].
  static const int disposalEligibilityTtlSeconds =
      PlaybackPoolPolicy.disposalEligibilityTtlSeconds;

  /// Mute state tracking: videoId -> isMuted
  final Map<String, bool> _muteStates = {};

  /// 🔥 PRODUCTION-GRADE: Pending focus requests (videoId -> owner)
  /// Used for TikTok-style first video autoplay - queues focus requests before controller is ready
  Map<String, String> get _pendingFocusRequests => _focus.pendingFocusRequests;

  final PlaybackPreloadBurstGuard _preloadBurstGuard =
      PlaybackPreloadBurstGuard();

  final PlaybackFeedIndexTracker _feedIndex = PlaybackFeedIndexTracker();
  int _visibleIndexGeneration = 0;
  final PlaybackFeedIndexTracker _discoverCategoryFeedIndex =
      PlaybackFeedIndexTracker();
  final PlaybackTabLifecycleCoordinator _tabLifecycle =
      PlaybackTabLifecycleCoordinator();
  final PlaybackStartupWarmCoordinator _startupWarm =
      PlaybackStartupWarmCoordinator();
  DateTime? _startupWarmCompletedAt;
  final PlaybackEvictionCoordinator _eviction =
      const PlaybackEvictionCoordinator();
  final PlaybackHomeLifecycleCoordinator _homeLifecycle =
      const PlaybackHomeLifecycleCoordinator();
  static const PlaybackControllerFactory _controllerFactory =
      PlaybackControllerFactory();
  static const PlaybackPendingFocusCoordinator _pendingFocus =
      PlaybackPendingFocusCoordinator();
  static const PlaybackFocusActivationCoordinator _focusActivation =
      PlaybackFocusActivationCoordinator();
  static const PlaybackControllerRegistrationCoordinator _registration =
      PlaybackControllerRegistrationCoordinator();
  static const PlaybackPauseAllCoordinator _pauseAllCoordinator =
      PlaybackPauseAllCoordinator();
  static const PlaybackBlockingCoordinator _blockingCoordinator =
      PlaybackBlockingCoordinator();
  static const PlaybackVisibleIndexCoordinator _visibleIndexCoordinator =
      PlaybackVisibleIndexCoordinator();
  static const PlaybackActiveOwnerCoordinator _activeOwnerCoordinator =
      PlaybackActiveOwnerCoordinator();
  static const PlaybackDisposePoolCoordinator _disposePoolCoordinator =
      PlaybackDisposePoolCoordinator();
  static const PlaybackAppResumeCoordinator _appResumeCoordinator =
      PlaybackAppResumeCoordinator();
  static const PlaybackEnsureReadyCoordinator _ensureReadyCoordinator =
      PlaybackEnsureReadyCoordinator();
  final PlaybackLoopCoordinator _loopCoordinator = PlaybackLoopCoordinator();
  static const PlaybackVolumeCoordinator _volumeCoordinator =
      PlaybackVolumeCoordinator();
  static const PlaybackRecoverControllerCoordinator _recoverCoordinator =
      PlaybackRecoverControllerCoordinator();
  static const PlaybackTelemetryCoordinator _telemetryCoordinator =
      PlaybackTelemetryCoordinator();
  static const PlaybackPoolCapCoordinator _poolCap =
      PlaybackPoolCapCoordinator();

  /// IndexedStack tab switch: HomeView stays mounted; keep home pool alive.
  bool _retainHomePoolForTabBackground = false;

  int? get _currentFeedIndex => _feedIndex.currentFeedIndex;

  Map<int, String> get _indexToVideoId => _feedIndex.indexToVideoId;
  Map<String, int> get _videoIdToIndex => _feedIndex.videoIdToIndex;
  Map<int, Duration> get _lastKnownPositions => _feedIndex.lastKnownPositions;

  /// Timing marks used to measure perceived playback readiness.
  final Map<String, DateTime> _controllerWarmStartedAt = {};
  final Map<String, DateTime> _focusRequestedAt = {};
  final Set<String> _firstFrameLoggedForActivation = {};

  /// 🔥 INSTANT PLAYBACK: Mark a controller as initializing
  void markControllerInitializing(String videoId) {
    _pool.markInitializing(videoId);
    secureLog(
        '🔄 PlaybackManager: Marked controller as initializing: $videoId');
  }

  /// Clear an initialization marker when a widget-level warmup exits before
  /// registration. Registration also clears this; this method is a safe no-op
  /// for the normal successful path.
  void clearControllerInitializing(String videoId) {
    if (_pool.initializing.remove(videoId)) {
      secureLog('✅ PlaybackManager: Cleared initializing marker: $videoId');
    }
  }

  /// Adjust the active video's volume without changing focus. Used by overlays
  /// such as comments that should keep video motion alive while ducking audio.
  Future<void> setActiveVideoVolume(double volume) {
    return _volumeCoordinator.setActiveVideoVolume(
      volume: volume,
      focus: _focus,
      controllerPool: _controllerPool,
      controllerOwners: _controllerOwners,
      muteStates: _muteStates,
      isControllerSafe: _isControllerSafe,
      onTelemetry: logTelemetry,
      log: secureLog,
    );
  }

  /// 🔥 PHASE 2.3: Mark controller as attached to a view (protects from disposal)
  void markControllerAttached(String videoId, int controllerId) {
    _pool.markAttached(videoId, controllerId);
    secureLog(
        '📌 PlaybackManager: Controller attached videoId=$videoId controllerId=$controllerId');
  }

  bool isControllerAttachedToView(String videoId, int controllerId) {
    return _pool.attached[videoId] == controllerId;
  }

  /// 🔥 PHASE 2.3: Mark controller as detached from view (eligible for disposal after cooldown)
  void markControllerDetached(String videoId) {
    if (_pool.attached.remove(videoId) != null) {
      secureLog('📌 PlaybackManager: Controller detached videoId=$videoId');
      _enforcePoolCap(reason: 'view_detached');
    }
  }

  /// Activation epoch to cancel stale async work
  int _activationEpoch = 0;
  String? _inFlightFocusKey;
  Future<void>? _inFlightFocusFuture;
  String? _inFlightSwitchKey;
  Future<void>? _inFlightSwitchFuture;

  /// 🔥 FIX: Track which controller is currently being played to prevent double audio
  VideoPlayerController? _currentlyPlayingController;

  /// Configuration
  // TikTok-style: keep current + forward warm slots, with room for one
  // transition controller during fast page changes.
  static const int poolRadius = 1;
  static const int recoveryTimeoutMs = 5000;
  static const int maxControllerPoolSize =
      PlaybackPoolPolicy.maxControllerPoolSize;

  // ============================================
  // STREAMS
  // ============================================

  /// Stream of active video ID changes
  Stream<String?> get activeVideoStream => _focus.activeVideoStream;

  /// Stream of active owner changes
  Stream<String?> get activeOwnerStream => _focus.activeOwnerStream;

  /// Stream of blocked state changes
  Stream<bool> get playbackBlockedStream => _focus.playbackBlockedStream;

  // ============================================
  // GETTERS
  // ============================================

  /// Get the currently active video ID
  String? get activeVideoId => _focus.activeVideoId;

  /// Get the currently active owner
  String? get activeOwner => _focus.activeOwner;
  String? get visibleOwner => _focus.visibleOwner;

  /// Check if a video ID is currently active
  bool isActive(String videoId) => _focus.isActive(videoId);

  /// 🔥 FIX: Extra protection check to ensure active video is never disposed
  /// This prevents auto-pause after many playbacks
  bool _isActiveVideo(String videoId) {
    // Check if this is the active video
    if (_focus.activeVideoId == videoId) return true;

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
        secureLog('⚠️ PlaybackManager: Error checking if video is active: $e');
        return true; // Don't dispose if we can't verify
      }
    }

    return false;
  }

  /// Check if we're in a paused state
  bool get isPaused => _tabLifecycle.isPaused;

  /// Check if playback is blocked
  bool get isPlaybackBlocked => _focus.blockLevel > 0;

  /// Get current block level
  int get blockLevel => _focus.blockLevel;

  /// Get current block reason
  String? get blockReason => _focus.blockReason;

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
    return _pool.isControllerSafe(videoId, controller);
  }

  /// No evict active, no evict attached, only past TTL. No exceptions.
  bool _canEvict(String id, VideoPlayerController controller, DateTime now) {
    return _pool.canEvict(
      id: id,
      controller: controller,
      now: now,
      activeVideoId: _focus.activeVideoId,
    );
  }

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
    _activeOwnerCoordinator.setActiveOwner(
      owner: owner,
      focus: _focus,
      controllerPool: _controllerPool,
      controllerOwners: _controllerOwners,
      muteStates: _muteStates,
      isControllerSafe: _isControllerSafe,
      log: secureLog,
    );
  }

  void setVisibleOwner(String owner) {
    if (_focus.visibleOwner == owner && _focus.activeOwner == owner) {
      return;
    }
    final String? previousVisible = _focus.visibleOwner;
    _focus.setVisibleOwner(owner);
    secureLog(
      '👁️ PlaybackManager: Visible owner set to: $owner '
      '(was $previousVisible)',
    );
    _reconcilePoolForVisibleOwner(owner);
    setActiveOwner(owner);
    _enforcePoolCap(reason: 'visible_owner_$owner');
  }

  /// Force unblock completely (sets block level to 0)
  /// Use this when you need to ensure playback is unblocked (e.g., PlayerScreen opening)
  void forceUnblock() {
    if (_focus.forceUnblock()) {
      secureLog(
          '🔓 PlaybackManager: FORCE UNBLOCKING (was blocked, reason cleared)');
      secureLog('✅ PlaybackManager: FORCE UNBLOCKED - ready for playback');
    }
  }

  Future<void> recoverInteractionOnAppResume({
    String fallbackOwner = PlaybackOwners.home,
  }) {
    _tabLifecycle.isPaused = false;
    return _appResumeCoordinator.recoverInteractionOnAppResume(
      focus: _focus,
      controllerPool: _controllerPool,
      controllerOwners: _controllerOwners,
      forceUnblock: forceUnblock,
      setActiveOwner: setActiveOwner,
      pauseAllExcept: pauseAllExcept,
      requestFocus: requestFocus,
      isControllerSafe: _isControllerSafe,
      fallbackOwner: fallbackOwner,
      log: secureLog,
    );
  }

  /// Check if a specific owner can play audio
  ///
  /// **Purpose:**
  /// Returns true only if the given owner matches the active owner and playback
  /// is not blocked. This prevents non-active owners from playing audio.
  ///
  /// **Hierarchical Owners:**
  /// Supports hierarchical owners (e.g., 'home/forYou' matches 'home').
  /// If activeOwner is 'home', then 'home/forYou' (and other home/*) can play.
  ///
  /// **Parameters:**
  /// - [owner]: The owner key to check (e.g., 'home', 'home/forYou', 'discover')
  ///
  /// **Returns:**
  /// - `true` if owner matches active owner (or is a sub-owner) and playback is not blocked
  /// - `false` if owner doesn't match or playback is blocked
  bool canPlay(String owner) {
    if (_focus.blockLevel > 0) {
      secureLog(
          '🚫 PlaybackManager: Owner $owner cannot play (blocked, level: $_focus.blockLevel)');
      return false;
    }

    if (!_focus.ownerMatchesVisibleOwner(owner)) {
      secureLog(
          '🚫 PlaybackManager: Owner $owner cannot play (visibleOwner: $_focus.visibleOwner)');
      return false;
    }

    // 🔥 INSTANT PLAYBACK: Auto-set active owner if null (instead of blocking)
    // This prevents canPlay() from blocking playback unnecessarily
    if (_focus.activeOwner == null) {
      secureLog(
          '🔧 PlaybackManager: Active owner is null, auto-setting to $owner for instant playback');
      setActiveOwner(owner);
      return true; // Now can play after auto-setting
    }

    // Check exact match or hierarchical match (e.g., 'home/forYou' matches 'home')
    final ownerMatches =
        owner == _focus.activeOwner || owner.startsWith('$_focus.activeOwner/');
    if (!ownerMatches) {
      secureLog(
          '🚫 PlaybackManager: Owner $owner cannot play (activeOwner: $_focus.activeOwner)');
      return false;
    }

    return true;
  }

  bool _shouldLoopVideo(String videoId) {
    if (_focus.activeVideoId != videoId) {
      return false;
    }
    if (_focus.blockLevel > 0) {
      return false;
    }
    if (_tabLifecycle.isPaused) {
      return false;
    }
    final String? owner = _controllerOwners[videoId];
    if (!PlaybackLoopCoordinator.isFeedLoopOwner(owner)) {
      return false;
    }
    if (!_focus.ownerMatchesVisibleOwner(owner!)) {
      return false;
    }
    if (_focus.activeOwner == null) {
      return false;
    }
    return canPlay(owner);
  }

  Future<void> _configureControllerLooping(
    String videoId,
    VideoPlayerController controller,
  ) {
    return _loopCoordinator.configureForVideo(
      videoId: videoId,
      controller: controller,
      shouldLoop: _shouldLoopVideo,
      canPlay: canPlay,
      resolveOwner: (String id) => _controllerOwners[id],
      log: secureLog,
    );
  }

  // ============================================
  // CORE METHODS
  // ============================================

  /// Activate a specific video (pause all others, play this one)
  ///
  /// Routes to switchActiveTo for atomic focus switching.
  void activate(String videoId, {String? owner}) {
    // Schedule async work without blocking
    switchActiveTo(videoId, owner ?? _focus.activeOwner ?? 'home')
        .catchError((e) {
      secureLog('⚠️ PlaybackManager: Error in activate: $e');
    });
  }

  Future<void> _ensurePlayingUnmuted(VideoPlayerController controller) async {
    final targetVideoId = _focus.activeVideoId;
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
      secureLog(
          'GPM PLAY id=$targetVideoId initialized=$initialized hasError=$hasError '
          'isPlayingBefore=$isPlayingBefore');
      if (!initialized || hasError) return;
      _currentlyPlayingController = controller;
      _focusRequestedAt[targetVideoId] = DateTime.now();
      _firstFrameLoggedForActivation.remove(targetVideoId);
      try {
        await controller.setLooping(true);
        secureLog('LOOP_ENABLED videoId=$targetVideoId reason=focus');
        secureLog('LOOP_NATIVE_ENABLED videoId=$targetVideoId reason=focus');
      } catch (e, st) {
        ignorePlaybackTeardownError('global_playback', e, st);
      }
      final Duration duration = value.duration;
      if (duration > Duration.zero && value.position >= duration) {
        secureLog(
          'LOOP_ENDED_DETECTED videoId=$targetVideoId '
          'position=${value.position.inMilliseconds} '
          'duration=${duration.inMilliseconds} reason=focus',
        );
        secureLog(
          'LOOP_MANUAL_SKIPPED_NATIVE_ACTIVE videoId=$targetVideoId '
          'reason=focus',
        );
      }
      if (value.isPlaying && value.position > Duration.zero) {
        if (_focus.activeVideoId == targetVideoId &&
            _controllerPool[targetVideoId] == controller) {
          await controller.setVolume(1.0);
          secureLog(
              '🔊 PlaybackManager: Video already playing - unmuted immediately');
        }
        return;
      }
      if (!value.isPlaying) {
        await controller.play();
        try {
          final isPlayingAfter = controller.value.isPlaying;
          secureLog(
              'GPM PLAY id=$targetVideoId isPlayingAfter=$isPlayingAfter');
        } catch (e, st) {
          ignorePlaybackTeardownError('global_playback', e, st);
        }
        secureLog('▶️ PlaybackManager: Started playing video');
      }
      final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final Duration probeDelay1 = Duration(milliseconds: isAndroid ? 75 : 50);
      final Duration probeDelay2 = Duration(milliseconds: isAndroid ? 100 : 50);
      final Duration minPositionForUnmute =
          Duration(milliseconds: isAndroid ? 16 : 30);

      await controller.setVolume(0.0);
      await Future.delayed(probeDelay1);
      if (_focus.activeVideoId != targetVideoId ||
          _controllerPool[targetVideoId] != controller) {
        try {
          await controller.setVolume(0.0);
        } catch (e, st) {
          ignorePlaybackTeardownError('global_playback', e, st);
        }
        return;
      }
      var probe = controller.value;
      var ready = probe.isInitialized &&
          !probe.hasError &&
          probe.isPlaying &&
          !probe.isBuffering &&
          probe.position >= minPositionForUnmute;
      if (ready) {
        await controller.setVolume(1.0);
        secureLog(
            '🔊 PlaybackManager: Unmuted video after ${probeDelay1.inMilliseconds}ms');
        return;
      }
      await Future.delayed(probeDelay2);
      if (_focus.activeVideoId != targetVideoId ||
          _controllerPool[targetVideoId] != controller) {
        try {
          await controller.setVolume(0.0);
        } catch (e, st) {
          ignorePlaybackTeardownError('global_playback', e, st);
        }
        return;
      }
      probe = controller.value;
      ready = probe.isInitialized &&
          !probe.hasError &&
          probe.isPlaying &&
          !probe.isBuffering;
      if (ready) {
        await controller.setVolume(1.0);
        secureLog(
          '🔊 PlaybackManager: Unmuted video after '
          '${probeDelay1.inMilliseconds + probeDelay2.inMilliseconds}ms',
        );
        return;
      }
      if (isAndroid) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_focus.activeVideoId == targetVideoId &&
            _controllerPool[targetVideoId] == controller) {
          final androidProbe = controller.value;
          if (androidProbe.isInitialized &&
              !androidProbe.hasError &&
              androidProbe.isPlaying) {
            await controller.setVolume(1.0);
            secureLog(
                '🔊 PlaybackManager: Unmuted video after Android extended probe');
            return;
          }
        }
      }
      final finalProbe = controller.value;
      if (finalProbe.isInitialized &&
          !finalProbe.hasError &&
          finalProbe.isPlaying) {
        await controller.setVolume(1.0);
        secureLog('🔊 PlaybackManager: Unmuted video (optimistic)');
      }
    } catch (e) {
      secureLog('⚠️ PlaybackManager: Error ensuring play/unmute: $e');
      if (_currentlyPlayingController == controller) {
        _currentlyPlayingController = null;
      }
    }
  }

  Future<void> _safePauseAndMute(VideoPlayerController controller) async {
    try {
      await controller.pause();
    } catch (e, st) {
      ignorePlaybackTeardownError('global_playback', e, st);
    }
    try {
      await controller.setVolume(0.0);
    } catch (e, st) {
      ignorePlaybackTeardownError('global_playback', e, st);
    }
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
        } catch (e, st) {
          ignorePlaybackTeardownError('global_playback', e, st);
        }
        _muteStates[id] = true;
        continue;
      }

      await _safePauseAndMute(controller);
      _muteStates[id] = true;
    }
  }

  /// Atomic switch: pause/mute old, ensure new, dispose old (throttled), play new.
  Future<void> switchActiveTo(String newVideoId, String owner) {
    final String requestKey = '$owner::$newVideoId';
    final VideoPlayerController? controller = _controllerPool[newVideoId];
    if (_focus.activeVideoId == newVideoId &&
        _focus.activeOwner == owner &&
        controller != null &&
        identical(_currentlyPlayingController, controller) &&
        _isControllerSafe(newVideoId, controller)) {
      secureLog(
          'GPM switch ignored id=$newVideoId owner=$owner already active');
      return Future<void>.value();
    }
    if (_inFlightSwitchKey == requestKey && _inFlightSwitchFuture != null) {
      secureLog('GPM switch joined id=$newVideoId owner=$owner');
      return _inFlightSwitchFuture!;
    }

    late final Future<void> future;
    future = _focusActivation
        .switchActiveTo(
      newVideoId: newVideoId,
      owner: owner,
      activationEpoch: _activationEpoch,
      bumpActivationEpoch: () => ++_activationEpoch,
      isStaleEpoch: (int epoch) => epoch != _activationEpoch,
      focus: _focus,
      pool: _pool,
      controllerOwners: _controllerOwners,
      muteStates: _muteStates,
      getCurrentlyPlayingController: () => _currentlyPlayingController,
      setCurrentlyPlayingController: (VideoPlayerController? c) {
        _currentlyPlayingController = c;
      },
      ownerMatchesVisible: _focus.ownerMatchesVisibleOwner,
      setActiveOwner: setActiveOwner,
      canPlay: canPlay,
      muteAllExcept: _muteAllExcept,
      safePauseAndMute: _safePauseAndMute,
      ensurePlayingUnmuted: _ensurePlayingUnmuted,
      isControllerSafe: _isControllerSafe,
      log: secureLog,
    )
        .whenComplete(() {
      _alignCurrentFeedIndexWithActiveVideo();
      if (_inFlightSwitchKey == requestKey &&
          identical(_inFlightSwitchFuture, future)) {
        _inFlightSwitchKey = null;
        _inFlightSwitchFuture = null;
      }
    });
    _inFlightSwitchKey = requestKey;
    _inFlightSwitchFuture = future;
    return future;
  }

  /// Request focus for a specific video (pause all others)
  Future<void> requestFocus(String videoId, String owner) {
    final String requestKey = '$owner::$videoId';
    final VideoPlayerController? controller = _controllerPool[videoId];
    if (_focus.activeVideoId == videoId &&
        _focus.activeOwner == owner &&
        controller != null &&
        identical(_currentlyPlayingController, controller) &&
        _isControllerSafe(videoId, controller)) {
      secureLog('GPM focus ignored id=$videoId owner=$owner already active');
      return Future<void>.value();
    }
    if (_inFlightFocusKey == requestKey && _inFlightFocusFuture != null) {
      secureLog('GPM focus joined id=$videoId owner=$owner');
      return _inFlightFocusFuture!;
    }

    late final Future<void> future;
    future = _focusActivation
        .requestFocus(
      videoId: videoId,
      owner: owner,
      focus: _focus,
      pendingFocusRequests: _pendingFocusRequests,
      pool: _pool,
      controllerOwners: _controllerOwners,
      muteStates: _muteStates,
      getCurrentlyPlayingController: () => _currentlyPlayingController,
      ownerMatchesVisible: _focus.ownerMatchesVisibleOwner,
      setActiveOwner: setActiveOwner,
      canPlay: canPlay,
      pauseAll: pauseAll,
      muteAllExcept: _muteAllExcept,
      switchActiveTo: switchActiveTo,
      safePauseAndMute: _safePauseAndMute,
      isControllerSafe: _isControllerSafe,
      log: secureLog,
    )
        .whenComplete(() {
      _alignCurrentFeedIndexWithActiveVideo();
      if (_inFlightFocusKey == requestKey &&
          identical(_inFlightFocusFuture, future)) {
        _inFlightFocusKey = null;
        _inFlightFocusFuture = null;
      }
    });
    _inFlightFocusKey = requestKey;
    _inFlightFocusFuture = future;
    return future;
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
    logTelemetry('pause_all', reason: 'pauseAll');
    _pauseAllCoordinator.pauseAll(
      controllerPool: _controllerPool,
      muteStates: _muteStates,
      onControllerUnsafeRemove: (String videoId) {
        _disposedControllers[videoId] = true;
        _controllerPool.remove(videoId);
      },
      isControllerSafe: _isControllerSafe,
      setCurrentlyPlayingController: (VideoPlayerController? c) {
        _currentlyPlayingController = c;
      },
      log: secureLog,
    );
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
    _blockingCoordinator.block(
      focus: _focus,
      pauseAll: pauseAll,
      onTelemetry: logTelemetry,
      reason: reason,
      log: secureLog,
    );
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
    _blockingCoordinator.unblock(
      focus: _focus,
      onTelemetry: logTelemetry,
      log: secureLog,
    );
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
    _registration.registerController(
      videoId: videoId,
      controller: controller,
      pool: _pool,
      focus: _focus,
      muteStates: _muteStates,
      videoIdToIndex: _videoIdToIndex,
      currentFeedIndex: _currentFeedIndex,
      canEvict: _canEvict,
      isControllerSafe: _isControllerSafe,
      onLogControllerEvent: (String event, String videoId,
              {int? controllerId, String? reason}) =>
          _logControllerEvent(event, videoId,
              controllerId: controllerId, reason: reason),
      onUnregister: unregisterController,
      onApplyPendingFocus: (String id) {
        _applyPendingFocusIfExists(id).catchError((Object e) {
          secureLog('⚠️ PlaybackManager: Error applying pending focus: $e');
        });
      },
      getCurrentlyPlayingController: () => _currentlyPlayingController,
      setCurrentlyPlayingController: (VideoPlayerController? c) {
        _currentlyPlayingController = c;
      },
      scheduleDeferredPoolControllerDispose:
          _registration.scheduleDeferredPoolControllerDispose,
      owner: owner,
      scrollDirection: _feedIndex.lastScrollDirection,
      log: secureLog,
    );
    _configureControllerLooping(videoId, controller).catchError((Object e) {
      secureLog('⚠️ PlaybackManager: Error configuring loop for $videoId: $e');
    });
    _logPoolAudit('created', videoId, reason: owner ?? 'register');
    _enforcePoolCap(reason: 'register', requestedVideoId: videoId);
  }

  void unregisterController(String videoId) {
    final VideoPlayerController? controller = _controllerPool[videoId];
    if (videoId == _focus.activeVideoId &&
        controller != null &&
        _isControllerSafe(videoId, controller)) {
      try {
        if (controller.value.isPlaying) {
          secureLog(
            'ACTIVE_CONTROLLER_DISPOSE_ATTEMPT_BLOCKED videoId=$videoId '
            'controller=${controller.hashCode}',
          );
          return;
        }
      } catch (e, st) {
        ignorePlaybackTeardownError('global_playback', e, st);
      }
    }
    _loopCoordinator.detachForVideo(videoId);
    _registration.unregisterController(
      videoId: videoId,
      pool: _pool,
      focus: _focus,
      muteStates: _muteStates,
      warmStartedAt: _controllerWarmStartedAt,
      focusRequestedAt: _focusRequestedAt,
      firstFrameLoggedKeys: _firstFrameLoggedForActivation,
      isControllerSafe: _isControllerSafe,
      getCurrentlyPlayingController: () => _currentlyPlayingController,
      setCurrentlyPlayingController: (VideoPlayerController? c) {
        _currentlyPlayingController = c;
      },
      disposeControllerAfterPause: _registration.disposeControllerAfterPause,
      log: secureLog,
    );
  }

  void _disposeControllerAfterPause(
    String videoId,
    VideoPlayerController controller,
  ) {
    _registration.disposeControllerAfterPause(
      videoId: videoId,
      controller: controller,
      pool: _pool,
      isControllerSafe: _isControllerSafe,
      log: secureLog,
    );
  }

  void setDesiredFocus(String videoId, String owner) {
    secureLog(
        '🎯 PlaybackManager: Setting desired focus for $videoId (owner: $owner)');

    final VideoPlayerController? controller = _controllerPool[videoId];
    if (controller != null && _isControllerSafe(videoId, controller)) {
      try {
        if (controller.value.isInitialized && !controller.value.hasError) {
          secureLog(
              '✅ PlaybackManager: Controller exists and is ready, applying focus immediately for $videoId');
          requestFocus(videoId, owner).catchError((Object e) {
            secureLog('⚠️ PlaybackManager: Error applying immediate focus: $e');
          });
          _pendingFocusRequests.remove(videoId);
          return;
        }
      } catch (e) {
        secureLog('⚠️ PlaybackManager: Error checking controller state: $e');
      }
    }

    _pendingFocusRequests[videoId] = owner;
    secureLog(
        '⏳ PlaybackManager: Controller not ready for $videoId, queued focus request (owner: $owner)');
    secureLog(
        '📊 PlaybackManager: Pending focus requests: ${_pendingFocusRequests.length}');
  }

  Future<void> _applyPendingFocusIfExists(
    String videoId, {
    int retries = 0,
  }) {
    return _pendingFocus.applyPendingFocusIfExists(
      videoId: videoId,
      pendingFocusRequests: _pendingFocusRequests,
      resolveController: (String id) => _controllerPool[id],
      isControllerSafe: _isControllerSafe,
      switchActiveTo: switchActiveTo,
      retries: retries,
      log: secureLog,
    );
  }

  void clearDesiredFocus(String videoId) {
    if (_pendingFocusRequests.remove(videoId) != null) {
      secureLog(
          '🗑️ PlaybackManager: Cleared pending focus request for $videoId');
    }
  }

  void clearDesiredFocusForOwner(String owner, {String? exceptVideoId}) {
    final int cleared = _focus.clearPendingFocusForOwner(
      owner,
      exceptVideoId: exceptVideoId,
    );
    if (cleared > 0) {
      secureLog(
          '🗑️ PlaybackManager: Cleared $cleared pending focus requests for owner $owner');
    }
  }

  void clearAllDesiredFocus() {
    final int count = _focus.clearAllPendingFocus();
    if (count > 0) {
      secureLog(
          '🗑️ PlaybackManager: Cleared all pending focus requests ($count)');
    }
  }

  /// Dispose all controllers and clear state (for tab switches).
  /// 🔥 PHASE 2.3: Skips controllers still attached (view will dispose them).
  void disposeAll() {
    _retainHomePoolForTabBackground = false;
    _disposePoolCoordinator.disposeAll(
      pool: _pool,
      focus: _focus,
      feedIndex: _feedIndex,
      muteStates: _muteStates,
      warmStartedAt: _controllerWarmStartedAt,
      focusRequestedAt: _focusRequestedAt,
      firstFrameLoggedKeys: _firstFrameLoggedForActivation,
      clearTabPaused: () => _tabLifecycle.isPaused = false,
      isControllerSafe: _isControllerSafe,
      disposeControllerAfterPause: _disposeControllerAfterPause,
      log: secureLog,
    );
  }

  /// Dispose controllers for a specific owner (e.g., when category feed closes)
  /// 🔥 CRITICAL MEMORY FIX: Prevents MediaCodec NO_MEMORY errors
  void disposeControllersForOwner(String owner) {
    _disposePoolCoordinator.disposeControllersForOwner(
      owner: owner,
      focus: _focus,
      controllerOwners: _controllerOwners,
      unregisterController: unregisterController,
      log: secureLog,
    );
  }

  // ============================================
  // TAB SWITCH HANDLING
  // ============================================

  /// Pause all and set paused state (for tab switching)
  void pauseAllForTabSwitch() {
    _tabLifecycle.pauseForTabSwitch(
      onPauseAll: pauseAll,
      log: secureLog,
    );
  }

  /// Pin home warm window and retain pooled controllers during main-tab leave.
  void beginHomeTabBackgroundRetention({int? currentIndex}) {
    _retainHomePoolForTabBackground = true;
    final int? index = currentIndex ?? _currentFeedIndex;
    if (index != null) {
      pinHomeWarmWindowAtIndex(index);
      final String? currentVideoId = _indexToVideoId[index];
      if (currentVideoId != null && currentVideoId.isNotEmpty) {
        _pinCurrentVideo(currentVideoId, reason: 'tab_background');
      }
    }
    secureLog('📌 PlaybackManager: Home tab background retention ON');
  }

  void endHomeTabBackgroundRetention() {
    _retainHomePoolForTabBackground = false;
    secureLog('📌 PlaybackManager: Home tab background retention OFF');
  }

  bool get isRetainingHomePoolForTabBackground =>
      _retainHomePoolForTabBackground;

  /// Protects current ± warm-window indices from pool eviction.
  void pinHomeWarmWindowAtIndex(int index) {
    final ({int backward, int forward}) radii =
        PlaybackWarmWindowPolicy.radiiForDirection(
      _feedIndex.lastScrollDirection,
    );
    _updatePinSet(
      index,
      backwardRadius: radii.backward,
      forwardRadius: radii.forward,
    );
  }

  /// Resume playback after tab switch
  /// ⚠️ DEPRECATED: Use setActiveOwner() instead for proper single active owner model
  void resumeAfterTabSwitch() {
    _tabLifecycle.resumeAfterTabSwitch(
      onRestoreFocus: restoreCurrentFeedFocus,
      activeVideoId: _focus.activeVideoId,
      blockLevel: _focus.blockLevel,
      videoOwner: _focus.activeVideoId != null
          ? _controllerOwners[_focus.activeVideoId]
          : null,
      canPlayOwner: canPlay,
      resolveController: (String videoId) => _controllerPool[videoId],
      isControllerSafe: _isControllerSafe,
      onMuteStateChanged: (String videoId, bool isMuted) {
        _muteStates[videoId] = isMuted;
      },
      log: secureLog,
    );
  }

  /// Get a controller for a video ID (if it exists in the pool)
  /// Get controller for a video ID
  /// 🔒 SAFETY: Returns null if controller is disposed or unsafe
  VideoPlayerController? getController(String videoId) {
    final controller = _controllerPool[videoId];
    if (controller == null) return null;

    // Check if controller is safe before returning
    if (!_isControllerSafe(videoId, controller)) {
      if (_initializingControllers.contains(videoId) ||
          shouldRetainController(videoId)) {
        return null;
      }
      secureLog(
          '⚠️ PlaybackManager: Controller for $videoId is unsafe, removing from pool');
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

  /// Pins Discover full-screen feed controllers so eviction does not churn them.
  void pinSessionVideoIds(Iterable<String> videoIds) {
    for (final String videoId in videoIds) {
      if (videoId.isEmpty) {
        continue;
      }
      _pool.pinnedVideoIds.add(videoId);
      _logControllerEvent('PIN_SET', videoId, reason: 'discover_session');
    }
    _logPoolSnapshot(reason: 'discover_session_pin');
  }

  void unpinSessionVideoIds(Iterable<String> videoIds) {
    for (final String videoId in videoIds) {
      if (videoId.isEmpty) {
        continue;
      }
      _pool.pinnedVideoIds.remove(videoId);
    }
    _logPoolSnapshot(reason: 'discover_session_unpin');
  }

  bool shouldRetainController(String videoId) {
    if (videoId.isEmpty) return false;
    if (_focus.activeVideoId == videoId) return true;
    if (_initializingControllers.contains(videoId)) return true;
    if (_pinnedVideoIds.contains(videoId)) return true;
    if (_controllerOwners[videoId] == PlaybackOwners.player ||
        _controllerOwners[videoId] == PlaybackOwners.discoverPlayer) {
      return true;
    }
    final int? currentIndex = _currentFeedIndex;
    final int? videoIndex = _videoIdToIndex[videoId];
    if (currentIndex != null &&
        videoIndex != null &&
        !PlaybackWarmWindowPolicy.isOutsideWarmWindow(
          videoIndex: videoIndex,
          currentIndex: currentIndex,
          direction: _feedIndex.lastScrollDirection,
        )) {
      return true;
    }
    return false;
  }

  VideoPlayerController? get activeController {
    final videoId = _focus.activeVideoId;
    if (videoId == null) return null;
    final controller = _controllerPool[videoId];
    if (controller == null || !_isControllerSafe(videoId, controller)) {
      return null;
    }
    return controller;
  }

  Map<String, VideoPlayerController> get preloadedControllers =>
      Map.unmodifiable(_controllerPool);

  bool get mutedState {
    final videoId = _focus.activeVideoId;
    if (videoId == null) return true;
    return _muteStates[videoId] ?? true;
  }

  Future<void> playVisibleVideo({
    required int index,
    required HomeVideo video,
  }) {
    return onVisibleIndexChanged(index, video);
  }

  Future<void> pauseAllExcept(String videoId) => _muteAllExcept(videoId);

  void preloadNextVideos({
    required int currentIndex,
    required List<HomeVideo> videos,
    int count = 3,
    String controllerOwner = PlaybackOwners.home,
  }) {
    if (videos.isEmpty || currentIndex < 0 || currentIndex >= videos.length) {
      return;
    }
    preloadAround(
      currentIndex,
      videos,
      direction: _feedIndex.lastScrollDirection,
      controllerOwner: controllerOwner,
    );
    final ({int backward, int forward}) radii =
        PlaybackWarmWindowPolicy.radiiForDirection(
            _feedIndex.lastScrollDirection);
    final int maxOffset =
        radii.forward > radii.backward ? radii.forward : radii.backward;
    for (int index = currentIndex + 1;
        index <= currentIndex + maxOffset && index < videos.length;
        index++) {
      final HomeVideo video = videos[index];
      if (video.id.isEmpty || video.videoURL.isEmpty) continue;
      unawaited(
        ensureControllerReady(
          index,
          video,
          controllerOwner: controllerOwner,
        ),
      );
    }
  }

  void disposeFarAwayVideos(int currentIndex) {
    disposeFarControllers(currentIndex);
  }

  Future<VideoPlayerController?> recoverFailedController(
    HomeVideo video, {
    String owner = PlaybackOwners.home,
  }) {
    return _recoverCoordinator.recoverFailedController(
      video: video,
      unregisterController: unregisterController,
      resolvePlayableSource: VideoHealthGate.instance.resolvePlayableSource,
      getOrCreateController: getOrCreateController,
      owner: owner,
      log: secureLog,
    );
  }

  Future<VideoPlayerController?> _waitForInitializingController(
    String videoId, {
    int attempts = 40,
    Duration step = const Duration(milliseconds: 50),
  }) {
    return _controllerFactory.waitForInitializingController(
      videoId: videoId,
      pool: _pool,
      isControllerSafe: _isControllerSafe,
      attempts: attempts,
      step: step,
      log: secureLog,
    );
  }

  /// Idempotent: return existing controller if present and safe; else create, init, register.
  /// Only manager creates VideoPlayerControllers (stops ExoPlayer/MediaCodec churn).
  Future<VideoPlayerController?> getOrCreateController(
    String videoId,
    String url, {
    String? owner,
  }) async {
    final VideoPlayerController? controller =
        await _controllerFactory.getOrCreate(
      videoId: videoId,
      url: url,
      pool: _pool,
      warmStartedAt: _controllerWarmStartedAt,
      isControllerSafe: _isControllerSafe,
      registerController: registerController,
      waitForInitializing: _waitForInitializingController,
      ensureRoomFor: _ensureRoomForController,
      owner: owner,
      log: secureLog,
    );
    if (controller != null &&
        _controllerPool[videoId] == controller &&
        _isControllerSafe(videoId, controller)) {
      await _configureControllerLooping(videoId, controller);
    } else if (controller != null) {
      secureLog(
        'CONTROLLER_RETURNED_DISPOSED_BUG videoId=$videoId '
        'controller=${controller.hashCode} '
        'pooled=${_controllerPool[videoId]?.hashCode ?? 'none'}',
      );
      return null;
    }
    return controller;
  }

  Set<String> _protectedVideoIdsForPoolCap({String? requestedVideoId}) {
    return <String>{
      if (requestedVideoId != null && requestedVideoId.isNotEmpty)
        requestedVideoId,
      ..._pendingFocusRequests.keys,
    };
  }

  void _pinCurrentVideo(String videoId, {String? owner, String? reason}) {
    if (videoId.isEmpty) {
      return;
    }
    _pool.pinnedVideoIds.add(videoId);
    secureLog(
      'CURRENT_VIDEO_PINNED videoId=$videoId '
      'owner=${owner ?? _controllerOwners[videoId] ?? 'unknown'} '
      'reason=${reason ?? 'current'}',
    );
  }

  void _ensureRoomForController(String videoId, {String? owner}) {
    if (videoId.isEmpty || _pool.containsKey(videoId)) {
      return;
    }
    _pinCurrentVideo(videoId, owner: owner, reason: 'before_create');
    if (_pool.length < maxControllerPoolSize) {
      return;
    }
    final int evicted = _poolCap.enforcePoolCap(
      pool: _pool,
      feedIndex: _feedIndexForPoolCap(),
      activeVideoId: _focus.activeVideoId,
      isActiveVideo: _isActiveVideo,
      onUnregister: unregisterController,
      onPoolAudit: _logPoolAudit,
      protectedVideoIds: _protectedVideoIdsForPoolCap(
        requestedVideoId: videoId,
      ),
      maxSize: maxControllerPoolSize - 1,
      reason: 'ensure_room_before_create',
    );
    if (evicted == 0 && _pool.length >= maxControllerPoolSize) {
      secureLog(
        'EVICTION_BLOCKED_CURRENT videoId=$videoId '
        'pool=${_pool.length} cap=$maxControllerPoolSize '
        'pendingFocus=${_pendingFocusRequests.keys.toList()}',
      );
    }
  }

  // ============================================
  // DEBUGGING
  // ============================================

  /// Get current state for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      ..._focus.debugSnapshot(),
      'isPaused': _tabLifecycle.isPaused,
      'controllerCount': _controllerPool.length,
      'controllerKeys': _controllerPool.keys.toList(),
      'owners': _controllerOwners,
    };
  }

  /// Log current state for debugging
  void logCurrentState() {
    final info = getDebugInfo();
    secureLog('🎵 PlaybackManager State: $info');
  }

  /// Clean up streams (call when app is closing)
  void dispose() {
    _loopCoordinator.detachAll();
    disposeAll();
    _focus.dispose();
  }

  // ============================================
  // TELEMETRY (lightweight)
  // ============================================

  void logTelemetry(String event,
      {String? videoId, String? owner, String? reason, double? volume}) {
    _telemetryCoordinator.logTelemetry(
      focus: _focus,
      event: event,
      videoId: videoId,
      owner: owner,
      reason: reason,
      volume: volume,
      log: secureLog,
    );
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
    _telemetryCoordinator.logControllerEvent(
      event: event,
      videoId: videoId,
      pool: _pool,
      pinnedVideoIds: _pinnedVideoIds,
      initializingControllers: _initializingControllers,
      cooldownUntil: _cooldownUntil,
      controllerId: controllerId,
      reason: reason,
      onPoolSnapshot: ({String? reason}) => _logPoolSnapshot(reason: reason),
      log: secureLog,
    );
  }

  void _logPoolSnapshot({String? reason}) {
    if (LikeInteractionBoundary.isActive) {
      secureLog(
        'POOL_SIZE_DURING_DOUBLE_TAP size=${_pool.length} '
        'cap=$maxControllerPoolSize reason=${reason ?? 'unknown'}',
      );
    }
    _telemetryCoordinator.logPoolSnapshot(
      pool: _pool,
      pinnedVideoIds: _pinnedVideoIds,
      initializingControllers: _initializingControllers,
      cooldownUntil: _cooldownUntil,
      reason: reason,
      log: secureLog,
    );
  }

  // ============================================
  // PHASE 1: PIN SET MANAGEMENT
  // ============================================

  /// Update pin set for the active window around the current video.
  void _updatePinSet(
    int currentIndex, {
    int backwardRadius = 1,
    int forwardRadius = 1,
  }) {
    _pool.updatePinSet(
      currentIndex: currentIndex,
      indexToVideoId: _indexToVideoId,
      backwardRadius: backwardRadius,
      forwardRadius: forwardRadius,
    );
    for (int offset = -backwardRadius; offset <= forwardRadius; offset++) {
      final int index = currentIndex + offset;
      final String? videoId = _indexToVideoId[index];
      if (videoId != null && _pool.containsKey(videoId)) {
        _logControllerEvent('PIN_SET', videoId,
            reason: 'index=$index offset=$offset');
      }
    }
    _enforcePoolCap(reason: 'pin_set_update');
    _logPoolSnapshot(reason: 'pin_set_update');
  }

  // ============================================
  // TIKTOK-STYLE FEED MANAGEMENT
  // ============================================

  /// Called when user enters HomeView
  /// 🎯 SINGLE ACTIVE OWNER: Uses setActiveOwner instead of unblock
  void onEnterHomeView() {
    _homeLifecycle.onEnterHomeView(
      setActiveOwner: setVisibleOwner,
      restoreCurrentFeedFocus: restoreCurrentFeedFocus,
      log: secureLog,
    );
  }

  void restoreCurrentFeedFocus() {
    _homeLifecycle.restoreCurrentFeedFocus(
      currentFeedIndex: _currentFeedIndex,
      videoIdAtIndex: (int index) => _indexToVideoId[index],
      clearDesiredFocusForOwner: clearDesiredFocusForOwner,
      setDesiredFocus: setDesiredFocus,
      log: secureLog,
    );
  }

  /// Called when user leaves HomeView
  /// ✅ FIX #1: Non-blocking - just pause and save position
  /// Reserve block()/unblock() for global situations like camera, heavy modals, etc.
  void onLeaveHomeView() {
    _homeLifecycle.onLeaveHomeView(
      saveCurrentPosition: _saveCurrentPosition,
      clearDesiredFocusForOwner: clearDesiredFocusForOwner,
      pauseAll: pauseAll,
      log: secureLog,
    );
  }

  void _syncFeedIndexMapping(int index, String videoId) {
    _feedIndex.syncMapping(
      index: index,
      videoId: videoId,
      onClearStaleFocus: clearDesiredFocus,
      log: secureLog,
    );
    _alignCurrentFeedIndexWithActiveVideo();
  }

  void _alignCurrentFeedIndexWithActiveVideo() {
    final String? activeId = _focus.activeVideoId;
    if (activeId == null) {
      return;
    }
    final int? mappedIndex = _videoIdToIndex[activeId];
    if (mappedIndex != null) {
      _feedIndex.currentFeedIndex = mappedIndex;
    }
  }

  void noteFirstFrameRendered(
    String videoId, {
    int? controllerId,
    Size? size,
  }) {
    final activationStartedAt = _focusRequestedAt[videoId];
    final warmStartedAt = _controllerWarmStartedAt[videoId];
    final now = DateTime.now();
    final activationMs = activationStartedAt == null
        ? null
        : now.difference(activationStartedAt).inMilliseconds;
    final int? controllerAgeMs = warmStartedAt == null
        ? null
        : now.difference(warmStartedAt).inMilliseconds;
    final int? activationToFirstFrameMs = activationMs;
    final int? warmReuseMs =
        controllerAgeMs != null && activationToFirstFrameMs != null
            ? controllerAgeMs - activationToFirstFrameMs
            : controllerAgeMs;
    final key = '$videoId:${activationStartedAt?.millisecondsSinceEpoch ?? 0}';
    if (_firstFrameLoggedForActivation.contains(key)) return;
    _firstFrameLoggedForActivation.add(key);
    secureLog(
      '🎞️ PlaybackManager: first_frame video=$videoId '
      'controller=${controllerId ?? 'unknown'} '
      'size=${size == null ? 'unknown' : '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}'} '
      'activationToFirstFrameMs=${activationToFirstFrameMs ?? 'n/a'} '
      'controllerAgeMs=${controllerAgeMs ?? 'n/a'} '
      'warmReuseMs=${warmReuseMs ?? 'n/a'} '
      'pool=${_controllerPool.length}',
    );
    HomeFirstFrameGate.instance.markFirstFrameRendered(
      videoId: videoId,
      source: 'playback_manager',
    );
  }

  /// Called when visible index changes in vertical feed.
  /// Mutes all videos first (await) then ensures controller exists and queues focus.
  Future<void> onVisibleIndexChanged(int newIndex, HomeVideo video) {
    final int generation = ++_visibleIndexGeneration;
    return _visibleIndexCoordinator.onVisibleIndexChanged(
      newIndex: newIndex,
      video: video,
      requestGeneration: generation,
      isRequestStale: () => generation != _visibleIndexGeneration,
      feedIndex: _feedIndex,
      savePositionForIndex: _savePositionForIndex,
      syncFeedIndexMapping: _syncFeedIndexMapping,
      clearDesiredFocus: clearDesiredFocus,
      clearDesiredFocusForOwner: clearDesiredFocusForOwner,
      getPooledController: getController,
      waitForInitializing: _waitForInitializingController,
      getOrCreateController: getOrCreateController,
      requestFocus: requestFocus,
      resolvePlayableSource: VideoHealthGate.instance.resolvePlayableSource,
      isControllerReady: _isControllerSafe,
      log: secureLog,
    );
  }

  /// Called when app lifecycle changes
  void onAppLifecycleChanged(AppLifecycleState state) {
    _homeLifecycle.onAppLifecycleChanged(
      state: state,
      saveCurrentPosition: _saveCurrentPosition,
      pauseAll: pauseAll,
      currentFeedIndex: _currentFeedIndex,
      log: secureLog,
    );
  }

  /// Ensure controller is ready for given index
  /// 🔥 FIX: Optimized for faster initialization - reduced timeout and better error handling
  Future<void> ensureControllerReady(
    int index,
    HomeVideo video, {
    String controllerOwner = PlaybackOwners.home,
  }) {
    return _ensureReadyCoordinator.ensureControllerReady(
      index: index,
      video: video,
      pool: _pool,
      initializingControllers: _initializingControllers,
      lastKnownPositions: _lastKnownPositions,
      isControllerSafe: _isControllerSafe,
      waitForInitializing: _waitForInitializingController,
      resolvePlayableSource: VideoHealthGate.instance.resolvePlayableSource,
      getOrCreateController: getOrCreateController,
      syncFeedIndexMapping: _syncFeedIndexMapping,
      controllerOwner: controllerOwner,
      log: secureLog,
    );
  }

  void preloadStartupWindow(
    List<HomeVideo> videos, {
    int startIndex = 0,
    bool requestFocusOnStart = true,
  }) {
    final DateTime? completedAt = _startupWarmCompletedAt;
    if (completedAt != null &&
        startIndex == 0 &&
        DateTime.now().difference(completedAt) < const Duration(seconds: 20)) {
      secureLog(
        '⏭️ PlaybackManager: Skipping duplicate startup preload '
        '(first video already warm)',
      );
      return;
    }
    _startupWarm.preloadStartupWindow(
      videos: videos,
      startIndex: startIndex,
      requestFocusOnStart: requestFocusOnStart,
      onSyncMapping: _syncFeedIndexMapping,
      onUpdatePinSet: (int index) {
        final ({int backward, int forward}) radii =
            PlaybackWarmWindowPolicy.radiiForDirection(1);
        _updatePinSet(
          index,
          backwardRadius: radii.backward,
          forwardRadius: radii.forward,
        );
      },
      onEnsureReady: ensureControllerReady,
      onRequestFocus: requestFocus,
      onDisposeFarControllers: disposeFarControllers,
      log: secureLog,
    );
  }

  /// Await first playable controller before HomeView is shown (startup path).
  Future<void> warmFirstFeedController(
    List<HomeVideo> videos, {
    int startIndex = 0,
  }) async {
    if (videos.isEmpty) {
      return;
    }
    final int safeIndex = startIndex.clamp(0, videos.length - 1);
    final HomeVideo video = videos[safeIndex];
    if (video.id.isEmpty) {
      return;
    }
    _syncFeedIndexMapping(safeIndex, video.id);
    final ({int backward, int forward}) radii =
        PlaybackWarmWindowPolicy.radiiForDirection(1);
    _updatePinSet(
      safeIndex,
      backwardRadius: radii.backward,
      forwardRadius: radii.forward,
    );
    _feedIndex.lastScrollDirection = 1;
    secureLog(
      '🚀 PlaybackManager: Blocking warm for first feed videos from index '
      '$safeIndex (count=${radii.forward + 1})',
    );
    final int warmEnd = (safeIndex + radii.forward).clamp(0, videos.length - 1);
    await ensureControllerReady(safeIndex, videos[safeIndex]);
    if (warmEnd > safeIndex) {
      await Future.wait<void>(<Future<void>>[
        for (int index = safeIndex + 1; index <= warmEnd; index++)
          ensureControllerReady(index, videos[index]),
      ]);
    }
    _startupWarmCompletedAt = DateTime.now();
  }

  /// Preload controllers around given index
  /// 🔒 SAFETY: Defers disposal to avoid disposing controllers during widget build
  /// 🔥 FIX SLOW LOADING: Preloads videos in background (non-blocking) for instant UI response
  /// Binds Discover category swipe feed without touching Home index mappings.
  void bindDiscoverCategoryFeed(List<HomeVideo> videos) {
    _discoverCategoryFeedIndex.clear();
    for (int index = 0; index < videos.length; index++) {
      final String videoId = videos[index].id;
      if (videoId.isEmpty) {
        continue;
      }
      _discoverCategoryFeedIndex.syncMapping(
        index: index,
        videoId: videoId,
      );
    }
    if (videos.isNotEmpty) {
      _discoverCategoryFeedIndex.currentFeedIndex = 0;
    }
    secureLog(
      '📋 PlaybackManager: Bound Discover category feed (${videos.length} videos)',
    );
  }

  void preloadDiscoverCategoryAround(
    int index,
    List<HomeVideo> videos, {
    int direction = 0,
  }) {
    if (videos.isEmpty || index < 0 || index >= videos.length) {
      return;
    }
    _eviction.preloadAround(
      index: index,
      videos: videos,
      pool: _pool,
      feedIndex: _discoverCategoryFeedIndex,
      burstGuard: _preloadBurstGuard,
      onSyncFeedIndexMapping: (int mappedIndex, String videoId) {
        _discoverCategoryFeedIndex.syncMapping(
          index: mappedIndex,
          videoId: videoId,
        );
      },
      onUpdatePinSet: _updateDiscoverCategoryPinSet,
      onEnsureControllerReady: ensureControllerReady,
      onDisposeFarControllers: (int currentIndex) {
        _eviction.disposeFarControllers(
          index: currentIndex,
          pool: _pool,
          feedIndex: _discoverCategoryFeedIndex,
          muteStates: _muteStates,
          activeVideoId: _focus.activeVideoId,
          isActiveVideo: _isActiveVideo,
          onUpdatePinSet: _updateDiscoverCategoryPinSet,
          onLogControllerEvent: (String event, String videoId,
              {String? reason}) {
            _logControllerEvent(event, videoId, reason: reason);
          },
          log: secureLog,
        );
      },
      direction: direction,
      controllerOwner: PlaybackOwners.discoverPlayer,
      log: secureLog,
    );
    _discoverCategoryFeedIndex.currentFeedIndex = index;
    requestFocus(videos[index].id, PlaybackOwners.discoverPlayer);
  }

  void _updateDiscoverCategoryPinSet(
    int currentIndex, {
    int backwardRadius = 1,
    int forwardRadius = 1,
  }) {
    _pool.updatePinSet(
      currentIndex: currentIndex,
      indexToVideoId: _discoverCategoryFeedIndex.indexToVideoId,
      backwardRadius: backwardRadius,
      forwardRadius: forwardRadius,
    );
    for (int offset = -backwardRadius; offset <= forwardRadius; offset++) {
      final int mappedIndex = currentIndex + offset;
      final String? videoId =
          _discoverCategoryFeedIndex.indexToVideoId[mappedIndex];
      if (videoId != null && _pool.containsKey(videoId)) {
        _logControllerEvent(
          'PIN_SET',
          videoId,
          reason: 'discover_category index=$mappedIndex',
        );
      }
    }
  }

  void preloadAround(
    int index,
    List<HomeVideo> videos, {
    int direction = 0,
    String controllerOwner = PlaybackOwners.home,
  }) {
    _eviction.preloadAround(
      index: index,
      videos: videos,
      pool: _pool,
      feedIndex: _feedIndex,
      burstGuard: _preloadBurstGuard,
      onSyncFeedIndexMapping: _syncFeedIndexMapping,
      onUpdatePinSet: _updatePinSet,
      onEnsureControllerReady: ensureControllerReady,
      onDisposeFarControllers: disposeFarControllers,
      direction: direction,
      controllerOwner: controllerOwner,
      log: secureLog,
    );
  }

  /// 🔥 PHASE 1 FIX: Two-stage eviction (cooldown then disposal)
  /// Dispose controllers far from current index with cooldown protection
  /// 🔒 SAFETY: Only disposes controllers that are definitely not in use
  /// 🔥 CRITICAL MEMORY FIX: Also enforces maximum pool size
  void disposeFarControllers(int index) {
    _eviction.disposeFarControllers(
      index: index,
      pool: _pool,
      feedIndex: _feedIndex,
      muteStates: _muteStates,
      activeVideoId: _focus.activeVideoId,
      isActiveVideo: _isActiveVideo,
      onUpdatePinSet: _updatePinSet,
      onLogControllerEvent: (String event, String videoId, {String? reason}) {
        _logControllerEvent(event, videoId, reason: reason);
      },
      log: secureLog,
    );
    _enforcePoolCap(reason: 'dispose_far_$index');
  }

  void _reconcilePoolForVisibleOwner(String visibleOwner) {
    if (_retainHomePoolForTabBackground &&
        visibleOwner != PlaybackOwners.home &&
        !visibleOwner.startsWith('${PlaybackOwners.home}/')) {
      secureLog(
        '👁️ PlaybackManager: Skipping home pool strip — tab background '
        'retention active',
      );
      return;
    }
    final int stripped = _poolCap.stripConflictingSurfaceControllers(
      visibleOwner: visibleOwner,
      pool: _pool,
      controllerOwners: _controllerOwners,
      onUnregister: unregisterController,
      onPoolAudit: _logPoolAudit,
    );
    if (stripped > 0) {
      _logPoolSnapshot(reason: 'surface_handoff_$visibleOwner');
    }
  }

  PlaybackFeedIndexTracker _feedIndexForPoolCap() {
    final String? visible = _focus.visibleOwner;
    if (visible == PlaybackOwners.discoverPlayer) {
      return _discoverCategoryFeedIndex;
    }
    return _feedIndex;
  }

  void _enforcePoolCap({required String reason, String? requestedVideoId}) {
    final int evicted = _poolCap.enforcePoolCap(
      pool: _pool,
      feedIndex: _feedIndexForPoolCap(),
      activeVideoId: _focus.activeVideoId,
      isActiveVideo: _isActiveVideo,
      onUnregister: unregisterController,
      onPoolAudit: _logPoolAudit,
      protectedVideoIds: _protectedVideoIdsForPoolCap(
        requestedVideoId: requestedVideoId,
      ),
      reason: reason,
    );
    if (evicted > 0) {
      _logPoolSnapshot(reason: reason);
    }
  }

  void _logPoolAudit(
    String action,
    String videoId, {
    String? reason,
  }) {
    _telemetryCoordinator.logPoolAudit(
      action: action,
      videoId: videoId,
      poolSize: _pool.length,
      reason: reason,
      log: secureLog,
    );
  }

  /// Get controller for index
  /// 🔒 SAFETY: Returns null if controller is disposed or unsafe
  VideoPlayerController? getControllerForIndex(int index) {
    final videoId = _indexToVideoId[index];
    if (videoId == null) return null;
    return getController(videoId); // Use safe getController method
  }

  /// Get current feed index
  int? get currentFeedIndex => _feedIndex.currentFeedIndex;

  /// Save current position
  void _saveCurrentPosition() {
    _feedIndex.saveCurrentPosition(
      resolveController: getControllerForIndex,
      isControllerSafe: _isControllerSafe,
      log: secureLog,
    );
  }

  /// Save position for specific index
  void _savePositionForIndex(int index) {
    _feedIndex.savePositionForIndex(
      index: index,
      resolveController: getControllerForIndex,
      isControllerSafe: _isControllerSafe,
      log: secureLog,
    );
  }
}

/// Riverpod provider for the global playback manager
final globalPlaybackManagerProvider = Provider<GlobalPlaybackManager>((ref) {
  return GlobalPlaybackManager.instance;
});
