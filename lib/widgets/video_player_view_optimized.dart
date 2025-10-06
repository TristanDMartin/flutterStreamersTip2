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
import '../providers/following_provider.dart';
import '../services/performance_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/robust_auth_service.dart';
import '../services/enhanced_like_service.dart';
import '../widgets/enhanced_like_button.dart';
import '../services/video_controller_manager.dart';
import '../services/video_preloader_service.dart';
import '../services/production_logging_service.dart';
import '../services/audio_enhancement_service.dart';
import '../services/global_playback_coordinator.dart';
import '../providers/playback_coordinator_provider.dart';
import '../widgets/comments_view_optimized.dart';
import '../widgets/streamer_share_sheet.dart';

// SIMPLIFIED: Global video management for TikTok-like behavior
class GlobalVideoController {
  static bool _shouldPauseAllVideos = false;
  static bool _shouldResumeCurrentVideo = false;
  static bool _shouldPauseHomeViewVideos =
      false; // SIMPLIFIED: Only pause, don't dispose

  static bool get shouldPauseAllVideos => _shouldPauseAllVideos;
  static bool get shouldResumeCurrentVideo => _shouldResumeCurrentVideo;
  static bool get shouldDisposeAllVideos =>
      _shouldPauseHomeViewVideos; // Alias for compatibility
  static bool get shouldDisposeInactiveTabVideos =>
      _shouldPauseHomeViewVideos; // Alias for compatibility

  /// Pause ALL videos immediately - used when scrolling within same tab
  static void pauseAllVideos() {
    _shouldPauseAllVideos = true;
    log('🔊 GlobalVideoController: Set pause signal to true - ALL videos should pause');
    // Reset after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _shouldPauseAllVideos = false;
      log('🔊 GlobalVideoController: Reset pause signal to false');
    });
  }

  /// Resume current video with instant play
  static void resumeCurrentVideo() {
    _shouldResumeCurrentVideo = true;
    log('🔊 GlobalVideoController: Set resume signal to true - INSTANT PLAY');
    // Reset after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _shouldResumeCurrentVideo = false;
      log('🔊 GlobalVideoController: Reset resume signal to false');
    });
  }

  /// SIMPLIFIED: Pause HomeView videos only - used when navigating away from HomeView
  static void disposeAllVideos() {
    _shouldPauseHomeViewVideos = true;
    log('⏸️ GlobalVideoController: PAUSE HOMEVIEW VIDEOS - stopping HomeView audio streams');
    // Reset after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _shouldPauseHomeViewVideos = false;
      log('⏸️ GlobalVideoController: Reset pause HomeView signal to false');
    });
  }

  /// SIMPLIFIED: Alias for compatibility
  static void disposeInactiveTabVideos(String newActiveTabId) {
    disposeAllVideos(); // Same behavior
  }
}

class VideoPlayerViewOptimized extends ConsumerStatefulWidget {
  final HomeVideo video;
  final bool isCurrentVideo;
  final bool isFirstVideo;
  final String tabId; // Track which tab this video belongs to
  final HomeViewModel homeViewModel;
  final bool showSheet;
  final String sheetType;
  final VoidCallback onShowProfile;
  final VoidCallback onShowComments;
  final VoidCallback onShowShare;
  final VoidCallback onShowStreamerCard;
  final bool isLiked;
  final bool isBookmarked;

