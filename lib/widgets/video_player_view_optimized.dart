import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/home_video.dart';
import '../providers/home_provider.dart';
import '../providers/following_provider.dart';
import '../services/performance_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/robust_auth_service.dart';
import '../services/like_service.dart';
import '../services/video_performance_service.dart';
import '../widgets/comments_view_optimized.dart';
import '../widgets/streamer_share_sheet.dart';

// Global pause signal for immediate video control
class GlobalVideoController {
  static bool _shouldPauseAllVideos = false;
  static bool _shouldResumeCurrentVideo = false;
  
  static bool get shouldPauseAllVideos => _shouldPauseAllVideos;
  static bool get shouldResumeCurrentVideo => _shouldResumeCurrentVideo;
  
  static void pauseAllVideos() {
    _shouldPauseAllVideos = true;
    print('🔊 GlobalVideoController: Set pause signal to true');
    log('🔊 GlobalVideoController: Set pause signal to true');
    // Reset after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _shouldPauseAllVideos = false;
      print('🔊 GlobalVideoController: Reset pause signal to false');
      log('🔊 GlobalVideoController: Reset pause signal to false');
    });
  }
  
  static void resumeCurrentVideo() {
    _shouldResumeCurrentVideo = true;
    log('🔊 GlobalVideoController: Set resume signal to true');
    // Reset after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _shouldResumeCurrentVideo = false;
      log('🔊 GlobalVideoController: Reset resume signal to false');
    });
  }
}

class VideoPlayerViewOptimized extends ConsumerStatefulWidget {
  final HomeVideo video;
  final bool isCurrentVideo;
  final bool isFirstVideo;
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
  ConsumerState<VideoPlayerViewOptimized> createState() => _VideoPlayerViewOptimizedState();
}

