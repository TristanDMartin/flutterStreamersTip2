import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// cspell:ignore unmuted unmuting HOMEVIEW
import '../models/home_video.dart';
import '../providers/home_provider.dart';
import '../services/performance_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/robust_auth_service.dart';
import '../widgets/enhanced_like_button.dart';
import '../widgets/double_tap_gesture_detector.dart';
import '../widgets/enhanced_share_sheet.dart';
import '../services/streamers_tip_like_service.dart';
import '../services/video_controller_registry.dart';
import '../services/production_logging_service.dart';
import '../services/audio_enhancement_service.dart';
import '../services/global_playback_manager.dart';
import '../widgets/comments_view2.dart';
import '../services/follow_button_service.dart';
import '../services/enhanced_algorithm_service.dart';
import '../services/unified_bookmark_service.dart';
import '../services/video_resume_service.dart';
import '../services/feed_telemetry_service.dart';
import '../routing/app_navigator.dart';
import '../utils/video_health_gate.dart';
import '../utils/responsive_layout.dart';
import '../constants/app_colors.dart';
import '../services/thumbnail_service.dart';
import '../widgets/creator_command_center_overlay.dart';
import '../providers/creator_command_provider.dart';

class VideoPlayerViewOptimized extends ConsumerStatefulWidget {
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
  String? _lastResolvedUrl;
  bool _isInitialized = false;
  bool _isPlaying = false;