  const VideoPlayerViewOptimized({
    super.key,
    required this.video,
    required this.isCurrentVideo,
    required this.isFirstVideo,
    required this.tabId,
    required this.homeViewModel,
    required this.showSheet,
    required this.sheetType,
    required this.onShowProfile,
    required this.onShowComments,
    required this.onShowShare,
    required this.onShowStreamerCard,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  @override
  ConsumerState<VideoPlayerViewOptimized> createState() =>
      _VideoPlayerViewOptimizedState();
}

class _VideoPlayerViewOptimizedState
    extends ConsumerState<VideoPlayerViewOptimized>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
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

  // Production-ready controller management
  final VideoControllerManager _controllerManager = VideoControllerManager();
  final ProductionLoggingService _logger = ProductionLoggingService();
  GlobalPlaybackCoordinator? _playbackCoordinator;

  /// Safe controller operations with comprehensive error handling
  Future<bool> _safeSetVolume(double volume) async {
    if (_videoPlayerController == null || _isDisposed) {
      _logger.warn('Cannot set volume: controller is null or disposed',
          tag: 'VideoPlayer');
      return false;
    }

    try {
      if (_controllerManager.isControllerSafe(widget.video.id)) {
        await _videoPlayerController!.setVolume(volume);
        _logger.debug('Volume set to $volume for ${widget.video.id}',
            tag: 'VideoPlayer');
        return true;
      } else {
        _logger.warn(
            'Controller not safe for volume operation: ${widget.video.id}',
            tag: 'VideoPlayer');
        return false;
      }
    } catch (e) {
      _logger.error('Error setting volume to $volume',
          tag: 'VideoPlayer', error: e);
      return false;
    }
  }

  Future<bool> _safePlay() async {
    if (_videoPlayerController == null || _isDisposed) {
      _logger.warn('Cannot play: controller is null or disposed',
          tag: 'VideoPlayer');
      return false;
    }

    try {
      if (_controllerManager.isControllerSafe(widget.video.id)) {
        await _videoPlayerController!.play();
        _controllerManager.markPlaying(widget.video.id);
        _logger.debug('Video playing: ${widget.video.id}', tag: 'VideoPlayer');
        return true;
      } else {
        _logger.warn(
            'Controller not safe for play operation: ${widget.video.id}',
            tag: 'VideoPlayer');
        return false;
      }
    } catch (e) {
      _logger.error('Error playing video', tag: 'VideoPlayer', error: e);
      return false;
    }
  }

  Future<bool> _safePause() async {
    if (_videoPlayerController == null || _isDisposed) {
      _logger.warn('Cannot pause: controller is null or disposed',
          tag: 'VideoPlayer');
      return false;
    }

    try {
      if (_controllerManager.isControllerSafe(widget.video.id)) {
        await _videoPlayerController!.pause();
        _controllerManager.markPaused(widget.video.id);
        _logger.debug('Video paused: ${widget.video.id}', tag: 'VideoPlayer');
        return true;
      } else {
        _logger.warn(
            'Controller not safe for pause operation: ${widget.video.id}',
            tag: 'VideoPlayer');
        return false;
      }
    } catch (e) {
      _logger.error('Error pausing video', tag: 'VideoPlayer', error: e);
      return false;
    }
  }

  // Track state changes to prevent duplicate callbacks
  bool _lastShouldPauseAllVideos = false;
  bool _lastShouldResumeCurrentVideo = false;
  bool _lastGlobalShouldPauseAllVideos = false;
  bool _lastGlobalShouldResumeCurrentVideo = false;

  // Track last tap position for floating hearts
  Offset _lastTapPosition = Offset.zero;

  // Key for like button (for floating hearts animation)
  final GlobalKey _likeButtonKey = GlobalKey();

  @override
  bool get wantKeepAlive => true; // Keep pages alive while swiping

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize playback coordinator
    _playbackCoordinator = ref.read(playbackCoordinatorProvider);

    // TIKTOK-STYLE: Initialize video immediately for instant playback
    _initializeVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Track performance
    PerformanceService()
        .trackVideoPlayback(widget.video.id, PlaybackEvent.pause);

    // Unregister from playback coordinator
    if (_playbackCoordinator != null) {
      _playbackCoordinator!.unregisterController(widget.video.id);
    }

    // With AutomaticKeepAliveClientMixin and preloader, we don't dispose controllers here
    // The VideoPreloaderService manages controller lifecycle
    if (_videoPlayerController != null && !_isDisposed) {
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
        // Don't set _videoPlayerController = null or _isDisposed = true
        // Keep the reference for potential reuse by preloader
      }
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerViewOptimized oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_videoPlayerController == null || !_isInitialized) return;

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
        // Request focus from coordinator - this will pause all other videos
        if (_playbackCoordinator != null) {
          _playbackCoordinator!.requestFocus(widget.video.id, widget.tabId);
          log('🎵 VideoPlayer: Requested focus for current video: ${widget.video.id}');
        }

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
        // Relinquish focus - this video is no longer current
        if (_playbackCoordinator != null) {
          _playbackCoordinator!.relinquishFocus(widget.video.id);
          log('🎵 VideoPlayer: Relinquished focus for non-current video: ${widget.video.id}');
        }