class _VideoPlayerViewOptimizedState extends ConsumerState<VideoPlayerViewOptimized> 
    with WidgetsBindingObserver {
  VideoPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasIncrementedView = false;
  bool _isBookmarkLoading = false; // Prevent multiple rapid taps
  bool _showPlayPauseIndicatorOverlay = false; // Show play/pause indicator animation
  bool _audioUnmuted = false; // Track if audio has been unmuted by user interaction
  
  // Track state changes to prevent duplicate callbacks
  bool _lastShouldPauseAllVideos = false;
  bool _lastShouldResumeCurrentVideo = false;
  bool _lastGlobalShouldPauseAllVideos = false;
  bool _lastGlobalShouldResumeCurrentVideo = false;
  
  // Track last tap position for floating hearts
  Offset _lastTapPosition = Offset.zero;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // TIKTOK-STYLE: Initialize video immediately for instant playback
    _initializeVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Track performance
    PerformanceService().trackVideoPlayback(widget.video.id, PlaybackEvent.pause);
    
    // Remove error listener and dispose controller safely
    if (_videoPlayerController != null) {
      _videoPlayerController!.removeListener(_videoErrorListener);
      // Use performance service to dispose controller safely
      VideoPerformanceService().disposeController(widget.video.videoURL);
      _videoPlayerController = null;
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
            _videoPlayerController!.pause();
            log('⏸️ Video paused due to HomeView navigation: ${widget.video.id}');
            // Update UI state after build completes (prevents setState error)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _isPlaying = false);
              }
            });
            return;
          }
    
    // React when the page becomes current/non-current
    if (oldWidget.isCurrentVideo != widget.isCurrentVideo) {
      if (widget.isCurrentVideo) {
        // Auto-unmute audio when video becomes current (instant audio)
        _videoPlayerController!.setVolume(1.0);
        setState(() => _audioUnmuted = true);
        
        _videoPlayerController!.play();
        setState(() => _isPlaying = true);
        
        log('🔊 Auto-unmuted audio for current video: ${widget.video.id}');
        debugPrint('🔊 Auto-unmuted audio for current video: ${widget.video.id}');
      } else {
        _videoPlayerController!.pause();
        setState(() => _isPlaying = false);
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
        _videoPlayerController!.pause();
        setState(() => _isPlaying = false);
        break;
      case AppLifecycleState.resumed:
        if (widget.isCurrentVideo) {
          // Auto-unmute audio when app resumes (instant audio)
          _videoPlayerController!.setVolume(1.0);
          setState(() => _audioUnmuted = true);
          
          _videoPlayerController!.play();
          setState(() => _isPlaying = true);
          
          log('🔊 Auto-unmuted audio on app resume: ${widget.video.id}');
          debugPrint('🔊 Auto-unmuted audio on app resume: ${widget.video.id}');
        }
        break;
      case AppLifecycleState.detached:
        _videoPlayerController!.pause();
        setState(() => _isPlaying = false);
        break;
      case AppLifecycleState.hidden:
        _videoPlayerController!.pause();
        setState(() => _isPlaying = false);
        break;
    }
  }

  Future<void> _initializeVideo() async {
    // Start performance tracking
    PerformanceService().startVideoLoad(widget.video.id);
    
    try {
        // Validate video URL first
        if (widget.video.videoURL.isEmpty) {
          throw Exception('Video URL is empty');
        }
        
        final videoUri = Uri.tryParse(widget.video.videoURL);
        if (videoUri == null || !videoUri.hasAbsolutePath) {
          throw Exception('Invalid video URL: ${widget.video.videoURL}');
        }
        
        // FRAME OPTIMIZATION: Use microtask to prevent blocking main thread
        await Future.microtask(() {});
      
      // Try warm controller first (TikTok style)
      _videoPlayerController = VideoPerformanceService().getReady(widget.video.videoURL);
      
      if (_videoPlayerController != null) {
        log('🎬 Using prewarmed controller from VideoPerformanceService');
        debugPrint('🎬 Using prewarmed controller from VideoPerformanceService');
        // Ensure prewarmed controller has correct settings
        await _videoPlayerController!.setLooping(true);
        await _videoPlayerController!.setVolume(0); // Start muted for autoplay compliance
        log('🔇 Prewarmed controller set to volume 0');
        debugPrint('🔇 Prewarmed controller set to volume 0');
      }
      
      if (_videoPlayerController == null) {
        // Create new controller if not prewarmed
        _videoPlayerController = VideoPlayerController.networkUrl(
          videoUri,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
        
        // Add error listener before initialization
        _videoPlayerController!.addListener(_videoErrorListener);
        
            if (!_videoPlayerController!.value.isInitialized) {
              await _videoPlayerController!.initialize().timeout(
                const Duration(seconds: 8), // Reduced timeout for faster failure detection
                onTimeout: () {
                  throw Exception('Video initialization timeout');
                },
              );
            }
        
        await _videoPlayerController!.setLooping(true);
        await _videoPlayerController!.setVolume(0); // Start muted for autoplay compliance
        log('🔇 Video initialized with volume 0 for autoplay compliance');
        debugPrint('🔇 Video initialized with volume 0 for autoplay compliance');
      }
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = widget.isCurrentVideo;
        });
        
        // TIKTOK-STYLE INSTANT PLAYBACK: Play immediately without any delay
        if (_isPlaying && mounted && _videoPlayerController != null) {
          // Auto-unmute audio for instant playback
          _videoPlayerController!.setVolume(1.0);
          setState(() => _audioUnmuted = true);
          
          _videoPlayerController!.play();
          log('🎬 INSTANT PLAY: Video started immediately for ${widget.video.id}');
          log('🔊 Auto-unmuted audio for instant playback - Volume: 1.0');
          debugPrint('🔊 Auto-unmuted audio for instant playback - Volume: 1.0');
        }
        
        // Complete performance tracking
        PerformanceService().completeVideoLoad(widget.video.id, success: true);
        log('✅ Video initialized successfully: ${widget.video.id}');
      }
    } catch (e) {
      log('❌ Error initializing video: $e');
      PerformanceService().completeVideoLoad(widget.video.id, success: false);
      
      // Handle video error gracefully without crashing
      _handleVideoError(e);
      
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _isPlaying = false;
        });
      }
    }
  }

  void _videoErrorListener() {
    if (_videoPlayerController?.value.hasError == true) {
      final error = _videoPlayerController?.value.errorDescription ?? 'Unknown video error';
      log('❌ Video player error: $error');
      _handleVideoError(Exception(error));
    }
  }

  void _handleVideoError(dynamic error) {
    // Log error but don't crash the app
    debugPrint('🎥 Video Error (Handled): $error');
    
    // Show user-friendly error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video playback error: ${_getUserFriendlyErrorMessage(error)}'),
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
    } else if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection issue';
    } else if (errorString.contains('format') || errorString.contains('codec')) {
      return 'Video format not supported';
    } else if (errorString.contains('permission')) {
      return 'Permission denied';
    } else {
      return 'Unable to play video';
    }
  }

  Future<void> _togglePlayPause() async {
    if (_videoPlayerController == null || !_isInitialized) return;
    
    // Unmute audio on first user interaction
    if (!_audioUnmuted) {
      // Try multiple approaches to ensure audio works
      await _videoPlayerController!.setVolume(1.0);
      
      // Wait a moment for the volume change to take effect
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Try setting volume again to ensure it sticks
      await _videoPlayerController!.setVolume(1.0);
      
      // Force a restart of playback to ensure audio takes effect
      final wasPlaying = _videoPlayerController!.value.isPlaying;
      if (wasPlaying) {
        await _videoPlayerController!.pause();
        await Future.delayed(const Duration(milliseconds: 50));
        await _videoPlayerController!.play();
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
      debugPrint('🔊 Video state - Playing: $isPlaying, Position: $position, Duration: $duration');
      
      // Note: Video should have audio if it was uploaded with audio
      log('🔊 Audio unmuting completed for video: ${widget.video.id}');
      debugPrint('🔊 Audio unmuting completed for video: ${widget.video.id}');
      
      // Audio is now auto-unmuted, no need for user feedback
    }
    
    if (_isPlaying) {
      _videoPlayerController!.pause();
      setState(() {
        _isPlaying = false;
      });
      
      // Track playback performance
      PerformanceService().trackVideoPlayback(widget.video.id, PlaybackEvent.pause);
    } else {
      _videoPlayerController!.play();
      setState(() {
        _isPlaying = true;
      });
      
      // Track playback performance
      PerformanceService().trackVideoPlayback(widget.video.id, PlaybackEvent.play);
      
      // Increment view count (only once per video)
      if (!_hasIncrementedView) {
        _hasIncrementedView = true;
        _incrementViewCount();
      }
    }
  }

  void _handleLikeChanged() {
    // Update the video's like state in the parent
    if (widget.homeViewModel.updateVideoLikeState != null) {
      widget.homeViewModel.updateVideoLikeState!(widget.video.id);
    }
    setState(() {});
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
      final analyticsRef = firestore.collection('video_analytics').doc(widget.video.id);
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

  void _handleLike() {
    // Handle like button tap
    HapticFeedback.lightImpact();
    _handleLikeChanged();
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
    final isCurrentlyFollowing = ref.read(followingProvider).followingList.contains(widget.video.creator.id);
    // Currently following: $isCurrentlyFollowing
    // Following list: ${ref.read(followingProvider).followingList}
    // Followers list: ${ref.read(followingProvider).followersList}
    
    EngagementAnalyticsService().trackEngagement(
      videoId: widget.video.id,
      event: isCurrentlyFollowing ? EngagementEvent.unfollow : EngagementEvent.follow,
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
      final isCurrentlyFollowing = ref.read(followingProvider).followingList.contains(widget.video.creator.id);
      
      if (isCurrentlyFollowing) {
        ref.read(followingProvider.notifier).unfollowUser(widget.video.creator.id);
        // Mock unfollowed: ${widget.video.creator.id}
      } else {
        ref.read(followingProvider.notifier).followUser(widget.video.creator.id);
        // Mock followed: ${widget.video.creator.id}
      }
    } catch (e) {
      // Mock follow error: $e
    }
  }

  void _handleTap() {
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();
    
    // Toggle play/pause with animation
    _togglePlayPause();
    
    // Show play/pause indicator animation
    _showPlayPauseIndicator();
  }

  void _handleDoubleTap() {
    // Double tap anywhere on video to like/unlike
    HapticFeedback.lightImpact();
    
    // Trigger the like button programmatically
    _triggerLikeButton();
  }
  
  void _handleDoubleTapDown(TapDownDetails details) {
    // Capture the tap position for floating hearts animation
    _lastTapPosition = details.globalPosition;
  }
  
  void _triggerLikeButton() {
    // Update the video's like state immediately
    if (widget.homeViewModel.updateVideoLikeState != null) {
      widget.homeViewModel.updateVideoLikeState!(widget.video.id);
    }
    
    // Update local state
    setState(() {
      // The OptimizedLikeButton will handle the actual like logic
      // We just need to trigger the visual update
    });
    
    // Trigger the like service directly
    _performLikeToggle();
  }
  
  Future<void> _performLikeToggle() async {
    try {
      // Import the LikeService
      final likeService = LikeService();
      
      // Toggle the like state
      await likeService.toggleLike(widget.video.id);
      
      // Track engagement
      likeService.trackLikeEngagement(widget.video.id, !widget.video.isLiked);
      
      // Create floating hearts animation if liking
      if (!widget.video.isLiked) {
        _createFloatingHearts();
      }
    } catch (e) {
      // Error toggling like: $e
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
  
  void _createFloatingHearts() {
    // Use the actual tap position for floating hearts animation
    final tapPosition = _lastTapPosition;
    
    // Create multiple hearts with staggered timing
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _showFloatingHeart(tapPosition);
        }
      });
    }
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
  
  void _showFloatingHeart(Offset position) {
    // Show a temporary floating heart overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => _FloatingHeartOverlay(position: position),
    );
    
    // Remove the overlay after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Listen for pause signal when leaving HomeView
        final homeState = ref.watch(homeProvider);
        
        // DEBUG: Log every state change
        log('🔍 Consumer: shouldPauseAllVideos=${homeState.shouldPauseAllVideos}, _lastShouldPauseAllVideos=$_lastShouldPauseAllVideos, controller=${_videoPlayerController != null}, initialized=$_isInitialized');
        log('🔍 GlobalController: shouldPauseAllVideos=${GlobalVideoController.shouldPauseAllVideos}, _lastGlobalShouldPauseAllVideos=$_lastGlobalShouldPauseAllVideos');
        
        // Check if we should pause all videos (when leaving HomeView)
        if (homeState.shouldPauseAllVideos && !_lastShouldPauseAllVideos && _videoPlayerController != null && _isInitialized) {
          _lastShouldPauseAllVideos = true;
          // IMMEDIATE pause - stops audio instantly
          // CRITICAL: Mute audio first, then pause video
          _videoPlayerController!.setVolume(0.0);
          _videoPlayerController!.pause();
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
        if (homeState.shouldResumeCurrentVideo && !_lastShouldResumeCurrentVideo && widget.isCurrentVideo && _videoPlayerController != null && _isInitialized) {
          _lastShouldResumeCurrentVideo = true;
          // IMMEDIATE resume - starts audio instantly
          _videoPlayerController!.setVolume(1.0);
          _videoPlayerController!.play();
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
        } else if (!homeState.shouldResumeCurrentVideo) {
          _lastShouldResumeCurrentVideo = false;
        }
        
        // ALSO check global controller for immediate response
        if (GlobalVideoController.shouldPauseAllVideos && !_lastGlobalShouldPauseAllVideos && _videoPlayerController != null && _isInitialized) {
          _lastGlobalShouldPauseAllVideos = true;
          // IMMEDIATE pause - stops audio instantly
          print('⏸️ Video paused due to GlobalVideoController: ${widget.video.id}');
          log('⏸️ Video paused due to GlobalVideoController: ${widget.video.id}');
          // CRITICAL: Mute audio first, then pause video
          _videoPlayerController!.setVolume(0.0);
          _videoPlayerController!.pause();
          // Update UI state after build completes (prevents setState error)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isPlaying = false);
            }
          });
        } else if (!GlobalVideoController.shouldPauseAllVideos) {
          _lastGlobalShouldPauseAllVideos = false;
        }
        
        // AGGRESSIVE TEST: Try to pause immediately if we detect any navigation
        // This is a temporary test to see if we can force pause
        if (_videoPlayerController != null && _isInitialized && _isPlaying) {
          // Check if we're not the current video (which might indicate navigation)
          if (!widget.isCurrentVideo) {
            log('🔍 AGGRESSIVE TEST: Video not current, attempting immediate pause: ${widget.video.id}');
            _videoPlayerController!.pause();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _isPlaying = false);
              }
            });
          }
        }
        
        // Check if we should resume current video (when returning to HomeView)
        if (GlobalVideoController.shouldResumeCurrentVideo && !_lastGlobalShouldResumeCurrentVideo && widget.isCurrentVideo && _videoPlayerController != null && _isInitialized) {
          _lastGlobalShouldResumeCurrentVideo = true;
          // IMMEDIATE resume - starts audio instantly
          _videoPlayerController!.setVolume(1.0);
          _videoPlayerController!.play();
          log('▶️ Video resumed due to GlobalVideoController: ${widget.video.id}');
          // Update UI state after build completes (prevents setState error)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isPlaying = true);
            }
          });
        } else if (!GlobalVideoController.shouldResumeCurrentVideo) {
          _lastGlobalShouldResumeCurrentVideo = false;
        }
        
        return GestureDetector(
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
          onDoubleTapDown: _handleDoubleTapDown,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Stack(
              children: [
                // TIKTOK-STYLE: Always show video player, no placeholder delay
                _buildVideoPlayer(),
                
                // UI Overlay
                _buildUIOverlay(),
                
                // Action buttons overlay
                _buildActionButtons(),
                
                // Play/Pause indicator overlay
                if (_showPlayPauseIndicatorOverlay) _buildPlayPauseIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildInstantThumbnail() {
    // TIKTOK-STYLE: Show thumbnail instantly, no loading indicators
    if (widget.video.thumbnailURL != null && widget.video.thumbnailURL!.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          widget.video.thumbnailURL!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          // No loading builder - show immediately
          errorBuilder: (context, error, stackTrace) {
            debugPrint('⚠️ VideoPlayer: Failed to load thumbnail: $error');
            return _buildGradientPlaceholder();
          },
          // Optimize for instant display
          cacheWidth: 400,
          cacheHeight: 400,
          filterQuality: FilterQuality.medium,
        ),
      );
    } else {
      return _buildGradientPlaceholder();
    }
  }

  Widget _buildGradientPlaceholder() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF2D2D2D),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // TIKTOK-STYLE: Show video immediately or use thumbnail as instant fallback
    if (_videoPlayerController == null || !_isInitialized) {
      // Show thumbnail immediately while video loads in background
      return _buildInstantThumbnail();
    }
    
    return Positioned.fill(
      child: FittedBox(
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
    const paddingAboveNav = 50.0; // Match right action buttons TikTok-style spacing
    
    // Position caption block right above bottom navigation
    final bottomPosition = safeBottom + navHeight + paddingAboveNav;
    
    return Positioned(
      left: leftInset,
      right: rightInset,
      bottom: bottomPosition,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.25, // Use maxHeight instead of fixed height
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
                    final isFollowing = ref.watch(followingProvider).followingList.contains(widget.video.creator.id);
                    return GestureDetector(
                      onTap: () => _handleFollow(ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isFollowing ? null : const LinearGradient(
                            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)], // Match ProfileView edit button
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
    const paddingAboveNav = 112.0; // TikTok-style large padding above bottom nav
    
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
          // Like button
          _buildActionButton(
            icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
            count: widget.video.likes.toString(),
            onTap: _handleLike,
            isActive: widget.isLiked,
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
                : (widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border),
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
    const btnSize = 52.0; // Increased from 44.0 to 52.0 to match _buildActionButtons
    return SizedBox(
      width: btnSize,
      height: btnSize,
      child: InkWell(
        onTap: onTap != null ? () {
          HapticFeedback.lightImpact();
          onTap();
        } : null,
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
                        isActive ? const Color(0xFF9248D2) : Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: isActive ? const Color(0xFF9248D2) : Colors.white.withValues(alpha: 0.85),
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