  /// Derived from controller so we never have initialized=true and controller=null.
  bool get _controllerReady {
    try {
      final c = _videoPlayerController;
      return c != null && !c.value.hasError && c.value.isInitialized;
    } catch (_) {
      return false;
    }
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
      false; // Local bookmark state that syncs with FavoritesService
  bool _didFirstReadyRebuild =
      false; // Track if we've triggered rebuild when controller becomes ready
  bool _isCaptionExpanded = false;
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
  late UnifiedBookmarkService _bookmarkService;
  final VideoResumeService _resumeService = VideoResumeService();

  // Stream subscription for bookmark state changes
  StreamSubscription<BookmarkEvent>? _bookmarkSubscription;

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

  // 🔥 PRODUCTION-GRADE: Black screen recovery state
  int _blackScreenRecoveryAttempts =
      0; // Track recovery attempts per video session
  DateTime? _lastBlackScreenRecoveryAt; // Timestamp of last recovery attempt
  static final Map<String, int> _recoveryAttemptsPerVideo =
      {}; // Track attempts per videoId across sessions
  static const Duration _blackScreenRecoveryCooldown =
      Duration(milliseconds: 1500); // Cooldown between recovery attempts
  static const int _maxRecoveryAttempts =
      2; // Max recovery attempts per video session
  bool _hasTrackedWatch = false; // Track if we've logged a watch (>50%)
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

  // 🔥 PHASE 2.1: Surface/MediaCodec BAD_INDEX Fix - Surface recreation epoch (feature-flagged)
  int _surfaceEpoch = 0;
  int _textureRebuildTick = 0;
  static const bool _enableSurfaceWatchdogRecreate =
      false; // Feature flag for surface recreation watchdog

  // 🔥 TIKTOK-STYLE: Broken video quarantine (session-local)
  static final Set<String> _brokenVideoIds = <String>{};

  // 🔥 TIKTOK-STYLE: Video health state
  bool _isUnplayable = false;

  // Callback for auto-skip broken videos
  VoidCallback? onVideoUnplayable;
  DateTime? _lastRecoveryAt;
  static const Duration _recoveryCooldown = Duration(seconds: 6);
  int _lastLoopRefreshMs = 0;
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
    } catch (_) {}
  }

  Future<void> _disposeVideoController() async {
    if (_isDisposingController || _isDisposed) {
      debugPrint('[VideoPlayer] dispose skipped (already disposing/disposed)');
      return;
    }
    _isDisposingController = true;
    final controller = _videoPlayerController;
    final controllerHashCode = controller?.hashCode;

    // 🔥 PRODUCTION-GRADE: Increment version FIRST to abort any pending async operations
    _controllerVersion++;
    log('🗑️ VideoPlayer: Disposing controller ${controllerHashCode ?? 'null'}, version incremented to $_controllerVersion');

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
      log('🗑️ VideoPlayer: Unregistering controller ${controllerHashCode} from owner $owner');
      debugPrint(
          '[VideoPlayer] unregister owner=$owner controller=$controllerHashCode');
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
          log('🔌 VideoPlayer: Removed all listeners from controller $controllerHashCode');
        } else {
          log('⚠️ VideoPlayer: Controller $controllerHashCode already disposed, skipping listener removal');
        }
      } catch (e) {
        // Controller may already be disposed - this is okay
        log('⚠️ VideoPlayer: Could not remove listeners (controller disposed): $e');
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
    } catch (_) {}
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
    if (controller == null) return false;
    try {
      controller.value; // Just touching it will throw if disposed
      return true;
    } catch (_) {
      return false;
    }
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
        log('⚠️ VideoPlayer: Cleared disposed controller ref for ${widget.video.id}');
        if (wasCurrent && mounted) {
          _initializeVideo();
        }
      }
    });
  }

  /// ✅ PRODUCTION-GRADE: Adopt a pooled controller properly with version tracking
  /// This ensures immediate setState, listener attachment, and rebuild
  /// Also increments controller version to abort stale async operations
  void _adoptController(VideoPlayerController controller) {
    if (!mounted) return;

    // 🔥 PRODUCTION-GRADE: If controller instance changed, increment version and detach old listeners
    final controllerChanged = _currentControllerInstance != controller;
    final controllerId = controller.hashCode;
    if (controllerChanged && _currentControllerInstance != null) {
      final oldControllerId = _currentControllerInstance!.hashCode;
      log('🎬 CONTROLLER_DETACHED: videoId=${widget.video.id} controllerId=$oldControllerId');
      GlobalPlaybackManager.instance.markControllerDetached(widget.video.id);
      log('🔄 VideoPlayer: Controller instance changed ($oldControllerId -> $controllerId), incrementing version and detaching old listeners');

      // Detach listeners and dispose old controller (manager may have skipped dispose if attached).
      final oldController = _currentControllerInstance;
      try {
        if (oldController != null && _canUseController(oldController)) {
          oldController.removeListener(_videoErrorListener);
          oldController.removeListener(_videoStateListener);
          oldController.removeListener(_videoPositionListener);
          oldController.removeListener(_onControllerChanged);
          log('🔌 VideoPlayer: Detached all listeners from old controller ${oldController.hashCode}');
          oldController.dispose();
        }
      } catch (e) {
        log('⚠️ VideoPlayer: Error detaching/disposing old controller: $e');
      }

      // Increment version to abort any stale async operations
      _controllerVersion++;
      log('📌 VideoPlayer: Controller version incremented to $_controllerVersion');
    }

    _videoPlayerController = controller;
    _currentControllerInstance = controller;
    _isDisposed = false;
    _didFirstReadyRebuild = false;
    _posterTimer?.cancel();
    _posterTimer = null;
    _thumbnailVisible = true;
    try {
      _isInitialized =
          controller.value.isInitialized && !controller.value.hasError;
      _isPlaying = controller.value.isPlaying;
    } catch (_) {
      _isInitialized = false;
      _isPlaying = false;
    }

    log('🎬 CONTROLLER_ATTACHED: videoId=${widget.video.id} controllerId=$controllerId '
        'init=$_isInitialized isPlaying=$_isPlaying');

    _clearPosterAfterFrameIfPlaying(
      controller: controller,
      reason: 'adopted initialized controller',
    );

    // 🔥 PRODUCTION-GRADE: Reset black screen recovery state on controller change
    _blackScreenRecoveryAttempts = 0;
    _lastBlackScreenRecoveryAt = null;
    _hasSeenFirstFrame = false;
    _firstFrameRenderedAt = null;
    _playbackStartTime = null;
    _firstFrameWatchdog?.cancel();
    _firstFrameWatchdog = null;

    // Attach listener to new controller
    try {
      if (_canUseController(controller)) {
        controller.addListener(_onControllerChanged);
        log('🔌 VideoPlayer: Attached _onControllerChanged listener to controller ${controller.hashCode}');
      }
    } catch (e) {
      log('⚠️ VideoPlayer: Error attaching listener to new controller: $e');
    }

    // Force rebuild immediately so VideoPlayer enters tree with new key
    setState(() {});
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
        setState(() {});
      }
    } catch (_) {
      // Controller disposed mid-notify - ignore
    }
  }

  /// Adopt controller from pool when one exists for this videoId (removes identity gate).
  /// Ensures view and manager share the same controller so focus requests succeed.
  bool _tryAdoptFromPool({required String reason}) {
    if (!mounted || !widget.isCurrentVideo) return false;

    final mgr = GlobalPlaybackManager.instance;
    final pooled = mgr.getController(widget.video.id);
    if (pooled == null) return false;

    try {
      if (!_canUseController(pooled) || pooled.value.hasError) return false;
    } catch (_) {
      return false;
    }

    if (_videoPlayerController != null &&
        identical(_videoPlayerController, pooled)) {
      mgr.markControllerAttached(widget.video.id, pooled.hashCode);
      log('VVIEW adopt id=${widget.video.id} pooledHash=${pooled.hashCode} (already same) reason=$reason');
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
      } catch (_) {}
      mgr.markControllerAttached(widget.video.id, pooled.hashCode);
      log('VVIEW adopt id=${widget.video.id} pooledHash=${pooled.hashCode} (replaced local) reason=$reason');
      return true;
    }

    _adoptController(pooled);
    try {
      if (_canUseController(pooled)) {
        pooled.addListener(_videoErrorListener);
        pooled.addListener(_videoStateListener);
        pooled.addListener(_videoPositionListener);
      }
    } catch (_) {}
    mgr.markControllerAttached(widget.video.id, pooled.hashCode);
    log('VVIEW adopt id=${widget.video.id} pooledHash=${pooled.hashCode} reason=$reason');
    return true;
  }

  VideoPlayerController? _obtainActiveController() {
    if (_isDisposed || _isDisposingController) return null;

    if (_registry.isControllerDisposed(widget.video.id)) {
      _registry.resetDisposed(widget.video.id);
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

  void _markControllerDisposed({Object? error, String? reason}) {
    if (_isDisposed) return;
    final VideoPlayerController? oldController = _currentControllerInstance;
    _isDisposed = true;
    _isDisposingController = false;
    _isInitialized = false;
    _isPlaying = false;
    _controllerVersion++;
    _videoPlayerController = null;
    _currentControllerInstance = null;
    log('🗑️ VideoPlayer: Controller marked as disposed (version $_controllerVersion, reason: ${reason ?? 'unknown'})');
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
    } catch (_) {}
    try {
      _registry.dispose(widget.video.id);
    } catch (_) {}

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
    log('🎯 Watch time tracking stopped for video ${widget.video.id}');
  }

  /// Initialize bookmark state from UnifiedBookmarkService and listen to changes
  void _initializeBookmarkState() {
    _bookmarkService = UnifiedBookmarkService.instance;

    // ✅ FIX: Use widget.isBookmarked if provided (from PlayerScreen), otherwise query service
    // This ensures we use the pre-loaded state from PlayerScreen for better performance
    // Note: widget.isBookmarked defaults to false, so we check service as fallback
    if (widget.isBookmarked) {
      _isBookmarked = true; // Use pre-loaded state from PlayerScreen
    } else {
      // Query service to get actual state (handles case where prop wasn't provided)
      _isBookmarked = _bookmarkService.isBookmarked(widget.video.id);
    }

    // Listen to bookmark state changes to prevent memory leaks
    _bookmarkSubscription = _bookmarkService.eventStream.listen((event) {
      if (event.videoId == widget.video.id) {
        switch (event.type) {
          case BookmarkEventType.toggle:
          case BookmarkEventType.success:
            if (mounted) {
              setState(() {
                _isBookmarked = event.isBookmarked ?? false;
              });
            }
            break;
          case BookmarkEventType.error:
            // Revert optimistic update on error
            if (mounted) {
              setState(() {
                _isBookmarked = _bookmarkService.isBookmarked(widget.video.id);
              });
            }
            break;
        }
      }
    });

    if (kDebugMode) {
      debugPrint(
          '📚 VideoPlayerView: Initialized bookmark state for video ${widget.video.id}: $_isBookmarked');
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
          primary: 'favorites',
          fallback: 'favoriteCount',
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
  }) {
    final dynamic primaryValue = data[primary];
    if (primaryValue is num) {
      return primaryValue.toInt();
    }
    if (fallback != null) {
      final dynamic fallbackValue = data[fallback];
      if (fallbackValue is num) {
        return fallbackValue.toInt();
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
    if (!mounted || _isDisposed) {
      log('🚫 VideoPlayer: Skipping focus request ($reason) - widget not mounted or disposed: ${widget.video.id}');
      return false;
    }

    if (!widget.isCurrentVideo) {
      log('🚫 VideoPlayer: Skipping focus request ($reason) - video not current: ${widget.video.id}');
      return false;
    }

    final playbackManager = GlobalPlaybackManager.instance;

    if (playbackManager.isPlaybackBlocked) {
      log('🚫 VideoPlayer: Skipping focus request ($reason) - playback blocked: ${widget.video.id}');
      _safeSetVolume(0.0);
      return false;
    }

    if (!playbackManager.canPlay(_ownerKey)) {
      log('🚫 VideoPlayer: Skipping focus request ($reason) - owner $_ownerKey cannot play: ${widget.video.id}');
      return false;
    }

    final pooled = playbackManager.getController(widget.video.id);
    if (pooled == null) {
      log('VVIEW focus id=${widget.video.id} reason=$reason controller=null (queuing)');
      playbackManager.setDesiredFocus(widget.video.id, _ownerKey);
      return false;
    }

    if (_videoPlayerController == null ||
        !identical(_videoPlayerController, pooled)) {
      _tryAdoptFromPool(reason: 'attemptRequestFocus');
    }

    if (_hasRequestedFocus && _lastRequestedVideoId == widget.video.id) {
      log('⏭️ VideoPlayer: Skipping focus request ($reason) - already requested for this video: ${widget.video.id}');
      return false;
    }

    _hasRequestedFocus = true;
    _lastRequestedVideoId = widget.video.id;

    log('VVIEW focus id=${widget.video.id} reason=$reason');
    playbackManager.requestFocus(widget.video.id, _ownerKey);
    log('✅ VideoPlayer: Focus request completed ($reason) for: ${widget.video.id}');
    return true;
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
    if (!mounted || _isDisposed || !widget.isCurrentVideo) {
      return false;
    }

    final playbackManager = GlobalPlaybackManager.instance;

    if (_videoPlayerController == null) {
      _tryAdoptFromPool(reason: '$reason: adopt');
    }

    final controller = _obtainActiveController();
    if (controller == null) {
      playbackManager.setDesiredFocus(widget.video.id, _ownerKey);
      if (allowRetry) {
        _scheduleActivationRetry('$reason: waiting for controller');
      }
      return false;
    }

    if (playbackManager.isPlaybackBlocked) {
      _safeSetVolume(0.0);
      if (allowRetry) {
        StreamSubscription<bool>? blockSubscription;
        blockSubscription =
            playbackManager.playbackBlockedStream.listen((isBlocked) {
          if (!isBlocked) {
            blockSubscription?.cancel();
            _scheduleActivationRetry('$reason: block cleared',
                delay: const Duration(milliseconds: 40));
          }
        });
      }
      return false;
    }

    if (!playbackManager.canPlay(_ownerKey)) {
      playbackManager.setDesiredFocus(widget.video.id, _ownerKey);
      if (allowRetry) {
        _retryFocusSubscription?.cancel();
        _retryFocusSubscription =
            playbackManager.activeOwnerStream.listen((activeOwner) {
          final ownerMatches = activeOwner != null &&
              (_ownerKey == activeOwner ||
                  _ownerKey.startsWith('$activeOwner/'));
          if (ownerMatches) {
            _retryFocusSubscription?.cancel();
            _retryFocusSubscription = null;
            _scheduleActivationRetry('$reason: owner became active',
                delay: const Duration(milliseconds: 40));
          }
        });
      }
      return false;
    }

    _retryFocusSubscription?.cancel();
    _retryFocusSubscription = null;
    return _attemptRequestFocus(reason);
  }

  // Key for like button (for floating hearts animation)
  final GlobalKey _likeButtonKey = GlobalKey();

  // Heart animation state (removed - using EnhancedLikeButton animations instead)

  @override
  bool get wantKeepAlive => true; // Keep pages alive while swiping

  @override
  void initState() {
    super.initState();
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
      if (ownerMatches && widget.isCurrentVideo && _isInitialized) {
        final controller = _obtainActiveController();
        if (controller != null &&
            controller.value.isInitialized &&
            !controller.value.isPlaying) {
          log('🔄 VideoPlayer: Owner $owner became active for ${widget.video.id}');
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

    _tryAdoptFromPool(reason: 'initState');

    // 🚀 INSTANT PLAYBACK: Initialize video immediately if no pooled controller found
    // Start initialization immediately, don't wait
    if (_videoPlayerController == null) {
      _initializeVideo().then((_) {
        // ✅ FIX: _initializeVideo() already calls requestFocus() if video is current (line 1275)
        // Don't call _handleVideoEnter() here to avoid duplicate play calls
        // requestFocus() → activate() already handles playback, _handleVideoEnter() would cause double audio
      }).catchError((e) {
        log('⚠️ VideoPlayer: Error initializing video ${widget.video.id}: $e');
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

    _bookmarkSubscription?.cancel();
    _bookmarkSubscription = null;

    _commentCountSubscription?.cancel();
    _commentCountSubscription = null;
    _videoDocStatsSubscription?.cancel();
    _videoDocStatsSubscription = null;

    _activeOwnerSubscription?.cancel();
    _activeOwnerSubscription = null;

    _retryFocusSubscription?.cancel();
    _retryFocusSubscription = null;

    _stopWatchTimeTracking();

    PerformanceService()
        .trackVideoPlayback(widget.video.id, PlaybackEvent.pause);

    try {
      final VideoPlayerController? controller = _currentControllerInstance;
      if (controller != null) {
        _unregisterFromPlaybackManagerIfSameInstance(
          videoId: widget.video.id,
          controller: controller,
        );
      }
      log('🎵 VideoPlayer: Unregistered controller from PlaybackManager for video ${widget.video.id}');
    } catch (e) {
      log('⚠️ VideoPlayer: Could not unregister from PlaybackManager (widget already disposed): $e');
    }

    try {
      _registry.markHidden(widget.video.id);
      _registry.dispose(widget.video.id);
      log('🔒 VideoPlayer: Unregistered controller from Registry for video ${widget.video.id}');
    } catch (e) {
      log('⚠️ VideoPlayer: Could not unregister from Registry (widget already disposed): $e');
    }

    _isDisposed = true;

    // Prune per-video static maps to prevent unbounded growth over long sessions.
    final videoId = widget.video.id;
    _recoveryAttemptsPerVideo.remove(videoId);
    _lastHardReinit.remove(videoId);
    // _brokenVideoIds entries are intentionally kept for the session duration
    // so the feed skips permanently broken videos; remove them only on retry.

    _disposeVideoController();

    super.dispose();
  }

  void _startFirstFrameWatchdog() {
    _firstFrameWatchdog?.cancel();
    // ✅ TIKTOK-STYLE: Check after 600ms if audio is playing but no frames
    _firstFrameWatchdog =
        Timer(const Duration(milliseconds: 600), _handleFirstFrameTimeout);
  }

  // ✅ TIKTOK-STYLE: Force remount texture for stuck texture recovery
  void _forceRemountTexture() {
    if (!mounted) return;
    setState(() => _textureRebuildTick++);
  }

  void _clearPosterAfterFrameIfPlaying({
    required VideoPlayerController controller,
    required String reason,
  }) {
    if (!_thumbnailVisible || !mounted || _isDisposed) return;

    try {
      final value = controller.value;
      final hasFrameDimensions = value.size.width > 0 && value.size.height > 0;
      final playbackStarted = value.isPlaying || value.position > Duration.zero;
      if (!value.isInitialized || value.hasError) return;
      if (!hasFrameDimensions || !playbackStarted) return;
    } catch (_) {
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
      _firstFrameWatchdog?.cancel();
      _firstFrameWatchdog = null;
      log('✅ VideoPlayer: Poster cleared for ${widget.video.id} ($reason)');
    });
  }

  bool _canTriggerRecovery() {
    final now = DateTime.now();
    if (_lastRecoveryAt != null &&
        now.difference(_lastRecoveryAt!) < _recoveryCooldown) {
      log('⏳ VideoPlayer: Recovery throttled for ${widget.video.id}');
      return false;
    }
    _lastRecoveryAt = now;
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
    final c = _videoPlayerController;
    if (c == null || _isDisposed || !_isInitialized || !mounted) {
      log('🚫 VideoPlayer: First frame watchdog timeout but conditions not met (controller: ${c != null}, disposed: $_isDisposed, initialized: $_isInitialized, mounted: $mounted)');
      return;
    }

    // 🔒 GUARD: Only run for current video
    if (!widget.isCurrentVideo) {
      log('🚫 VideoPlayer: First frame watchdog timeout but video not current: ${widget.video.id}');
      return;
    }

    VideoPlayerValue v;
    try {
      v = c.value;
    } catch (e) {
      log('⚠️ VideoPlayer: Error accessing controller value in watchdog: $e');
      return;
    }

    // 🔒 GUARD: Only trigger if audio is playing
    final playing = v.isPlaying;
    final positionAdvancing = v.position > Duration.zero;

    if (!playing && !positionAdvancing) {
      log('🚫 VideoPlayer: First frame watchdog timeout but not playing: ${widget.video.id}');
      return;
    }

    // 🔒 GUARD: Only trigger if we haven't seen first frame
    if (_hasSeenFirstFrame) {
      log('✅ VideoPlayer: First frame watchdog timeout but frame already detected: ${widget.video.id}');
      return;
    }

    // ✅ BLACK SCREEN DETECTED
    final controllerHashCode = c.hashCode;
    final timeSinceStart = _playbackStartTime != null
        ? DateTime.now().difference(_playbackStartTime!).inMilliseconds
        : null;

    log('🚨 VideoPlayer: BLACKSCREEN_DETECTED for ${widget.video.id} (controller: $controllerHashCode, isPlaying: $playing, position: ${v.position.inMilliseconds}ms, size: ${v.size.width}x${v.size.height}${timeSinceStart != null ? ', timeSinceStart: ${timeSinceStart}ms' : ''})');

    // Check cooldown and attempt limits
    final now = DateTime.now();
    if (_lastBlackScreenRecoveryAt != null &&
        now.difference(_lastBlackScreenRecoveryAt!) <
            _blackScreenRecoveryCooldown) {
      log('⏳ VideoPlayer: Black screen recovery throttled (cooldown) for ${widget.video.id}');
      return;
    }

    if (_blackScreenRecoveryAttempts >= _maxRecoveryAttempts) {
      log('🚫 VideoPlayer: RECOVERY_GIVE_UP for ${widget.video.id} (max attempts: $_maxRecoveryAttempts reached)');
      _recoveryAttemptsPerVideo[widget.video.id] = _blackScreenRecoveryAttempts;
      return;
    }

    _blackScreenRecoveryAttempts++;
    _lastBlackScreenRecoveryAt = now;
    _recoveryAttemptsPerVideo[widget.video.id] = _blackScreenRecoveryAttempts;

    log('🔧 VideoPlayer: RECOVERY_ATTEMPT_${_blackScreenRecoveryAttempts} for ${widget.video.id} (controller: $controllerHashCode)');

    // 🔥 TIERED RECOVERY STRATEGY
    if (_blackScreenRecoveryAttempts == 1) {
      // Tier 1: Force widget rebuild (cheap, immediate)
      log('🔧 VideoPlayer: RECOVERY_ATTEMPT_1_REBUILD_WIDGET for ${widget.video.id}');
      _recoverBlackScreenTier1();
    } else if (_blackScreenRecoveryAttempts == 2) {
      // Tier 2: Force texture remount (medium cost)
      log('🔧 VideoPlayer: RECOVERY_ATTEMPT_2_REMOUNT_TEXTURE for ${widget.video.id}');
      _recoverBlackScreenTier2();
    } else {
      // Tier 3: Recreate controller (expensive, last resort)
      log('🔧 VideoPlayer: RECOVERY_ATTEMPT_3_RECREATE_CONTROLLER for ${widget.video.id}');
      _recoverBlackScreenTier3();
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
    log('🔧 VideoPlayer: Tier 1 recovery - forcing widget rebuild for ${widget.video.id}');
    _forceRemountTexture();

    // Also try seeking to current position to kick decoder
    try {
      final v = c.value;
      if (v.isInitialized && v.position > Duration.zero) {
        c.seekTo(v.position).catchError((e) {
          log('⚠️ VideoPlayer: Error seeking in Tier 1 recovery: $e');
        });
      }
    } catch (e) {
      log('⚠️ VideoPlayer: Error accessing controller value in Tier 1 recovery: $e');
    }
  }

  /// 🔥 PRODUCTION-GRADE: Tier 2 Recovery - Force texture remount
  /// Increments texture rebuild tick multiple times to force texture reattachment
  void _recoverBlackScreenTier2() {
    if (!mounted || _isDisposed) return;

    final c = _videoPlayerController;
    if (c == null || !_canUseController(c)) return;

    log('🔧 VideoPlayer: Tier 2 recovery - forcing texture remount for ${widget.video.id}');

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
              log('⚠️ VideoPlayer: Error requesting focus after Tier 2 recovery: $e');
            });
          });
        }).catchError((e) {
          log('⚠️ VideoPlayer: Error pausing in Tier 2 recovery: $e');
        });
      }
    } catch (e) {
      log('⚠️ VideoPlayer: Error accessing controller value in Tier 2 recovery: $e');
    }
  }

  /// 🔥 PRODUCTION-GRADE: Tier 3 Recovery - Recreate controller
  /// Fully dispose and recreate the controller (expensive, last resort)
  ///
  /// **CRITICAL:** Does NOT dispose controller directly - marks it for disposal
  /// and lets widget.dispose() handle actual disposal to prevent race conditions
  void _recoverBlackScreenTier3() {
    if (!mounted || _isDisposed) return;

    log('🔧 VideoPlayer: Tier 3 recovery - recreating controller for ${widget.video.id}');

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
      } catch (_) {}

      // Mark controller for replacement (don't dispose yet)
      _videoPlayerController = null;
      _currentControllerInstance = null;
      _controllerVersion++;

      // Unregister from playback manager (this is safe)
      try {
        GlobalPlaybackManager.instance.unregisterController(widget.video.id);
      } catch (_) {}

      log('🔧 VideoPlayer: Tier 3 recovery - marked old controller for replacement (will be disposed in widget.dispose())');
    }

    // Reinitialize video with fresh controller
    if (mounted && !_isDisposed) {
      _isInitialized = false;
      _hasSeenFirstFrame = false;
      _firstFrameRenderedAt = null;
      _playbackStartTime = null;

      // Clear recovery state for fresh start
      _blackScreenRecoveryAttempts = 0;
      _lastBlackScreenRecoveryAt = null;

      // Reinitialize - this will create a new controller
      _initializeVideo(isRetry: true).catchError((e) {
        log('⚠️ VideoPlayer: Error reinitializing in Tier 3 recovery: $e');
      });
    }
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
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if ((nowMs - _lastLoopRefreshMs) > 1000) {
          _lastLoopRefreshMs = nowMs;
          debugPrint(
              '🔁 Stall check: Video stuck past end, forcing seek for ${widget.video.id}');
          controller.seekTo(Duration.zero).catchError((e) {
            debugPrint('❌ Stall check seek failed: $e');
          });
          _lastPlaybackPosition = Duration.zero;
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
      log('⚠️ VideoPlayer: Stall check ${_consecutiveStallChecks}/$_stallCheckThreshold for ${widget.video.id} (position: ${value.position.inSeconds}s, last: ${_lastPlaybackPosition.inSeconds}s)');
    }

    _lastPlaybackPosition = value.position;

    // 🔥 FIX: Only trigger recovery after multiple consecutive stall checks
    // This prevents false positives after many playbacks
    if (_consecutiveStallChecks >= _stallCheckThreshold &&
        !_stuckRecoveryAttempted) {
      if (!_canHardReinit(widget.video.id)) {
        log('⛔ VideoPlayer: Hard reinit blocked (cooldown) for ${widget.video.id}');
        _consecutiveStallChecks = 0; // Reset counter if blocked
        return;
      }
      _markHardReinit(widget.video.id);
      if (!_canTriggerRecovery()) {
        _consecutiveStallChecks = 0; // Reset counter if recovery throttled
        return;
      }
      log('🧊 VideoPlayer: Stall confirmed (${_consecutiveStallChecks} checks), reinitializing ${widget.video.id}');
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
      _playbackGeneration++;
      log('🔄 VideoPlayer: Generation incremented to $_playbackGeneration (isCurrent: ${widget.isCurrentVideo})');

      // Reset error state when becoming current (fresh start)
      if (widget.isCurrentVideo) {
        _playbackError = null;
        _showErrorAfterDelay = false;
        _isUnplayable = false;
      }
    }

    // If video changed, reset state
    if (oldWidget.video.id != widget.video.id) {
      _playbackGeneration++;
      _playbackError = null;
      _showErrorAfterDelay = false;
      _isUnplayable = false;
      _isCaptionExpanded = false;
      _taggedUsersFuture = _fetchTaggedUsers(widget.video.id);
      _initializeCommentCountListener();
      GlobalPlaybackManager.instance.clearDesiredFocus(oldWidget.video.id);
    }

    if (oldWidget.video.videoURL != widget.video.videoURL) {
      _isDisposed = false;
      _initializeVideo();
      return;
    }

    if (_registry.isControllerDisposed(widget.video.id)) {
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
        log('VVIEW init-start id=${widget.video.id} (no pool, creating)');
        log('🔄 VideoPlayer: No pooled controller found, initializing new one: ${widget.video.id}');
        _isDisposed = false; // Reset disposed flag to allow initialization
        _initializeVideo();
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
        log('⚠️ VideoPlayer: Controller became invalid during didUpdateWidget: ${widget.video.id}');
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
        log('VVIEW current=TRUE id=${widget.video.id} controller=$controllerSource');

        final videoIdChanged = oldWidget.video.id != widget.video.id;
        if (videoIdChanged || !oldWidget.isCurrentVideo) {
          _hasRequestedFocus = false;
          _lastRequestedVideoId = null;
          log('🔄 VideoPlayer: Reset focus flag (isCurrentVideo: false -> true, videoId: ${oldWidget.video.id} -> ${widget.video.id})');
        }

        // 🚀 ENHANCED ALGORITHM: Reset tracking flags when video becomes current
        _hasTrackedWatch = false;
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
              _resumeService.onPageLeave(
                widget.video.id,
                controllerValue.position,
                controllerValue.duration,
              );
            }
          } catch (_) {}
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
      log('🔄 VideoPlayer: Video ID changed while current (${oldWidget.video.id} -> ${widget.video.id}), resetting focus flag');
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
        log('🔄 VideoPlayer: Video is current but doesn\'t have focus, attempting to regain: ${widget.video.id}');
        _activateCurrentVideo('didUpdateWidget: fallback regain focus');
      }
    }
  }

  // Removed: didChangeAppLifecycleState
  // TikTok-style: GlobalPlaybackManager + NavigationObserver handle lifecycle globally
  // This prevents video from pausing when opening modals (CommentsView, ShareSheet, etc.)

  Future<void> _initializeVideo({bool isRetry = false}) async {
    if (_isInitializing) return;

    _isInitializing = true;
    log('VVIEW init-start id=${widget.video.id}');

    // 🔥 TIKTOK-STYLE: Capture generation at start
    final currentGen = _playbackGeneration;

    // 🔥 TIKTOK-STYLE: Check if video is in quarantine
    if (_brokenVideoIds.contains(widget.video.id)) {
      log('🚫 VideoPlayer: Video ${widget.video.id} is quarantined, skipping initialization');
      _isUnplayable = true;
      _playbackError = 'Video unavailable';
      _isInitializing = false;
      _handleUnplayableVideo('quarantined', {});
      return;
    }

    // Start performance tracking
    PerformanceService().startVideoLoad(widget.video.id);

    try {
      // 🔥 PRODUCTION-GRADE: Capture controller version at start of async operation
      final initVersion = _controllerVersion;

      // 🔥 TIKTOK-STYLE: Abort if generation changed (user swiped away)
      if (currentGen != _playbackGeneration) {
        log('🔄 VideoPlayer: Generation changed, aborting initialization (was $currentGen, now $_playbackGeneration)');
        _isInitializing = false;
        return;
      }

      // 🔥 PRODUCTION-GRADE: Abort if controller version changed (controller was swapped/disposed)
      if (initVersion != _controllerVersion) {
        log('🔄 VideoPlayer: Controller version changed during init, aborting (was $initVersion, now $_controllerVersion)');
        _isInitializing = false;
        return;
      }

      _registry.resetDisposed(widget.video.id);
      _stuckRecoveryAttempted = false;
      _consecutiveStallChecks =
          0; // 🔥 FIX: Reset stall counter on initialization

      // 🔥 INSTANT PLAYBACK: Mark controller as initializing (prevents premature focus requests)
      GlobalPlaybackManager.instance
          .markControllerInitializing(widget.video.id);

      // 🔥 TIKTOK-STYLE: Use Health Gate - don't create controller until we have playable URL
      // 🔥 FIX: Use fallback URL immediately (non-blocking) - don't wait for Firestore
      // This prevents freezes during video transitions
      final healthResult = await VideoHealthGate.instance.resolvePlayableSource(
        widget.video.id,
        cachedData: null, // Skip Firestore fetch - use fallback URL immediately
        fallbackUrl:
            widget.video.videoURL.isNotEmpty ? widget.video.videoURL : null,
      );

      // 🔥 PRODUCTION-GRADE: Abort if generation or controller version changed
      if (currentGen != _playbackGeneration ||
          initVersion != _controllerVersion) {
        log('🔄 VideoPlayer: Generation or controller version changed during health check, aborting (gen: $currentGen -> $_playbackGeneration, ver: $initVersion -> $_controllerVersion)');
        _isInitializing = false;
        return;
      }

      if (healthResult is Unplayable) {
        log('🚫 VideoPlayer: Video ${widget.video.id} is unplayable: ${healthResult.reason}');
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

      final playable = healthResult as Playable;
      _isUnplayable = false;

      final url = playable.url;
      _playbackError = null;
      _showErrorAfterDelay = false;

      log('✅ VideoPlayer: Health gate passed, using ${playable.quality} URL for ${widget.video.id}');

      // ✅ Stability: avoid controller churn when URL hasn't changed.
      // Recreating controllers can trigger Android surface issues ("audio-only").
      if (!isRetry &&
          _videoPlayerController != null &&
          _isInitialized &&
          !_isDisposed &&
          _canUseController(_videoPlayerController) &&
          _lastResolvedUrl == url) {
        log('✅ VideoPlayer: Reusing existing controller for ${widget.video.id} (same URL, no retry)');
        if (widget.isCurrentVideo && mounted) {
          _activateCurrentVideo('_initializeVideo: reuse existing controller');
        }
        return;
      }

      // 🔥 PRODUCTION-GRADE: If we have existing controller with different URL, pause it but don't dispose
      // Only dispose in widget.dispose() to prevent lifecycle violations
      if (_videoPlayerController != null) {
        final oldController = _videoPlayerController;
        final oldHashCode = oldController?.hashCode;
        log('🔄 VideoPlayer: Replacing controller $oldHashCode with new controller for ${widget.video.id}');

        // Detach listeners from old controller
        try {
          if (oldController != null && _canUseController(oldController)) {
            oldController.removeListener(_videoErrorListener);
            oldController.removeListener(_videoStateListener);
            oldController.removeListener(_videoPositionListener);
            oldController.removeListener(_onControllerChanged);
            log('🔌 VideoPlayer: Detached all listeners from old controller $oldHashCode');
          }
        } catch (e) {
          log('⚠️ VideoPlayer: Error detaching listeners from old controller: $e');
        }

        try {
          await oldController!.pause();
          await oldController.setVolume(0.0);
        } catch (_) {}
        // Mark old controller for disposal later (will be disposed in widget.dispose())
        _videoPlayerController = null;
        _currentControllerInstance = null;
        _isInitialized = false;
        _isPlaying = false;
        _controllerVersion++;
        log('📌 VideoPlayer: Controller version incremented to $_controllerVersion (old controller $oldHashCode)');
        // Release focus safely: only unregister if PlaybackManager still holds THIS controller.
        try {
          final playbackController =
              GlobalPlaybackManager.instance.getController(widget.video.id);
          if (playbackController != null &&
              oldController != null &&
              identical(playbackController, oldController)) {
            GlobalPlaybackManager.instance
                .unregisterController(widget.video.id);
          }
        } catch (_) {}
      }
      _isDisposed = false;

      debugPrint(
          '🎥 Getting controller from manager for ${widget.video.id} url=$url quality=${playable.quality}');
      final playbackManager = GlobalPlaybackManager.instance;
      final controllerFromManager = await playbackManager.getOrCreateController(
        widget.video.id,
        url,
        owner: _ownerKey,
      );
      if (controllerFromManager == null) {
        log('🚫 VideoPlayer: getOrCreateController returned null: ${widget.video.id}');
        _isUnplayable = true;
        _playbackError = 'Failed to get or create controller';
        _isInitializing = false;
        _handleUnplayableVideo(
            'get_or_create_failed', {'videoId': widget.video.id});
        return;
      }
      if (currentGen != _playbackGeneration ||
          initVersion != _controllerVersion) {
        log('🔄 VideoPlayer: Generation/version changed during getOrCreateController, aborting');
        _isInitializing = false;
        return;
      }
      if (_isDisposed || !mounted) {
        _isInitializing = false;
        return;
      }
      _videoPlayerController = controllerFromManager;
      _currentControllerInstance = controllerFromManager;
      _videoPlayerController!.addListener(_onControllerChanged);
      try {
        _isInitialized = controllerFromManager.value.isInitialized &&
            !controllerFromManager.value.hasError;
        _isPlaying = controllerFromManager.value.isPlaying;
      } catch (_) {
        _isInitialized = false;
        _isPlaying = false;
      }
      if (mounted) setState(() {});
      _videoRetryCount = 0;
      _playbackError = null;
      _showErrorAfterDelay = false;
      _lastResolvedUrl = url;
      await _videoPlayerController!.setLooping(true);
      final isBlocked = playbackManager.isPlaybackBlocked;
      await _videoPlayerController!.setVolume(0.0);
      if (isBlocked) await _videoPlayerController!.pause();
      if (_canUseController(controllerFromManager)) {
        controllerFromManager.addListener(_videoErrorListener);
        controllerFromManager.addListener(_videoStateListener);
        controllerFromManager.addListener(_videoPositionListener);
      }
      if (_isDisposed || !mounted) {
        _isInitializing = false;
        return;
      }
      _startLoopCheckTimer();
      playbackManager.markControllerAttached(
          widget.video.id, controllerFromManager.hashCode);
      _registry.register(widget.video.id, controllerFromManager);
      _wasRegistered = true;
      _registry.markVisible(widget.video.id);
      _hasRequestedFocus = false;
      _isInitialized = true;
      _logger.debug('Video initialized successfully: ${widget.video.id}',
          tag: 'VideoPlayer');

      // 🚀 INSTANT PLAYBACK: Auto-play immediately if this is the current video
      // ✅ FIX: Removed duplicate _safePlay() call - activate() handles playback
      // This prevents the video from starting then restarting
      if (widget.isCurrentVideo && mounted && !_isDisposed) {
        debugPrint(
            '🎯 VideoPlayer: Auto-playing current video INSTANTLY - videoId: ${widget.video.id}');
        // 🔥 INSTANT PLAYBACK: Use consistent GlobalPlaybackManager instance
        // 🔥 FIX: Use same instance throughout (don't mix instance and provider)
        final playbackManager = GlobalPlaybackManager.instance;

        // 🔥 INSTANT PLAYBACK: Ensure active owner is set before checking canPlay
        // If no active owner, set it to the video's owner for instant playback
        if (playbackManager.activeOwner == null) {
          log('🔧 VideoPlayer: No active owner set, setting to $_ownerKey for instant playback');
          playbackManager.setActiveOwner(_ownerKey);
        }

        log('🔍 DEBUG: PlaybackManager state - activeOwner: ${playbackManager.activeOwner}, isPlaybackBlocked: ${playbackManager.isPlaybackBlocked}, canPlay($_ownerKey): ${playbackManager.canPlay(_ownerKey)}');

        _activateCurrentVideo(
          '_initializeVideo: controller initialized and current',
        );

        if (mounted && !_isDisposed) {
          setState(() => _isPlaying = true); // reflect pending playback in UI
          widget.onVideoPlaySuccess
              ?.call(); // Reset consecutive-failure counter
        }

        // Apply audio enhancement while staying muted; GPM will unmute/play
        if (playbackManager.canPlay(_ownerKey)) {
          _applyAudioEnhancement();
        } else {
          debugPrint(
              '🚫 VideoPlayer: Owner $_ownerKey cannot play, skipping activation: ${widget.video.id}');
        }

        _startFirstFrameWatchdog();
        _startStallWatchdog();

        // Check resume position in background and seek if needed (non-blocking)
        _resumeService.onPageEnter(widget.video.id).then((targetPosition) {
          if (targetPosition != null &&
              targetPosition > Duration.zero &&
              mounted &&
              _videoPlayerController != null &&
              _isInitialized) {
            try {
              // 🔥 CRITICAL FIX: Check controller is still valid before seeking
              final seekController = _videoPlayerController;
              if (seekController != null &&
                  !_isDisposed &&
                  !_isDisposingController &&
                  _canUseController(seekController)) {
                seekController.seekTo(targetPosition).then((_) {
                  log('▶️ VideoResume: Auto-resumed from ${targetPosition.inSeconds}s for ${widget.video.id}');
                }).catchError((e) {
                  log('⚠️ VideoResume: Error seeking: $e');
                });
              }
            } catch (e) {
              log('⚠️ VideoResume: Error seeking: $e');
            }
          }
        }).catchError((e) {
          log('⚠️ VideoResume: Error getting resume position: $e');
        });
      }
    } on TimeoutException catch (_) {
      _logger.error('Error initializing video: ${widget.video.id}',
          tag: 'VideoPlayer', error: 'Initialization timeout');
      _playbackError =
          'Video took too long to load. Check connection and retry.';
      if (mounted && !_isDisposed) {
        _handleVideoError(_playbackError!);
      }
      // 🔥 PRODUCTION-GRADE: Don't dispose here - just pause/mute and null reference
      // Disposal only happens in widget.dispose()
      if (_videoPlayerController != null) {
        try {
          await _videoPlayerController!.pause();
          await _videoPlayerController!.setVolume(0.0);
        } catch (_) {}
        _videoPlayerController = null;
        _currentControllerInstance = null;
        _isInitialized = false;
        _isPlaying = false;
        _controllerVersion++;
      }
    } catch (e) {
      _logger.error('Error initializing video: ${widget.video.id}',
          tag: 'VideoPlayer', error: e);

      final errorString = e.toString().toLowerCase();
      final isNetworkError = errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('timeout') ||
          errorString.contains('socket') ||
          errorString.contains('failed host lookup');

      // 🔥 PRIORITY 1: Detect OutOfMemoryError and MediaCodec errors
      final isOutOfMemoryError = errorString.contains('outofmemory') ||
          errorString.contains('out of memory') ||
          errorString.contains('no_memory') ||
          (errorString.contains('memory') &&
              errorString.contains('allocation')) ||
          (errorString.contains('mediacodec') &&
              errorString.contains('bufferinfo')) ||
          errorString.contains('illegalstateexception');

      // Check for format-related errors
      final isFormatError = errorString.contains('format') ||
          errorString.contains('unsupported') ||
          errorString.contains('codec') ||
          errorString.contains('mime type') ||
          errorString.contains('not supported') ||
          errorString.contains('unable to instantiate decoder');

      // 🔥 PRIORITY 1: Handle OOM errors gracefully
      if (isOutOfMemoryError) {
        log('⚠️ VideoPlayer: OutOfMemoryError detected - device memory too low for video playback');
        _playbackError =
            'Device memory too low for video playback. Try closing other apps.';
        if (mounted && !_isDisposed) {
          _handleVideoError(_playbackError!);
        }
        // 🔥 FINAL FIX: Don't dispose here - just pause/mute and null reference
        // Disposal only happens in widget.dispose() to prevent lifecycle violations
        if (_videoPlayerController != null) {
          try {
            await _videoPlayerController!.pause();
            await _videoPlayerController!.setVolume(0.0);
          } catch (_) {}
          _videoPlayerController = null;
        }
        _videoRetryCount = 0;
        // Don't retry on OOM - it will just fail again
        return;
      }

      // 🔥 TIKTOK-STYLE: Format errors = quarantine (session-local)
      if (isFormatError) {
        log('🚫 VideoPlayer: Format error detected, quarantining video ${widget.video.id}');
        _brokenVideoIds.add(widget.video.id);
        _isUnplayable = true;

        // Log for backend
        VideoHealthGate.instance.logUnplayableVideo(
          widget.video.id,
          'format_not_supported',
          {'error': e.toString(), 'errorString': errorString},
        );

        _handleUnplayableVideo('format_not_supported', {'error': e.toString()});
        // 🔥 FINAL FIX: Don't dispose here - just pause/mute and null reference
        // Disposal only happens in widget.dispose() to prevent lifecycle violations
        if (_videoPlayerController != null) {
          try {
            await _videoPlayerController!.pause();
            await _videoPlayerController!.setVolume(0.0);
          } catch (_) {}
          _videoPlayerController = null;
          _currentControllerInstance = null;
          _controllerVersion++; // Increment version
        }
        _videoRetryCount = 0;
        return; // Don't retry format errors
      }

      // 🔥 REMOVED: Old URL refresh logic - health gate handles this now

      if (isNetworkError &&
          _videoRetryCount < _maxVideoRetries &&
          mounted &&
          !_isDisposed) {
        _videoRetryCount++;
        final retryDelay = Duration(
          seconds: _videoRetryDelay.inSeconds * _videoRetryCount,
        );

        if (kDebugMode) {
          debugPrint(
            '🔄 VideoPlayer: Network error detected, retrying (${_videoRetryCount}/$_maxVideoRetries) after ${retryDelay.inSeconds}s',
          );
        }

        // 🔥 FINAL FIX: Don't dispose here - just pause/mute and null reference
        // Disposal only happens in widget.dispose() to prevent lifecycle violations
        if (_videoPlayerController != null) {
          try {
            await _videoPlayerController!.pause();
            await _videoPlayerController!.setVolume(0.0);
          } catch (_) {}
          _videoPlayerController = null;
        }

        Future.delayed(retryDelay, () {
          if (mounted && !_isDisposed) {
            _initializeVideo(isRetry: true);
          }
        });
      } else {
        // 🔥 REMOVED: URL refresh logic - health gate handles this

        _playbackError = _getUserFriendlyErrorMessage(e);
        _showErrorAfterDelay = true;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted &&
              !_isDisposed &&
              widget.isCurrentVideo &&
              _showErrorAfterDelay) {
            _handleVideoError(_playbackError!);
          }
        });
        _videoRetryCount = 0;
        // 🔥 FINAL FIX: Don't dispose here - just pause/mute and null reference
        // Disposal only happens in widget.dispose() to prevent lifecycle violations
        if (_videoPlayerController != null) {
          try {
            await _videoPlayerController!.pause();
            await _videoPlayerController!.setVolume(0.0);
          } catch (_) {}
          _videoPlayerController = null;
        }
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Apply TikTok-style audio enhancement to the current video
  /// 🔥 FIX: Added safety checks to prevent "Bad state: No active player" errors
  Future<void> _applyAudioEnhancement() async {
    try {
      // 🔥 FIX: Validate controller is safe before applying enhancement
      if (_videoPlayerController == null || !_isInitialized || _isDisposed) {
        log('⚠️ VideoPlayer: Cannot apply audio enhancement - controller not ready');
        return;
      }

      // 🔥 FIX: Check if controller is safe to use
      if (!_canUseController(_videoPlayerController)) {
        log('⚠️ VideoPlayer: Controller not safe for audio enhancement: ${widget.video.id}');
        return;
      }

      // Initialize audio enhancement service
      final audioEnhancement = AudioEnhancementService();
      await audioEnhancement.initialize();

      // Apply audio enhancement to the video player
      await audioEnhancement.enhanceVideoPlayer(_videoPlayerController!);

      log('🔊 AudioEnhancementService: Applied TikTok-style audio enhancement to video: ${widget.video.id}');
    } catch (e, stackTrace) {
      log('❌ AudioEnhancementService: Error applying audio enhancement: $e');
      log('Stack trace: $stackTrace');
      // Don't fail video playback if audio enhancement fails
    }
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
      } catch (_) {}
      return;
    }

    try {
      final controllerValue = _videoPlayerController!.value;
      if (controllerValue.hasError) {
        final error = controllerValue.errorDescription ?? 'Unknown video error';
        log('❌ Video player error: $error');

        // 🔥 PRIORITY 1: Check for OOM errors in video player error stream
        final errorString = error.toString().toLowerCase();
        final isOutOfMemoryError = errorString.contains('outofmemory') ||
            errorString.contains('out of memory') ||
            errorString.contains('no_memory') ||
            (errorString.contains('memory') &&
                errorString.contains('allocation'));

        if (isOutOfMemoryError) {
          log('⚠️ VideoPlayer: OutOfMemoryError in video player error stream');
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
      log('⚠️ VideoPlayer: Controller disposed during error listener: $e');
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

  // 🔥 FIX: Dedicated position listener for aggressive loop handling
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
      } catch (_) {}
      return;
    }

    try {
      final controllerValue = _videoPlayerController!.value;
      if (!controllerValue.isInitialized) return;

      final duration = controllerValue.duration;
      final position = controllerValue.position;
      final isPlaying = controllerValue.isPlaying;

      // 🔥 FIX: Reset stall counter if position is advancing (successful playback)
      if (isPlaying && position > _lastPlaybackPosition) {
        final positionDiff = (position - _lastPlaybackPosition).inMilliseconds;
        if (positionDiff >= 50) {
          // Only reset if meaningful advancement
          _consecutiveStallChecks = 0;
        }
      }

      // Let native looping handle the loop - only intervene if clearly stuck
      // Native setLooping(true) should handle seamless looping without black screens
      if (duration > Duration.zero && isPlaying) {
        // Only seek if video is clearly stuck way past the end (native loop failed)
        if (position > duration + const Duration(milliseconds: 500)) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if ((nowMs - _lastLoopRefreshMs) > 1000) {
            _lastLoopRefreshMs = nowMs;
            debugPrint(
                '🔁 Position listener: Video stuck past end, forcing seek for ${widget.video.id}');
            // 🔥 CRITICAL FIX: Check controller is still valid before seeking
            final seekController = _videoPlayerController;
            if (seekController != null &&
                !_isDisposed &&
                !_isDisposingController) {
              seekController.seekTo(Duration.zero).catchError((e) {
                log('⚠️ VideoPlayer: Error forcing seek on loop: $e');
              });
              _lastPlaybackPosition = Duration.zero;
            }
          }
          return;
        }
      }
    } catch (e) {
      log('⚠️ VideoPlayer: Error in position listener: $e');
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
      } catch (_) {}
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
          setState(() {
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
            log('✅ VideoPlayer: First frame rendered for ${widget.video.id} (controller: ${controller.hashCode}, size: ${value.size.width}x${value.size.height}${timeToFirstFrame != null ? ', timeToFirstFrame: ${timeToFirstFrame}ms' : ''})');
          } else if (positionAdvancing && !hasValidSize) {
            // Position advancing but no size yet - log but don't mark as first frame
            // This helps identify "audio but no video" cases
            log('⚠️ VideoPlayer: Position advancing but no video size yet for ${widget.video.id} (position: ${value.position.inMilliseconds}ms, size: ${value.size.width}x${value.size.height})');
          }
        }
      }
    } catch (_) {
      // Controller might be disposed - ignore
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
      if (duration > Duration.zero &&
          position > duration + const Duration(milliseconds: 500) &&
          isPlaying &&
          !_isDisposed &&
          _isInitialized) {
        // Only seek if native looping clearly failed (position way past end)
        // 🔥 CRITICAL FIX: Check controller is still valid before seeking
        final seekController = _videoPlayerController;
        if (seekController != null &&
            !_isDisposingController &&
            _canUseController(seekController)) {
          seekController.seekTo(Duration.zero).catchError((e) {
            log('⚠️ VideoPlayer: Error seeking to start on loop: $e');
          });
          _lastPlaybackPosition = Duration.zero;
        }
        return;
      }

      if (isPlaying != _isPlaying && mounted) {
        final currentController = _videoPlayerController;
        if (!identical(controller, currentController)) return;

        _logger.debug(
            'Video state changed - isPlaying: $isPlaying, _isPlaying: $_isPlaying',
            tag: 'VideoPlayer');

        if (isPlaying && !_isPlaying) {
          _consecutiveStallChecks = 0;
          _stuckRecoveryAttempted = false;
          log('✅ VideoPlayer: Playback started successfully, reset stall counter for ${widget.video.id}');
          // Keep a very short fallback fade in case first-frame detection lags,
          // but do not hold the poster long enough to make the feed look frozen.
          if (_thumbnailVisible) {
            _posterTimer?.cancel();
            _posterTimer = Timer(const Duration(milliseconds: 150), () {
              if (!mounted || _isDisposed) return;
              setState(() => _thumbnailVisible = false);
            });
          }
        }

        if (!isPlaying) {
          _posterTimer?.cancel();
          _posterTimer = null;
        }

        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!identical(_videoPlayerController, controller)) return;
            setState(() {
              _isPlaying = isPlaying;
            });
          });
        }
      }
    } catch (e) {
      log('⚠️ VideoPlayer: Controller disposed during state listener: $e');
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
      if (!value.isPlaying) return;

      final duration = value.duration;
      final position = value.position;

      if (duration <= Duration.zero) return;

      // Only intervene when clearly past end (native loop failed)
      if (position < duration) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if ((nowMs - _lastLoopRefreshMs) < 1000) return;
      _lastLoopRefreshMs = nowMs;

      if (!_canUseController(controller)) return;
      debugPrint(
          '🔁 Loop timer: Video past end, forcing seek for ${widget.video.id}');
      controller.seekTo(Duration.zero).then((_) {
        _lastPlaybackPosition = Duration.zero;
      }).catchError((e) {
        debugPrint('❌ Loop timer force seek failed: $e');
      });
    });
  }

  void _handleVideoError(dynamic error) {
    if (kDebugMode) {
      debugPrint('🎥 Video Error (Handled): $error');
    }

    if (!mounted || _isDisposed) return;

    if (!widget.isCurrentVideo || _isInitializing) {
      log('⚠️ VideoPlayer: Suppressing error display - video not current or initializing: ${widget.video.id}');
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

    log('🚫 VideoPlayer: Handling unplayable video ${widget.video.id}: $reason');

    setState(() {
      _isUnplayable = true;
      _playbackError = 'Video unavailable';
    });

    // 🔥 TIKTOK-STYLE: Auto-skip broken videos after 8s (spec: max 8s before auto-skip)
    if (widget.isCurrentVideo && widget.onVideoUnplayable != null) {
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && widget.isCurrentVideo && _isUnplayable) {
          log('⏭️ VideoPlayer: Auto-skipping unplayable video ${widget.video.id}');
          FeedTelemetryService().logVideoAutoSkipped(
            videoId: widget.video.id,
            reason: reason,
          );
          widget.onVideoUnplayable!();
        }
      });
    }
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
                      log('⏭️ VideoPlayer: User manually skipped unplayable video ${widget.video.id}');
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
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('402') ||
        errorString.contains('invalidresponsecode') ||
        errorString.contains('payment required')) {
      return 'Video unavailable. Storage limit exceeded.';
    }
    if (errorString.contains('unrecognizedinputformat') ||
        errorString.contains('could read the stream') ||
        errorString.contains('extractor')) {
      return 'Video format not supported.';
    }
    if (errorString.contains('outofmemory') ||
        errorString.contains('out of memory') ||
        errorString.contains('no_memory') ||
        (errorString.contains('memory') &&
            errorString.contains('allocation')) ||
        errorString.contains('mediacodec') &&
            errorString.contains('bufferinfo') ||
        errorString.contains('illegalstateexception')) {
      return 'Device memory too low for video playback. Video resolution may be too high for this device.';
    }
    if (errorString.contains('timeout')) {
      return 'Video took too long to load';
    }
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection issue';
    }
    if (errorString.contains('format') || errorString.contains('codec')) {
      return 'Video format not supported';
    }
    if (errorString.contains('permission')) {
      return 'Permission denied';
    }
    return 'Unable to play video';
  }

  Future<void> _togglePlayPause() async {
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

    log('🎮 _togglePlayPause controller=${c != null} ready=$_controllerReady playing=${c?.value.isPlaying ?? false}');

    if (c == null || !_controllerReady) {
      log('❌ Cannot toggle: controller missing or not ready');
      return;
    }

    if (_isDisposed) return;

    try {
      final _ = c.value;
    } catch (e) {
      log('❌ VideoPlayer: Controller disposed in _togglePlayPause: $e');
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

  void _handleLikeChanged() async {
    // Sync the parent state with the enhanced service
    try {
      // Use the new sync method to get the correct state from the service
      await widget.homeViewModel.setVideoLikeStateFromService(widget.video.id);

      // Force a rebuild to ensure UI updates immediately
      setState(() {
        // The EnhancedLikeButton will handle its own state updates
        // This ensures the parent widget also updates
      });
    } catch (e) {
      // Fallback to simple toggle if enhanced service fails
      if (widget.homeViewModel.updateVideoLikeState != null) {
        widget.homeViewModel.updateVideoLikeState!(widget.video.id);
      }
      setState(() {});
    }
  }

  Future<void> _handleFavoriteChanged() async {
    final UnifiedBookmarkService bookmarkService =
        UnifiedBookmarkService.instance;
    if (bookmarkService.hasPendingOperation(widget.video.id)) {
      return;
    }
    try {
      final BookmarkResult result =
          await bookmarkService.toggleBookmark(widget.video.id);

      if (result.success) {
        if (mounted) {
          setState(() {
            _isBookmarked = result.isBookmarked!;
          });
        }
        debugPrint(
            '✅ VideoPlayerView: Bookmark toggled for video ${widget.video.id}: $_isBookmarked');
      } else {
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Revert bookmark state on error
        _isBookmarked = bookmarkService.isBookmarked(widget.video.id);
        setState(() {});
      }
    } catch (e) {
      // Show user-friendly error message
      if (mounted) {
        String errorMessage = 'Failed to update bookmark';
        if (e.toString().contains('Video not found')) {
          errorMessage = 'Video no longer available in feed';
        } else if (e.toString().contains('PERMISSION_DENIED')) {
          errorMessage = 'Unable to save bookmark - check connection';
        } else {
          errorMessage = 'Failed to update bookmark';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Revert bookmark state on error
      _isBookmarked =
          UnifiedBookmarkService.instance.isBookmarked(widget.video.id);
      if (mounted) {
        setState(() {});
      }

      // Log error for debugging
      log('❌ Error toggling bookmark for video ${widget.video.id}: $e');
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

  void _handleProfileTap() {
    // Handle profile/avatar tap - open StreamerCardView for other users
    HapticFeedback.lightImpact();
    log('👤 VideoPlayer: Opening StreamerCard for ${widget.video.creator.username}');

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
      currentUserId: currentUserId,
      onDismiss: () {
        Navigator.of(context).pop();
        restoreAfterStreamerCard('streamer_card_dismissed');
        log('👤 VideoPlayer: Returned from StreamerCard, restoring playback');
      },
    ).then((_) {
      // Also unblock when back button is used (fallback)
      restoreAfterStreamerCard('streamer_card_back');
      log('👤 VideoPlayer: Back from StreamerCard (via back button)');
    });
  }

  void _navigateToTaggedUserProfile(String userId) {
    HapticFeedback.lightImpact();
    log('👤 VideoPlayer: Opening StreamerCard for tagged user: $userId');

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
        log('👤 VideoPlayer: Returned from tagged user profile, restoring playback');
      },
    ).then((_) {
      restoreAfterTaggedProfile('tagged_profile_back');
      log('👤 VideoPlayer: Back from tagged user profile (via back button)');
    });
  }

  void _handleComment() {
    if (widget.onShowComments != null) {
      widget.onShowComments!();
      return;
    }

    HapticFeedback.lightImpact();

    showModalBottomSheet<void>(
      context: context,
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

  void _handleBookmark() {
    if (UnifiedBookmarkService.instance.hasPendingOperation(widget.video.id)) {
      return;
    }
    HapticFeedback.lightImpact();
    _handleFavoriteChanged();
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

  void _handleFollowTap(WidgetRef ref, FollowButtonState currentState) async {
    // Follow button tapped - use NetworkView Connections logic
    HapticFeedback.lightImpact();

    final auth = ref.read(robustAuthServiceProvider);
    final viewerId = auth.currentUser?.id;

    if (viewerId == null) {
      log('⚠️ VideoPlayer: Cannot follow - user not authenticated');
      return;
    }

    final followService = ref.read(followButtonServiceProvider);

    // Track engagement
    EngagementAnalyticsService().trackEngagement(
      videoId: widget.video.id,
      event: currentState == FollowButtonState.following
          ? EngagementEvent.unfollow
          : EngagementEvent.follow,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
        'creatorId': widget.video.creator.id,
        'previousState': currentState.buttonText,
      },
    );

    // Handle based on current state
    bool success = false;
    switch (currentState) {
      case FollowButtonState.follow:
        // Follow the user
        success = await followService.followUser(
          viewerId: viewerId,
          creatorId: widget.video.creator.id,
        );
        if (success) {
          log('✅ VideoPlayer: Successfully followed ${widget.video.creator.username}');
          // Trigger UI rebuild
          if (mounted) setState(() {});
        }
        break;

      case FollowButtonState.following:
        // Unfollow the user
        success = await followService.unfollowUser(
          viewerId: viewerId,
          creatorId: widget.video.creator.id,
        );
        if (success) {
          log('✅ VideoPlayer: Successfully unfollowed ${widget.video.creator.username}');
          // Trigger UI rebuild
          if (mounted) setState(() {});
        }
        break;

      case FollowButtonState.connected:
        // Show options menu (Message, Unfollow, Report)
        log('👥 VideoPlayer: Connected user tapped - showing options');
        // TODO: Show bottom sheet with options
        break;

      case FollowButtonState.self:
        // No action for self
        break;
    }

    if (!success &&
        currentState != FollowButtonState.connected &&
        currentState != FollowButtonState.self) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to ${currentState == FollowButtonState.following ? 'unfollow' : 'follow'}. Please try again.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // _handleMockFollow removed - now using FollowButtonService with real Firestore

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

  void _handleDoubleTap(Offset position) async {
    debugPrint(
        '💖💖 DOUBLE TAP DETECTED at position: $position for video ${widget.video.id}');

    // Double tap anywhere on video to like (never unlikes - TikTok behavior)
    HapticFeedback.mediumImpact();

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ DOUBLE TAP: No user logged in');
      return;
    }

    debugPrint('🔄 DOUBLE TAP: Calling doubleTapLike service...');

    // Use StreamersTipLikeService for idempotent double-tap like
    final service = StreamersTipLikeService();
    final shouldAnimate = await service.doubleTapLike(widget.video.id, userId);

    debugPrint('🎬 DOUBLE TAP: Service returned shouldAnimate: $shouldAnimate');

    // Only show animation if the like was successful (not already liked)
    if (shouldAnimate) {
      debugPrint('✨ DOUBLE TAP: Creating floating heart animation');
      _createHeartAnimation(position);
    } else {
      debugPrint('⏭️ DOUBLE TAP: Skipping animation (already liked)');
    }
  }

  void _createHeartAnimation(Offset position) {
    // Create floating heart animation for double-tap
    debugPrint('💖 Heart animation triggered at position: $position');

    // Create a floating heart overlay
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _FloatingHeartOverlay(
        position: position,
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

    return Consumer(
      builder: (context, ref, child) {
        // Video playback is now managed by the PlaybackCoordinator block/unblock system
        // No need for manual pause/resume logic here

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
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

              if (widget.showHUD) _buildPremiumFeedScrim(),

              // DEBUG: show video id when in debug mode to aid identification
              if (kDebugMode)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.video.id,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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

  Widget _buildVideoPlayer() {
    // ✅ FIX BLACK SCREEN: Build must be pure - no state mutation inside build()
    // Controller adoption is now handled in initState() and didUpdateWidget()

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
      } catch (_) {}
    }

    VideoPlayerValue v;
    try {
      v = controller.value;
    } catch (_) {
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
    final String playerKey = _enableSurfaceWatchdogRecreate
        ? 'VideoPlayer:${widget.video.id}:${controller.hashCode}:$_surfaceEpoch'
        : 'VideoPlayer:${widget.video.id}:${controller.hashCode}';

    final videoAspectRatio = width / height;
    final useContainedStage = _shouldUseContainedStage(videoAspectRatio);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (useContainedStage) _buildContainedBackdrop(),
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
                        child: _buildThumbnailPoster(
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
        if (useContainedStage) _buildContainedStageScrim(),
      ],
    );
  }

  bool _shouldUseContainedStage(double videoAspectRatio) {
    const double targetVerticalAspectRatio = 9 / 16;
    const double verticalTolerance = 0.09;

    if (videoAspectRatio <= 0) return false;
    return (videoAspectRatio - targetVerticalAspectRatio).abs() >
        verticalTolerance;
  }

  Widget _buildContainedBackdrop() {
    final url = _resolveThumbnailUrl(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            placeholder: (_, __) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                const Color(0xFF0B071D).withValues(alpha: 0.78),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContainedStageScrim() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.95,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.16),
              Colors.black.withValues(alpha: 0.34),
            ],
            stops: const [0.58, 0.82, 1.0],
          ),
        ),
      ),
    );
  }

  String? _resolveThumbnailUrl(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final containerWidth = mediaQuery?.size.width ?? 393;
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final fallbackUrl = _buildMuxFallbackThumbnailUrl();

    final optimizedUrl = _thumbnailService.getDisplayReadyThumbnailUrl(
      thumbnails: widget.video.thumbnails,
      containerWidth: containerWidth,
      devicePixelRatio: devicePixelRatio,
      fallbackUrl: widget.video.thumbnailURL ?? fallbackUrl,
    );

    if (optimizedUrl != null && optimizedUrl.isNotEmpty) {
      return optimizedUrl;
    }

    final thumbnailUrl = widget.video.thumbnailURL;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) return thumbnailUrl;
    return fallbackUrl;
  }

  String? _buildMuxFallbackThumbnailUrl() {
    final videoUrl = widget.video.videoURL;
    if (videoUrl.contains('stream.mux.com')) {
      final uri = Uri.tryParse(videoUrl);
      if (uri != null) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final playbackId = segments.first.replaceAll('.m3u8', '');
          if (playbackId.isNotEmpty) {
            return 'https://image.mux.com/$playbackId/thumbnail.jpg?time=0';
          }
        }
      }
    }
    return null;
  }

  Widget _buildThumbnailPoster({BoxFit fit = BoxFit.cover}) {
    final url = _resolveThumbnailUrl(context);
    if (url == null) return const ColoredBox(color: Colors.black);
    final mediaQuery = MediaQuery.maybeOf(context);
    final containerWidth = mediaQuery?.size.width ?? 393;
    final containerHeight = mediaQuery?.size.height ?? 852;
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: (containerWidth * devicePixelRatio).round(),
      memCacheHeight: (containerHeight * devicePixelRatio).round(),
      filterQuality: FilterQuality.high,
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      placeholder: (_, __) => const ColoredBox(color: Colors.black),
    );
  }

  /// Cinematic bottom scrim: improves caption contrast + brand tint.
  Widget _buildPremiumFeedScrim() {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: AppColors.homeFeedBottomScrimStops,
              colors: AppColors.homeFeedBottomScrim,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUIOverlay() {
    final media = MediaQuery.of(context);
    final railMetrics = _ActionRailMetrics.of(context);
    final safeBottom = media.viewPadding.bottom;

    // Constants - TikTok-style spacing
    final leftInset = railMetrics.leftInset;
    final rightInset = railMetrics.metadataRightInset;
    final bottomNavHeight = railMetrics.bottomNavHeight;
    final bottomNavMargin = railMetrics.bottomNavMargin;
    final paddingAboveNav = railMetrics.metadataPaddingAboveNav;

    // Different positioning for each view type:
    // - HomeView: Perfect as is (standard TikTok positioning)
    // - ProfileView: Move down a little more
    // - DiscoverView: At the very bottom
    final isCategoryFeed = widget.tabId.startsWith('discoverView_');
    final isProfileView =
        widget.tabId.startsWith('profile_') || widget.tabId == 'playerScreen';

    double bottomPosition;
    if (isCategoryFeed) {
      // DiscoverView: At the very bottom - use minimal spacing
      bottomPosition = safeBottom + 20.0; // Just safe area + 20px
    } else if (isProfileView) {
      // ProfileView: At the very bottom (matches DiscoverView)
      bottomPosition = safeBottom + 20.0; // Just safe area + 20px
    } else {
      bottomPosition =
          safeBottom + bottomNavHeight + bottomNavMargin + paddingAboveNav;
    }

    return Positioned(
      left: leftInset,
      right: rightInset,
      bottom: bottomPosition,
      child: Container(
        constraints: BoxConstraints(
          maxHeight:
              media.size.height * 0.25, // Use maxHeight instead of fixed height
        ),
        padding: EdgeInsets.all(railMetrics.metadataPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Creator row: avatar + username + follow pill
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onShowProfile ?? () => _handleProfileTap(),
                  child: _buildUserAvatar(),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: widget.onShowProfile ?? () => _handleProfileTap(),
                    child: Text(
                      '@${widget.video.creator.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.2,
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
                const SizedBox(width: 8),
                // Follow pill next to username - uses NetworkView Connections logic
                Consumer(
                  builder: (context, ref, child) {
                    final auth = ref.watch(robustAuthServiceProvider);
                    final viewerId = auth.currentUser?.id;

                    if (viewerId == null) {
                      return const SizedBox.shrink(); // Hide if not logged in
                    }

                    return FutureBuilder<FollowButtonState>(
                      future:
                          ref.read(followButtonServiceProvider).getButtonState(
                                viewerId: viewerId,
                                creatorId: widget.video.creator.id,
                              ),
                      builder: (context, snapshot) {
                        final state = snapshot.data ?? FollowButtonState.follow;

                        // Hide button for self
                        if (state == FollowButtonState.self) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        return GestureDetector(
                          onTap: state.isTappable
                              ? () => _handleFollowTap(ref, state)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: state.showGradient
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF955CFF),
                                        Color(0xFF3D99F7)
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                  : null,
                              color: state == FollowButtonState.following
                                  ? Colors.grey[600]
                                  : (state == FollowButtonState.connected
                                      ? const Color(0xFF9248D2)
                                      : null),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              state.buttonText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildExpandableCaption(),
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

  Widget _buildExpandableCaption() {
    final caption = widget.video.caption.trim();
    if (caption.isEmpty) {
      return const SizedBox.shrink();
    }

    const captionStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.2,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: const TextSpan(),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        textPainter.text = TextSpan(text: caption, style: captionStyle);
        textPainter.layout(maxWidth: constraints.maxWidth);
        final hasOverflow = textPainter.didExceedMaxLines;

        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                caption,
                maxLines: _isCaptionExpanded ? null : 2,
                overflow: _isCaptionExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: captionStyle,
              ),
              if (hasOverflow) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    if (!mounted) return;
                    setState(() {
                      _isCaptionExpanded = !_isCaptionExpanded;
                    });
                  },
                  child: Text(
                    _isCaptionExpanded ? 'less' : 'more',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
      log('❌ Error fetching tagged users: $e', name: 'VideoPlayerView');
      return [];
    }
  }

  Widget _buildActionButtons() {
    final media = MediaQuery.of(context);
    final railMetrics = _ActionRailMetrics.of(context);

    // Calculate position - TikTok-style spacing above bottom navigation
    final rightInset = railMetrics.rightInset;
    final bottomNavHeight = railMetrics.bottomNavHeight;
    final bottomNavMargin = railMetrics.bottomNavMargin;
    final paddingAboveNav = railMetrics.railPaddingAboveNav;
    final safeBottom = media.viewPadding.bottom;

    // Different positioning for each view type:
    // - HomeView: Perfect as is (standard TikTok positioning)
    // - ProfileView: Move down a little more
    // - DiscoverView: At the very bottom
    final isCategoryFeed = widget.tabId.startsWith('discoverView_');
    final isProfileView =
        widget.tabId.startsWith('profile_') || widget.tabId == 'playerScreen';
    double bottom;
    if (isCategoryFeed) {
      bottom = safeBottom + 20.0;
    } else if (isProfileView) {
      bottom = safeBottom + 20.0;
    } else {
      bottom = safeBottom + bottomNavHeight + bottomNavMargin + paddingAboveNav;
    }

    return Positioned(
      bottom: bottom,
      right: rightInset,
      child: GestureDetector(
        // Let children handle taps; still prevent hit-testing from falling through
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enhanced Like button with animations
            EnhancedLikeButton(
              videoId: widget.video.id,
              initialLikeCount: widget.video.likes,
              initialIsLiked: widget.isLiked,
              onLikeChanged: _handleLikeChanged,
              iconKey: _likeButtonKey,
              source: 'button',
              width: railMetrics.likeWidth,
              height: railMetrics.likeHeight,
              iconSize: railMetrics.likeIconSize,
              labelFontSize: railMetrics.likeLabelFontSize,
              labelGap: railMetrics.labelGap,
              sparkleSize: railMetrics.sparkleSize,
            ),
            SizedBox(height: railMetrics.itemGap),

            // Comment button with real-time count
            _buildActionButton(
              icon: Icons.chat_bubble_outline,
              count: _formatCompactCount(_commentCount),
              onTap: _handleComment,
              metrics: railMetrics,
            ),
            SizedBox(height: railMetrics.itemGap),

            _buildActionButton(
              icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              count: _formatCompactCount(_favoriteCount),
              onTap: _bookmarkService.hasPendingOperation(widget.video.id)
                  ? null
                  : _handleBookmark,
              isActive: _isBookmarked,
              isLoading: false,
              metrics: railMetrics,
            ),
            SizedBox(height: railMetrics.itemGap),

            // Share button
            _buildActionButton(
              icon: Icons.share,
              count:
                  _shareCount > 0 ? _formatCompactCount(_shareCount) : 'Share',
              onTap: _handleShare,
              metrics: railMetrics,
            ),
            SizedBox(height: railMetrics.avatarGap),

            _buildTrailingRailButton(railMetrics.avatarSize),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingRailButton(double size) {
    final commandSnapshot = ref.watch(creatorCommandSnapshotProvider);
    final bool showCommandCenterTrigger =
        widget.showCommandCenterTrigger && widget.tabId == 'home/forYou';
    final bool showAlertPulse =
        commandSnapshot.valueOrNull?.alertCount != null &&
            (commandSnapshot.valueOrNull!.alertCount > 0 ||
                commandSnapshot.valueOrNull!.pendingWorkCount > 0);

    if (showCommandCenterTrigger) {
      return StreamersTipCommandCenterTrigger(
        size: size,
        showAlertPulse: showAlertPulse,
        onTap: widget.onCommandCenterTap ?? () {},
      );
    }

    return GestureDetector(
      onTap: widget.onShowProfile ?? () => _handleProfileTap(),
      child: _buildActionAvatar(size: size),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback? onTap,
    bool isActive = false,
    bool isLoading = false,
    required _ActionRailMetrics metrics,
  }) {
    final btnSize = metrics.buttonSize;
    final bool isShareAction = count == 'Share';
    final Color labelColor = isActive
        ? AppColors.textPrimary.withValues(alpha: 0.98)
        : Colors.white.withValues(alpha: 0.92);

    return SizedBox(
      width: btnSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: btnSize,
            height: btnSize,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap != null
                    ? () {
                        HapticFeedback.lightImpact();
                        onTap();
                      }
                    : null,
                borderRadius: BorderRadius.circular(btnSize / 2),
                child: Center(
                  child: Container(
                    width: btnSize - 4,
                    height: btnSize - 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.2),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isLoading
                          ? SizedBox(
                              width: metrics.progressSize,
                              height: metrics.progressSize,
                              child: CircularProgressIndicator(
                                strokeWidth: metrics.progressStrokeWidth,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isActive
                                      ? AppColors.primary
                                      : Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : Icon(
                              icon,
                              color: isActive
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.96),
                              size: isShareAction
                                  ? metrics.shareIconSize
                                  : metrics.iconSize,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: metrics.labelGap),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.16),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              count,
              key: ValueKey<String>(
                  '${icon.codePoint}-$count-$isActive-$isLoading'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: isShareAction
                    ? metrics.shareLabelFontSize
                    : metrics.labelFontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactCount(int value) {
    if (value <= 0) return '0';
    if (value < 1000) return value.toString();

    String formatWithSuffix(double compactValue, String suffix) {
      final hasDecimal = compactValue < 10;
      final text = hasDecimal
          ? compactValue.toStringAsFixed(1)
          : compactValue.toStringAsFixed(0);
      return '${text.replaceFirst(RegExp(r'\.0$'), '')}$suffix';
    }

    if (value < 1000000) {
      return formatWithSuffix(value / 1000, 'K');
    }

    return formatWithSuffix(value / 1000000, 'M');
  }

  Widget _buildUserAvatar() {
    final avatarUrl = widget.video.creator.avatarURL;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildDefaultAvatar();
    }

    return CachedNetworkImage(
      imageUrl: avatarUrl,
      width: 32,
      height: 32,
      imageBuilder: (context, imageProvider) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
      placeholder: (context, url) => _buildDefaultAvatar(),
      errorWidget: (context, url, error) {
        log('❌ Avatar load error for ${widget.video.creator.username}: $error');
        return _buildDefaultAvatar();
      },
    );
  }

  Widget _buildActionAvatar({double size = 40}) {
    final avatarUrl = widget.video.creator.avatarURL;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildDefaultActionAvatar(size: size);
    }

    return CachedNetworkImage(
      imageUrl: avatarUrl,
      width: size,
      height: size,
      imageBuilder: (context, imageProvider) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.65),
            width: 1.6,
          ),
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
      placeholder: (context, url) => _buildDefaultActionAvatar(size: size),
      errorWidget: (context, url, error) {
        log('❌ Action avatar load error for ${widget.video.creator.username}: $error');
        return _buildDefaultActionAvatar(size: size);
      },
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFFF6CAB),
            Color(0xFF8E54E9),
            Color(0xFF3D99F7),
            Color(0xFFFF6CAB),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildDefaultActionAvatar({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFFF6CAB),
            Color(0xFF8E54E9),
            Color(0xFF3D99F7),
            Color(0xFFFF6CAB),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

class _ActionRailMetrics {
  const _ActionRailMetrics({
    required this.leftInset,
    required this.rightInset,
    required this.metadataRightInset,
    required this.bottomNavHeight,
    required this.bottomNavMargin,
    required this.metadataPaddingAboveNav,
    required this.railPaddingAboveNav,
    required this.metadataPadding,
    required this.buttonSize,
    required this.iconSize,
    required this.shareIconSize,
    required this.labelFontSize,
    required this.shareLabelFontSize,
    required this.likeWidth,
    required this.likeHeight,
    required this.likeIconSize,
    required this.likeLabelFontSize,
    required this.labelGap,
    required this.itemGap,
    required this.avatarGap,
    required this.avatarSize,
    required this.sparkleSize,
    required this.progressSize,
    required this.progressStrokeWidth,
  });

  final double leftInset;
  final double rightInset;
  final double metadataRightInset;
  final double bottomNavHeight;
  final double bottomNavMargin;
  final double metadataPaddingAboveNav;
  final double railPaddingAboveNav;
  final double metadataPadding;
  final double buttonSize;
  final double iconSize;
  final double shareIconSize;
  final double labelFontSize;
  final double shareLabelFontSize;
  final double likeWidth;
  final double likeHeight;
  final double likeIconSize;
  final double likeLabelFontSize;
  final double labelGap;
  final double itemGap;
  final double avatarGap;
  final double avatarSize;
  final double sparkleSize;
  final double progressSize;
  final double progressStrokeWidth;

  static _ActionRailMetrics of(BuildContext context) {
    final responsive = context.responsive;
    final width = MediaQuery.sizeOf(context).width;
    final compact = responsive.isCompactPhone || width < 360;
    final small = responsive.isSmallPhone || width < 390;
    final rightInset = compact ? 8.0 : (small ? 10.0 : 12.0);
    final buttonSize = compact ? 46.0 : (small ? 50.0 : 54.0);
    final likeWidth = compact ? 52.0 : (small ? 56.0 : 60.0);

    return _ActionRailMetrics(
      leftInset: responsive.spacing(compact ? 10 : 12),
      rightInset: rightInset,
      metadataRightInset: rightInset + likeWidth + (compact ? 10.0 : 14.0),
      bottomNavHeight: compact ? 76.0 : (small ? 80.0 : 84.0),
      bottomNavMargin: compact ? 6.0 : 8.0,
      metadataPaddingAboveNav: compact ? 28.0 : (small ? 34.0 : 40.0),
      railPaddingAboveNav: compact ? 64.0 : (small ? 70.0 : 76.0),
      metadataPadding: responsive.spacing(compact ? 12 : 16),
      buttonSize: buttonSize,
      iconSize: compact ? 25.0 : (small ? 27.0 : 29.0),
      shareIconSize: compact ? 23.0 : (small ? 25.0 : 27.0),
      labelFontSize: compact ? 10.0 : 11.0,
      shareLabelFontSize: compact ? 9.0 : 10.0,
      likeWidth: likeWidth,
      likeHeight: compact ? 76.0 : (small ? 84.0 : 90.0),
      likeIconSize: compact ? 29.0 : (small ? 31.0 : 33.0),
      likeLabelFontSize: compact ? 10.5 : 11.5,
      labelGap: compact ? 3.0 : 4.0,
      itemGap: compact ? 3.0 : 5.0,
      avatarGap: compact ? 7.0 : 9.0,
      avatarSize: compact ? 34.0 : (small ? 37.0 : 40.0),
      sparkleSize: compact ? 66.0 : (small ? 72.0 : 78.0),
      progressSize: compact ? 16.0 : 18.0,
      progressStrokeWidth: compact ? 2.0 : 2.2,
    );
  }
}

class _FloatingHeartOverlay extends StatefulWidget {
  final Offset position;

  const _FloatingHeartOverlay({required this.position});

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

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
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
