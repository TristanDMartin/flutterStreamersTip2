import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
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
import '../services/share_service_optimized.dart';
import '../widgets/enhanced_like_button.dart';
import '../widgets/double_tap_gesture_detector.dart';
import '../widgets/share_sheet_view.dart';
import '../services/streamers_tip_like_service.dart';
import '../services/video_controller_registry.dart';
import '../services/production_logging_service.dart';
import '../services/audio_enhancement_service.dart';
import '../services/global_playback_manager.dart';
import '../widgets/comments_view2.dart';
import '../widgets/streamer_card_view.dart';
import '../services/follow_button_service.dart';
import '../services/unified_algorithm_service.dart';
import '../services/unified_bookmark_service.dart';

// DEPRECATED: GlobalVideoController replaced by UnifiedVideoControlService
// This class is kept for backward compatibility but delegates to UnifiedVideoControlService

class VideoPlayerViewOptimized extends ConsumerStatefulWidget {
  final HomeVideo video;
  final bool isCurrentVideo;
  final bool isFirstVideo;
  final String tabId; // Track which tab this video belongs to
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

  VideoPlayerViewOptimized({
    super.key,
    required this.video,
    required this.isCurrentVideo,
    required this.isFirstVideo,
    required this.tabId,
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
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasIncrementedView = false;
  bool _isBookmarkLoading = false; // Prevent multiple rapid taps
  bool _showPlayPauseIndicatorOverlay =
      false; // Show play/pause indicator animation
  bool _audioUnmuted =
      false; // Track if audio has been unmuted by user interaction
  bool _isDisposed = false; // Track if this widget's controller is disposed
  bool _isBookmarked =
      false; // Local bookmark state that syncs with FavoritesService

  // Production-ready controller management
  final VideoControllerRegistry _registry = VideoControllerRegistry();
  final ProductionLoggingService _logger = ProductionLoggingService();
  late UnifiedBookmarkService _bookmarkService;

  // Stream subscription for bookmark state changes
  StreamSubscription<BookmarkEvent>? _bookmarkSubscription;

  // 🚀 VIRAL ALGORITHM: Watch time tracking
  Timer? _watchTimeTracker;
  double _lastReportedWatchPercentage = 0.0;
  bool _hasWatchedOnce = false; // Track if this is a replay

  /// 🚀 VIRAL ALGORITHM: Start watch time tracking (optimized frequency)
  void _startWatchTimeTracking() {
    _watchTimeTracker?.cancel();
    _watchTimeTracker = Timer.periodic(const Duration(seconds: 3), (_) {
      _trackWatchProgress();
    });
    log('🎯 Watch time tracking started for video ${widget.video.id}');
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

    // Initialize current state
    _isBookmarked = _bookmarkService.isBookmarked(widget.video.id);

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

    debugPrint(
        '📚 VideoPlayerView: Initialized bookmark state for video ${widget.video.id}: $_isBookmarked');
  }

  // 🚀 VIRAL ALGORITHM: Track watch progress
  void _trackWatchProgress() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return;
    }

    final position = _videoPlayerController!.value.position;
    final duration = _videoPlayerController!.value.duration;

    if (duration.inSeconds == 0) return;

    final watchPercentage = (position.inSeconds / duration.inSeconds) * 100;

    // Report every 10% milestone
    if ((watchPercentage - _lastReportedWatchPercentage).abs() >= 10.0 ||
        watchPercentage >= 95.0) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final didComplete = watchPercentage >= 75.0;

      // Check if this is a replay
      final isReplay = _hasWatchedOnce && watchPercentage < 25.0;
      if (didComplete) _hasWatchedOnce = true;

      log('🎯 Watch progress: ${widget.video.id} - ${watchPercentage.toStringAsFixed(1)}% (isReplay: $isReplay, didComplete: $didComplete)');

      // Track engagement with unified algorithm
      UnifiedAlgorithmService.instance.trackEngagement(
        videoId: widget.video.id,
        creatorId: widget.video.creator.id,
        userId: currentUser.uid,
        watchPercentage: watchPercentage,
        totalDuration: duration.inSeconds.toDouble(),
        isReplay: isReplay,
        didComplete: didComplete,
      );

      _lastReportedWatchPercentage = watchPercentage;
    }
  }

  /// Safe controller operations with comprehensive error handling
  Future<bool> _safeSetVolume(double volume) async {
    if (_videoPlayerController == null || _isDisposed) {
      debugPrint(
          '❌ VideoPlayer: Cannot set volume - controller is null or disposed');
      _logger.warn('Cannot set volume: controller is null or disposed',
          tag: 'VideoPlayer');
      return false;
    }

    try {
      if (_registry.isSafe(widget.video.id)) {
        debugPrint(
            '🔊 VideoPlayer: Setting volume to $volume for videoId: ${widget.video.id}');
        await _videoPlayerController!.setVolume(volume);
        debugPrint(
            '✅ VideoPlayer: Volume set to $volume successfully for videoId: ${widget.video.id}');
        _logger.debug('Volume set to $volume for ${widget.video.id}',
            tag: 'VideoPlayer');
        return true;
      } else {
        debugPrint(
            '❌ VideoPlayer: Cannot set volume - controller not safe for videoId: ${widget.video.id}');
        _logger.warn(
            'Controller not safe for volume operation: ${widget.video.id}',
            tag: 'VideoPlayer');
        return false;
      }
    } catch (e) {
      debugPrint('❌ VideoPlayer: Error setting volume: $e');
      _logger.error('Error setting volume to $volume',
          tag: 'VideoPlayer', error: e);
      return false;
    }
  }

  Future<bool> _safePlay() async {
    if (_videoPlayerController == null || _isDisposed) {
      debugPrint('❌ VideoPlayer: Cannot play - controller is null or disposed');
      _logger.warn('Cannot play: controller is null or disposed',
          tag: 'VideoPlayer');
      return false;
    }

    try {
      // TEMPORARY FIX: Bypass safety check to restore functionality
      debugPrint(
          '▶️ VideoPlayer: Starting playback for videoId: ${widget.video.id}');

      // Ensure volume is preserved when resuming playback
      if (_audioUnmuted && _videoPlayerController!.value.volume == 0.0) {
        debugPrint('🔊 VideoPlayer: Restoring volume to 1.0 before play');
        await _videoPlayerController!.setVolume(1.0);
      }

      await _videoPlayerController!.play();

      // 🚀 VIRAL ALGORITHM: Start tracking watch time when video plays
      _startWatchTimeTracking();

      debugPrint(
          '✅ VideoPlayer: Playback started successfully for videoId: ${widget.video.id}');
      _logger.debug('Video playing: ${widget.video.id}', tag: 'VideoPlayer');
      return true;
    } catch (e) {
      debugPrint('❌ VideoPlayer: Error playing video: $e');
      _logger.error('Error playing video', tag: 'VideoPlayer', error: e);
      return false;
    }
  }

  Future<bool> _safePause() async {
    // AGGRESSIVE DEBUG: Track who is calling pause
    debugPrint('⚠️⚠️ _safePause() CALLED for video ${widget.video.id}');
    debugPrint('   Stack trace: ${StackTrace.current}');

    if (_videoPlayerController == null || _isDisposed) {
      _logger.warn('Cannot pause: controller is null or disposed',
          tag: 'VideoPlayer');
      return false;
    }

    try {
      // TEMPORARY FIX: Bypass safety check to restore functionality
      await _videoPlayerController!.pause();

      // 🚀 VIRAL ALGORITHM: Stop tracking when video pauses
      _stopWatchTimeTracking();

      _logger.debug('Video paused: ${widget.video.id}', tag: 'VideoPlayer');
      return true;
    } catch (e) {
      _logger.error('Error pausing video', tag: 'VideoPlayer', error: e);
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
    // Removed WidgetsBinding observer - GlobalPlaybackManager handles lifecycle
    // WidgetsBinding.instance.addObserver(this);

    // Initialize bookmark state from FavoritesService
    _initializeBookmarkState();

    // TIKTOK-STYLE: Initialize video immediately for instant playback
    _initializeVideo();
  }

  @override
  void dispose() {
    // Removed WidgetsBinding observer - GlobalPlaybackManager handles lifecycle
    // WidgetsBinding.instance.removeObserver(this);

    // 🔖 MEMORY LEAK FIX: Clean up bookmark subscription
    _bookmarkSubscription?.cancel();
    _bookmarkSubscription = null;

    // 🚀 VIRAL ALGORITHM: Stop watch time tracking
    _stopWatchTimeTracking();

    // Track performance
    PerformanceService()
        .trackVideoPlayback(widget.video.id, PlaybackEvent.pause);

    // Unregister from global playback manager (safe to call even if widget is disposed)
    try {
      final playbackManager = GlobalPlaybackManager.instance;
      playbackManager.unregisterController(widget.video.id);
      log('🎵 VideoPlayer: Unregistered controller from PlaybackManager for video ${widget.video.id}');
    } catch (e) {
      log('⚠️ VideoPlayer: Could not unregister from PlaybackManager (widget already disposed): $e');
    }

    // 🔒 SAFETY: Unregister from VideoControllerRegistry
    try {
      _registry.markHidden(widget.video.id);
      _registry.dispose(widget.video.id);
      log('🔒 VideoPlayer: Unregistered controller from Registry for video ${widget.video.id}');
    } catch (e) {
      log('⚠️ VideoPlayer: Could not unregister from Registry (widget already disposed): $e');
    }

    // Controllers now unregistered from GlobalPlaybackManager only

    // 🔒 SAFETY: Mark as disposed first to prevent listener callbacks
    _isDisposed = true;

    // With AutomaticKeepAliveClientMixin and preloader, we don't dispose controllers here
    // The VideoPreloaderService manages controller lifecycle
    if (_videoPlayerController != null) {
      try {
        // Check if controller is still valid before pausing
        final controllerValue = _videoPlayerController!.value;
        if (controllerValue.isInitialized && !controllerValue.hasError) {
          _videoPlayerController!.removeListener(_videoErrorListener);
          _videoPlayerController!.removeListener(_videoStateListener);
          _videoPlayerController!.pause(); // Pause but don't dispose
          _videoPlayerController!.setVolume(0.0); // Mute but don't dispose
        }
        // Don't dispose - let VideoPreloaderService handle it
        log('🔄 Widget dispose: Paused controller for ${widget.video.id} (managed by preloader)');
      } catch (e) {
        log('⚠️ Widget dispose: Error pausing controller: $e');
      } finally {
        // Don't set _videoPlayerController = null - keep reference for preloader
        // _isDisposed is already set to true above
      }
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerViewOptimized oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_videoPlayerController == null || !_isInitialized || _isDisposed)
      return;

    // Check if we should pause all videos (when leaving HomeView)
    final homeState = ref.read(homeProvider);
    if (homeState.shouldPauseAllVideos) {
      // IMMEDIATE pause - stops audio instantly
      _safePause().then((_) {
        log('⏸️ Video paused due to HomeView navigation: ${widget.video.id}');
        // Update UI state after build completes (prevents setState error)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        });
      });
      return;
    }

    // SIMPLE: React when the page becomes current/non-current
    if (oldWidget.isCurrentVideo != widget.isCurrentVideo) {
      if (widget.isCurrentVideo) {
        // 🔊 AUDIO FIX: Request focus from GlobalPlaybackManager
        GlobalPlaybackManager.instance
            .requestFocus(widget.video.id, widget.tabId);
        log('🎵 VideoPlayer: Requested focus for current video: ${widget.video.id}');

        // This video is now current - play it with TikTok-style audio enhancement
        _applyAudioEnhancement().then((_) async {
          await _safeSetVolume(1.0);
          setState(() => _audioUnmuted = true);

          await _safePlay();
          setState(() => _isPlaying = true);

          log('🔊 Video became current and is now playing with enhanced audio: ${widget.video.id}');
          debugPrint(
              '🔊 Video became current and is now playing with enhanced audio: ${widget.video.id}');
        });
      } else {
        // Video is no longer current - just pause (GlobalPlaybackManager handles focus)

        // This video is no longer current - pause it immediately
        _safePause().then((_) {
          _safeSetVolume(0.0); // Mute audio immediately
        });
        setState(() => _isPlaying = false);

        log('⏸️ Video no longer current, paused: ${widget.video.id}');
        debugPrint('⏸️ Video no longer current, paused: ${widget.video.id}');
      }
    }

    // 🔊 AUDIO FIX: Ensure focus if this video is current
    if (widget.isCurrentVideo) {
      final playbackManager = GlobalPlaybackManager.instance;
      if (playbackManager.activeVideoId != widget.video.id) {
        log('🎵 VideoPlayer: Current video doesn\'t have focus, requesting it: ${widget.video.id}');
        playbackManager.requestFocus(widget.video.id, widget.tabId);
      }
    }
  }

  // Removed: didChangeAppLifecycleState
  // TikTok-style: GlobalPlaybackManager + NavigationObserver handle lifecycle globally
  // This prevents video from pausing when opening modals (CommentsView, ShareSheet, etc.)

  Future<void> _initializeVideo() async {
    // Start performance tracking
    PerformanceService().startVideoLoad(widget.video.id);

    try {
      // Create controller directly - registry will handle safety
      _logger.debug('Creating video controller for: ${widget.video.id}',
          tag: 'VideoPlayer');

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoURL),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // 🚀 INSTANT SWITCHING: Aggressive initialization for seamless playback
      await _videoPlayerController!.initialize().timeout(
            const Duration(
                seconds: 12), // Increased timeout for better success rate
            onTimeout: () => throw Exception('Video initialization timeout'),
          );

      // Configure controller
      await _videoPlayerController!.setLooping(true);
      await _videoPlayerController!.setVolume(0.0); // Start muted

      debugPrint(
          '🔊 VideoPlayer: Controller configured - videoId: ${widget.video.id}, initial volume: 0.0, looping: true');
      _logger.debug('Video controller created successfully: ${widget.video.id}',
          tag: 'VideoPlayer');

      // Add listeners
      _videoPlayerController!.addListener(_videoErrorListener);
      _videoPlayerController!.addListener(_videoStateListener);

      // 🔊 AUDIO FIX: Register with GlobalPlaybackManager (single registration)
      GlobalPlaybackManager.instance.registerController(
        widget.video.id,
        _videoPlayerController!,
        owner: widget.tabId,
      );
      log('🎵 VideoPlayer: Registered controller with PlaybackManager for video ${widget.video.id}');

      // 🔒 SAFETY: Register with VideoControllerRegistry for safety checks
      final registrationSuccess =
          _registry.register(widget.video.id, _videoPlayerController!);
      if (registrationSuccess) {
        _registry
            .markVisible(widget.video.id); // Mark as visible for current video
        log('🔒 VideoPlayer: Registered controller with Registry for safety checks: ${widget.video.id}');
      } else {
        log('⚠️ VideoPlayer: Controller registration failed for video ${widget.video.id}');
      }

      _isInitialized = true;
      _logger.debug('Video initialized successfully: ${widget.video.id}',
          tag: 'VideoPlayer');

      // Auto-play if this is the current video
      if (widget.isCurrentVideo) {
        debugPrint(
            '🎯 VideoPlayer: Auto-playing current video - videoId: ${widget.video.id}');

        // 🔊 AUDIO FIX: Use GlobalPlaybackManager exclusively
        final playbackManager = ref.read(globalPlaybackManagerProvider);
        playbackManager.activate(widget.video.id, owner: widget.tabId);

        // Apply audio enhancement and unmute for first video
        _applyAudioEnhancement().then((_) async {
          await _safeSetVolume(1.0);
          setState(() => _audioUnmuted = true);
          debugPrint(
              '🔊 VideoPlayer: Audio unmuted for first video - videoId: ${widget.video.id}');
        });

        await _safePlay();
        debugPrint(
            '🎯 VideoPlayer: Auto-play completed - videoId: ${widget.video.id}');
      }
    } catch (e) {
      _logger.error('Error initializing video: ${widget.video.id}',
          tag: 'VideoPlayer', error: e);
    }
  }

  /// Apply TikTok-style audio enhancement to the current video
  Future<void> _applyAudioEnhancement() async {
    try {
      if (_videoPlayerController == null || !_isInitialized) return;

      // Initialize audio enhancement service
      final audioEnhancement = AudioEnhancementService();
      await audioEnhancement.initialize();

      // Apply audio enhancement to the video player
      await audioEnhancement.enhanceVideoPlayer(_videoPlayerController!);

      log('🔊 AudioEnhancementService: Applied TikTok-style audio enhancement to video: ${widget.video.id}');
    } catch (e) {
      log('❌ AudioEnhancementService: Error applying audio enhancement: $e');
      // Don't fail video playback if audio enhancement fails
    }
  }

  void _videoErrorListener() {
    // 🔒 SAFETY: Check if widget is still mounted and controller is valid
    if (!mounted || _videoPlayerController == null || _isDisposed) {
      return;
    }

    try {
      if (_videoPlayerController?.value.hasError == true) {
        final error = _videoPlayerController?.value.errorDescription ??
            'Unknown video error';
        log('❌ Video player error: $error');
        _handleVideoError(Exception(error));
      }
    } catch (e) {
      // Controller was disposed, remove listener to prevent further calls
      log('⚠️ VideoPlayer: Controller disposed during error listener: $e');
      _videoPlayerController?.removeListener(_videoErrorListener);
    }
  }

  void _videoStateListener() {
    // 🔒 SAFETY: Check if widget is still mounted and controller is valid
    if (!mounted || _videoPlayerController == null || _isDisposed) {
      return;
    }

    try {
      final isPlaying = _videoPlayerController!.value.isPlaying;
      if (isPlaying != _isPlaying) {
        _logger.debug(
            'Video state changed - isPlaying: $isPlaying, _isPlaying: $_isPlaying',
            tag: 'VideoPlayer');
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    } catch (e) {
      // Controller was disposed, remove listener to prevent further calls
      log('⚠️ VideoPlayer: Controller disposed during state listener: $e');
      _videoPlayerController?.removeListener(_videoStateListener);
    }
  }

  void _handleVideoError(dynamic error) {
    // Log error but don't crash the app
    debugPrint('🎥 Video Error (Handled): $error');

    // Show user-friendly error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Video playback error: ${_getUserFriendlyErrorMessage(error)}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              // Retry video initialization
              _initializeVideo();
            },
          ),
        ),
      );
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('timeout')) {
      return 'Video took too long to load';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network connection issue';
    } else if (errorString.contains('format') ||
        errorString.contains('codec')) {
      return 'Video format not supported';
    } else if (errorString.contains('permission')) {
      return 'Permission denied';
    } else {
      return 'Unable to play video';
    }
  }

  Future<void> _togglePlayPause() async {
    print(
        '🎮 _togglePlayPause called - _videoPlayerController: ${_videoPlayerController != null}, _isInitialized: $_isInitialized, _isPlaying: $_isPlaying');
    _logger.debug(
        '_togglePlayPause called - _videoPlayerController: ${_videoPlayerController != null}, _isInitialized: $_isInitialized, _isPlaying: $_isPlaying',
        tag: 'VideoPlayer');

    if (_videoPlayerController == null || !_isInitialized) {
      print(
          '❌ Cannot toggle play/pause - controller: ${_videoPlayerController != null}, initialized: $_isInitialized');
      _logger.warn(
          'Cannot toggle play/pause - controller: ${_videoPlayerController != null}, initialized: $_isInitialized',
          tag: 'VideoPlayer');
      return;
    }

    // Unmute audio on first user interaction with TikTok-style enhancement
    if (!_audioUnmuted) {
      // Apply audio enhancement before unmuting
      await _applyAudioEnhancement();

      // Try multiple approaches to ensure audio works
      await _safeSetVolume(1.0);

      // Wait a moment for the volume change to take effect
      await Future.delayed(const Duration(milliseconds: 100));

      // Try setting volume again to ensure it sticks
      await _safeSetVolume(1.0);

      // Force a restart of playback to ensure audio takes effect
      final wasPlaying = _videoPlayerController!.value.isPlaying;
      if (wasPlaying) {
        await _safePause();
        await Future.delayed(const Duration(milliseconds: 50));
        await _safePlay();
      }

      setState(() {
        _audioUnmuted = true;
      });

      log('🔊 Audio unmuted by user interaction - Volume set to 1.0');
      debugPrint('🔊 Audio unmuted by user interaction - Volume set to 1.0');

      // Verify volume was set correctly
      final currentVolume = _videoPlayerController!.value.volume;
      log('🔊 Current volume after setting: $currentVolume');
      debugPrint('🔊 Current volume after setting: $currentVolume');

      // Check video player state
      final isPlaying = _videoPlayerController!.value.isPlaying;
      final position = _videoPlayerController!.value.position;
      final duration = _videoPlayerController!.value.duration;

      log('🔊 Video state - Playing: $isPlaying, Position: $position, Duration: $duration');
      debugPrint(
          '🔊 Video state - Playing: $isPlaying, Position: $position, Duration: $duration');

      // Note: Video should have audio if it was uploaded with audio
      log('🔊 Audio unmuting completed for video: ${widget.video.id}');
      debugPrint('🔊 Audio unmuting completed for video: ${widget.video.id}');

      // Audio is now auto-unmuted, no need for user feedback
    }

    if (_isPlaying) {
      _logger.debug('Pausing video - current state: $_isPlaying',
          tag: 'VideoPlayer');
      final success = await _safePause();
      _logger.debug('Pause result: $success', tag: 'VideoPlayer');

      setState(() {
        _isPlaying = false;
      });

      // Track playback performance
      PerformanceService()
          .trackVideoPlayback(widget.video.id, PlaybackEvent.pause);
    } else {
      _logger.debug('Playing video - current state: $_isPlaying',
          tag: 'VideoPlayer');
      final success = await _safePlay();
      _logger.debug('Play result: $success', tag: 'VideoPlayer');

      setState(() {
        _isPlaying = true;
      });

      // Track playback performance
      PerformanceService()
          .trackVideoPlayback(widget.video.id, PlaybackEvent.play);

      // Increment view count (only once per video)
      if (!_hasIncrementedView) {
        _hasIncrementedView = true;
        _incrementViewCount();
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
    // Production-ready favorite toggle with unified bookmark service
    if (_isBookmarkLoading) return; // Prevent multiple rapid taps

    setState(() {
      _isBookmarkLoading = true;
    });

    try {
      final bookmarkService = UnifiedBookmarkService.instance;
      final result = await bookmarkService.toggleBookmark(widget.video.id);

      if (result.success) {
        _isBookmarked = result.isBookmarked!;
        setState(() {});

        debugPrint(
            '✅ VideoPlayerView: Bookmark toggled for video ${widget.video.id}: $_isBookmarked');

        // Track analytics
        // AnalyticsService.instance.trackEvent('bookmark_toggled', parameters: {
        //   'video_id': widget.video.id,
        //   'is_favorited': _isBookmarked,
        //   'creator_id': widget.video.creator.id,
        // });
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
      setState(() {});

      // Log error for debugging
      log('❌ Error toggling bookmark for video ${widget.video.id}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBookmarkLoading = false;
        });
      }
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final videoRef = firestore.collection('videos').doc(widget.video.id);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(videoRef);

        if (snapshot.exists) {
          final currentViews = snapshot.data()?['views'] ?? 0;
          transaction.update(videoRef, {
            'views': currentViews + 1,
            'lastViewedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Also update analytics collection
      final analyticsRef =
          firestore.collection('video_analytics').doc(widget.video.id);
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(analyticsRef);

        if (snapshot.exists) {
          final currentViews = snapshot.data()?['views'] ?? 0;
          transaction.update(analyticsRef, {
            'views': currentViews + 1,
            'lastViewedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(analyticsRef, {
            'views': 1,
            'likes': widget.video.likes,
            'shares': 0,
            'comments': widget.video.comments,
            'watchTime': 0.0,
            'engagementRate': 0.0,
            'lastViewedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint("Incremented view count for video: ${widget.video.id}");
    } catch (error) {
      debugPrint("Error incrementing view count: $error");
    }
  }

  void _handleProfileTap() {
    // Handle profile/avatar tap - open StreamerCardView for other users
    HapticFeedback.lightImpact();
    log('👤 VideoPlayer: Opening StreamerCard for ${widget.video.creator.username}');

    // Get current user ID for follow/connection logic
    final auth = ref.read(robustAuthServiceProvider);
    final currentUserId = auth.currentUser?.id;

    // Pause video playback when navigating away
    GlobalPlaybackManager.instance.block(reason: 'streamerCardOpened');

    // Navigate to StreamerCardView (for viewing other users)
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => StreamerCardView(
          userId: widget.video.creator.id,
          currentUserId: currentUserId,
          onDismiss: () {
            // Resume video playback when returning to HomeView
            Navigator.of(context).pop();
            GlobalPlaybackManager.instance.unblock();
            log('👤 VideoPlayer: Returned from StreamerCard, resuming playback');
          },
        ),
        fullscreenDialog: true,
      ),
    )
        .then((_) {
      // Also unblock when back button is used (fallback)
      GlobalPlaybackManager.instance.unblock();
      log('👤 VideoPlayer: Back from StreamerCard (via back button)');
    });
  }

  void _handleComment() {
    // Handle comment button tap - use callback if provided, else use internal
    if (widget.onShowComments != null) {
      widget.onShowComments!();
      return;
    }

    HapticFeedback.lightImpact();

    // Don't pause video when opening comments (TikTok-style)
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
    ).then((_) {
      // When modal closes, ensure video resumes if it was playing
      debugPrint('💬 CommentsView closed - video should continue playing');
      // Don't need to do anything - video should still be playing
    });
  }

  void _handleBookmark() {
    // Handle bookmark button tap with production-ready error handling
    if (_isBookmarkLoading) return; // Prevent multiple rapid taps

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

    // Open TikTok-style share sheet directly
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        debugPrint('📤 _handleShare: Building ShareSheetView...');
        return ShareSheetView(
          video: widget.video,
          payload: ShareServiceOptimized().getCachedPayload(widget.video.id),
          onDismiss: () {
            debugPrint('📤 _handleShare: ShareSheet dismissed');
          },
          onAction: (action) {
            debugPrint('📤 _handleShare: ShareSheet action: $action');
            ShareServiceOptimized().handleAction(
              action,
              widget.video.id,
              widget.video.creator.id,
            );
          },
        );
      },
    );
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
    print(
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

    // Initialize bookmark state on first build
    if (!_isInitialized) {
      _initializeBookmarkState();
    }

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
    // DEBUG: Log video controller state when modal is open
    debugPrint(
        '🎬 _buildVideoPlayer: videoId=${widget.video.id}, controller=${_videoPlayerController != null}, initialized=$_isInitialized, disposed=$_isDisposed, isCurrent=${widget.isCurrentVideo}');

    // 🚀 INSTANT SWITCHING: Only show video when fully ready - no thumbnails during swipes
    if (_videoPlayerController == null || !_isInitialized || _isDisposed) {
      debugPrint(
          '🎬 _buildVideoPlayer: CONTROLLER NOT READY - videoId=${widget.video.id}, controller=${_videoPlayerController != null}, initialized=$_isInitialized, disposed=$_isDisposed');

      // SEAMLESS RETURN: Reinitialize if controller was disposed
      if ((_videoPlayerController == null || _isDisposed) &&
          widget.isCurrentVideo) {
        log('🔄 VideoPlayer: Reinitializing disposed controller for current video: ${widget.video.id}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _initializeVideo();
          }
        });
      }

      // 🚀 INSTANT SWITCHING: Show black screen instead of thumbnail for seamless experience
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: widget.isCurrentVideo
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : null, // Non-current videos show pure black for instant switching
      );
    }

    // CRITICAL: Additional safety check to prevent disposed controller usage
    try {
      // Test if controller is still valid by accessing its value
      final controllerValue = _videoPlayerController!.value;
      if (!controllerValue.isInitialized || controllerValue.hasError) {
        log('⚠️ Controller not ready, showing black for seamless switching: ${widget.video.id}');
        return Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: widget.isCurrentVideo
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : null,
        );
      }

      // 🚀 INSTANT SWITCHING: Show black instead of thumbnail for seamless experience
      if (!controllerValue.isInitialized || controllerValue.size.isEmpty) {
        log('🖼️ Controller not fully ready, showing black for instant switching: ${widget.video.id}');
        return Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: widget.isCurrentVideo
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : null,
        );
      }
    } catch (e) {
      log('❌ Controller access error, showing black for seamless switching: $e');
      // Controller was disposed, trigger reinitialization
      _videoPlayerController = null;
      _isInitialized = false;
      _isDisposed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isCurrentVideo) {
          _initializeVideo();
        }
      });
      // 🚀 INSTANT SWITCHING: Show black instead of thumbnail
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: widget.isCurrentVideo
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : null,
      );
    }

    // Video is ready - show the actual video player
    // Additional safety check before creating VideoPlayer widget
    if (_videoPlayerController == null || _isDisposed) {
      log('⚠️ Controller became null/disposed during build, showing black screen');
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: widget.isCurrentVideo
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : null,
      );
    }

    try {
      return FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox(
          width: _videoPlayerController!.value.size.width,
          height: _videoPlayerController!.value.size.height,
          child: VideoPlayer(
            _videoPlayerController!,
            key: ValueKey(_videoPlayerController!.dataSource),
          ),
        ),
      );
    } catch (e) {
      log('❌ VideoPlayer widget error: $e - showing black screen');
      // Controller might be in invalid state, trigger reinitialization
      _videoPlayerController = null;
      _isInitialized = false;
      _isDisposed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isCurrentVideo) {
          _initializeVideo();
        }
      });
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: widget.isCurrentVideo
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : null,
      );
    }
  }

  Widget _buildUIOverlay() {
    final media = MediaQuery.of(context);
    final safeBottom = media.viewPadding.bottom;

    // Constants - TikTok-style spacing
    const navHeight = 100.0; // Height of bottom navigation
    const railWidth = 64.0;
    const leftInset = 12.0;
    const rightInset = railWidth + 16;
    const paddingAboveNav =
        50.0; // Match right action buttons TikTok-style spacing

    // Position caption block right above bottom navigation
    final bottomPosition = safeBottom + navHeight + paddingAboveNav;

    return Positioned(
      left: leftInset,
      right: rightInset,
      bottom: bottomPosition,
      child: Container(
        constraints: BoxConstraints(
          maxHeight:
              media.size.height * 0.25, // Use maxHeight instead of fixed height
        ),
        padding: const EdgeInsets.all(16.0),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
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
            // Video caption with overflow protection
            Flexible(
              child: Text(
                widget.video.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final media = MediaQuery.of(context);

    // Button specifications - TikTok-style sizing
    const btnSize = 56.0; // Increased from 52.0 to 56.0 for larger icons
    const gap = 16.0;
    const count = 4;
    const groupHeight = (count * btnSize) + ((count - 1) * gap);

    // Calculate position - TikTok-style spacing above bottom navigation
    const rightInset = 12.0;
    const bottomNavHeight = 100.0; // Height of bottom navigation
    const paddingAboveNav =
        112.0; // TikTok-style large padding above bottom nav

    final screenHeight = media.size.height;
    final safeBottom = media.viewPadding.bottom;
    // Bottom nav starts at: screenHeight - safeBottom - bottomNavHeight
    // We want buttons above it, so: bottomNavStart - paddingAboveNav - groupHeight
    final bottomNavStart = screenHeight - safeBottom - bottomNavHeight;
    final desiredTop = bottomNavStart - paddingAboveNav - groupHeight;
    final top = desiredTop.clamp(0.0, screenHeight - groupHeight);

    return Positioned(
      top: top,
      right: rightInset,
      child: GestureDetector(
        // Absorb taps on action buttons - don't let them pass through to video
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Empty - just absorb the tap, don't trigger video pause/play
        },
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
            ),
            const SizedBox(height: 16),

            // Comment button
            _buildActionButton(
              icon: Icons.chat_bubble_outline,
              count: widget.video.comments.toString(),
              onTap: _handleComment,
            ),
            const SizedBox(height: 16),

            // Bookmark button with loading state
            _buildActionButton(
              icon: _isBookmarkLoading
                  ? Icons.hourglass_empty
                  : (_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
              count: _isBookmarkLoading ? '...' : (_isBookmarked ? '1' : '0'),
              onTap: _isBookmarkLoading ? null : _handleBookmark,
              isActive: _isBookmarked,
              isLoading: _isBookmarkLoading,
            ),
            const SizedBox(height: 16),

            // Share button
            _buildActionButton(
              icon: Icons.share,
              count: 'Share',
              onTap: _handleShare,
            ),
            const SizedBox(height: 16),

            // Creator avatar - Made slightly smaller
            GestureDetector(
              onTap: widget.onShowProfile ?? () => _handleProfileTap(),
              child: _buildActionAvatar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback? onTap,
    bool isActive = false,
    bool isLoading = false,
  }) {
    const btnSize = 56.0; // TikTok-style sizing to match _buildActionButtons
    return SizedBox(
      width: btnSize,
      height: btnSize,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(btnSize / 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isActive
                            ? const Color(0xFF9248D2)
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: isActive
                        ? const Color(0xFF9248D2)
                        : Colors.white.withValues(alpha: 0.85),
                    size:
                        34, // TikTok-style larger icons (increased from 28 to 34)
                  ),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildActionAvatar() {
    final avatarUrl = widget.video.creator.avatarURL;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildDefaultActionAvatar();
    }

    return CachedNetworkImage(
      imageUrl: avatarUrl,
      width: 40,
      height: 40,
      imageBuilder: (context, imageProvider) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
      placeholder: (context, url) => _buildDefaultActionAvatar(),
      errorWidget: (context, url, error) {
        log('❌ Action avatar load error for ${widget.video.creator.username}: $error');
        return _buildDefaultActionAvatar();
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

  Widget _buildDefaultActionAvatar() {
    return Container(
      width: 40,
      height: 40,
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
          size: 20,
        ),
      ),
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