        // This video is no longer current - pause it immediately
        _safePause().then((_) {
          _safeSetVolume(0.0); // Mute audio immediately
        });
        setState(() => _isPlaying = false);

        log('⏸️ Video no longer current, paused: ${widget.video.id}');
        debugPrint('⏸️ Video no longer current, paused: ${widget.video.id}');
      }
    }

    // TIKTOK-STYLE: Also ensure focus if this video is current but coordinator doesn't have focus
    if (widget.isCurrentVideo && _playbackCoordinator != null) {
      // Check if this video should have focus but doesn't
      if (_playbackCoordinator!.activeVideoId != widget.video.id) {
        log('🎵 VideoPlayer: Current video doesn\'t have focus, requesting it: ${widget.video.id}');
        _playbackCoordinator!.requestFocus(widget.video.id, widget.tabId);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_videoPlayerController == null || !_isInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _safePause().then((_) {
          setState(() => _isPlaying = false);
        });
        break;
      case AppLifecycleState.resumed:
        if (widget.isCurrentVideo) {
          // Auto-unmute audio when app resumes with TikTok-style enhancement
          _applyAudioEnhancement().then((_) async {
            await _safeSetVolume(1.0);
            setState(() => _audioUnmuted = true);

            await _safePlay();
            setState(() => _isPlaying = true);

            log('🔊 Auto-unmuted audio on app resume with enhanced audio: ${widget.video.id}');
            debugPrint(
                '🔊 Auto-unmuted audio on app resume with enhanced audio: ${widget.video.id}');
          });
        }
        break;
      case AppLifecycleState.detached:
        _safePause().then((_) {
          setState(() => _isPlaying = false);
        });
        break;
      case AppLifecycleState.hidden:
        _safePause().then((_) {
          setState(() => _isPlaying = false);
        });
        break;
    }
  }

  Future<void> _initializeVideo() async {
    // Start performance tracking
    PerformanceService().startVideoLoad(widget.video.id);

    try {
      // Try to get preloaded controller first
      final preloader = VideoPreloaderService();
      _videoPlayerController =
          preloader.getPreloadedControllerById(widget.video.id);

      if (_videoPlayerController == null) {
        // Fallback to VideoControllerManager if not preloaded
        _videoPlayerController = await _controllerManager.getController(
            widget.video.id, widget.video.videoURL);
      }

      if (_videoPlayerController == null) {
        _logger.error('Failed to get controller from preloader or manager',
            tag: 'VideoPlayer');
        return;
      }

      // Add listeners
      _videoPlayerController!.addListener(_videoErrorListener);
      _videoPlayerController!.addListener(_videoStateListener);

      // Register with playback coordinator
      if (_playbackCoordinator != null) {
        _playbackCoordinator!.registerController(
          widget.video.id,
          _videoPlayerController!,
          widget
              .tabId, // Use tabId as the owner (e.g., 'home/forYou', 'home/following')
        );
      }

      _isInitialized = true;
      _logger.debug('Video initialized successfully: ${widget.video.id}',
          tag: 'VideoPlayer');

      // Auto-play if this is the current video
      if (widget.isCurrentVideo) {
        // Request focus from coordinator to ensure audio plays
        if (_playbackCoordinator != null) {
          _playbackCoordinator!.requestFocus(widget.video.id, widget.tabId);
        }
        await _safePlay();
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
    if (_videoPlayerController?.value.hasError == true) {
      final error = _videoPlayerController?.value.errorDescription ??
          'Unknown video error';
      log('❌ Video player error: $error');
      _handleVideoError(Exception(error));
    }
  }

  void _videoStateListener() {
    if (_videoPlayerController != null && mounted) {
      final isPlaying = _videoPlayerController!.value.isPlaying;
      if (isPlaying != _isPlaying) {
        _logger.debug(
            'Video state changed - isPlaying: $isPlaying, _isPlaying: $_isPlaying',
            tag: 'VideoPlayer');
        setState(() {
          _isPlaying = isPlaying;
        });
      }
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
    // Production-ready favorite toggle with error handling and analytics
    if (_isBookmarkLoading) return; // Prevent multiple rapid taps

    setState(() {
      _isBookmarkLoading = true;
    });

    try {
      // Call the async favorite update method
      if (widget.homeViewModel.updateVideoFavoriteState != null) {
        await widget.homeViewModel.updateVideoFavoriteState!(widget.video.id);
      }
      setState(() {});

      // Track analytics
      // AnalyticsService.instance.trackEvent('bookmark_toggled', parameters: {
      //   'video_id': widget.video.id,
      //   'is_favorited': widget.isBookmarked,
      //   'creator_id': widget.video.creator.id,
      // });
    } catch (e) {
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update bookmark: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }

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

  void _handleComment() {
    // Handle comment button tap
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CommentsViewOptimized(
          videoId: widget.video.id,
          videoOwnerId: widget.video.creator.id,
        );
      },
    );
  }

  void _handleBookmark() {
    // Handle bookmark button tap with production-ready error handling
    if (_isBookmarkLoading) return; // Prevent multiple rapid taps

    HapticFeedback.lightImpact();
    _handleFavoriteChanged();
  }

  void _handleShare() {
    // Handle share button tap
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StreamerShareSheet(
          userId: widget.video.creator.id,
          displayName: widget.video.creator.displayName,
          profileImageUrl: widget.video.creator.avatarURL,
          onDismiss: () {
            // Don't call Navigator.pop() here as it's already handled in the X button
            // This prevents double pop which causes black screen
          },
        );
      },
    );
  }

  void _handleFollow(WidgetRef ref) {
    // Follow button tapped for creator: ${widget.video.creator.id}
    HapticFeedback.lightImpact();

    // Check if user is authenticated
    final auth = FirebaseAuth.instance;
    final robustAuth = ref.read(robustAuthServiceProvider);

    // Current user ID: ${robustAuth.currentUser?.id ?? 'null'}
    // Firebase Auth user: ${auth.currentUser?.uid}

    // Check if we're in bypass mode (mock user)
    if (robustAuth.currentUser?.id == 'dev_user_123') {
      // Using mock follow functionality for development
      _handleMockFollow(ref);
      return;
    } else {
      // Using real Firebase follow functionality
    }

    if (auth.currentUser == null) {
      // User not authenticated, cannot follow
      return;
    }

    // Track follow/unfollow engagement
    final isCurrentlyFollowing = ref
        .read(followingProvider)
        .followingList
        .contains(widget.video.creator.id);
    // Currently following: $isCurrentlyFollowing
    // Following list: ${ref.read(followingProvider).followingList}
    // Followers list: ${ref.read(followingProvider).followersList}

    EngagementAnalyticsService().trackEngagement(
      videoId: widget.video.id,
      event: isCurrentlyFollowing
          ? EngagementEvent.unfollow
          : EngagementEvent.follow,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
        'creatorId': widget.video.creator.id,
      },
    );

    // Toggle follow state
    ref.read(followingProvider.notifier).toggleFollow(widget.video.creator.id);
  }

  void _handleMockFollow(WidgetRef ref) {
    try {
      // Mock follow functionality for development
      final isCurrentlyFollowing = ref
          .read(followingProvider)
          .followingList
          .contains(widget.video.creator.id);

      if (isCurrentlyFollowing) {
        ref
            .read(followingProvider.notifier)
            .unfollowUser(widget.video.creator.id);
        // Mock unfollowed: ${widget.video.creator.id}
      } else {
        ref
            .read(followingProvider.notifier)
            .followUser(widget.video.creator.id);
        // Mock followed: ${widget.video.creator.id}
      }
    } catch (e) {
      // Mock follow error: $e
    }
  }

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

  void _handleDoubleTap() {
    // Double tap anywhere on video to like/unlike
    HapticFeedback.lightImpact();

    // Trigger the enhanced like button programmatically
    _triggerEnhancedLikeButton();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    // Capture the tap position for floating hearts animation
    _lastTapPosition = details.globalPosition;
  }

  void _triggerEnhancedLikeButton() {
    // Trigger the enhanced like service directly for double-tap
    _performEnhancedLikeToggle();
  }

  Future<void> _performEnhancedLikeToggle() async {
    try {
      final enhancedLikeService = EnhancedLikeService();

      // Toggle like with enhanced service
      final result = await enhancedLikeService.toggleLike(widget.video.id,
          source: 'double-tap');

      if (result == LikeResult.success) {
        // Update parent state
        _handleLikeChanged();

        // Create enhanced floating hearts animation
        _createEnhancedFloatingHearts();
      }
    } catch (e) {
      log('❌ Error in enhanced like toggle: $e');
    }
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

  void _createEnhancedFloatingHearts() {
    // Use the like button position for enhanced floating hearts
    final renderBox =
        _likeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = renderBox != null
        ? renderBox.localToGlobal(
            Offset(renderBox.size.width / 2, renderBox.size.height / 2))
        : _lastTapPosition;

    // Create enhanced floating hearts with better animation
    EnhancedFloatingHearts.createFloatingHearts(
      context,
      origin,
      () {
        log('💖 Enhanced floating hearts animation completed');
      },
    );
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

    return Consumer(
      builder: (context, ref, child) {
        // Listen for pause signal when leaving HomeView
        final homeState = ref.watch(homeProvider);

        // DEBUG: Log every state change
        log('🔍 Consumer: shouldPauseAllVideos=${homeState.shouldPauseAllVideos}, _lastShouldPauseAllVideos=$_lastShouldPauseAllVideos, controller=${_videoPlayerController != null}, initialized=$_isInitialized');
        log('🔍 GlobalController: shouldPauseAllVideos=${GlobalVideoController.shouldPauseAllVideos}, _lastGlobalShouldPauseAllVideos=$_lastGlobalShouldPauseAllVideos');

        // Check if we should pause all videos (when leaving HomeView)
        if (homeState.shouldPauseAllVideos &&
            !_lastShouldPauseAllVideos &&
            _videoPlayerController != null &&
            _isInitialized) {
          _lastShouldPauseAllVideos = true;
          // IMMEDIATE pause - stops audio instantly
          // CRITICAL: Mute audio first, then pause video
          _safeSetVolume(0.0).then((_) {
            _safePause();
          });
          log('⏸️ Video paused due to HomeView navigation (Consumer): ${widget.video.id}');
          // Update UI state after build completes (prevents setState error)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isPlaying = false);
            }
          });
        } else if (!homeState.shouldPauseAllVideos) {
          _lastShouldPauseAllVideos = false;
        }

        // Check if we should resume current video (when returning to HomeView)
        if (homeState.shouldResumeCurrentVideo &&
            !_lastShouldResumeCurrentVideo &&
            widget.isCurrentVideo &&
            _videoPlayerController != null &&
            _isInitialized) {
          _lastShouldResumeCurrentVideo = true;

          try {
            // CRITICAL: Check if controller is ready before resuming
            if (_videoPlayerController!.value.isInitialized &&
                !_videoPlayerController!.value.hasError) {
              // IMMEDIATE resume - starts audio instantly
              _safeSetVolume(1.0).then((_) {
                _safePlay();
              });
              log('▶️ Video resumed when returning to HomeView: ${widget.video.id}');
              // Update UI state after build completes (prevents setState error)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _audioUnmuted = true;
                    _isPlaying = true;
                  });
                }
              });
            } else {
              log('⚠️ Video controller not ready for HomeProvider resume: ${widget.video.id}');
              // Trigger reinitialization
              _videoPlayerController = null;
              _isInitialized = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _initializeVideo();
                }
              });
            }
          } catch (e) {
            log('❌ Error resuming video via HomeProvider: $e');
            // Controller was disposed, trigger reinitialization
            _videoPlayerController = null;
            _isInitialized = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initializeVideo();
              }
            });
          }
        } else if (!homeState.shouldResumeCurrentVideo) {
          _lastShouldResumeCurrentVideo = false;
        }

        // ALSO check global controller for immediate response
        if (GlobalVideoController.shouldPauseAllVideos &&
            !_lastGlobalShouldPauseAllVideos &&
            _videoPlayerController != null &&
            _isInitialized &&
            !_isDisposed) {
          _lastGlobalShouldPauseAllVideos = true;
          // IMMEDIATE pause - stops audio instantly
          debugPrint(
              '⏸️ Video paused due to GlobalVideoController: ${widget.video.id}');
          log('⏸️ Video paused due to GlobalVideoController: ${widget.video.id}');
          // CRITICAL: Mute audio first, then pause video using safe operations
          _safeSetVolume(0.0).then((_) {
            _safePause();
          });
          // Update UI state after build completes (prevents setState error)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isPlaying = false);
            }
          });
        } else if (!GlobalVideoController.shouldPauseAllVideos) {
          _lastGlobalShouldPauseAllVideos = false;
        }

        // SIMPLIFIED: Only pause videos when navigating away, let widget dispose() handle cleanup
        if ((GlobalVideoController.shouldDisposeAllVideos ||
                GlobalVideoController.shouldDisposeInactiveTabVideos) &&
            _videoPlayerController != null &&
            _isInitialized &&
            !_isDisposed) {
          // Only pause, don't dispose - let the widget lifecycle handle disposal
          if (widget.tabId == 'forYou' || widget.tabId == 'following') {
            log('⏸️ SIMPLIFIED: Pausing HomeView video (no disposal): ${widget.video.id}');
            try {
              _safeSetVolume(0.0).then((_) {
                _safePause();
              });
              _isPlaying = false;
            } catch (e) {
              log('⚠️ Error pausing controller: $e');
              _isDisposed = true;
            }
          }
        }

        // SIMPLE: Ensure only current video plays
        if (_videoPlayerController != null &&
            _isInitialized &&
            _isPlaying &&
            !widget.isCurrentVideo) {
          log('⏸️ SIMPLE: Video not current, pausing: ${widget.video.id}');
          _safePause().then((_) {
            _safeSetVolume(0.0); // Mute audio immediately
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isPlaying = false);
            }
          });
        }

        // Check if we should resume current video (when returning to HomeView)
        if (GlobalVideoController.shouldResumeCurrentVideo &&
            !_lastGlobalShouldResumeCurrentVideo &&
            widget.isCurrentVideo &&
            _videoPlayerController != null &&
            _isInitialized) {
          _lastGlobalShouldResumeCurrentVideo = true;

          try {
            // CRITICAL: Check if controller is ready before resuming
            if (_videoPlayerController!.value.isInitialized &&
                !_videoPlayerController!.value.hasError) {
              // IMMEDIATE resume - starts audio instantly
              _safeSetVolume(1.0).then((_) {
                _safePlay();
              });
              log('▶️ Video resumed due to GlobalVideoController: ${widget.video.id}');
              // Update UI state after build completes (prevents setState error)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _isPlaying = true);
                }
              });
            } else {
              log('⚠️ Video controller not ready for resume: ${widget.video.id}');
              // Trigger reinitialization
              _videoPlayerController = null;
              _isInitialized = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _initializeVideo();
                }
              });
            }
          } catch (e) {
            log('❌ Error resuming video: $e');
            // Controller was disposed, trigger reinitialization
            _videoPlayerController = null;
            _isInitialized = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initializeVideo();
              }
            });
          }
        } else if (!GlobalVideoController.shouldResumeCurrentVideo) {
          _lastGlobalShouldResumeCurrentVideo = false;
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Stack(
            children: [
              // TIKTOK-STYLE: Always show video player, no placeholder delay
              GestureDetector(
                onTap: _handleTap,
                onDoubleTap: _handleDoubleTap,
                onDoubleTapDown: _handleDoubleTapDown,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: _buildVideoPlayer(),
                ),
              ),

              // UI Overlay (positioned above gesture detector)
              _buildUIOverlay(),

              // Action buttons overlay (positioned above gesture detector)
              _buildActionButtons(),

              // Play/Pause indicator overlay
              if (_showPlayPauseIndicatorOverlay) _buildPlayPauseIndicator(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstantThumbnail() {
    // TIKTOK-STYLE: Show thumbnail instantly, no loading indicators
    String? thumbnailUrl;

    // Try new VideoThumbnails system first
    if (widget.video.thumbnails != null &&
        widget.video.thumbnails!.urls.isNotEmpty) {
      // Get the best thumbnail size for the screen

      // Choose the best thumbnail size (720p, 540p, or 360p)
      if (widget.video.thumbnails!.urls.containsKey(720)) {
        thumbnailUrl = widget.video.thumbnails!.urls[720];
      } else if (widget.video.thumbnails!.urls.containsKey(540)) {
        thumbnailUrl = widget.video.thumbnails!.urls[540];
      } else if (widget.video.thumbnails!.urls.containsKey(360)) {
        thumbnailUrl = widget.video.thumbnails!.urls[360];
      } else {
        // Use the first available thumbnail
        thumbnailUrl = widget.video.thumbnails!.urls.values.first;
      }

      debugPrint(
          '🎬 VideoPlayer: Using new thumbnail system - URL: $thumbnailUrl');
    }
    // Fallback to legacy thumbnailURL
    else if (widget.video.thumbnailURL != null &&
        widget.video.thumbnailURL!.isNotEmpty) {
      thumbnailUrl = widget.video.thumbnailURL;
      debugPrint('🎬 VideoPlayer: Using legacy thumbnailURL: $thumbnailUrl');
    }

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          // No loading builder - show immediately
          errorBuilder: (context, error, stackTrace) {
            debugPrint('⚠️ VideoPlayer: Failed to load thumbnail: $error');
            return _buildBlackPlaceholder();
          },
          // Optimize for instant display
          cacheWidth: 400,
          cacheHeight: 400,
          filterQuality: FilterQuality.medium,
        ),
      );
    } else {
      debugPrint(
          '⚠️ VideoPlayer: No thumbnail URL available, showing black placeholder');
      return _buildBlackPlaceholder();
    }
  }

  Widget _buildBlackPlaceholder() {
    return Positioned.fill(
      child: Container(
        color: Colors.black, // Simple black background - no gradients
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // TIKTOK-STYLE: Show video immediately or use thumbnail as instant fallback
    if (_videoPlayerController == null || !_isInitialized || _isDisposed) {
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
      // Show thumbnail immediately while video loads in background
      return _buildInstantThumbnail();
    }

    // CRITICAL: Additional safety check to prevent disposed controller usage
    try {
      // Test if controller is still valid by accessing its value
      final controllerValue = _videoPlayerController!.value;
      if (!controllerValue.isInitialized || controllerValue.hasError) {
        log('⚠️ Controller not ready, showing thumbnail: ${widget.video.id}');
        return _buildInstantThumbnail();
      }

      // THUMBNAIL GATING: Show thumbnail until first frame is ready
      // This prevents the purple screen flash during texture attachment
      if (!controllerValue.isInitialized || controllerValue.size.isEmpty) {
        log('🖼️ Controller not fully ready, showing thumbnail until first frame: ${widget.video.id}');
        return _buildInstantThumbnail();
      }
    } catch (e) {
      log('❌ Controller access error, showing thumbnail: $e');
      // Controller was disposed, trigger reinitialization
      _videoPlayerController = null;
      _isInitialized = false;
      _isDisposed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isCurrentVideo) {
          _initializeVideo();
        }
      });
      return _buildInstantThumbnail();
    }

    // Video is ready - show the actual video player
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
                  onTap: widget.onShowProfile,
                  child: _buildUserAvatar(),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: widget.onShowProfile,
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
                // Follow pill next to username
                Consumer(
                  builder: (context, ref, child) {
                    final isFollowing = ref
                        .watch(followingProvider)
                        .followingList
                        .contains(widget.video.creator.id);
                    return GestureDetector(
                      onTap: () => _handleFollow(ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isFollowing
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF955CFF),
                                    Color(0xFF3D99F7)
                                  ], // Match ProfileView edit button
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: isFollowing ? Colors.grey[600] : null,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

    // Button specifications - Made slightly larger
    const btnSize = 52.0; // Increased from 44.0 to 52.0
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
                : (widget.isBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_border),
            count: _isBookmarkLoading
                ? '...'
                : (widget.video.isFavorited ? '1' : '0'),
            onTap: _isBookmarkLoading ? null : _handleBookmark,
            isActive: widget.isBookmarked,
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
            onTap: widget.onShowProfile,
            child: _buildActionAvatar(),
          ),
        ],
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
    const btnSize =
        52.0; // Increased from 44.0 to 52.0 to match _buildActionButtons
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
                    size: 28, // Increased from 24 to 28
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
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
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
                    child: const Icon(
                      Icons.favorite,
                      color: Color(0xFF9248D2),
                      size: 40,
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
