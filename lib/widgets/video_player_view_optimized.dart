import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:streamers_tip/utils/secure_log.dart';

// cspell:ignore unmuted unmuting HOMEVIEW
import '../models/feed_tab.dart';
import '../constants/playback_owners.dart';
import '../models/creator_profile_snapshot.dart';
import '../models/home_video.dart';
import '../services/creator_cache_service.dart';
import '../providers/home_provider.dart';
import '../services/performance_service.dart';
import '../services/robust_auth_service.dart';
import '../features/video_player/widgets/video_player_action_rail.dart';
import '../features/video_player/widgets/video_player_action_rail_metrics.dart';
import '../features/video_player/widgets/video_player_bookmark_listener.dart';
import '../features/video_player/widgets/video_player_creator_avatar.dart';
import '../features/video_player/widgets/video_player_feed_caption_overlay.dart';
import '../features/video_player/widgets/video_player_black_screen_recovery.dart';
import '../features/video_player/widgets/video_player_publish_state_overlay.dart';
import '../features/video_player/widgets/video_player_thumbnail_poster.dart';
import '../features/video_player/application/video_cell_bootstrap.dart';
import '../features/video_player/application/video_cell_init_attach_coordinator.dart';
import '../features/video_player/application/video_cell_init_error_coordinator.dart';
import '../features/video_player/application/video_cell_init_error_classifier.dart';
import '../features/video_player/application/video_cell_watchdog_tokens.dart';
import '../features/video_player/application/video_cell_activation_coordinator.dart';
import '../features/video_player/widgets/video_player_premium_feed_scrim.dart';
import '../features/video_player/widgets/video_player_contained_stage.dart';
import '../features/video_player/widgets/video_player_media3_home_surface.dart';
import '../features/video_player/platform/android_media3_home_controller.dart';
import '../widgets/double_tap_gesture_detector.dart';
import '../widgets/enhanced_share_sheet.dart';
import '../providers/video_like_provider.dart';
import '../services/video_controller_registry.dart';
import '../services/production_logging_service.dart';
import '../utils/safe_video_controller.dart';
import '../services/audio_enhancement_service.dart';
import '../services/global_playback_manager.dart';
import '../widgets/comments_view2.dart';
import '../services/enhanced_algorithm_service.dart';
import '../services/ml_recommendation_service.dart';
import '../services/unified_bookmark_service.dart';
import '../services/video_resume_service.dart';
import '../services/feed_telemetry_service.dart';
import '../routing/app_navigator.dart';
import '../utils/playback_teardown.dart';
import '../utils/video_health_gate.dart';
import '../utils/video_caption_resolver.dart';
import '../utils/interaction_diagnostics.dart';
import '../services/thumbnail_service.dart';
import '../widgets/creator_command_center_overlay.dart';
import '../models/creator_command_snapshot.dart';
import '../providers/creator_command_provider.dart';
import '../qa/qa_keys.dart';

class VideoPlayerViewOptimized extends ConsumerStatefulWidget {
  static const bool enableAndroidMedia3Home = bool.fromEnvironment(
    'STREAMERSTIP_ANDROID_MEDIA3_HOME',
    defaultValue: false,
  );

  final HomeVideo video;
  final bool isCurrentVideo;
  final bool isFirstVideo;
  final String
      tabId; // Track which tab this video belongs to (deprecated, use ownerKey)
  final String?
      ownerKey; // Owner key for single active owner model (e.g., 'home', 'discover', 'player', 'profile')
  final HomeViewModel homeViewModel;
  final bool showSheet;
  final String sheetType;
  final VoidCallback? onShowProfile; // Optional - falls back to internal method
  final VoidCallback? onShowComments; // Optional - falls back to _handleComment
  final VoidCallback? onShowShare; // Optional - falls back to _handleShare
  final VoidCallback?
      onShowStreamerCard; // Optional - falls back to internal method
  final bool isLiked;
  final bool isBookmarked;
  final bool showHUD; // NEW: Control whether to show HUD overlays
  final bool showCommandCenterTrigger;
  final VoidCallback? onCommandCenterTap;
  final VoidCallback? onVideoUnplayable; // 🔥 TIKTOK-STYLE: Auto-skip callback
  final VoidCallback? onVideoPlaySuccess; // Resets consecutive-failure counter

  /// When true, off-screen feed cells skip [initState] controller creation so
  /// the current page can initialize without competing ExoPlayer sessions.
  final bool deferOffscreenControllerInit;

  const VideoPlayerViewOptimized({
    super.key,
    required this.video,
    required this.isCurrentVideo,
    required this.isFirstVideo,
    required this.tabId,
    this.ownerKey, // Optional - will fall back to tabId if not provided
    required this.homeViewModel,
    required this.showSheet,
    required this.sheetType,
    this.onShowProfile, // Now optional
    this.onShowComments, // Now optional
    this.onShowShare, // Now optional
    this.onShowStreamerCard, // Now optional
    this.isLiked = false,
    this.isBookmarked = false,
    this.showHUD = true, // Default to true for backward compatibility
    this.showCommandCenterTrigger = false,
    this.onCommandCenterTap,
    this.onVideoUnplayable, // 🔥 TIKTOK-STYLE: Optional auto-skip callback
    this.onVideoPlaySuccess,
    this.deferOffscreenControllerInit = false,
  });

  @override
  ConsumerState<VideoPlayerViewOptimized> createState() =>
      _VideoPlayerViewOptimizedState();
}

class _VideoPlayerViewOptimizedState
    extends ConsumerState<VideoPlayerViewOptimized>
    with AutomaticKeepAliveClientMixin {
  // Removed WidgetsBindingObserver - GlobalPlaybackManager handles lifecycle
  VideoPlayerController? _videoPlayerController;
  AndroidMedia3HomeController? _nativeMedia3Controller;
  String? _nativeMedia3Url;
  String? _lastResolvedUrl;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _audioEnhancementScheduled = false;
  bool _audioEnhancementApplied = false;
  bool _nativeLoopingEnabled = false;
  int _loopEndedDetectedAtMs = 0;

  /// Derived from controller so we never have initialized=true and controller=null.
  bool get _controllerReady {
    final VideoPlayerController? c = _videoPlayerController;
    return readVideoControllerOr(
      c,
      (VideoPlayerValue v) => !v.hasError && v.isInitialized,
      false,
      context: '_controllerReady',
    );
  }

  bool get _media3HomeOwnerEnabled {
    return VideoPlayerViewOptimized.enableAndroidMedia3Home &&
        _ownerKey.startsWith('home');
  }

  bool get _useNativeMedia3Home {
    return false;
  }

  void _setStateSafely(VoidCallback update) {
    if (!mounted || _isDisposed) {
      return;
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) {
          return;
        }
        setState(update);
      });
      return;
    }

    setState(update);
  }

  bool _hasIncrementedView = false;
  static const Duration _minWatchTimeForView = Duration(seconds: 7);
  Timer? _viewCountTimer;
  bool _thumbnailVisible = true;
  Timer? _posterTimer;
  bool _showPlayPauseIndicatorOverlay =
      false; // Show play/pause indicator animation
  bool _audioUnmuted =
      false; // Track if audio has been unmuted by user interaction
  bool _isDisposed = false; // Track if this widget's controller is disposed
  bool _isDisposingController = false;
  bool _wasRegistered =
      false; // Track if controller was registered with registry
  bool _isBookmarked =
      false; // Local bookmark state; UnifiedBookmarkService is source of truth
  bool _didFirstReadyRebuild =
      false; // Track if we've triggered rebuild when controller becomes ready
  bool _doubleTapInFlight = false;
  Future<List<Map<String, dynamic>>>? _taggedUsersFuture;

  /// Standardized owner key for controller registration/disposal
  String get _ownerKey {
    // Prefer explicit ownerKey if provided, otherwise fall back to tabId
    if (widget.ownerKey != null && widget.ownerKey!.isNotEmpty) {
      return widget.ownerKey!;
    }
    // Fallback to tabId for backward compatibility
    return widget.tabId.isNotEmpty ? widget.tabId : 'home/forYou';
  }

  // Production-ready controller management
  final VideoControllerRegistry _registry = VideoControllerRegistry();
  final ProductionLoggingService _logger = ProductionLoggingService();
  final ThumbnailService _thumbnailService = ThumbnailService();
  static const VideoCellBootstrap _cellBootstrap = VideoCellBootstrap();
  static const VideoCellInitAttachCoordinator _initAttach =
      VideoCellInitAttachCoordinator();
  static const VideoCellInitErrorCoordinator _initErrors =
      VideoCellInitErrorCoordinator();
  static const VideoCellInitErrorClassifier _initErrorClassifier =
      VideoCellInitErrorClassifier();
  static const VideoCellActivationCoordinator _activation =
      VideoCellActivationCoordinator();
  late UnifiedBookmarkService _bookmarkService;
  final VideoResumeService _resumeService = VideoResumeService();

  // Stream subscription for bookmark state changes
  VideoPlayerBookmarkListener? _bookmarkListener;

  // Top-level video comments (matches CommentsView2); not denormalized field.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _commentCountSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _videoDocStatsSubscription;
  int _commentCount = 0; // Real-time comment count
  int _shareCount = 0;
  int _favoriteCount = 0;

  // Stream subscription for active owner changes (to resume playback when returning to view)
  StreamSubscription<String?>? _activeOwnerSubscription;

  // 🔥 INSTANT PLAYBACK: Retry subscription for requestFocus failures
  StreamSubscription<String?>? _retryFocusSubscription;

  // Network error recovery: Retry logic
  int _videoRetryCount = 0;
  static const int _maxVideoRetries = 3;
  static const Duration _videoRetryDelay = Duration(seconds: 2);

  // 🚀 VIRAL ALGORITHM: Watch time tracking
  Timer? _watchTimeTracker;
  Timer? _firstFrameWatchdog;
  Timer? _stallWatchdog;
  Timer? _loopCheckTimer; // 🔥 FIX: Dedicated timer for loop checking
  bool _stuckRecoveryAttempted = false;
  Duration _lastPlaybackPosition = Duration.zero;
  // ✅ TIKTOK-STYLE: Track when playback starts to detect "audio but no frames"
  DateTime? _playbackStartTime;
  bool _hasSeenFirstFrame = false;
  DateTime?
      _firstFrameRenderedAt; // 🔥 PRODUCTION-GRADE: Timestamp when first frame rendered

  static const VideoPlayerBlackScreenRecovery _blackScreenRecovery =
      VideoPlayerBlackScreenRecovery();
  final VideoPlayerBlackScreenRecoveryState _blackScreenRecoveryState =
      VideoPlayerBlackScreenRecoveryState();
  static final Map<String, int> _recoveryAttemptsPerVideo =
      {}; // Track attempts per videoId across sessions
  bool _hasTrackedWatch = false; // Track if we've logged a watch (>50%)
  bool _hasTrackedInterestWatch = false;
  bool _hasPreloadedNextAtSeventy = false;
  double _lastWatchPercentage =
      0.0; // Track last watch percentage for skip detection
  bool _hasRequestedFocus = false; // Debounce focus requests per visibility
  String?
      _lastRequestedVideoId; // Track which video we last requested focus for
  String? _playbackError;
  bool _showErrorAfterDelay =
      false; // 🔥 FIX: Don't show error immediately during transitions
  bool _isInitializing = false;
  // 🔥 REMOVED: _overrideVideoUrl - Health gate now handles URL selection

  // 🔥 TIKTOK-STYLE: Generation token to prevent stale errors
  int _playbackGeneration = 0;

  // 🔥 PRODUCTION-GRADE: Controller version token to prevent disposal race conditions
  // Increments whenever controller instance changes - used to abort stale async operations
  int _controllerVersion = 0;
  VideoPlayerController?
      _currentControllerInstance; // Track current controller instance

  // Surface/MediaCodec BAD_INDEX mitigation: keep routine keys stable, but
  // allow explicit first-frame recovery to recreate the platform texture.
  int _surfaceRecoveryEpoch = 0;

  // 🔥 TIKTOK-STYLE: Broken video quarantine (session-local)
  static final Set<String> _brokenVideoIds = <String>{};
  static final Set<String> _initializingVideoIds = <String>{};

  // 🔥 TIKTOK-STYLE: Video health state
  bool _isUnplayable = false;

  // Callback for auto-skip broken videos
  VoidCallback? onVideoUnplayable;
  int _lastLoopRefreshMs = 0;
  int _exactEndLoopRescueCount = 0;
  static final Map<String, DateTime> _lastHardReinit = {};
  static const Duration _hardReinitCooldown = Duration(seconds: 3);

  void _unregisterFromPlaybackManagerIfSameInstance({
    required String videoId,
    required VideoPlayerController controller,
  }) {
    try {
      final current = GlobalPlaybackManager.instance.getController(videoId);
      if (current == null) return;
      if (!identical(current, controller)) return;
      GlobalPlaybackManager.instance.unregisterController(videoId);
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }
  }

  void _disposeStaleManagerController(VideoPlayerController controller) {
    try {
      final current = GlobalPlaybackManager.instance.getController(
        widget.video.id,
      );
      if (current == null || !identical(current, controller)) {
        return;
      }
      GlobalPlaybackManager.instance.unregisterController(widget.video.id);
      secureLog(
        '🗑️ VideoPlayer: Disposed stale initialized controller for ${widget.video.id}',
      );
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }
  }

  Future<void> _disposeVideoController() async {
    if (_isDisposingController) {
      debugPrint('[VideoPlayer] dispose skipped (already disposing/disposed)');
      return;
    }
    _isDisposingController = true;
    final controller = _videoPlayerController;
    final controllerHashCode = controller?.hashCode;

    // 🔥 PRODUCTION-GRADE: Increment version FIRST to abort any pending async operations
    _controllerVersion++;
    secureLog(
        '🗑️ VideoPlayer: Disposing controller ${controllerHashCode ?? 'null'}, version incremented to $_controllerVersion');

    // 🔥 CRITICAL FIX: Set to null FIRST to prevent any new operations on it
    _videoPlayerController = null;
    _currentControllerInstance = null; // Clear instance tracking
    _isInitialized = false;
    _isDisposed = true; // Mark as disposed immediately to prevent further use

    if (controller == null) {
      _isDisposingController = false;
      return;
    }

    try {
      GlobalPlaybackManager.instance.markControllerDetached(widget.video.id);
      final owner = _ownerKey;
      secureLog(
        '🗑️ VideoPlayer: Unregistering controller '
        '$controllerHashCode from owner $owner',
      );
      debugPrint(
        '[VideoPlayer] unregister owner=$owner controller=$controllerHashCode',
      );
      _unregisterFromPlaybackManagerIfSameInstance(
        videoId: widget.video.id,
        controller: controller,
      );

      // 🔥 PRODUCTION-GRADE: Remove listeners with comprehensive error handling
      try {
        if (_canUseController(controller)) {
          controller.removeListener(_videoErrorListener);
          controller.removeListener(_videoStateListener);
          controller.removeListener(_videoPositionListener);
          controller.removeListener(_onControllerChanged);
          secureLog(
              '🔌 VideoPlayer: Removed all listeners from controller $controllerHashCode');
        } else {
          secureLog(
              '⚠️ VideoPlayer: Controller $controllerHashCode already disposed, skipping listener removal');
        }
      } catch (e) {
        // Controller may already be disposed - this is okay
        secureLog(
            '⚠️ VideoPlayer: Could not remove listeners (controller disposed): $e');
        debugPrint(
            '[VideoPlayer] Could not remove listeners (controller disposed): $e');
      }

      try {
        // Only pause/setVolume if controller is still valid
        if (!controller.value.hasError) {
          await controller.pause().catchError((_) {});
          await controller.setVolume(0.0).catchError((_) {});
        }
      } catch (e) {
        debugPrint(
            '[VideoPlayer] Could not pause/mute (controller disposed): $e');
      }

      try {
        // Let pending video_player platform play/pause completions settle before
        // the platform texture is torn down.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await controller.dispose();
      } catch (e, st) {
        debugPrint('[VideoPlayer] dispose error: $e\n$st');
      }
    } finally {
      _isDisposingController = false;
    }
  }

  Future<void> _pauseAndMuteController() async {
    final controller = _videoPlayerController;
    if (controller == null) return;
    try {
      await controller.pause();
      await controller.setVolume(0.0);
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  // 🔥 REMOVED: _releaseInactiveController() - no longer needed
  // Disposal only happens in widget.dispose() now

  // ✅ TIKTOK-STYLE: Only check if controller is safe to touch (not disposed)
  // Don't require initialized - we mount VideoPlayer early and overlay black until ready
  bool _canUseController(VideoPlayerController? controller) {
    return isVideoControllerAlive(controller);
  }

  /// Clear reference to a disposed controller after build (never mutate state in build).
  void _scheduleClearDisposedController(
      VideoPlayerController? disposedController) {
    if (disposedController == null) return;
    final toClear = disposedController;
    final wasCurrent = widget.isCurrentVideo;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_videoPlayerController == toClear) {
        setState(() {
          _videoPlayerController = null;
          _currentControllerInstance = null;
          _isInitialized = false;
          _isPlaying = false;
          _thumbnailVisible = true;
        });
        _posterTimer?.cancel();
        _posterTimer = null;
        secureLog(
            '⚠️ VideoPlayer: Cleared disposed controller ref for ${widget.video.id}');
        if (wasCurrent && mounted) {
          _initializeVideo();
        }
      }
    });
  }

  /// ✅ PRODUCTION-GRADE: Adopt a pooled controller properly with version tracking
  /// This ensures immediate setState, listener attachment, and rebuild
  /// Also increments controller version to abort stale async operations
  void _detachListenersFromController(VideoPlayerController controller) {
    try {
      if (!_canUseController(controller)) return;
      controller.removeListener(_videoErrorListener);
      controller.removeListener(_videoStateListener);
      controller.removeListener(_videoPositionListener);
      controller.removeListener(_onControllerChanged);
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }
  }

  /// Drop [VideoPlayer] from the tree, wait for surface release, then dispose.
  void _disposeReplacedControllerAfterSurfaceDetach(
    VideoPlayerController oldController,
    int oldControllerId,
  ) {
    unawaited(() async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || _isDisposed) return;
      try {
        if (_canUseController(oldController)) {
          await oldController.pause().catchError((_) {});
          await oldController.setVolume(0.0).catchError((_) {});
        }
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }
      try {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await oldController.dispose();
        secureLog(
            '🗑️ VideoPlayer: Disposed replaced controller $oldControllerId after surface detach');
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }
    }());
  }

  void _adoptController(VideoPlayerController controller) {
    if (!mounted) return;

    final controllerChanged = _currentControllerInstance != controller;
    final controllerId = controller.hashCode;
    if (controllerChanged && _currentControllerInstance != null) {
      final VideoPlayerController oldController = _currentControllerInstance!;
      final int oldControllerId = oldController.hashCode;
      secureLog(
          '🎬 CONTROLLER_DETACHED: videoId=${widget.video.id} controllerId=$oldControllerId');
      GlobalPlaybackManager.instance.markControllerDetached(widget.video.id);
      secureLog(
        '🔄 VideoPlayer: Controller instance changed '
        '($oldControllerId -> $controllerId); clearing surface before dispose',
      );
      _detachListenersFromController(oldController);
      _controllerVersion++;
      _videoPlayerController = null;
      _currentControllerInstance = null;
      setState(() {});
      _disposeReplacedControllerAfterSurfaceDetach(
          oldController, oldControllerId);
    }

    _videoPlayerController = controller;
    _currentControllerInstance = controller;
    unawaited(controller.setLooping(true).then((_) {
      secureLog('LOOP_ENABLED videoId=${widget.video.id} reason=adopt');
      secureLog('LOOP_NATIVE_ENABLED videoId=${widget.video.id} reason=adopt');
      _nativeLoopingEnabled = true;
    }).catchError((Object e, StackTrace st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }));
    _isDisposed = false;
    _didFirstReadyRebuild = false;
    _posterTimer?.cancel();
    _posterTimer = null;
    _thumbnailVisible = true;
    _isInitialized = readVideoControllerOr(
      controller,
      (VideoPlayerValue v) => v.isInitialized && !v.hasError,
      false,
      context: '_adoptController',
    );
    _isPlaying = readVideoControllerOr(
      controller,
      (VideoPlayerValue v) => v.isPlaying,
      false,
      context: '_adoptController',
    );
    _audioEnhancementScheduled = false;
    _audioEnhancementApplied = false;

    secureLog(
        '🎬 CONTROLLER_ATTACHED: videoId=${widget.video.id} controllerId=$controllerId '
        'init=$_isInitialized isPlaying=$_isPlaying');

    _clearPosterAfterFrameIfPlaying(
      controller: controller,
      reason: 'adopted initialized controller',
    );

    // 🔥 PRODUCTION-GRADE: Reset black screen recovery state on controller change
    _blackScreenRecovery.resetForControllerChange(_blackScreenRecoveryState);
    _hasSeenFirstFrame = false;
    _firstFrameRenderedAt = null;
    _playbackStartTime = null;
    _firstFrameWatchdog?.cancel();
    _firstFrameWatchdog = null;

    // Attach listener to new controller
    try {
      if (_canUseController(controller)) {
        controller.addListener(_onControllerChanged);
        secureLog(
            '🔌 VideoPlayer: Attached _onControllerChanged listener to controller ${controller.hashCode}');
      }
    } catch (e) {
      secureLog(
          '⚠️ VideoPlayer: Error attaching listener to new controller: $e');
    }

    _ensureManagerAttachment(controller);
    // Force rebuild immediately so VideoPlayer enters tree with new key
    _setStateSafely(() {});
  }

  /// ✅ FIX BLACK SCREEN: Listener that triggers ONE rebuild when controller becomes ready
  /// This is the missing piece when audio plays but frames don't render yet
  void _onControllerChanged() {
    if (!mounted) return;

    final c = _videoPlayerController;
    if (c == null) return;

    try {
      final v = c.value;

      // Trigger one rebuild when initialization becomes true OR when playing begins
      if (!_didFirstReadyRebuild && (v.isInitialized || v.isPlaying)) {
        _didFirstReadyRebuild = true;
        _setStateSafely(() {});
      }
    } catch (e, stack) {
      logPlaybackSwallowed('_onControllerChanged', e, stack);
    }
  }

  void _ensureManagerAttachment(VideoPlayerController controller) {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    if (!manager.isControllerAttachedToView(
      widget.video.id,
      controller.hashCode,
    )) {
      manager.markControllerAttached(widget.video.id, controller.hashCode);
    }
  }

  /// Adopt controller from pool when one exists for this videoId (removes identity gate).
  /// Ensures view and manager share the same controller so focus requests succeed.
  bool _tryAdoptFromPool({required String reason}) {
    if (!mounted || !widget.isCurrentVideo) return false;

    final registryController = _registry.getController(widget.video.id);
    if (registryController != null &&
        _canUseController(registryController) &&
        !registryController.value.hasError) {
      if (!identical(_videoPlayerController, registryController)) {
        _adoptController(registryController);
      }
      _ensureManagerAttachment(registryController);
      secureLog(
        'VVIEW adopt id=${widget.video.id} registryHash=${registryController.hashCode} reason=$reason',
      );
      return true;
    }

    final mgr = GlobalPlaybackManager.instance;
    final pooled = mgr.getController(widget.video.id);
    if (pooled == null) return false;

    if (!isVideoControllerAlive(pooled)) {
      mgr.unregisterController(widget.video.id);
      return false;
    }
    if (!isVideoControllerReady(pooled)) {
      return false;
    }

    if (_videoPlayerController != null &&
        identical(_videoPlayerController, pooled)) {
      _ensureManagerAttachment(pooled);
      secureLog(
          'VVIEW adopt id=${widget.video.id} pooledHash=${pooled.hashCode} (already same) reason=$reason');
      return true;
    }

    if (_videoPlayerController != null &&
        !identical(_videoPlayerController, pooled)) {
      _adoptController(pooled);
      try {
        if (_canUseController(pooled)) {
          pooled.addListener(_videoErrorListener);
          pooled.addListener(_videoStateListener);
          pooled.addListener(_videoPositionListener);
        }
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }
      _ensureManagerAttachment(pooled);
      secureLog(
          'VVIEW adopt id=${widget.video.id} pooledHash=${pooled.hashCode} (replaced local) reason=$reason');
      return true;
    }

    _adoptController(pooled);
    try {
      if (_canUseController(pooled)) {
        pooled.addListener(_videoErrorListener);
        pooled.addListener(_videoStateListener);
        pooled.addListener(_videoPositionListener);
      }
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }
    _ensureManagerAttachment(pooled);
    secureLog(
        'VVIEW adopt id=${widget.video.id} pooledHash=${pooled.hashCode} reason=$reason');
    return true;
  }

  VideoPlayerController? _obtainActiveController() {
    if (_isDisposed || _isDisposingController) return null;

    if (_registry.isControllerDisposed(widget.video.id) &&
        !GlobalPlaybackManager.instance.shouldRetainController(
          widget.video.id,
        )) {
      return null;
    }

    final registryController = _registry.getController(widget.video.id);
    if (registryController != null) {
      if (!_canUseController(registryController)) {
        _registry.dispose(widget.video.id);
        return null;
      }
      if (!identical(registryController, _videoPlayerController)) {
        _videoPlayerController = registryController;
      }
      return registryController;
    }

    final playbackController =
        GlobalPlaybackManager.instance.getController(widget.video.id);
    if (playbackController != null) {
      if (!identical(playbackController, _currentControllerInstance)) {
        return null;
      }
      if (!_canUseController(playbackController)) {
        GlobalPlaybackManager.instance.unregisterController(widget.video.id);
        return null;
      }
      if (!identical(playbackController, _videoPlayerController)) {
        _videoPlayerController = playbackController;
      }
      return playbackController;
    }

    if (_wasRegistered) {
      _markControllerDisposed(
        reason: 'Controller missing from registry and playback manager',
      );
      return null;
    }

    return _videoPlayerController;
  }

  bool get _isFeedPlaybackOwner =>
      _ownerKey == PlaybackOwners.home ||
      _ownerKey.startsWith('${PlaybackOwners.home}/');

  bool _shouldRunManualLoopRecovery({
    required VideoPlayerController controller,
    required VideoPlayerValue value,
    required String reason,
  }) {
    if (!widget.isCurrentVideo ||
        !_isFeedPlaybackOwner ||
        _isDisposed ||
        _isDisposingController ||
        !_canUseController(controller)) {
      return false;
    }
    final Duration duration = value.duration;
    final Duration position = value.position;
    if (duration <= Duration.zero || position < duration) {
      _loopEndedDetectedAtMs = 0;
      return false;
    }
    if (value.isPlaying) {
      secureLog(
        'LOOP_MANUAL_SKIPPED_NATIVE_ACTIVE videoId=${widget.video.id} '
        'reason=$reason alreadyPlaying=true',
      );
      return false;
    }
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_nativeLoopingEnabled) {
      _loopEndedDetectedAtMs =
          _loopEndedDetectedAtMs == 0 ? nowMs : _loopEndedDetectedAtMs;
      if (nowMs - _loopEndedDetectedAtMs < 700) {
        secureLog(
          'LOOP_MANUAL_SKIPPED_NATIVE_ACTIVE videoId=${widget.video.id} '
          'reason=$reason',
        );
        return false;
      }
    }
    if ((nowMs - _lastLoopRefreshMs) < 500) {
      secureLog(
        'LOOP_MANUAL_SKIPPED_NATIVE_ACTIVE videoId=${widget.video.id} '
        'reason=$reason debounce=true',
      );
      return false;
    }
    _lastLoopRefreshMs = nowMs;
    return true;
  }

  void _runManualLoopRecovery({
    required VideoPlayerController controller,
    required String reason,
  }) {
    secureLog(
      'LOOP_MANUAL_RESTART videoId=${widget.video.id} reason=$reason',
    );
    unawaited(controller.seekTo(Duration.zero).then((_) {
      if (widget.isCurrentVideo &&
          !_isDisposed &&
          !_isDisposingController &&
          _canUseController(controller)) {
        return controller.play();
      }
    }).then((_) {
      _lastPlaybackPosition = Duration.zero;
      _loopEndedDetectedAtMs = 0;
      secureLog(
        'CURRENT_VIDEO_STALL_RECOVERY videoId=${widget.video.id} '
        'reason=$reason',
      );
    }).catchError((Object e, StackTrace st) {
      secureLog(
        'LOOP_STOPPED_UNEXPECTEDLY videoId=${widget.video.id} reason=$e',
      );
      ignorePlaybackTeardownError('video_player', e, st);
    }));
  }

  void _markControllerDisposed({Object? error, String? reason}) {
    if (_isDisposed) return;
    if (GlobalPlaybackManager.instance
        .shouldRetainController(widget.video.id)) {
      secureLog(
        '📌 VideoPlayer: Ignoring disposed signal for warm-window video '
        '${widget.video.id} (reason: ${reason ?? 'unknown'})',
      );
      _isDisposed = false;
      _tryAdoptFromPool(reason: 'retain disposed signal');
      return;
    }
    final VideoPlayerController? oldController = _currentControllerInstance;
    _isDisposed = true;
    _audioEnhancementScheduled = false;
    _nativeLoopingEnabled = false;
    _loopEndedDetectedAtMs = 0;
    _isDisposingController = false;
    _isInitialized = false;
    _isPlaying = false;
    _controllerVersion++;
    _videoPlayerController = null;
    _currentControllerInstance = null;
    secureLog(
        '🗑️ VideoPlayer: Controller marked as disposed (version $_controllerVersion, reason: ${reason ?? 'unknown'})');
    _stopWatchTimeTracking();
    _firstFrameWatchdog?.cancel();
    _firstFrameWatchdog = null;
    _playbackStartTime = null;
    _hasSeenFirstFrame = false;
    _stallWatchdog?.cancel();
    _stallWatchdog = null;
    _loopCheckTimer?.cancel();
    _loopCheckTimer = null;
    _viewCountTimer?.cancel();
    _viewCountTimer = null;
    _posterTimer?.cancel();
    _posterTimer = null;
    try {
      if (oldController != null) {
        _unregisterFromPlaybackManagerIfSameInstance(
          videoId: widget.video.id,
          controller: oldController,
        );
      }
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }
    try {
      _registry.dispose(widget.video.id);
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }

    final message =
        'Controller disposed for ${widget.video.id}${reason != null ? ' ($reason)' : ''}';
    if (error != null) {
      _logger.warn('$message: $error', tag: 'VideoPlayer');
    } else {
      _logger.warn(message, tag: 'VideoPlayer');
    }
  }

  /// 🚀 VIRAL ALGORITHM: Stop watch time tracking
  void _stopWatchTimeTracking() {
    _watchTimeTracker?.cancel();
    _watchTimeTracker = null;
    secureLog('🎯 Watch time tracking stopped for video ${widget.video.id}');
  }

  /// Initialize bookmark state from UnifiedBookmarkService and listen to changes
  void _initializeBookmarkState() {
    _bookmarkListener = VideoPlayerBookmarkListener(
      videoId: widget.video.id,
      initialIsBookmarked: widget.isBookmarked,
      onBookmarkChanged: (bool isBookmarked) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isBookmarked = isBookmarked;
        });
      },
    );
    _bookmarkService = _bookmarkListener!.service;
    _isBookmarked = _bookmarkListener!.resolveInitialBookmarkState();
    _bookmarkListener!.startListening();
    _bookmarkListener!.ensureUserInitialized();

    if (kDebugMode) {
      debugPrint(
        '📚 VideoPlayerView: Initialized bookmark state for video '
        '${widget.video.id}: $_isBookmarked',
      );
    }
  }

  /// Comment badge = all visible comment docs (top-level + replies), not deleted.
  void _initializeCommentCountListener() {
    _commentCountSubscription?.cancel();
    _commentCountSubscription = null;
    _videoDocStatsSubscription?.cancel();
    _videoDocStatsSubscription = null;

    _commentCount = widget.video.comments;
    _shareCount = 0;
    _favoriteCount = 0;

    final DocumentReference<Map<String, dynamic>> videoRef =
        FirebaseFirestore.instance.collection('videos').doc(widget.video.id);

    _commentCountSubscription =
        videoRef.collection('comments').snapshots().listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        if (!mounted) {
          return;
        }
        final int nextCommentCount = _countVisibleComments(snapshot);
        if (_commentCount != nextCommentCount) {
          setState(() {
            _commentCount = nextCommentCount;
          });
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint(
            'Comment count listener error for ${widget.video.id}: $error',
          );
        }
      },
      cancelOnError: false,
    );

    _videoDocStatsSubscription = videoRef.snapshots().listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        if (!mounted || !snapshot.exists) {
          return;
        }
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) {
          return;
        }
        final int nextShareCount = _readStatCount(
          data,
          primary: 'shares',
          fallback: 'shareCount',
        );
        final int nextFavoriteCount = _readStatCount(
          data,
          primary: 'bookmarkCount',
          fallback: 'favoriteCount',
          additionalFallbacks: const [
            'favorites',
            'bookmarksCount',
            'savesCount'
          ],
        );
        if (_shareCount != nextShareCount ||
            _favoriteCount != nextFavoriteCount) {
          setState(() {
            _shareCount = nextShareCount;
            _favoriteCount = nextFavoriteCount;
          });
        }
      },
    );
  }

  int _countVisibleComments(QuerySnapshot<Map<String, dynamic>> snapshot) {
    int n = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final bool deleted = data['deleted'] as bool? ?? false;
      if (!deleted) {
        n++;
      }
    }
    return n;
  }

  int _readStatCount(
    Map<String, dynamic> data, {
    required String primary,
    String? fallback,
    List<String> additionalFallbacks = const [],
  }) {
    for (final key in <String>[
      primary,
      if (fallback != null) fallback,
      ...additionalFallbacks,
    ]) {
      final dynamic value = data[key];
      if (value is num) {
        return math.max(0, value.toInt());
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return math.max(0, parsed);
      }
    }
    return 0;
  }

  /// Safe controller operations with comprehensive error handling
  Future<bool> _safeSetVolume(double volume) async {
    if (_registry.isControllerDisposed(widget.video.id)) {
      _markControllerDisposed(
          reason: 'Registry reported disposal before setVolume');
      return false;
    }

    final controller = _obtainActiveController();
    if (controller == null) {
      _logger.warn('Cannot set volume: controller unavailable',
          tag: 'VideoPlayer');
      return false;
    }

    try {
      debugPrint(
          '🔊 VideoPlayer: Setting volume to $volume for videoId: ${widget.video.id}');
      await controller.setVolume(volume);
      debugPrint(
          '✅ VideoPlayer: Volume set to $volume successfully for videoId: ${widget.video.id}');
      _logger.debug('Volume set to $volume for ${widget.video.id}',
          tag: 'VideoPlayer');
      return true;
    } catch (e) {
      _logger.error('Error setting volume to $volume',
          tag: 'VideoPlayer', error: e);
      _markControllerDisposed(error: e, reason: 'setVolume');
      return false;
    }
  }

  // ✅ REMOVED: _handleVideoEnter() method - no longer needed
  // All playback now goes through requestFocus() → activate() → play() single path
  // This eliminates duplicate play calls and double audio issues
  // Resume/seek logic is handled elsewhere in the codebase

  /// 🔥 PRODUCTION-GRADE: Consolidated focus request method with full lifecycle awareness
  ///
  /// **Purpose:**
  /// Single source of truth for requesting video focus. Handles all gating logic,
  /// prevents duplicate calls, and ensures focus is only requested at the correct moment.
  ///
  /// **Guards:**
  /// - Widget must be mounted and not disposed
  /// - Video must be current (`isCurrentVideo == true`)
  /// - Playback must not be blocked (modals, backgrounding, etc.)
  /// - Controller must exist and be safe to use
  /// - Must not have already requested focus for this video
  /// - Owner must be able to play
  ///
  /// **Lifecycle:**
  /// - Resets `_hasRequestedFocus` when videoId changes or when isCurrentVideo transitions false -> true
  /// - Tracks last requested videoId to prevent duplicate requests
  ///
  /// **Returns:**
  /// - `true` if focus was requested successfully
  /// - `false` if focus was skipped due to invalid state
  bool _attemptRequestFocus(String reason) {
    final GlobalPlaybackManager playbackManager =
        GlobalPlaybackManager.instance;
    final VideoPlayerController? pooled =
        playbackManager.getController(widget.video.id);
    final VideoCellFocusAttemptOutcome outcome =
        _activation.attemptRequestFocus(
      mounted: mounted,
      isDisposed: _isDisposed,
      isCurrentVideo: widget.isCurrentVideo,
      videoId: widget.video.id,
      ownerKey: _ownerKey,
      hasRequestedFocusForVideo: _hasRequestedFocus,
      lastRequestedVideoId: _lastRequestedVideoId,
      pooledController: pooled,
      widgetController: _videoPlayerController,
      controllersMatchPool:
          pooled != null && identical(_videoPlayerController, pooled),
      adoptFromPool: (String r) => _tryAdoptFromPool(reason: r),
      isPlaybackBlocked: playbackManager.isPlaybackBlocked,
      canPlayOwner: playbackManager.canPlay(_ownerKey),
      setDesiredFocus: playbackManager.setDesiredFocus,
      reason: reason,
      log: secureLog,
    );
    if (outcome == VideoCellFocusAttemptOutcome.skippedBlocked) {
      _safeSetVolume(0.0);
    }
    if (outcome == VideoCellFocusAttemptOutcome.requested) {
      _hasRequestedFocus = true;
      _lastRequestedVideoId = widget.video.id;
      playbackManager.requestFocus(widget.video.id, _ownerKey);
      secureLog(
        '✅ VideoPlayer: Focus request completed ($reason) for: '
        '${widget.video.id}',
      );
      return true;
    }
    return false;
  }

  void _scheduleActivationRetry(String reason,
      {Duration delay = const Duration(milliseconds: 120)}) {
    _retryFocusSubscription?.cancel();
    _retryFocusSubscription = null;

    Future.delayed(delay, () {
      if (!mounted || _isDisposed || !widget.isCurrentVideo) return;
      _hasRequestedFocus = false;
      _lastRequestedVideoId = null;
      _attemptRequestFocus(reason);
    });
  }

  bool _activateCurrentVideo(String reason, {bool allowRetry = true}) {
    final GlobalPlaybackManager playbackManager =
        GlobalPlaybackManager.instance;
    final VideoCellActivateOutcome outcome = _activation.activateCurrentVideo(
      mounted: mounted,
      isDisposed: _isDisposed,
      isCurrentVideo: widget.isCurrentVideo,
      videoId: widget.video.id,
      ownerKey: _ownerKey,
      allowRetry: allowRetry,
      reason: reason,
      resolveActiveController: _obtainActiveController,
      adoptFromPoolWhenEmpty: (String r) => _tryAdoptFromPool(reason: r),
      isPlaybackBlocked: playbackManager.isPlaybackBlocked,
      canPlayOwner: playbackManager.canPlay(_ownerKey),
      setDesiredFocus: playbackManager.setDesiredFocus,
      cancelPendingRetrySubscription: () {
        _retryFocusSubscription?.cancel();
        _retryFocusSubscription = null;
      },
      runAttemptRequestFocus: _attemptRequestFocus,
      log: secureLog,
    );
    switch (outcome) {
      case VideoCellActivateOutcome.notEligible:
        return false;
      case VideoCellActivateOutcome.requestedFocus:
        return true;
      case VideoCellActivateOutcome.retryNoController:
        if (allowRetry) {
          _scheduleActivationRetry('$reason: waiting for controller');
        }
        return false;
      case VideoCellActivateOutcome.retryWhenBlocked:
        _safeSetVolume(0.0);
        if (allowRetry) {
          StreamSubscription<bool>? blockSubscription;
          blockSubscription =
              playbackManager.playbackBlockedStream.listen((bool isBlocked) {
            if (!isBlocked) {
              blockSubscription?.cancel();
              _scheduleActivationRetry(
                '$reason: block cleared',
                delay: const Duration(milliseconds: 40),
              );
            }
          });
        }
        return false;
      case VideoCellActivateOutcome.retryWhenOwnerActive:
        if (allowRetry) {
          _retryFocusSubscription?.cancel();
          _retryFocusSubscription =
              playbackManager.activeOwnerStream.listen((String? activeOwner) {
            final bool ownerMatches = activeOwner != null &&
                (_ownerKey == activeOwner ||
                    _ownerKey.startsWith('$activeOwner/'));
            if (ownerMatches) {
              _retryFocusSubscription?.cancel();
              _retryFocusSubscription = null;
              _scheduleActivationRetry(
                '$reason: owner became active',
                delay: const Duration(milliseconds: 40),
              );
            }
          });
        }
        return false;
    }
  }

  // Key for like button (for floating hearts animation)
  final GlobalKey _likeButtonKey = GlobalKey();

  // Heart animation state (removed - using EnhancedLikeButton animations instead)

  @override
  bool get wantKeepAlive => true; // Keep pages alive while swiping

  @override
  void initState() {
    super.initState();
    if (widget.isCurrentVideo) {
      CreatorCacheService.instance.set(
        widget.video.creator.id,
        widget.video.creatorSnapshot,
      );
    }
    // Removed WidgetsBinding observer - GlobalPlaybackManager handles lifecycle
    // WidgetsBinding.instance.addObserver(this);

    // ✅ FIX: Initialize bookmark state once in initState (not in build)
    _initializeBookmarkState();

    // Initialize real-time comment count listener
    _initializeCommentCountListener();
    _taggedUsersFuture = _fetchTaggedUsers(widget.video.id);

    // 🔄 RESUME ON OWNER CHANGE: Listen for active owner changes to resume playback
    _activeOwnerSubscription =
        GlobalPlaybackManager.instance.activeOwnerStream.listen((activeOwner) {
      if (!mounted || _isDisposed) return;
      final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (!routeIsCurrent) return;

      final owner = _ownerKey;
      // 🔥 SINGLE ACTIVE OWNER: Use hierarchical matching (e.g., 'home/forYou' matches 'home')
      final ownerMatches = activeOwner != null &&
          (owner == activeOwner || owner.startsWith('$activeOwner/'));

      // Let the playback manager arbitrate focus changes instead of
      // force-playing from the widget layer on every owner change.
      if (_media3HomeOwnerEnabled) {
        _syncNativeMedia3Playback('activeOwnerStream');
        return;
      }
      if (ownerMatches && widget.isCurrentVideo && _isInitialized) {
        final controller = _obtainActiveController();
        if (controller != null &&
            controller.value.isInitialized &&
            !controller.value.isPlaying) {
          secureLog(
              '🔄 VideoPlayer: Owner $owner became active for ${widget.video.id}');
          _hasRequestedFocus = false;
          _lastRequestedVideoId = null;
          GlobalPlaybackManager.instance
              .setDesiredFocus(widget.video.id, owner);
          _scheduleActivationRetry(
            'activeOwnerStream',
            delay: const Duration(milliseconds: 40),
          );
        }
      }
    });

    if (_media3HomeOwnerEnabled) {
      secureLog(
          '🎬 PersistentMedia3Home: cell surface disabled for ${widget.video.id} owner=$_ownerKey tab=${widget.tabId}');
      return;
    }

    if (_readyPlaybackUrlFromVideo() == null) {
      _isUnplayable = true;
      _playbackError = 'Video is still processing';
      return;
    }

    _tryAdoptFromPool(reason: 'initState');

    // 🚀 INSTANT PLAYBACK: Initialize video immediately if no pooled controller found
    // Start initialization immediately, don't wait
    if (_videoPlayerController == null) {
      if (widget.deferOffscreenControllerInit && !widget.isCurrentVideo) {
        return;
      }
      _initializeVideo().then((_) {
        // ✅ FIX: _initializeVideo() already calls requestFocus() if video is current (line 1275)
        // Don't call _handleVideoEnter() here to avoid duplicate play calls
        // requestFocus() → activate() already handles playback, _handleVideoEnter() would cause double audio
      }).catchError((e) {
        secureLog(
            '⚠️ VideoPlayer: Error initializing video ${widget.video.id}: $e');
      });
    }
  }

  @override
  void dispose() {
    // Removed WidgetsBinding observer - GlobalPlaybackManager handles lifecycle
    // WidgetsBinding.instance.removeObserver(this);

    _firstFrameWatchdog?.cancel();
    _firstFrameWatchdog = null;
    _stallWatchdog?.cancel();
    _stallWatchdog = null;
    _loopCheckTimer?.cancel();
    _loopCheckTimer = null;
    _posterTimer?.cancel();
    _posterTimer = null;
    _viewCountTimer?.cancel();
    _viewCountTimer = null;

    _bookmarkListener?.dispose();
    _bookmarkListener = null;

    _commentCountSubscription?.cancel();
    _commentCountSubscription = null;
    _videoDocStatsSubscription?.cancel();
    _videoDocStatsSubscription = null;

    _activeOwnerSubscription?.cancel();
    _activeOwnerSubscription = null;

    _retryFocusSubscription?.cancel();
    _retryFocusSubscription = null;

    _stopWatchTimeTracking();
    _nativeMedia3Controller?.dispose();
    _nativeMedia3Controller = null;

    PerformanceService()
        .trackVideoPlayback(widget.video.id, PlaybackEvent.pause);

    final bool retainController =
        GlobalPlaybackManager.instance.shouldRetainController(widget.video.id);

    try {
      final VideoPlayerController? controller = _currentControllerInstance;
      if (controller != null && retainController) {
        _detachListenersFromController(controller);
        GlobalPlaybackManager.instance.markControllerDetached(widget.video.id);
        _registry.detach(widget.video.id);
        secureLog(
          '📌 VideoPlayer: Detached widget for warm-window controller '
          '${widget.video.id}',
        );
      } else if (controller != null) {
        _unregisterFromPlaybackManagerIfSameInstance(
          videoId: widget.video.id,
          controller: controller,
        );
      }
      secureLog(
          '🎵 VideoPlayer: Unregistered controller from PlaybackManager for video ${widget.video.id}');
    } catch (e) {
      secureLog(
          '⚠️ VideoPlayer: Could not unregister from PlaybackManager (widget already disposed): $e');
    }

    try {
      if (retainController) {
        _registry.detach(widget.video.id);
      } else {
        _registry.markHidden(widget.video.id);
        _registry.dispose(widget.video.id);
      }
      secureLog(
          '🔒 VideoPlayer: Unregistered controller from Registry for video ${widget.video.id}');
    } catch (e) {
      secureLog(
          '⚠️ VideoPlayer: Could not unregister from Registry (widget already disposed): $e');
    }
    if (_exactEndLoopRescueCount > 0) {
      secureLog(
        '📊 VideoPlayer: Exact-end loop rescues total='
        '$_exactEndLoopRescueCount for ${widget.video.id}',
      );
      _exactEndLoopRescueCount = 0;
    }

    _isDisposed = true;

    // Prune per-video static maps to prevent unbounded growth over long sessions.
    final videoId = widget.video.id;
    _recoveryAttemptsPerVideo.remove(videoId);
    _lastHardReinit.remove(videoId);
    // _brokenVideoIds entries are intentionally kept for the session duration
    // so the feed skips permanently broken videos; remove them only on retry.

    if (retainController) {
      _videoPlayerController = null;
      _currentControllerInstance = null;
      _isInitialized = false;
    } else {
      _disposeVideoController();
    }

    super.dispose();
  }

  void _startFirstFrameWatchdog() {
    _firstFrameWatchdog?.cancel();
    final int watchdogMs = VideoCellWatchdogTokens.firstFrameTimeoutMs(
      platform: defaultTargetPlatform,
    );
    _firstFrameWatchdog = Timer(
      Duration(milliseconds: watchdogMs),
      _handleFirstFrameTimeout,
    );
  }

  // ✅ TIKTOK-STYLE: Force remount texture for stuck texture recovery
  void _forceRemountTexture() {
    if (!mounted) return;
    setState(() => _surfaceRecoveryEpoch++);
  }

  void _clearPosterAfterFrameIfPlaying({
    required VideoPlayerController controller,
    required String reason,
  }) {
    if (!_thumbnailVisible || !mounted || _isDisposed) return;

    final bool canClearPoster = readVideoControllerOr(
      controller,
      (VideoPlayerValue value) {
        final bool hasFrameDimensions =
            value.size.width > 0 && value.size.height > 0;
        final bool playbackStarted =
            value.isPlaying || value.position > Duration.zero;
        if (!value.isInitialized || value.hasError) {
          return false;
        }
        return hasFrameDimensions && playbackStarted;
      },
      false,
      context: '_clearPosterAfterFrameIfPlaying',
    );
    if (!canClearPoster) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || !_thumbnailVisible) return;
      if (!identical(_videoPlayerController, controller)) return;
      setState(() {
        _thumbnailVisible = false;
        _hasSeenFirstFrame = true;
        _firstFrameRenderedAt ??= DateTime.now();
      });
      GlobalPlaybackManager.instance.noteFirstFrameRendered(
        widget.video.id,
        controllerId: controller.hashCode,
        size: controller.value.size,
      );
      _firstFrameWatchdog?.cancel();
      _firstFrameWatchdog = null;
      secureLog(
          '✅ VideoPlayer: Poster cleared for ${widget.video.id} ($reason)');
    });
  }

  bool _canTriggerRecovery() {
    final DateTime now = DateTime.now();
    if (!_blackScreenRecovery.tryConsumeRecoverySlot(
      state: _blackScreenRecoveryState,
      now: now,
    )) {
      secureLog('⏳ VideoPlayer: Recovery throttled for ${widget.video.id}');
      return false;
    }
    return true;
  }

  bool _canHardReinit(String videoId) {
    final last = _lastHardReinit[videoId];
    if (last == null) return true;
    return DateTime.now().difference(last) > _hardReinitCooldown;
  }

  void _markHardReinit(String videoId) {
    _lastHardReinit[videoId] = DateTime.now();
  }

  /// 🔥 PRODUCTION-GRADE: Handle first frame timeout (black screen detection)
  ///
  /// **Conditions for black screen detection:**
  /// - Audio is playing OR isPlaying == true
  /// - No video frame has been rendered within threshold (_hasSeenFirstFrame == false)
  /// - Widget isCurrentVideo == true and visible
  /// - Controller is initialized
  ///
  /// **Recovery Tiers:**
  /// - Tier 1 (Attempt 1): Force widget rebuild by changing key
  /// - Tier 2 (Attempt 2): Force texture remount (current implementation)
  /// - Tier 3 (Attempt 3+): Recreate controller (expensive, last resort)
  ///
  /// **Guardrails:**
  /// - Max 2 recovery attempts per video session
  /// - Cooldown between attempts (1500ms)
  /// - Only runs for current video
  /// - Cancelled on video change, tab switch, dispose
  void _handleFirstFrameTimeout() {
    final VideoPlayerController? c = _videoPlayerController;
    if (c == null || _isDisposed || !_isInitialized || !mounted) {
      secureLog(
          '🚫 VideoPlayer: First frame watchdog timeout but conditions not met (controller: ${c != null}, disposed: $_isDisposed, initialized: $_isInitialized, mounted: $mounted)');
      return;
    }

    VideoPlayerValue v;
    try {
      v = c.value;
    } catch (e) {
      secureLog(
          '⚠️ VideoPlayer: Error accessing controller value in watchdog: $e');
      return;
    }

    final bool playing = v.isPlaying;
    final bool positionAdvancing = v.position > Duration.zero;
    final DateTime now = DateTime.now();
    final VideoPlayerBlackScreenRecoveryAction action =
        _blackScreenRecovery.evaluate(
      state: _blackScreenRecoveryState,
      isCurrentVideo: widget.isCurrentVideo,
      hasSeenFirstFrame: _hasSeenFirstFrame,
      isPlaying: playing,
      positionAdvancing: positionAdvancing,
      now: now,
    );

    if (action == VideoPlayerBlackScreenRecoveryAction.none) {
      if (!widget.isCurrentVideo) {
        secureLog(
            '🚫 VideoPlayer: First frame watchdog timeout but video not current: ${widget.video.id}');
      } else if (_hasSeenFirstFrame) {
        secureLog(
            '✅ VideoPlayer: First frame watchdog timeout but frame already detected: ${widget.video.id}');
      } else if (!playing && !positionAdvancing) {
        secureLog(
            '🚫 VideoPlayer: First frame watchdog timeout but not playing: ${widget.video.id}');
      } else if (_blackScreenRecoveryState.lastRecoveryAt != null &&
          now.difference(_blackScreenRecoveryState.lastRecoveryAt!) <
              VideoPlayerBlackScreenRecovery().cooldown) {
        secureLog(
            '⏳ VideoPlayer: Black screen recovery throttled (cooldown) for ${widget.video.id}');
      }
      return;
    }

    final int controllerHashCode = c.hashCode;
    final int? timeSinceStart = _playbackStartTime != null
        ? now.difference(_playbackStartTime!).inMilliseconds
        : null;
    secureLog(
      '🚨 VideoPlayer: BLACKSCREEN_DETECTED for ${widget.video.id} '
      '(controller: $controllerHashCode, isPlaying: $playing, '
      'position: ${v.position.inMilliseconds}ms, '
      'size: ${v.size.width}x${v.size.height}'
      '${timeSinceStart != null ? ', timeSinceStart: ${timeSinceStart}ms' : ''})',
    );

    if (action == VideoPlayerBlackScreenRecoveryAction.giveUp) {
      secureLog(
        '🚫 VideoPlayer: RECOVERY_GIVE_UP for ${widget.video.id} '
        '(max attempts: ${_blackScreenRecovery.maxAttempts} reached)',
      );
      _recoveryAttemptsPerVideo[widget.video.id] =
          _blackScreenRecoveryState.attempts;
      _markVideoUnplayableAfterRecoveryFailure(v);
      return;
    }

    _recoveryAttemptsPerVideo[widget.video.id] =
        _blackScreenRecoveryState.attempts;
    secureLog(
      '🔧 VideoPlayer: RECOVERY_ATTEMPT_${_blackScreenRecoveryState.attempts} '
      'for ${widget.video.id} (controller: $controllerHashCode)',
    );

    switch (action) {
      case VideoPlayerBlackScreenRecoveryAction.tier1Rebuild:
        secureLog(
          '🔧 VideoPlayer: RECOVERY_ATTEMPT_1_REBUILD_WIDGET '
          'for ${widget.video.id}',
        );
        _recoverBlackScreenTier1();
      case VideoPlayerBlackScreenRecoveryAction.tier2Remount:
        secureLog(
          '🔧 VideoPlayer: RECOVERY_ATTEMPT_2_REMOUNT_TEXTURE '
          'for ${widget.video.id}',
        );
        _recoverBlackScreenTier2();
      case VideoPlayerBlackScreenRecoveryAction.tier3Recreate:
        secureLog(
          '🔧 VideoPlayer: RECOVERY_ATTEMPT_3_RECREATE_CONTROLLER '
          'for ${widget.video.id}',
        );
        _recoverBlackScreenTier3();
      case VideoPlayerBlackScreenRecoveryAction.none:
      case VideoPlayerBlackScreenRecoveryAction.giveUp:
        break;
    }
  }

  /// 🔥 PRODUCTION-GRADE: Tier 1 Recovery - Force widget rebuild
  /// Changes widget key to force Flutter to recreate VideoPlayer State and reattach texture/surface
  void _recoverBlackScreenTier1() {
    if (!mounted || _isDisposed) return;

    final c = _videoPlayerController;
    if (c == null || !_canUseController(c)) return;

    // Force widget rebuild by incrementing texture rebuild tick
    // This changes the key, forcing VideoPlayer widget to remount
    secureLog(
        '🔧 VideoPlayer: Tier 1 recovery - forcing widget rebuild for ${widget.video.id}');
    _forceRemountTexture();

    // Also try seeking to current position to kick decoder
    try {
      final v = c.value;
      if (v.isInitialized && v.position > Duration.zero) {
        c.seekTo(v.position).catchError((e) {
          secureLog('⚠️ VideoPlayer: Error seeking in Tier 1 recovery: $e');
        });
      }
    } catch (e) {
      secureLog(
          '⚠️ VideoPlayer: Error accessing controller value in Tier 1 recovery: $e');
    }
    _scheduleFirstFrameRecoveryRecheck('tier1');
  }

  /// 🔥 PRODUCTION-GRADE: Tier 2 Recovery - Force texture remount
  /// Increments texture rebuild tick multiple times to force texture reattachment
  void _recoverBlackScreenTier2() {
    if (!mounted || _isDisposed) return;

    final c = _videoPlayerController;
    if (c == null || !_canUseController(c)) return;

    secureLog(
        '🔧 VideoPlayer: Tier 2 recovery - forcing texture remount for ${widget.video.id}');

    // Force texture remount (current implementation)
    _forceRemountTexture();

    try {
      final v = c.value;
      if (v.isInitialized) {
        c.pause().then((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted || _isDisposed || !_canUseController(c)) return;
            if (!widget.isCurrentVideo) {
              c.setVolume(0.0).catchError((_) {});
              return;
            }
            if (GlobalPlaybackManager.instance.activeVideoId !=
                widget.video.id) {
              c.setVolume(0.0).catchError((_) {});
              return;
            }
            GlobalPlaybackManager.instance
                .requestFocus(widget.video.id, _ownerKey)
                .catchError((e) {
              secureLog(
                  '⚠️ VideoPlayer: Error requesting focus after Tier 2 recovery: $e');
            });
          });
        }).catchError((e) {
          secureLog('⚠️ VideoPlayer: Error pausing in Tier 2 recovery: $e');
        });
      }
    } catch (e) {
      secureLog(
          '⚠️ VideoPlayer: Error accessing controller value in Tier 2 recovery: $e');
    }
    _scheduleFirstFrameRecoveryRecheck('tier2');
  }

  /// 🔥 PRODUCTION-GRADE: Tier 3 Recovery - Recreate controller
  /// Fully dispose and recreate the controller (expensive, last resort)
  ///
  /// **CRITICAL:** Does NOT dispose controller directly - marks it for disposal
  /// and lets widget.dispose() handle actual disposal to prevent race conditions
  void _recoverBlackScreenTier3() {
    if (!mounted || _isDisposed) return;

    secureLog(
        '🔧 VideoPlayer: Tier 3 recovery - recreating controller for ${widget.video.id}');

    // 🔥 CRITICAL FIX: Don't dispose controller here - just mark it for replacement
    // Actual disposal happens in widget.dispose() to prevent "used after disposed" errors
    final c = _videoPlayerController;
    if (c != null) {
      // Pause and mute the old controller (safe operations)
      try {
        if (_canUseController(c)) {
          c.pause().catchError((_) {});
          c.setVolume(0.0).catchError((_) {});
        }
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }

      // Mark controller for replacement (don't dispose yet)
      _videoPlayerController = null;
      _currentControllerInstance = null;
      _controllerVersion++;

      // Unregister from playback manager (this is safe)
      try {
        GlobalPlaybackManager.instance.unregisterController(widget.video.id);
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }

      secureLog(
          '🔧 VideoPlayer: Tier 3 recovery - marked old controller for replacement (will be disposed in widget.dispose())');
    }

    // Reinitialize video with fresh controller
    if (mounted && !_isDisposed) {
      _isInitialized = false;
      _hasSeenFirstFrame = false;
      _firstFrameRenderedAt = null;
      _playbackStartTime = null;

      // Clear recovery state for fresh start
      _blackScreenRecovery.resetForTier3Retry(_blackScreenRecoveryState);

      // Reinitialize - this will create a new controller
      _initializeVideo(isRetry: true).catchError((e) {
        secureLog(
            '⚠️ VideoPlayer: Error reinitializing in Tier 3 recovery: $e');
      });
    }
  }

  void _scheduleFirstFrameRecoveryRecheck(String tier) {
    _firstFrameWatchdog?.cancel();
    _firstFrameWatchdog = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _isDisposed || !widget.isCurrentVideo) return;
      if (_hasSeenFirstFrame) return;
      secureLog(
          '🔎 VideoPlayer: Rechecking first frame after $tier recovery for ${widget.video.id}');
      _handleFirstFrameTimeout();
    });
  }

  void _markVideoUnplayableAfterRecoveryFailure(VideoPlayerValue value) {
    final videoId = widget.video.id;
    _brokenVideoIds.add(videoId);
    _isUnplayable = true;
    _playbackError = 'Video playback failed';
    _showErrorAfterDelay = true;

    try {
      final controller = _videoPlayerController;
      if (controller != null && _canUseController(controller)) {
        controller.setVolume(0.0).catchError((_) {});
        controller.pause().catchError((_) {});
      }
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }

    VideoHealthGate.instance.logUnplayableVideo(
      videoId,
      'first_frame_watchdog_exhausted',
      <String, dynamic>{
        'positionMs': value.position.inMilliseconds,
        'isPlaying': value.isPlaying,
        'isBuffering': value.isBuffering,
        'size': '${value.size.width}x${value.size.height}',
        'attempts': _blackScreenRecoveryState.attempts,
      },
    );

    _handleUnplayableVideo('first_frame_watchdog_exhausted', <String, dynamic>{
      'videoId': videoId,
      'attempts': _blackScreenRecoveryState.attempts,
    });
  }

  void _startStallWatchdog() {
    _stallWatchdog?.cancel();
    _lastPlaybackPosition = Duration.zero;
    _stallWatchdog =
        Timer.periodic(const Duration(seconds: 3), (_) => _checkForStall());
  }

  // 🔥 FIX: Track consecutive stall checks to prevent false positives
  int _consecutiveStallChecks = 0;
  static const int _stallCheckThreshold =
      3; // Require 3 consecutive stalls (9 seconds) before recovery

  void _checkForStall() {
    final controller = _videoPlayerController;
    if (controller == null || _isDisposed || !_isInitialized) return;
    final value = controller.value;

    // If looping naturally reset to the start, just record and continue
    if (value.position < _lastPlaybackPosition) {
      _lastPlaybackPosition = value.position;
      _consecutiveStallChecks =
          0; // 🔥 FIX: Reset stall counter on successful loop
      return;
    }

    final duration = value.duration;

    // Let native looping handle the loop - only intervene if clearly stuck
    // Native setLooping(true) should handle seamless looping without black screens
    // Only check if video is stuck way past the end (native loop failed)
    if (duration.inMilliseconds > 0 &&
        !_isDisposed &&
        !_isDisposingController) {
      final position = value.position.inMilliseconds;
      final durationMs = duration.inMilliseconds;
      if (position > durationMs + 500 && _canUseController(controller)) {
        secureLog(
          'BUFFER_STALL_DETECTED videoId=${widget.video.id} '
          'position=$position duration=$durationMs reason=stall_watchdog',
        );
        if (_shouldRunManualLoopRecovery(
          controller: controller,
          value: value,
          reason: 'stall_watchdog',
        )) {
          _runManualLoopRecovery(
            controller: controller,
            reason: 'stall_watchdog',
          );
        }
        return;
      }
    }

    if (!value.isPlaying) {
      _lastPlaybackPosition = value.position;
      _consecutiveStallChecks =
          0; // 🔥 FIX: Reset if not playing (user paused or blocked)
      return;
    }

    // Avoid stall recovery when we are at the tail end of the video
    if (duration > Duration.zero &&
        (duration - value.position) <= const Duration(milliseconds: 700)) {
      _lastPlaybackPosition = value.position;
      _consecutiveStallChecks = 0; // 🔥 FIX: Reset near end (normal behavior)
      return;
    }

    // 🔥 FIX: Check if position advanced (accounting for small timing differences)
    final advanced = value.position > _lastPlaybackPosition;
    final positionDiff =
        (value.position - _lastPlaybackPosition).inMilliseconds;

    // 🔥 FIX: Only count as stall if position hasn't advanced by at least 50ms
    // This prevents false positives from brief frame delays
    if (advanced && positionDiff >= 50) {
      _lastPlaybackPosition = value.position;
      _consecutiveStallChecks = 0; // 🔥 FIX: Reset on successful advancement
      return;
    }

    // 🔥 FIX: Increment stall counter only if truly stalled
    if (!advanced || positionDiff < 50) {
      _consecutiveStallChecks++;
      secureLog(
        '⚠️ VideoPlayer: Stall check $_consecutiveStallChecks/'
        '$_stallCheckThreshold for ${widget.video.id} '
        '(position: ${value.position.inSeconds}s, '
        'last: ${_lastPlaybackPosition.inSeconds}s)',
      );
    }

    _lastPlaybackPosition = value.position;

    // 🔥 FIX: Only trigger recovery after multiple consecutive stall checks
    // This prevents false positives after many playbacks
    if (_consecutiveStallChecks >= _stallCheckThreshold &&
        !_stuckRecoveryAttempted) {
      if (!_canHardReinit(widget.video.id)) {
        secureLog(
            '⛔ VideoPlayer: Hard reinit blocked (cooldown) for ${widget.video.id}');
        _consecutiveStallChecks = 0; // Reset counter if blocked
        return;
      }
      _markHardReinit(widget.video.id);
      if (!_canTriggerRecovery()) {
        _consecutiveStallChecks = 0; // Reset counter if recovery throttled
        return;
      }
      secureLog(
        '🧊 VideoPlayer: Stall confirmed '
        '($_consecutiveStallChecks checks), reinitializing ${widget.video.id}',
      );
      _stuckRecoveryAttempted = true;
      _consecutiveStallChecks = 0; // Reset after triggering recovery
      _stallWatchdog?.cancel();
      // 🔥 FINAL FIX: Don't dispose here - just pause and reinitialize
      // Disposal only happens in widget.dispose()
      _pauseAndMuteController().then((_) {
        if (mounted) {
          _videoPlayerController = null;
          _currentControllerInstance = null;
          _controllerVersion++; // Increment version
          _isInitialized = false;
          _initializeVideo(isRetry: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerViewOptimized oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 🔥 TIKTOK-STYLE: Increment generation on active index change
    if (oldWidget.isCurrentVideo != widget.isCurrentVideo) {
      final bool becomingCurrent =
          !oldWidget.isCurrentVideo && widget.isCurrentVideo;
      final bool hasReadyController = _videoPlayerController != null &&
          _isInitialized &&
          _canUseController(_videoPlayerController);
      if (!becomingCurrent || !hasReadyController) {
        _playbackGeneration++;
        secureLog(
          '🔄 VideoPlayer: Generation incremented to $_playbackGeneration '
          '(isCurrent: ${widget.isCurrentVideo})',
        );
      }

      // Reset error state when becoming current (fresh start)
      if (becomingCurrent) {
        _brokenVideoIds.remove(widget.video.id);
        _playbackError = null;
        _showErrorAfterDelay = false;
        _isUnplayable = false;
        _audioEnhancementScheduled = false;
        _hasPreloadedNextAtSeventy = false;
      }
    }

    // If video changed, reset state
    if (oldWidget.video.id != widget.video.id) {
      _playbackGeneration++;
      _playbackError = null;
      _showErrorAfterDelay = false;
      _isUnplayable = false;
      _audioEnhancementScheduled = false;
      _audioEnhancementApplied = false;
      _hasPreloadedNextAtSeventy = false;
      _taggedUsersFuture = _fetchTaggedUsers(widget.video.id);
      _initializeCommentCountListener();
      GlobalPlaybackManager.instance.clearDesiredFocus(oldWidget.video.id);
    }

    if (_media3HomeOwnerEnabled) {
      return;
    }

    if (oldWidget.video.videoURL != widget.video.videoURL) {
      _isDisposed = false;
      _initializeVideo();
      return;
    }

    if (_videoPlayerController != null &&
        !isVideoControllerAlive(_videoPlayerController, logDisposed: false)) {
      _markControllerDisposed(
        reason: 'stale local controller before widget update',
      );
      GlobalPlaybackManager.instance.markControllerDetached(widget.video.id);
      if (!widget.isCurrentVideo) {
        return;
      }
    }

    if (_registry.isControllerDisposed(widget.video.id) &&
        !GlobalPlaybackManager.instance.shouldRetainController(
          widget.video.id,
        )) {
      _markControllerDisposed(
          reason: 'Registry reported disposal before widget update');
    }

    // ✅ FIX BLACK SCREEN: Controller adoption is now handled at the top of didUpdateWidget
    // This code path is no longer needed, but keeping as fallback
    if ((_videoPlayerController == null || _isDisposed) &&
        widget.isCurrentVideo &&
        mounted) {
      _tryAdoptFromPool(reason: 'didUpdateWidget: null or disposed');

      if (_videoPlayerController == null) {
        if (_isInitializing || _brokenVideoIds.contains(widget.video.id)) {
          return;
        }
        secureLog('VVIEW init-start id=${widget.video.id} (no pool, creating)');
        secureLog(
            '⚠️ VideoPlayer: PRELOAD_MISS — no pooled controller, initializing: '
            '${widget.video.id}');
        _isDisposed = false; // Reset disposed flag to allow initialization
        _initializeVideo();
      } else {
        _hasRequestedFocus = false;
        _lastRequestedVideoId = null;
        _activateCurrentVideo(
          'didUpdateWidget: controller from pool or recovery',
        );
      }
      return; // Don't continue with normal didUpdateWidget logic
    }

    // Normal update logic - only proceed if controller is ready
    // 🔥 FIX: Also check if controller is still valid (not disposed)
    if (_videoPlayerController == null ||
        !_isInitialized ||
        _isDisposed ||
        !_canUseController(_videoPlayerController)) {
      // If controller is disposed, mark it and trigger reinitialization if needed
      if (_videoPlayerController != null &&
          !_canUseController(_videoPlayerController)) {
        secureLog(
            '⚠️ VideoPlayer: Controller became invalid during didUpdateWidget: ${widget.video.id}');
        _markControllerDisposed(
            reason: 'controller invalid during didUpdateWidget');
        if (widget.isCurrentVideo && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _initializeVideo();
            }
          });
        }
      }
      return;
    }

    // 🔥 FIX: Only bail when neither the bound video nor the current/visible
    // state changed. If isCurrentVideo changed for the same cell we still need
    // the pause/resume handoff below or off-screen audio can continue playing.
    if (oldWidget.video.id == widget.video.id &&
        oldWidget.isCurrentVideo == widget.isCurrentVideo) {
      return; // Nothing important changed, skip processing
    }

    if (oldWidget.isCurrentVideo != widget.isCurrentVideo) {
      if (widget.isCurrentVideo) {
        final poolController =
            GlobalPlaybackManager.instance.getController(widget.video.id);
        final controllerSource = _videoPlayerController == null
            ? 'null'
            : (poolController != null &&
                    identical(_videoPlayerController, poolController)
                ? 'pool'
                : 'local');
        secureLog(
            'VVIEW current=TRUE id=${widget.video.id} controller=$controllerSource');

        final videoIdChanged = oldWidget.video.id != widget.video.id;
        if (videoIdChanged || !oldWidget.isCurrentVideo) {
          _hasRequestedFocus = false;
          _lastRequestedVideoId = null;
          secureLog(
              '🔄 VideoPlayer: Reset focus flag (isCurrentVideo: false -> true, videoId: ${oldWidget.video.id} -> ${widget.video.id})');
        }

        // 🚀 ENHANCED ALGORITHM: Reset tracking flags when video becomes current
        _hasTrackedWatch = false;
        _hasTrackedInterestWatch = false;
        _lastWatchPercentage = 0.0;

        // ✅ PRODUCTION-GRADE: Use consolidated focus request method
        // This handles all guards (mounted, not blocked, controller exists, etc.)
        _activateCurrentVideo('didUpdateWidget: became current');

        // ✅ FIX: Don't call _handleVideoEnter() here - requestFocus() → activate() already plays the video
        // _handleVideoEnter() would cause duplicate play() calls leading to double audio
        // Only handle resume/seek logic if needed, but don't call play again
      } else {
        _firstFrameWatchdog?.cancel();
        _firstFrameWatchdog = null;
        _stallWatchdog?.cancel();
        _stallWatchdog = null;
        GlobalPlaybackManager.instance.clearDesiredFocus(widget.video.id);
        GlobalPlaybackManager.instance.markControllerDetached(widget.video.id);
        if (_videoPlayerController != null && !_isDisposed) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null &&
              _lastWatchPercentage > 0.0 &&
              _lastWatchPercentage < 30.0 &&
              !_hasTrackedWatch) {
            EnhancedAlgorithmService.instance.trackSkip(
              videoId: widget.video.id,
              creatorId: widget.video.creator.id,
              userId: currentUser.uid,
              watchPercentage: _lastWatchPercentage,
            );
            _hasTrackedWatch = true;
          }
          try {
            final controllerValue = _videoPlayerController!.value;
            if (controllerValue.isInitialized && !controllerValue.hasError) {
              if (!_isFeedPlaybackOwner) {
                _resumeService.onPageLeave(
                  widget.video.id,
                  controllerValue.position,
                  controllerValue.duration,
                );
              }
            }
          } catch (e, st) {
            ignorePlaybackTeardownError('video_player', e, st);
          }
          _pauseAndMuteController().then((_) {
            if (mounted) {
              setState(() => _isPlaying = false);
            }
            _hasRequestedFocus = false;
            _lastRequestedVideoId = null;
          });
        } else {
          _hasRequestedFocus = false;
          _lastRequestedVideoId = null;
        }
      }
    }

    // ✅ PRODUCTION-GRADE: Handle videoId changes while isCurrentVideo remains true
    // This can happen when the feed updates and a new video is shown in the same position
    if (widget.isCurrentVideo && oldWidget.video.id != widget.video.id) {
      secureLog(
          '🔄 VideoPlayer: Video ID changed while current (${oldWidget.video.id} -> ${widget.video.id}), resetting focus flag');
      _hasRequestedFocus = false;
      _lastRequestedVideoId = null;
      // Attempt to request focus for the new video
      _activateCurrentVideo('didUpdateWidget: current video id changed');
    }

    // ✅ PRODUCTION-GRADE: Fallback check - ensure focus if video is current but doesn't have it
    // This handles edge cases where focus was lost (e.g., after controller reinitialization)
    if (widget.isCurrentVideo) {
      final playbackManager = GlobalPlaybackManager.instance;
      final poolController = playbackManager.getController(widget.video.id);
      if (playbackManager.activeVideoId != widget.video.id &&
          poolController != null &&
          identical(poolController, _currentControllerInstance)) {
        secureLog(
            '🔄 VideoPlayer: Video is current but doesn\'t have focus, attempting to regain: ${widget.video.id}');
        _activateCurrentVideo('didUpdateWidget: fallback regain focus');
      }
    }
  }

  // Removed: didChangeAppLifecycleState
  // TikTok-style: GlobalPlaybackManager + NavigationObserver handle lifecycle globally
  // This prevents video from pausing when opening modals (CommentsView, ShareSheet, etc.)

  Future<void> _detachOldControllerForReplace(
    VideoPlayerController oldController,
  ) async {
    final int oldHashCode = oldController.hashCode;
    secureLog(
      '🔄 VideoPlayer: Replacing controller $oldHashCode with new controller '
      'for ${widget.video.id}',
    );
    try {
      if (_canUseController(oldController)) {
        oldController.removeListener(_videoErrorListener);
        oldController.removeListener(_videoStateListener);
        oldController.removeListener(_videoPositionListener);
        oldController.removeListener(_onControllerChanged);
        secureLog(
          '🔌 VideoPlayer: Detached all listeners from old controller '
          '$oldHashCode',
        );
      }
    } catch (e) {
      secureLog(
        '⚠️ VideoPlayer: Error detaching listeners from old controller: $e',
      );
    }
    try {
      await oldController.pause();
      await oldController.setVolume(0.0);
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }
    _videoPlayerController = null;
    _currentControllerInstance = null;
    _isInitialized = false;
    _isPlaying = false;
    _controllerVersion++;
    secureLog(
      '📌 VideoPlayer: Controller version incremented to $_controllerVersion '
      '(old controller $oldHashCode)',
    );
    try {
      final VideoPlayerController? playbackController =
          GlobalPlaybackManager.instance.getController(widget.video.id);
      if (playbackController != null &&
          identical(playbackController, oldController)) {
        GlobalPlaybackManager.instance.unregisterController(widget.video.id);
      }
    } catch (e, st) {
      ignorePlaybackTeardownError('video_player', e, st);
    }
  }

  Future<void> _wireManagerController(
    VideoPlayerController controller,
    String url,
  ) async {
    _videoPlayerController = controller;
    _currentControllerInstance = controller;
    _videoPlayerController!.addListener(_onControllerChanged);
    _isInitialized = readVideoControllerOr(
      controller,
      (VideoPlayerValue v) => v.isInitialized && !v.hasError,
      false,
      context: '_initFromManager',
    );
    _isPlaying = readVideoControllerOr(
      controller,
      (VideoPlayerValue v) => v.isPlaying,
      false,
      context: '_initFromManager',
    );
    if (mounted) setState(() {});
    _videoRetryCount = 0;
    _playbackError = null;
    _showErrorAfterDelay = false;
    _lastResolvedUrl = url;
    final GlobalPlaybackManager playbackManager =
        GlobalPlaybackManager.instance;
    final bool isBlocked = playbackManager.isPlaybackBlocked;
    await Future.wait<void>(<Future<void>>[
      _videoPlayerController!.setLooping(true).then((_) {
        _nativeLoopingEnabled = true;
        secureLog(
          'LOOP_NATIVE_ENABLED videoId=${widget.video.id} reason=initialize',
        );
      }),
      _videoPlayerController!.setVolume(0.0),
    ]);
    if (isBlocked) await _videoPlayerController!.pause();
    if (_canUseController(controller)) {
      controller.addListener(_videoErrorListener);
      controller.addListener(_videoStateListener);
      controller.addListener(_videoPositionListener);
    }
    _startLoopCheckTimer();
    playbackManager.markControllerAttached(
      widget.video.id,
      controller.hashCode,
    );
    _registry.register(widget.video.id, controller);
    _wasRegistered = true;
    _registry.markVisible(widget.video.id);
    _hasRequestedFocus = false;
    _isInitialized = true;
    _logger.debug(
      'Video initialized successfully: ${widget.video.id}',
      tag: 'VideoPlayer',
    );
  }

  void _scheduleResumeSeekAfterInit() {
    if (_isFeedPlaybackOwner) {
      final VideoPlayerController? controller = _videoPlayerController;
      if (controller != null && _canUseController(controller)) {
        try {
          final VideoPlayerValue value = controller.value;
          if (_shouldRunManualLoopRecovery(
            controller: controller,
            value: value,
            reason: 'feed_resume',
          )) {
            _runManualLoopRecovery(
                controller: controller, reason: 'feed_resume');
          }
        } catch (e, st) {
          ignorePlaybackTeardownError('video_player', e, st);
        }
      }
      return;
    }
    _resumeService
        .onPageEnter(widget.video.id)
        .then((Duration? targetPosition) {
      if (targetPosition == null ||
          targetPosition <= Duration.zero ||
          !mounted ||
          _videoPlayerController == null ||
          !_isInitialized) {
        return;
      }
      try {
        final VideoPlayerController? seekController = _videoPlayerController;
        if (seekController == null ||
            _isDisposed ||
            _isDisposingController ||
            !_canUseController(seekController)) {
          return;
        }
        seekController.seekTo(targetPosition).then((_) {
          secureLog(
            '▶️ VideoResume: Auto-resumed from '
            '${targetPosition.inSeconds}s for ${widget.video.id}',
          );
        }).catchError((Object e) {
          secureLog('⚠️ VideoResume: Error seeking: $e');
        });
      } catch (e) {
        secureLog('⚠️ VideoResume: Error seeking: $e');
      }
    }).catchError((Object e) {
      secureLog('⚠️ VideoResume: Error getting resume position: $e');
    });
  }

  Future<void> _applyInitErrorPlan(
    VideoCellInitErrorPlan plan, {
    Object? error,
  }) async {
    if (plan.userMessage != null) {
      _playbackError = plan.userMessage;
      if (plan.kind != VideoCellInitErrorKind.permanentSource) {
        if (mounted && !_isDisposed) {
          _handleVideoError(plan.userMessage!);
        }
      }
    }
    if (plan.quarantineVideo) {
      _brokenVideoIds.add(widget.video.id);
      _isUnplayable = true;
    }
    if (plan.logFormatUnplayable && error != null) {
      VideoHealthGate.instance.logUnplayableVideo(
        widget.video.id,
        'format_not_supported',
        <String, dynamic>{
          'error': error.toString(),
          'errorString': error.toString().toLowerCase(),
        },
      );
    }
    if (plan.unplayableReason != null) {
      _handleUnplayableVideo(
        plan.unplayableReason!,
        <String, dynamic>{
          if (error != null) 'error': error.toString(),
          'videoId': widget.video.id,
          if (plan.kind == VideoCellInitErrorKind.permanentSource)
            'playbackError': 'failed_playback',
        },
      );
    }
    if (plan.showErrorAfterDelay && plan.userMessage != null) {
      _showErrorAfterDelay = true;
      final String message = plan.userMessage!;
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted &&
            !_isDisposed &&
            widget.isCurrentVideo &&
            _showErrorAfterDelay) {
          _handleVideoError(message);
        }
      });
    }
    if (plan.clearControllerReference && _videoPlayerController != null) {
      try {
        await _videoPlayerController!.pause();
        await _videoPlayerController!.setVolume(0.0);
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }
      _videoPlayerController = null;
      _currentControllerInstance = null;
      if (plan.incrementControllerVersion) {
        _controllerVersion++;
      }
      _isInitialized = false;
      _isPlaying = false;
    }
    if (plan.resetRetryCount) {
      _videoRetryCount = 0;
    }
    if (plan.retryDelay != null) {
      _videoRetryCount++;
      if (kDebugMode) {
        debugPrint(
          '🔄 VideoPlayer: Network error detected, retrying '
          '($_videoRetryCount/$_maxVideoRetries) after '
          '${plan.retryDelay!.inSeconds}s',
        );
      }
      Future<void>.delayed(plan.retryDelay!, () {
        if (mounted && !_isDisposed) {
          _initializeVideo(isRetry: true);
        }
      });
    }
  }

  Future<void> _initializeVideo({bool isRetry = false}) async {
    final String? readyUrl = _readyPlaybackUrlFromVideo();
    final int initVersion = _controllerVersion;
    final int currentGen = _playbackGeneration;
    final VideoCellInitGate gate = _cellBootstrap.evaluatePreflight(
      hasReadyPlaybackUrl: readyUrl != null,
      useMedia3HomePath: _media3HomeOwnerEnabled && _useNativeMedia3Home,
      isInitializing: _isInitializing,
      isVideoInitializingElsewhere:
          _initializingVideoIds.contains(widget.video.id),
      isQuarantined: _brokenVideoIds.contains(widget.video.id),
      playbackGenerationAtStart: currentGen,
      currentPlaybackGeneration: _playbackGeneration,
      controllerVersionAtStart: initVersion,
      currentControllerVersion: _controllerVersion,
    );
    switch (gate) {
      case VideoCellInitGate.notReadyForFeed:
        _isUnplayable = true;
        _playbackError = 'Video is still processing';
        return;
      case VideoCellInitGate.delegateMedia3:
        _initializeNativeMedia3Home(isRetry ? 'initializeRetry' : 'initialize');
        return;
      case VideoCellInitGate.alreadyInitializing:
        secureLog(
          'VVIEW init-skip id=${widget.video.id} (already initializing)',
        );
        return;
      case VideoCellInitGate.quarantined:
        secureLog(
          '🚫 VideoPlayer: Video ${widget.video.id} is quarantined, '
          'skipping initialization',
        );
        _isUnplayable = true;
        _playbackError = 'Video unavailable';
        _handleUnplayableVideo('quarantined', {});
        return;
      case VideoCellInitGate.staleGeneration:
        secureLog(
          '🔄 VideoPlayer: Generation changed, aborting initialization '
          '(was $currentGen, now $_playbackGeneration)',
        );
        return;
      case VideoCellInitGate.staleControllerVersion:
        secureLog(
          '🔄 VideoPlayer: Controller version changed during init, aborting '
          '(was $initVersion, now $_controllerVersion)',
        );
        return;
      case VideoCellInitGate.none:
        break;
    }

    _isInitializing = true;
    _initializingVideoIds.add(widget.video.id);
    secureLog('VVIEW init-start id=${widget.video.id}');

    // Start performance tracking
    PerformanceService().startVideoLoad(widget.video.id);

    try {
      _registry.resetDisposed(widget.video.id);
      _stuckRecoveryAttempted = false;
      _consecutiveStallChecks =
          0; // 🔥 FIX: Reset stall counter on initialization

      // 🔥 INSTANT PLAYBACK: Mark controller as initializing (prevents premature focus requests)
      GlobalPlaybackManager.instance
          .markControllerInitializing(widget.video.id);

      final String? playbackUrl = readyUrl;
      if (playbackUrl == null) {
        secureLog(
          '🚫 VideoPlayer: No playback URL resolved for ${widget.video.id}; '
          'raw videoURL=${widget.video.videoURL}',
        );
        _isUnplayable = true;
        _isInitializing = false;
        _handleUnplayableVideo('missing_playback_url', {
          'videoId': widget.video.id,
          'videoURL': widget.video.videoURL,
          'status': widget.video.status,
        });
        return;
      }
      final VideoPlayableResult healthResult =
          await _cellBootstrap.resolvePlayableSource(
        videoId: widget.video.id,
        fallbackUrl: playbackUrl,
      );

      if (currentGen != _playbackGeneration ||
          initVersion != _controllerVersion) {
        secureLog(
          '🔄 VideoPlayer: Generation or controller version changed during '
          'health check, aborting (gen: $currentGen -> $_playbackGeneration, '
          'ver: $initVersion -> $_controllerVersion)',
        );
        _isInitializing = false;
        return;
      }

      if (healthResult is Unplayable) {
        secureLog(
            '🚫 VideoPlayer: Video ${widget.video.id} is unplayable: ${healthResult.reason}');
        _isUnplayable = true;
        _isInitializing = false;

        // Log for backend
        VideoHealthGate.instance.logUnplayableVideo(
          widget.video.id,
          healthResult.reason,
          healthResult.debugInfo,
        );

        // Handle unplayable video
        _handleUnplayableVideo(healthResult.reason, healthResult.debugInfo);
        return;
      }

      final Playable playable = healthResult as Playable;
      _isUnplayable = false;
      _playbackError = null;
      _showErrorAfterDelay = false;
      secureLog(
        '✅ VideoPlayer: Health gate passed, using ${playable.quality} URL '
        'for ${widget.video.id}',
      );
      _isDisposed = false;
      debugPrint(
        '🎥 Getting controller from manager for ${widget.video.id} '
        'url=${playable.url} quality=${playable.quality}',
      );
      final VideoCellAttachOutcome outcome = await _initAttach.attachPlayable(
        videoId: widget.video.id,
        ownerKey: _ownerKey,
        playable: playable,
        isRetry: isRetry,
        playbackGenerationAtStart: currentGen,
        currentPlaybackGeneration: _playbackGeneration,
        controllerVersionAtStart: initVersion,
        currentControllerVersion: _controllerVersion,
        existingController: _videoPlayerController,
        isInitialized: _isInitialized,
        isDisposed: _isDisposed,
        lastResolvedUrl: _lastResolvedUrl,
        isCurrentVideo: widget.isCurrentVideo,
        mounted: mounted,
        canUseController: _canUseController,
        detachAndPauseOldController: _detachOldControllerForReplace,
        getOrCreateController: (String url) {
          return GlobalPlaybackManager.instance.getOrCreateController(
            widget.video.id,
            url,
            owner: _ownerKey,
          );
        },
        disposeStaleController: (VideoPlayerController c) async {
          _disposeStaleManagerController(c);
        },
        wireController: _wireManagerController,
        activateCurrentVideo: (String reason) async {
          final GlobalPlaybackManager playbackManager =
              GlobalPlaybackManager.instance;
          if (playbackManager.activeOwner == null) {
            secureLog(
              '🔧 VideoPlayer: No active owner set, setting to $_ownerKey '
              'for instant playback',
            );
            playbackManager.setActiveOwner(_ownerKey);
          }
          secureLog(
            '🔍 DEBUG: PlaybackManager state - activeOwner: '
            '${playbackManager.activeOwner}, isPlaybackBlocked: '
            '${playbackManager.isPlaybackBlocked}, canPlay($_ownerKey): '
            '${playbackManager.canPlay(_ownerKey)}',
          );
          _activateCurrentVideo(reason);
          if (mounted && !_isDisposed) {
            setState(() => _isPlaying = true);
          }
          _startFirstFrameWatchdog();
          _startStallWatchdog();
          _scheduleResumeSeekAfterInit();
        },
        notifyPlaySuccess: () => widget.onVideoPlaySuccess?.call(),
        log: secureLog,
      );
      switch (outcome) {
        case VideoCellAttachOutcome.reuseExisting:
        case VideoCellAttachOutcome.attached:
          break;
        case VideoCellAttachOutcome.getOrCreateFailed:
          secureLog(
            '🚫 VideoPlayer: getOrCreateController returned null: '
            '${widget.video.id}',
          );
          _brokenVideoIds.add(widget.video.id);
          _isUnplayable = true;
          _playbackError = 'Failed to get or create controller';
          _handleUnplayableVideo(
            'get_or_create_failed',
            <String, dynamic>{
              'videoId': widget.video.id,
              'playbackError': 'failed_playback',
            },
          );
          return;
        case VideoCellAttachOutcome.abortedStale:
        case VideoCellAttachOutcome.abortedUnmounted:
          return;
      }
    } on TimeoutException catch (_) {
      _logger.error(
        'Error initializing video: ${widget.video.id}',
        tag: 'VideoPlayer',
        error: 'Initialization timeout',
      );
      await _applyInitErrorPlan(_initErrors.planForTimeout());
    } catch (e) {
      _logger.error(
        'Error initializing video: ${widget.video.id}',
        tag: 'VideoPlayer',
        error: e,
      );
      if (e is! TimeoutException) {
        final VideoCellInitErrorPlan plan = _initErrors.planForError(
          error: e,
          retryCount: _videoRetryCount,
          maxRetries: _maxVideoRetries,
          baseRetryDelay: _videoRetryDelay,
        );
        if (plan.kind == VideoCellInitErrorKind.format) {
          secureLog(
            '🚫 VideoPlayer: Format error detected, quarantining video '
            '${widget.video.id}',
          );
        }
        if (plan.kind == VideoCellInitErrorKind.permanentSource) {
          secureLog(
            '🚫 VideoPlayer: Permanent source error detected, quarantining '
            'video ${widget.video.id}',
          );
        }
        if (!mounted || _isDisposed) {
          return;
        }
        await _applyInitErrorPlan(plan, error: e);
      }
    } finally {
      _isInitializing = false;
      _initializingVideoIds.remove(widget.video.id);
      GlobalPlaybackManager.instance.clearControllerInitializing(
        widget.video.id,
      );
    }
  }

  /// Apply TikTok-style audio enhancement to the current video
  /// 🔥 FIX: Added safety checks to prevent "Bad state: No active player" errors
  Future<void> _applyAudioEnhancement() async {
    try {
      if (_isFeedPlaybackOwner) {
        secureLog(
          'AUDIO_ENHANCEMENT_SKIPPED_LOOP_TEST videoId=${widget.video.id}',
        );
        return;
      }
      if (_audioEnhancementApplied) {
        secureLog(
          'AUDIO_ENHANCEMENT_APPLIED_ONCE videoId=${widget.video.id}',
        );
        return;
      }
      // 🔥 FIX: Validate controller is safe before applying enhancement
      if (_videoPlayerController == null || !_isInitialized || _isDisposed) {
        secureLog(
            '⚠️ VideoPlayer: Cannot apply audio enhancement - controller not ready');
        return;
      }

      // 🔥 FIX: Check if controller is safe to use
      if (!_canUseController(_videoPlayerController)) {
        secureLog(
            '⚠️ VideoPlayer: Controller not safe for audio enhancement: ${widget.video.id}');
        return;
      }

      // Initialize audio enhancement service
      final audioEnhancement = AudioEnhancementService();
      await audioEnhancement.initialize();

      // Apply audio enhancement to the video player
      await audioEnhancement.enhanceVideoPlayer(_videoPlayerController!);
      _audioEnhancementApplied = true;

      secureLog(
        'AUDIO_ENHANCEMENT_APPLIED_ONCE videoId=${widget.video.id}',
      );
    } catch (e, stackTrace) {
      secureLog(
          '❌ AudioEnhancementService: Error applying audio enhancement: $e');
      secureLog('Stack trace: $stackTrace');
      // Don't fail video playback if audio enhancement fails
    }
  }

  void _scheduleAudioEnhancementAfterFirstFrame() {
    if (_audioEnhancementScheduled || _audioEnhancementApplied) return;
    _audioEnhancementScheduled = true;
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted ||
          _isDisposed ||
          !widget.isCurrentVideo ||
          !_hasSeenFirstFrame ||
          !GlobalPlaybackManager.instance.canPlay(_ownerKey)) {
        _audioEnhancementScheduled = false;
        return;
      }
      _applyAudioEnhancement().whenComplete(() {
        if (mounted) {
          _audioEnhancementScheduled = false;
        }
      });
    });
  }

  void _videoErrorListener() {
    // 🔥 PRODUCTION-GRADE: Check mounted, controller validity, and version consistency
    if (!mounted ||
        _videoPlayerController == null ||
        _videoPlayerController != _currentControllerInstance ||
        !_canUseController(_videoPlayerController)) {
      // Controller was swapped or disposed - remove listener to prevent further calls
      try {
        _videoPlayerController?.removeListener(_videoErrorListener);
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }
      return;
    }

    try {
      final controllerValue = _videoPlayerController!.value;
      if (controllerValue.hasError) {
        final error = controllerValue.errorDescription ?? 'Unknown video error';
        secureLog('❌ Video player error: $error');

        // 🔥 PRIORITY 1: Check for OOM errors in video player error stream
        final errorString = error.toString().toLowerCase();
        final isOutOfMemoryError = errorString.contains('outofmemory') ||
            errorString.contains('out of memory') ||
            errorString.contains('no_memory') ||
            (errorString.contains('memory') &&
                errorString.contains('allocation'));

        if (isOutOfMemoryError) {
          secureLog(
              '⚠️ VideoPlayer: OutOfMemoryError in video player error stream');
          _playbackError =
              'Device memory too low for video playback. Try closing other apps.';
          if (mounted && !_isDisposed) {
            setState(() {
              // Error state already set
            });
          }
          // ✅ TIKTOK-STYLE: Pause/mute and drop reference, let disposal happen in widget.dispose()
          _pauseAndMuteController().then((_) {
            if (mounted) {
              _videoPlayerController = null;
              _isInitialized = false;
            }
          });
        } else {
          _handleVideoError(Exception(error));
        }
      }
    } catch (e) {
      secureLog(
          '⚠️ VideoPlayer: Controller disposed during error listener: $e');
      _markControllerDisposed(error: e, reason: 'error listener');
      // 🔥 CRITICAL FIX: Check if controller is still valid before removing listener
      try {
        final controller = _videoPlayerController;
        if (controller != null && !_isDisposingController) {
          controller.removeListener(_videoErrorListener);
        }
      } catch (e) {
        // Controller may be disposed - this is okay
      }
    }
  }

  // Position listener only rescues true native-loop failures. Routine exact-end
  // boundaries are left to video_player/ExoPlayer native looping; forcing
  // seek/play at every end flushes MediaCodec and causes GC/buffer churn.
  void _videoPositionListener() {
    // 🔥 PRODUCTION-GRADE: Check mounted, controller validity, and version consistency
    if (!mounted ||
        _videoPlayerController == null ||
        _videoPlayerController != _currentControllerInstance ||
        !_canUseController(_videoPlayerController) ||
        !_isInitialized ||
        _isDisposed) {
      // Controller was swapped or disposed - remove listener to prevent further calls
      try {
        _videoPlayerController?.removeListener(_videoPositionListener);
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }
      return;
    }

    try {
      final controllerValue = _videoPlayerController!.value;
      if (!controllerValue.isInitialized) return;

      final duration = controllerValue.duration;
      final position = controllerValue.position;
      final isPlaying = controllerValue.isPlaying;

      if (isPlaying &&
          !_hasTrackedInterestWatch &&
          position >= const Duration(seconds: 3)) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          _hasTrackedInterestWatch = true;
          MLRecommendationService().trackUserInteraction(
            userId: currentUser.uid,
            videoId: widget.video.id,
            interactionType: 'watch_3s',
            creatorId: widget.video.creator.id,
            metadata: {
              'categoryId': widget.video.categoryId,
              'creatorId': widget.video.creator.id,
              'caption': widget.video.caption,
            },
          );
        }
      }

      // 🔥 FIX: Reset stall counter if position is advancing (successful playback)
      if (isPlaying && position > _lastPlaybackPosition) {
        final positionDiff = (position - _lastPlaybackPosition).inMilliseconds;
        if (positionDiff >= 50) {
          // Only reset if meaningful advancement
          _consecutiveStallChecks = 0;
        }
      }

      // Let native looping handle the normal loop boundary. Only intervene if
      // playback is clearly stuck past the end.
      if (widget.isCurrentVideo && duration > Duration.zero) {
        if (!_hasPreloadedNextAtSeventy &&
            position.inMilliseconds >=
                (duration.inMilliseconds * 0.70).round()) {
          _hasPreloadedNextAtSeventy = true;
          _preloadAdjacentForWatchProgress();
        }

        final bool endedAndStopped = !isPlaying && position >= duration;
        final bool stuckPastEnd = isPlaying &&
            position > duration + const Duration(milliseconds: 500);
        if (endedAndStopped || stuckPastEnd) {
          secureLog(
            'LOOP_ENDED_DETECTED videoId=${widget.video.id} '
            'position=${position.inMilliseconds} '
            'duration=${duration.inMilliseconds} reason=position_listener',
          );
          final VideoPlayerController? seekController = _videoPlayerController;
          if (seekController != null &&
              _shouldRunManualLoopRecovery(
                controller: seekController,
                value: controllerValue,
                reason: 'position_listener',
              )) {
            _runManualLoopRecovery(
              controller: seekController,
              reason: 'position_listener',
            );
          }
          return;
        }
      }
    } catch (e) {
      secureLog('⚠️ VideoPlayer: Error in position listener: $e');
    }
  }

  void _preloadAdjacentForWatchProgress() {
    if (!_ownerKey.startsWith('home')) return;
    try {
      final homeState = ref.read(homeProvider);
      final feed = homeState.activeFeed ?? FeedTab.forYou;
      final videos = homeState.feedData(feed).videos;
      final index = videos.indexWhere((video) => video.id == widget.video.id);
      if (index < 0) return;
      secureLog(
        '⚡ VideoPlayer: 70% watch progress, preloading adjacent window '
        'for ${widget.video.id} at index $index',
      );
      GlobalPlaybackManager.instance.preloadAround(
        index,
        videos,
        direction: 1,
        controllerOwner: _ownerKey,
      );
    } catch (e) {
      secureLog('⚠️ VideoPlayer: Error preloading at 70% progress: $e');
    }
  }

  void _videoStateListener() {
    // 🔥 PRODUCTION-GRADE: Multiple checks to prevent using disposed controller
    if (!mounted ||
        _isDisposed ||
        _isDisposingController ||
        _videoPlayerController == null ||
        _videoPlayerController != _currentControllerInstance) {
      // Controller was swapped or disposed - remove listener to prevent further calls
      try {
        _videoPlayerController?.removeListener(_videoStateListener);
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }
      return;
    }

    // 🔥 FIX BLACK SCREEN: Trigger rebuild when controller becomes initialized
    // This ensures video displays as soon as controller is ready
    // Only rebuild if _isInitialized flag doesn't match actual state (prevents infinite loops)
    try {
      final controller = _videoPlayerController;
      if (controller != null && _canUseController(controller)) {
        final value = controller.value;
        final actuallyInitialized = value.isInitialized && !value.hasError;
        if (actuallyInitialized && !_isInitialized && mounted) {
          final controllerToCheck = controller;
          _setStateSafely(() {
            if (identical(_videoPlayerController, controllerToCheck)) {
              _isInitialized = true;
            }
          });
        }

        // ✅ TIKTOK-STYLE: Track when playback starts and detect first frame
        if (value.isPlaying &&
            _playbackStartTime == null &&
            widget.isCurrentVideo) {
          _playbackStartTime = DateTime.now();
          _hasSeenFirstFrame = false;
          _startFirstFrameWatchdog();
        }

        // 🔥 PRODUCTION-GRADE: Deterministic first frame detection
        // Use size.width > 0 && size.height > 0 as primary indicator (more reliable than position)
        // Position can advance with audio-only, but size indicates decoder has frame dimensions
        if (value.isPlaying && !_hasSeenFirstFrame && widget.isCurrentVideo) {
          final hasValidSize = value.size.width > 0 && value.size.height > 0;
          final positionAdvancing = value.position > Duration.zero;

          if (hasValidSize) {
            _hasSeenFirstFrame = true;
            _firstFrameRenderedAt = DateTime.now();
            _firstFrameWatchdog?.cancel();
            _firstFrameWatchdog = null;
            GlobalPlaybackManager.instance.noteFirstFrameRendered(
              widget.video.id,
              controllerId: controller.hashCode,
              size: value.size,
            );

            // Drop the poster as soon as we have a confirmed rendered frame.
            // This avoids the "frozen/blurry on open" look caused by keeping the
            // thumbnail on top after playback has already started.
            if (_thumbnailVisible && mounted) {
              _posterTimer?.cancel();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _isDisposed) return;
                if (_thumbnailVisible) {
                  setState(() => _thumbnailVisible = false);
                }
              });
            }

            // Log first frame rendered for analytics
            final timeToFirstFrame = _playbackStartTime != null
                ? _firstFrameRenderedAt!
                    .difference(_playbackStartTime!)
                    .inMilliseconds
                : null;
            secureLog(
                '✅ VideoPlayer: First frame rendered for ${widget.video.id} (controller: ${controller.hashCode}, size: ${value.size.width}x${value.size.height}${timeToFirstFrame != null ? ', timeToFirstFrame: ${timeToFirstFrame}ms' : ''})');
            _scheduleAudioEnhancementAfterFirstFrame();
          } else if (positionAdvancing && !hasValidSize) {
            // Position advancing but no size yet - log but don't mark as first frame
            // This helps identify "audio but no video" cases
            secureLog(
                '⚠️ VideoPlayer: Position advancing but no video size yet for ${widget.video.id} (position: ${value.position.inMilliseconds}ms, size: ${value.size.width}x${value.size.height})');
          }
        }
      }
    } catch (e, stack) {
      logPlaybackSwallowed('_onVideoTick', e, stack);
    }

    final controller = _videoPlayerController;
    if (controller == null || !_canUseController(controller)) return;

    try {
      final controllerValue = controller.value;
      final isPlaying = controllerValue.isPlaying;

      // 🔥 FIX: Handle video end - let native looping handle it if enabled
      // Only manually seek if native looping isn't working (which should be rare)
      final duration = controllerValue.duration;
      final position = controllerValue.position;

      // Native looping should handle this automatically, but check as fallback
      // Only seek if video is clearly stuck past the end (position way beyond duration)
      final bool endedAndStopped = !isPlaying && position >= duration;
      final bool stuckPastEnd =
          isPlaying && position > duration + const Duration(milliseconds: 500);
      if (duration > Duration.zero &&
          widget.isCurrentVideo &&
          (endedAndStopped || stuckPastEnd) &&
          !_isDisposed &&
          _isInitialized) {
        final seekController = _videoPlayerController;
        if (seekController != null &&
            _shouldRunManualLoopRecovery(
              controller: seekController,
              value: controllerValue,
              reason: 'state_listener',
            )) {
          secureLog(
            'LOOP_ENDED_DETECTED videoId=${widget.video.id} '
            'position=${position.inMilliseconds} '
            'duration=${duration.inMilliseconds} reason=state_listener',
          );
          _runManualLoopRecovery(
            controller: seekController,
            reason: 'state_listener',
          );
        }
        return;
      }

      if (isPlaying != _isPlaying && mounted && !_isDisposed) {
        final currentController = _videoPlayerController;
        if (!identical(controller, currentController)) return;

        _logger.debug(
            'Video state changed - isPlaying: $isPlaying, _isPlaying: $_isPlaying',
            tag: 'VideoPlayer');

        if (isPlaying && !_isPlaying) {
          _consecutiveStallChecks = 0;
          _stuckRecoveryAttempted = false;
          secureLog(
              '✅ VideoPlayer: Playback started successfully, reset stall counter for ${widget.video.id}');
          // Keep a very short fallback fade in case first-frame detection lags,
          // but do not hold the poster long enough to make the feed look frozen.
          if (_thumbnailVisible) {
            _posterTimer?.cancel();
            _posterTimer = Timer(const Duration(milliseconds: 150), () {
              if (!mounted || _isDisposed) return;
              _setStateSafely(() => _thumbnailVisible = false);
            });
          }
        }

        if (!isPlaying) {
          _posterTimer?.cancel();
          _posterTimer = null;
        }

        _setStateSafely(() => _isPlaying = isPlaying);
      }
    } catch (e) {
      secureLog(
          '⚠️ VideoPlayer: Controller disposed during state listener: $e');
      _markControllerDisposed(error: e, reason: 'state listener');
      // 🔥 CRITICAL FIX: Check if controller is still valid before removing listener
      try {
        final controller = _videoPlayerController;
        if (controller != null && !_isDisposingController) {
          controller.removeListener(_videoStateListener);
        }
      } catch (e) {
        // Controller may be disposed - this is okay
      }
    }
  }

  // Fallback loop check: only seek when native looping failed (position past end).
  // Native setLooping(true) handles normal case; timer avoids seek spam.
  void _startLoopCheckTimer() {
    _loopCheckTimer?.cancel();
    _loopCheckTimer =
        Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted || _isDisposed || !_isInitialized) {
        timer.cancel();
        return;
      }

      final controller = _videoPlayerController;
      if (controller == null || !controller.value.isInitialized) return;

      final value = controller.value;
      final duration = value.duration;
      final position = value.position;

      if (duration <= Duration.zero) return;

      final bool endedAndStopped = !value.isPlaying && position >= duration;
      final bool stuckPastEnd = value.isPlaying &&
          position > duration + const Duration(milliseconds: 750);
      if (!endedAndStopped && !stuckPastEnd) return;

      secureLog(
        'LOOP_ENDED_DETECTED videoId=${widget.video.id} '
        'position=${position.inMilliseconds} duration=${duration.inMilliseconds} '
        'reason=loop_timer',
      );
      if (_shouldRunManualLoopRecovery(
        controller: controller,
        value: value,
        reason: 'loop_timer',
      )) {
        _runManualLoopRecovery(controller: controller, reason: 'loop_timer');
      }
    });
  }

  void _handleVideoError(dynamic error) {
    if (kDebugMode) {
      debugPrint('🎥 Video Error (Handled): $error');
    }

    if (!mounted || _isDisposed) return;

    if (!widget.isCurrentVideo || _isInitializing) {
      secureLog(
          '⚠️ VideoPlayer: Suppressing error display - video not current or initializing: ${widget.video.id}');
      return;
    }

    FeedTelemetryService().logVideoLoadError(
      videoId: widget.video.id,
      error: error?.toString() ?? 'Unknown',
    );

    setState(() {
      _playbackError = _getUserFriendlyErrorMessage(error);
      _showErrorAfterDelay = true;
    });
  }

  /// 🔥 TIKTOK-STYLE: Handle unplayable videos (neutral overlay, auto-skip)
  void _handleUnplayableVideo(String reason, Map<String, dynamic> debugInfo) {
    if (!mounted || _isDisposed) return;

    secureLog(
        '🚫 VideoPlayer: Handling unplayable video ${widget.video.id}: $reason');

    if (_isPermanentUnplayableReason(reason)) {
      _brokenVideoIds.add(widget.video.id);
      _videoRetryCount = 0;
    }

    setState(() {
      _isUnplayable = true;
      _playbackError = 'Video unavailable';
    });

    // 🔥 TIKTOK-STYLE: Auto-skip broken videos after 8s (spec: max 8s before auto-skip)
    if (widget.isCurrentVideo && widget.onVideoUnplayable != null) {
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && widget.isCurrentVideo && _isUnplayable) {
          secureLog(
              '⏭️ VideoPlayer: Auto-skipping unplayable video ${widget.video.id}');
          FeedTelemetryService().logVideoAutoSkipped(
            videoId: widget.video.id,
            reason: reason,
          );
          widget.onVideoUnplayable!();
        }
      });
    }
  }

  bool _isPermanentUnplayableReason(String reason) {
    return reason == 'get_or_create_failed' ||
        reason == '404_source_not_found' ||
        reason == 'format_not_supported' ||
        reason == 'quarantined';
  }

  // 🚀 INSTANT PLAYBACK: Removed _buildLoadingState() - never show loading indicators
  // Videos will appear instantly when ready (black screen while loading in background)

  /// 🔥 TIKTOK-STYLE: State B - Unplayable overlay (neutral, not red)
  Widget _buildUnplayableOverlay() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_outline,
              color: Colors.grey,
              size: 64,
            ),
            const SizedBox(height: 16),
            const SelectableText.rich(
              TextSpan(
                text: 'Video unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Skip button (auto-skip in feed)
                if (widget.onVideoUnplayable != null)
                  TextButton(
                    onPressed: () {
                      secureLog(
                          '⏭️ VideoPlayer: User manually skipped unplayable video ${widget.video.id}');
                      widget.onVideoUnplayable!();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Skip'),
                  ),
                const SizedBox(width: 12),
                // Retry button (only if user stops on video)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isUnplayable = false;
                      _playbackError = null;
                      _showErrorAfterDelay = false;
                    });
                    // Remove from quarantine to allow retry
                    _brokenVideoIds.remove(widget.video.id);
                    _initializeVideo();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 TIKTOK-STYLE: State C - Failed state (Tap to retry, not red)
  Widget _buildFailedState() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.refresh,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            SelectableText.rich(
              TextSpan(
                text: _getUserFriendlyErrorMessage(_playbackError!),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _playbackError = null;
                  _showErrorAfterDelay = false;
                });
                _initializeVideo();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Tap to retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    return _initErrorClassifier.userFriendlyMessage(error);
  }

  Future<void> _togglePlayPause() async {
    if (_useNativeMedia3Home) {
      final controller = _nativeMedia3Controller;
      if (controller == null) return;
      final mgr = GlobalPlaybackManager.instance;
      if (mgr.isPlaybackBlocked || !mgr.canPlay(_ownerKey)) {
        await controller.setMuted(true);
        await controller.pause();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }
      if (!_audioUnmuted && mounted) {
        setState(() => _audioUnmuted = true);
      }
      mgr.setDesiredFocus(widget.video.id, _ownerKey);
      if (_isPlaying) {
        await controller.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await controller.setMuted(false);
        await controller.play();
        if (mounted) setState(() => _isPlaying = true);
      }
      return;
    }

    final mgr = GlobalPlaybackManager.instance;
    var c = _videoPlayerController ?? mgr.getController(widget.video.id);

    if (c == null) {
      _tryAdoptFromPool(reason: 'togglePlayPause');
      c = _videoPlayerController ?? mgr.getController(widget.video.id);
    }
    if (c == null) {
      await _initializeVideo();
      c = _videoPlayerController ?? mgr.getController(widget.video.id);
    }

    secureLog(
        '🎮 _togglePlayPause controller=${c != null} ready=$_controllerReady playing=${c?.value.isPlaying ?? false}');

    if (c == null || !_controllerReady) {
      secureLog('❌ Cannot toggle: controller missing or not ready');
      return;
    }

    if (_isDisposed) return;

    try {
      final _ = c.value;
    } catch (e) {
      secureLog('❌ VideoPlayer: Controller disposed in _togglePlayPause: $e');
      _markControllerDisposed(error: e, reason: 'togglePlayPause');
      return;
    }

    final owner = _ownerKey;
    if (mgr.isPlaybackBlocked) {
      _safeSetVolume(0.0);
      return;
    }
    if (!mgr.canPlay(owner)) {
      _safeSetVolume(0.0);
      return;
    }

    if (!_audioUnmuted) {
      await _applyAudioEnhancement();
      if (mounted) setState(() => _audioUnmuted = true);
    }

    final wasPlaying = c.value.isPlaying;
    mgr.setDesiredFocus(widget.video.id, owner);
    await mgr.requestFocus(widget.video.id, owner);

    if (wasPlaying) {
      _viewCountTimer?.cancel();
      _viewCountTimer = null;
      await c.pause();
      if (mounted) setState(() => _isPlaying = false);
      PerformanceService()
          .trackVideoPlayback(widget.video.id, PlaybackEvent.pause);
    } else {
      await mgr.switchActiveTo(widget.video.id, owner);
      if (!c.value.isPlaying) await c.play();
      if (mounted) setState(() => _isPlaying = true);
      PerformanceService()
          .trackVideoPlayback(widget.video.id, PlaybackEvent.play);

      if (!_hasIncrementedView) {
        _viewCountTimer?.cancel();
        _viewCountTimer = Timer(_minWatchTimeForView, () {
          if (!mounted || _isDisposed) return;
          _viewCountTimer?.cancel();
          _viewCountTimer = null;
          _hasIncrementedView = true;
          _incrementViewCount();
        });
      }
    }
  }

  void _handleLikeChanged() {
    _trackInterestSignal('like');
  }

  Future<void> _handleFavoriteChanged() async {
    final UnifiedBookmarkService bookmarkService =
        UnifiedBookmarkService.instance;
    if (bookmarkService.hasPendingOperation(widget.video.id)) {
      return;
    }
    final bool wasBookmarked = _isBookmarked;
    final int countBefore = _favoriteCount;
    if (mounted) {
      setState(() {
        _isBookmarked = !wasBookmarked;
        if (_isBookmarked) {
          _favoriteCount = countBefore + 1;
        } else {
          _favoriteCount = (countBefore - 1).clamp(0, 1 << 30);
        }
      });
    }
    try {
      final User? authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        await bookmarkService.initialize(authUser.uid);
      }
      final BookmarkResult result =
          await bookmarkService.toggleBookmark(widget.video.id);

      if (result.success) {
        if (result.isBookmarked == true) {
          _trackInterestSignal('save');
        }
        if (mounted) {
          setState(() {
            _isBookmarked = result.isBookmarked!;
          });
        }
        debugPrint(
            '✅ VideoPlayerView: Bookmark toggled for video ${widget.video.id}: $_isBookmarked');
      } else {
        if (mounted) {
          setState(() {
            _isBookmarked = wasBookmarked;
            _favoriteCount = countBefore;
          });
        }
        // Show user-friendly error message
        if (mounted) {
          String errorMessage = 'Failed to update bookmark';
          if (result.error?.contains('Maximum bookmarks limit reached') ==
              true) {
            errorMessage = 'Bookmark limit reached (1000 videos)';
          } else if (result.error?.contains('PERMISSION_DENIED') == true) {
            errorMessage = 'Unable to save bookmark - check connection';
          } else if (result.error?.contains('User not authenticated') == true) {
            errorMessage = 'Please log in to save bookmarks';
          } else {
            errorMessage = 'Failed to update bookmark';
          }

          final ColorScheme scheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                errorMessage,
                style: TextStyle(color: scheme.onInverseSurface),
              ),
              backgroundColor: scheme.inverseSurface.withValues(alpha: 0.92),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBookmarked = wasBookmarked;
          _favoriteCount = countBefore;
        });
        String errorMessage = 'Failed to update bookmark';
        if (e.toString().contains('Video not found')) {
          errorMessage = 'Video no longer available in feed';
        } else if (e.toString().contains('PERMISSION_DENIED')) {
          errorMessage = 'Unable to save bookmark - check connection';
        } else {
          errorMessage = 'Failed to update bookmark';
        }

        final ColorScheme scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              errorMessage,
              style: TextStyle(color: scheme.onInverseSurface),
            ),
            backgroundColor: scheme.inverseSurface.withValues(alpha: 0.92),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      secureLog('❌ Error toggling bookmark for video ${widget.video.id}: $e');
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      final analyticsRef = FirebaseFirestore.instance
          .collection('video_analytics')
          .doc(widget.video.id);
      await analyticsRef.set({
        'views': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint("Incremented view count for video: ${widget.video.id}");
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint("Error incrementing view count: $error");
      }
    }
  }

  void _trackInterestSignal(String interactionType) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    MLRecommendationService().trackUserInteraction(
      userId: currentUser.uid,
      videoId: widget.video.id,
      interactionType: interactionType,
      creatorId: widget.video.creator.id,
      metadata: {
        'categoryId': widget.video.categoryId,
        'creatorId': widget.video.creator.id,
        'caption': widget.video.caption,
      },
    );
  }

  void _handleProfileTap() {
    // Handle profile/avatar tap - open StreamerCardView for other users
    HapticFeedback.lightImpact();
    _trackInterestSignal('profile_open');
    secureLog(
        '👤 VideoPlayer: Opening StreamerCard for ${widget.video.creator.username}');

    // Get current user ID for follow/connection logic
    final auth = ref.read(robustAuthServiceProvider);
    final currentUserId = auth.currentUser?.id;

    final playbackManager = GlobalPlaybackManager.instance;

    void restoreAfterStreamerCard(String reason) {
      playbackManager.unblock();
      if (!mounted || _isDisposed || !widget.isCurrentVideo) return;
      _hasRequestedFocus = false;
      _lastRequestedVideoId = null;
      playbackManager.setDesiredFocus(widget.video.id, _ownerKey);
      _activateCurrentVideo(reason);
    }

    // Pause video playback when navigating away
    playbackManager.block(reason: 'streamerCardOpened');

    // Navigate to StreamerCardView (for viewing other users)
    AppNavigator.openStreamerCard(
      context,
      userId: widget.video.creator.id,
      initialCreator: widget.video.creatorSnapshot,
      currentUserId: currentUserId,
      onDismiss: () {
        Navigator.of(context).pop();
        restoreAfterStreamerCard('streamer_card_dismissed');
        secureLog(
            '👤 VideoPlayer: Returned from StreamerCard, restoring playback');
      },
    ).then((_) {
      // Also unblock when back button is used (fallback)
      restoreAfterStreamerCard('streamer_card_back');
      secureLog('👤 VideoPlayer: Back from StreamerCard (via back button)');
    });
  }

  void _navigateToTaggedUserProfile(String userId) {
    HapticFeedback.lightImpact();
    secureLog('👤 VideoPlayer: Opening StreamerCard for tagged user: $userId');

    // Get current user ID for follow/connection logic
    final auth = ref.read(robustAuthServiceProvider);
    final currentUserId = auth.currentUser?.id;

    final playbackManager = GlobalPlaybackManager.instance;

    void restoreAfterTaggedProfile(String reason) {
      playbackManager.unblock();
      if (!mounted || _isDisposed || !widget.isCurrentVideo) return;
      _hasRequestedFocus = false;
      _lastRequestedVideoId = null;
      playbackManager.setDesiredFocus(widget.video.id, _ownerKey);
      _activateCurrentVideo(reason);
    }

    // Pause video playback when navigating away
    playbackManager.block(reason: 'taggedUserProfileOpened');

    // Navigate to StreamerCardView for tagged user
    AppNavigator.openStreamerCard(
      context,
      userId: userId,
      currentUserId: currentUserId,
      onDismiss: () {
        Navigator.of(context).pop();
        restoreAfterTaggedProfile('tagged_profile_dismissed');
        secureLog(
            '👤 VideoPlayer: Returned from tagged user profile, restoring playback');
      },
    ).then((_) {
      restoreAfterTaggedProfile('tagged_profile_back');
      secureLog(
          '👤 VideoPlayer: Back from tagged user profile (via back button)');
    });
  }

  Future<void> _handleComment() async {
    if (widget.onShowComments != null) {
      widget.onShowComments!();
      return;
    }

    HapticFeedback.lightImpact();
    _trackInterestSignal('comment_open');

    showModalBottomSheet<void>(
      context: context,
      routeSettings: const RouteSettings(name: '/comments'),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => CommentsView2(
        videoId: widget.video.id,
        videoOwnerId: widget.video.creator.id,
      ),
    ).whenComplete(() {
      if (!mounted || _isDisposed || !widget.isCurrentVideo) return;
      _hasRequestedFocus = false;
      _lastRequestedVideoId = null;
      GlobalPlaybackManager.instance
          .setDesiredFocus(widget.video.id, _ownerKey);
      _activateCurrentVideo('comments_dismissed');
    });
  }

  Future<void> _handleBookmark() async {
    if (UnifiedBookmarkService.instance.hasPendingOperation(widget.video.id)) {
      return;
    }
    HapticFeedback.lightImpact();
    await _handleFavoriteChanged();
  }

  void _handleShare() {
    // Use callback if provided, else use internal implementation
    if (widget.onShowShare != null) {
      widget.onShowShare!();
      return;
    }

    debugPrint(
        '📤 _handleShare: Opening ShareSheetView for video ${widget.video.id}');
    HapticFeedback.lightImpact();
    _trackInterestSignal('share');

    // Open enhanced TikTok-style share sheet
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        debugPrint('📤 _handleShare: Building EnhancedShareSheet...');
        return EnhancedShareSheet(
          video: widget.video,
          onClose: () {
            debugPrint('📤 _handleShare: EnhancedShareSheet dismissed');
            Navigator.pop(context);
          },
        );
      },
    ).whenComplete(() {
      if (!mounted || _isDisposed || !widget.isCurrentVideo) return;
      _hasRequestedFocus = false;
      _lastRequestedVideoId = null;
      GlobalPlaybackManager.instance
          .setDesiredFocus(widget.video.id, _ownerKey);
      _activateCurrentVideo('share_dismissed');
    });
  }

  void _handleTap() {
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();

    // Debug logging
    debugPrint(
        '🎯 TAP DETECTED! - _isPlaying: $_isPlaying, _isInitialized: $_isInitialized, _videoPlayerController: ${_videoPlayerController != null}');
    _logger.debug(
        'Tap detected - Current state: _isPlaying=$_isPlaying, _isInitialized=$_isInitialized',
        tag: 'VideoPlayer');

    // Toggle play/pause with animation
    _togglePlayPause();

    // Show play/pause indicator animation
    _showPlayPauseIndicator();
  }

  void _handleDoubleTap(Offset position) {
    debugPrint(
        '💖💖 DOUBLE TAP DETECTED at position: $position for video ${widget.video.id}');
    InteractionDiagnostics.logDoubleTapStart(videoId: widget.video.id);

    if (_doubleTapInFlight) {
      return;
    }
    _doubleTapInFlight = true;

    // Double tap anywhere on video to like (never unlikes - TikTok behavior)
    HapticFeedback.mediumImpact();

    if (FirebaseAuth.instance.currentUser?.uid == null) {
      debugPrint('❌ DOUBLE TAP: No user logged in');
      _doubleTapInFlight = false;
      return;
    }

    debugPrint('✨ DOUBLE TAP: Creating floating heart animation');
    _createHeartAnimation(position);

    final VideoLikeState likeState = ref.read(
      videoLikeProvider(widget.video.id),
    );
    if (!likeState.isLiked) {
      debugPrint('LIKE_DOUBLE_TAP_OPTIMISTIC video=${widget.video.id}');
      ref.read(videoLikeProvider(widget.video.id).notifier).toggleOptimistic(
            source: 'double_tap',
            onBackgroundSyncComplete: () {
              _doubleTapInFlight = false;
            },
          );
      _handleLikeChanged();
    } else {
      _doubleTapInFlight = false;
    }
    InteractionDiagnostics.logDoubleTapUiDone(videoId: widget.video.id);
  }

  void _createHeartAnimation(Offset position) {
    debugPrint('💖 Heart animation triggered at position: $position');
    final OverlayState overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (BuildContext context) => IgnorePointer(
        child: _FloatingHeartOverlay(
          position: position,
          onAnimationComplete: () {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
            InteractionDiagnostics.logOverlayHeartRemoved();
          },
        ),
      ),
    );
    overlay.insert(overlayEntry);
  }

  /// Show play/pause indicator animation with TikTok-style effects
  void _showPlayPauseIndicator() {
    // 1. Immediate haptic feedback
    HapticFeedback.lightImpact();

    // 2. Show indicator with animation
    setState(() {
      _showPlayPauseIndicatorOverlay = true;
    });

    // 3. Hide indicator after animation
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIndicatorOverlay = false;
        });
      }
    });
  }

  /// Build play/pause indicator overlay with TikTok-style animation
  Widget _buildPlayPauseIndicator() {
    return Center(
      child: AnimatedScale(
        scale: _showPlayPauseIndicatorOverlay ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.elasticOut,
        child: AnimatedOpacity(
          opacity: _showPlayPauseIndicatorOverlay ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 60, // Increased size since no container background
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // ✅ FIX: Bookmark initialization moved to initState() to prevent duplicate subscriptions
    final String? readyUrl = _readyPlaybackUrlFromVideo();
    if (readyUrl == null) {
      return VideoPlayerPublishStateOverlay(status: widget.video.status);
    }

    return Consumer(
      builder: (context, ref, child) {
        // Video playback is now managed by the PlaybackCoordinator block/unblock system
        // No need for manual pause/resume logic here

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: _media3HomeOwnerEnabled ? Colors.transparent : Colors.black,
          child: Stack(
            children: [
              // TIKTOK-STYLE: Video player with tap handling
              // Use custom double-tap detector to avoid gesture conflicts
              DoubleTapGestureDetector(
                onSingleTap: _handleTap,
                onDoubleTap: _handleDoubleTap,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: _buildVideoPlayer(),
                ),
              ),

              if (widget.showHUD) const VideoPlayerPremiumFeedScrim(),

              if (widget.showHUD &&
                  widget.video.overlayCaption.trim().isNotEmpty &&
                  widget.video.overlayCaption.trim() !=
                      resolveFeedDisplayCaption(
                        caption: widget.video.caption,
                        overlayCaption: widget.video.overlayCaption,
                      ))
                VideoPlayerOverlayCaption(
                  overlayCaption: widget.video.overlayCaption,
                ),

              // HUD Overlays - only show if showHUD is true
              if (widget.showHUD) ...[
                // UI Overlay (positioned above gesture detector)
                _buildUIOverlay(),

                // Action buttons overlay (positioned above gesture detector)
                _buildActionButtons(),

                // Play/Pause indicator overlay
                if (_showPlayPauseIndicatorOverlay) _buildPlayPauseIndicator(),

                // Heart animations now handled by EnhancedLikeButton
              ],
            ],
          ),
        );
      },
    );
  }

  String? _resolveNativeMedia3Url() {
    return _readyPlaybackUrlFromVideo();
  }

  String? _readyPlaybackUrlFromVideo() {
    return _cellBootstrap.readyPlaybackUrlFromVideo(
      status: widget.video.status,
      videoUrl: widget.video.videoURL,
    );
  }

  void _initializeNativeMedia3Home(String reason) {
    if (!_useNativeMedia3Home) return;
    final url = _resolveNativeMedia3Url();
    if (url == null) {
      _isUnplayable = true;
      _playbackError = 'Video unavailable';
      _handleUnplayableVideo('missing_playback_url', {
        'videoId': widget.video.id,
        'source': 'android_media3_home',
        'reason': reason,
      });
      return;
    }
    _isDisposed = false;
    _isInitialized = true;
    _playbackError = null;
    _showErrorAfterDelay = false;
    _isUnplayable = false;
    _nativeMedia3Url = url;
    _lastResolvedUrl = url;
    _syncNativeMedia3Playback(reason);
    if (mounted) setState(() {});
  }

  // ignore: unused_element
  Future<void> _disposeNativeMedia3Home() async {
    final controller = _nativeMedia3Controller;
    _nativeMedia3Controller = null;
    _nativeMedia3Url = null;
    _isPlaying = false;
    if (controller == null) return;
    try {
      await controller.setMuted(true);
      await controller.pause();
      await controller.dispose();
    } catch (e, st) {
      logPlaybackSwallowed('android_media3_home.dispose', e, st);
    }
  }

  Future<void> _syncNativeMedia3Playback(String reason) async {
    if (!_media3HomeOwnerEnabled) return;
    final controller = _nativeMedia3Controller;
    final url = _nativeMedia3Url ?? _resolveNativeMedia3Url();
    if (url == null) return;
    _nativeMedia3Url = url;

    final playbackManager = GlobalPlaybackManager.instance;
    if (widget.isCurrentVideo &&
        playbackManager.activeOwner == null &&
        (reason == 'initState' || reason == 'platformViewCreated')) {
      playbackManager.setActiveOwner(_ownerKey);
    }
    final activeOwner = playbackManager.activeOwner;
    final ownerCanPlay = activeOwner != null &&
        (_ownerKey == activeOwner || _ownerKey.startsWith('$activeOwner/'));
    final bool canPlay = _useNativeMedia3Home &&
        !playbackManager.isPlaybackBlocked &&
        ownerCanPlay;
    if (widget.isCurrentVideo) {
      playbackManager.setDesiredFocus(widget.video.id, _ownerKey);
    }

    if (controller == null) return;

    await controller.setSource(url, autoplay: canPlay);
    if (canPlay) {
      await controller.setMuted(false);
      await controller.play();
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _audioUnmuted = true;
        });
      }
      widget.onVideoPlaySuccess?.call();
      PerformanceService()
          .trackVideoPlayback(widget.video.id, PlaybackEvent.play);
      secureLog('✅ Media3Home: playing ${widget.video.id} ($reason)');
    } else {
      await controller.setMuted(true);
      await controller.pause();
      if (mounted) setState(() => _isPlaying = false);
      secureLog('⏸️ Media3Home: paused ${widget.video.id} ($reason)');
    }
  }

  // ignore: unused_element
  Widget _buildNativeMedia3HomePlayer() {
    if (_isUnplayable && widget.isCurrentVideo) {
      return _buildUnplayableOverlay();
    }
    final url = _nativeMedia3Url ?? _resolveNativeMedia3Url();
    if (url == null) {
      return const ColoredBox(color: Colors.black);
    }

    final playbackManager = GlobalPlaybackManager.instance;
    final activeOwner = playbackManager.activeOwner;
    final ownerCanPlay = activeOwner != null &&
        (_ownerKey == activeOwner || _ownerKey.startsWith('$activeOwner/'));
    final bool autoplay = widget.isCurrentVideo &&
        !playbackManager.isPlaybackBlocked &&
        ownerCanPlay;

    return VideoPlayerMedia3HomeSurface(
      video: widget.video,
      url: url,
      autoplay: autoplay,
      thumbnailVisible: _thumbnailVisible,
      thumbnailService: _thumbnailService,
      onPlatformViewCreated: (AndroidMedia3HomeController controller) {
        controller.onFirstFrame = () {
          if (!mounted || !_useNativeMedia3Home) return;
          setState(() {
            _thumbnailVisible = false;
            _hasSeenFirstFrame = true;
            _firstFrameRenderedAt ??= DateTime.now();
          });
        };
        controller.onError = (String message) {
          if (!mounted || !_useNativeMedia3Home) return;
          _handleVideoError(message);
        };
        _nativeMedia3Controller = controller;
        _syncNativeMedia3Playback('platformViewCreated');
      },
    );
  }

  Widget _buildVideoPlayer() {
    // ✅ FIX BLACK SCREEN: Build must be pure - no state mutation inside build()
    // Controller adoption is now handled in initState() and didUpdateWidget()

    if (_media3HomeOwnerEnabled) {
      final url = _nativeMedia3Url ?? _resolveNativeMedia3Url();
      if (!widget.isCurrentVideo && url != null) {
        return VideoPlayerThumbnailPoster(
          video: widget.video,
          thumbnailService: _thumbnailService,
        );
      }
      return const ColoredBox(color: Colors.transparent);
    }

    if (!widget.isCurrentVideo && _ownerKey.startsWith('home')) {
      return VideoPlayerThumbnailPoster(
        video: widget.video,
        thumbnailService: _thumbnailService,
      );
    }

    // 🔥 TIKTOK-STYLE: Three-state UX - never show red during swiping

    // State B: Unplayable (neutral overlay)
    if (_isUnplayable && widget.isCurrentVideo) {
      return _buildUnplayableOverlay();
    }

    // State C: Failed after having playable URL (only show if current and user stopped)
    if (_playbackError != null &&
        _showErrorAfterDelay &&
        !_isInitializing &&
        widget.isCurrentVideo) {
      return _buildFailedState();
    }

    // ✅ FIX BLACK SCREEN: Pure rendering - just render whatever controller is set
    // Don't gate on isInitialized too strictly - mount VideoPlayer early so it can render ASAP
    final controller = _videoPlayerController;

    if (controller == null) {
      // TikTok-style: Videos should be preloaded - show black while waiting
      return const ColoredBox(color: Colors.black);
    }

    // 🔥 CRITICAL FIX: Check if controller is safe to use BEFORE accessing value or passing to VideoPlayer
    // Never mutate state in build - schedule post-frame cleanup to avoid "used after disposed" in VideoPlayer.didUpdateWidget
    if (!_canUseController(controller)) {
      _scheduleClearDisposedController(controller);
      return const ColoredBox(color: Colors.black);
    }

    if (_wasRegistered) {
      try {
        final poolController =
            GlobalPlaybackManager.instance.getController(widget.video.id);
        if (poolController != null && !identical(poolController, controller)) {
          _scheduleClearDisposedController(controller);
          return const ColoredBox(color: Colors.black);
        }
      } catch (e, st) {
        ignorePlaybackTeardownError('video_player', e, st);
      }
    }

    VideoPlayerValue v;
    try {
      v = controller.value;
    } catch (e, stack) {
      logPlaybackSwallowed('_buildVideoLayer', e, stack);
      _scheduleClearDisposedController(controller);
      return const ColoredBox(color: Colors.black);
    }

    if (widget.isCurrentVideo) {
      _clearPosterAfterFrameIfPlaying(
        controller: controller,
        reason: 'build current initialized controller',
      );
    }

    final double width = v.size.width > 0 ? v.size.width : 16;
    final double height = v.size.height > 0 ? v.size.height : 9;

    // 🔥 CRITICAL: Final check right before passing to VideoPlayer (controller may have been disposed in another callback)
    if (!_canUseController(controller)) {
      _scheduleClearDisposedController(controller);
      return const ColoredBox(color: Colors.black);
    }

    // ✅ TIKTOK-STYLE: Always mount VideoPlayer (this is the key)
    // Flutter's VideoPlayer can be mounted before init - texture pipeline attaches early
    // 🔥 FIX DISPOSAL RACE: Use controller.hashCode in key to force recreation if controller changes
    // 🔥 FIX BLACK SCREEN: Use SizedBox.expand() when size is unknown (not 1×1 fallback)
    final String playerKey =
        'VideoPlayer:${widget.video.id}:${controller.hashCode}:$_surfaceRecoveryEpoch';

    final videoAspectRatio = width / height;
    final bool useContainedStage =
        VideoPlayerContainedStageLogic.shouldUseContainedStage(
      videoAspectRatio,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (useContainedStage)
          VideoPlayerContainedBackdrop(
            video: widget.video,
            thumbnailService: _thumbnailService,
          ),
        if (width > 0 && height > 0)
          ClipRect(
            child: FittedBox(
              fit: useContainedStage ? BoxFit.contain : BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: width,
                height: height,
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoPlayer(
                        controller,
                        key: ValueKey(playerKey),
                      ),
                      AnimatedOpacity(
                        opacity: _thumbnailVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: VideoPlayerThumbnailPoster(
                          video: widget.video,
                          thumbnailService: _thumbnailService,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          SizedBox.expand(
            child: VideoPlayer(
              controller,
              key: ValueKey(playerKey),
            ),
          ),
        if (useContainedStage) const VideoPlayerContainedStageScrim(),
      ],
    );
  }

  Widget _buildUIOverlay() {
    final media = MediaQuery.of(context);
    final railMetrics = VideoPlayerActionRailMetrics.of(context);
    final safeBottom = media.viewPadding.bottom;

    final leftInset = railMetrics.leftInset;
    final rightInset = railMetrics.metadataRightInset;

    // Different positioning for each view type:
    // - HomeView: keep creator text safely above the floating dock
    // - ProfileView: Move down a little more
    // - DiscoverView: At the very bottom
    final isCategoryFeed = widget.tabId.startsWith('discoverView_');
    final isProfileView =
        widget.tabId.startsWith('profile_') || widget.tabId == 'playerScreen';

    double bottomPosition;
    if (isCategoryFeed) {
      bottomPosition = safeBottom + 20.0;
    } else if (isProfileView) {
      bottomPosition = safeBottom + 20.0;
    } else {
      final double dockBase =
          railMetrics.bottomNavHeight + railMetrics.bottomNavMargin;
      final double platformHomeLift =
          defaultTargetPlatform == TargetPlatform.iOS ? -40.0 : 0.0;
      bottomPosition = safeBottom +
          dockBase +
          railMetrics.metadataPaddingAboveNav +
          42.0 +
          platformHomeLift;
    }

    return Positioned(
      left: leftInset,
      right: rightInset,
      bottom: bottomPosition,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Creator row: avatar + username + follow pill
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onShowProfile ?? () => _handleProfileTap(),
                  child: VideoPlayerCreatorAvatar(
                    avatarUrl: widget.video.creator.avatarURL,
                    username: widget.video.creator.username,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: GestureDetector(
                    onTap: widget.onShowProfile ?? () => _handleProfileTap(),
                    child: Text(
                      '@${widget.video.creator.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        letterSpacing: -0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.65),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            VideoPlayerExpandableCaption(
              key: ValueKey<String>('caption-${widget.video.id}'),
              caption: widget.video.caption,
              overlayCaption: widget.video.overlayCaption,
            ),
            // Tagged users
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _taggedUsersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final taggedUsers = snapshot.data!;
                if (taggedUsers.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: taggedUsers.map((user) {
                        return GestureDetector(
                          onTap: () => _navigateToTaggedUserProfile(
                              user['userId'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (user['avatarURL'] != null &&
                                    user['avatarURL'].toString().isNotEmpty)
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          user['avatarURL'].toString(),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.withValues(alpha: 0.3),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (user['displayName'] as String? ?? 'U')
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  '@${user['username']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
            // Video tags/hashtags
            if (widget.video.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.video.tags.map((tag) {
                  debugPrint('🏷️ VideoPlayerView: Displaying tag: $tag');
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tag.startsWith('#') ? tag : '#$tag',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Fetch tagged users for a video (requires auth; returns [] on permission-denied).
  Future<List<Map<String, dynamic>>> _fetchTaggedUsers(String videoId) async {
    if (FirebaseAuth.instance.currentUser == null) return [];
    try {
      final tagsSnapshot = await FirebaseFirestore.instance
          .collection('tags')
          .where('videoId', isEqualTo: videoId)
          .get();

      if (tagsSnapshot.docs.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> taggedUsers = [];
      for (final tagDoc in tagsSnapshot.docs) {
        final tagData = tagDoc.data();
        final taggedUserId = tagData['taggedUserId'] as String?;
        if (taggedUserId == null) continue;

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(taggedUserId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          taggedUsers.add({
            'userId': taggedUserId,
            'username': userData['username'] ?? 'unknown',
            'displayName':
                userData['displayName'] ?? userData['username'] ?? 'Unknown',
            'avatarURL': userData['avatarURL'] ?? userData['avatarUrl'] ?? '',
          });
        }
      }

      return taggedUsers;
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED') ||
          e
              .toString()
              .contains('Unable to resolve host firestore.googleapis.com') ||
          e.toString().contains('cloud_firestore/unavailable')) {
        return [];
      }
      secureLog('❌ Error fetching tagged users: $e', name: 'VideoPlayerView');
      return [];
    }
  }

  Widget _buildActionButtons() {
    final VideoPlayerActionRailMetrics railMetrics =
        VideoPlayerActionRailMetrics.of(context);

    return VideoPlayerActionRail(
      tabId: widget.tabId,
      videoId: widget.video.id,
      initialLikeCount: widget.video.likes,
      initialIsLiked: widget.isLiked,
      onLikeChanged: _handleLikeChanged,
      likeButtonKey: _likeButtonKey,
      commentCount: _commentCount,
      onComment: () => unawaited(_handleComment()),
      isBookmarked: _isBookmarked,
      favoriteCount: _favoriteCount,
      isBookmarkPending: _bookmarkService.hasPendingOperation(widget.video.id),
      onBookmark: () => unawaited(_handleBookmark()),
      shareCount: _shareCount,
      onShare: _handleShare,
      trailing: _buildTrailingRailButton(railMetrics.avatarSize),
    );
  }

  Widget _buildTrailingRailButton(double size) {
    final commandSnapshot = ref.watch(creatorCommandSnapshotProvider);
    final bool showCommandCenterTrigger =
        widget.showCommandCenterTrigger && widget.tabId == 'home/forYou';
    final CreatorCommandSnapshot? hub = commandSnapshot.valueOrNull;
    final bool showAlertPulse = hub != null &&
        (hub.alertCount > 0 ||
            hub.scheduledQueueCount > 0 ||
            hub.draftCount > 0);

    if (showCommandCenterTrigger) {
      return StreamersTipCommandCenterTrigger(
        key: QaKeys.commandCenterTrigger,
        size: size,
        showAlertPulse: showAlertPulse,
        onTap: widget.onCommandCenterTap ?? () {},
      );
    }

    return GestureDetector(
      onTap: widget.onShowProfile ?? () => _handleProfileTap(),
      child: VideoPlayerCreatorAvatar(
        avatarUrl: widget.video.creator.avatarURL,
        username: widget.video.creator.username,
        size: size,
        showBorder: true,
      ),
    );
  }
}

class _FloatingHeartOverlay extends StatefulWidget {
  final Offset position;
  final VoidCallback? onAnimationComplete;

  const _FloatingHeartOverlay({
    required this.position,
    this.onAnimationComplete,
  });

  @override
  State<_FloatingHeartOverlay> createState() => _FloatingHeartOverlayState();
}

class _FloatingHeartOverlayState extends State<_FloatingHeartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // Instagram-style elastic bounce
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));

    _positionAnimation = Tween<Offset>(
      begin: widget.position,
      end: Offset(widget.position.dx, widget.position.dy - 100),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.addStatusListener(_handleAnimationStatus);
    _controller.forward();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    widget.onAnimationComplete?.call();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      color: Colors.transparent,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                left: _positionAnimation.value.dx - 20,
                top: _positionAnimation.value.dy - 20,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF9248D2), // Purple
                          Color(0xFF7768DF), // Another purple
                          Color(0xFF1670DE), // Blue
                          Color(0xFF3C8BD6), // Lighter blue
                          Color(0xFF4897D2), // Lightest blue
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 🔥 CRITICAL FIX: Safe wrapper for VideoPlayer that validates controller before use
/// Prevents "controller used after being disposed" errors by checking controller validity
/// in didUpdateWidget before the VideoPlayer tries to add listeners
