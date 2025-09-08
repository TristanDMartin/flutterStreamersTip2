import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/home_video.dart';
import '../providers/home_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/following_provider.dart';
import '../services/performance_service.dart';
import '../services/video_cache_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/robust_auth_service.dart';

import 'action_button.dart';
import 'video_thumbnail_widget.dart';
import 'optimized_like_button.dart';

class VideoPlayerView extends ConsumerStatefulWidget {
  final HomeVideo video;
  final bool isCurrentVideo;
  final bool isFirstVideo;
  final HomeViewModel homeViewModel;
  final bool showSheet;
  final String sheetType;
  
  // Action callbacks
  final VoidCallback onShowProfile;
  final VoidCallback onShowComments;
  final VoidCallback onShowShare;
  final VoidCallback onShowStreamerCard;
  
  const VideoPlayerView({
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
  });

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlaying = false;

  // Removed _isLoading as it's not used with thumbnail loading
  bool _hasIncrementedView = false;
  
  // Local state for UI
  // Like state - simplified
  final GlobalKey _likeIconKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    // Track performance
    PerformanceService().trackVideoPlayback(widget.video.id, PlaybackEvent.pause);
    
    // Dispose video controller
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    
    // Clear any pending animations
    // Note: Animation controllers are disposed by the widget lifecycle
    
    // Cleanup complete
    
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    // Start performance tracking
    PerformanceService().startVideoLoad(widget.video.id);
    
    try {
      // Check cache first
      final cacheService = VideoCacheService();
      await cacheService.initialize();
      
      File? cachedVideo;
      if (cacheService.isVideoCached(widget.video.videoURL)) {
        cachedVideo = cacheService.getCachedVideo(widget.video.videoURL);
        print('📦 Using cached video: ${widget.video.id}');
      }
      
      // Initialize video controller
      if (cachedVideo != null) {
        _videoPlayerController = VideoPlayerController.file(cachedVideo);
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.video.videoURL),
        );
      }
      
      await _videoPlayerController!.initialize();
      
      // Cache the video for future use
      if (cachedVideo == null) {
        // Note: In a real implementation, you'd want to download and cache the video
        // For now, we'll just track that we loaded it
        print('📦 Video loaded from network: ${widget.video.id}');
      }
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        // Set up video looping
        _videoPlayerController!.addListener(() {
          if (_videoPlayerController!.value.position >= _videoPlayerController!.value.duration) {
            // Track video completion engagement
            EngagementAnalyticsService().trackEngagement(
              videoId: widget.video.id,
              event: EngagementEvent.videoComplete,
              metadata: {
                'timestamp': DateTime.now().toIso8601String(),
                'watchTime': 1.0, // 100% completion
                'videoDuration': _videoPlayerController!.value.duration.inSeconds,
              },
            );
            
            _videoPlayerController!.seekTo(Duration.zero);
            _videoPlayerController!.play();
          }
        });
        
        // Start playing if this is the current video
        if (widget.isCurrentVideo) {
          _playVideo();
        }
      }
      
      // Complete performance tracking
      PerformanceService().completeVideoLoad(widget.video.id, success: true);
    } catch (e) {
      print('Error initializing video: $e');
      PerformanceService().completeVideoLoad(widget.video.id, success: false);
      
      if (mounted) {
        setState(() {
          // Video initialization failed
        });
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isCurrentVideo != oldWidget.isCurrentVideo) {
      if (widget.isCurrentVideo) {
        _playVideo();
        _incrementViewIfNeeded();
      } else {
        _pauseVideo();
        _muteVideo();
      }
    }
  }

  void _playVideo() {
    if (_videoPlayerController != null && _isInitialized) {
      _videoPlayerController!.play();
      setState(() {
        _isPlaying = true;
      });
      
      // Track playback performance
      PerformanceService().trackVideoPlayback(widget.video.id, PlaybackEvent.play);
      
      // Track video view engagement
      EngagementAnalyticsService().trackEngagement(
        videoId: widget.video.id,
        event: EngagementEvent.videoView,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'videoDuration': _videoPlayerController?.value.duration.inSeconds ?? 0,
        },
      );
    }
  }

  void _pauseVideo() {
    if (_videoPlayerController != null && _isInitialized) {
      _videoPlayerController!.pause();
      setState(() {
        _isPlaying = false;
      });
      
      // Track playback performance
      PerformanceService().trackVideoPlayback(widget.video.id, PlaybackEvent.pause);
    }
  }

  void _muteVideo() {
    if (_videoPlayerController != null && _isInitialized) {
      _videoPlayerController!.setVolume(0.0);
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _incrementViewIfNeeded() {
    if (!_hasIncrementedView && widget.isCurrentVideo) {
      _hasIncrementedView = true;
      // TODO: Implement view increment logic
      print('Incrementing view for video: ${widget.video.id}');
    }
  }

  void _handleLikeChanged() {
    // Optional callback when like state changes
    setState(() {});
  }

  void _handleFavorite() {
    // Immediate haptic feedback
    HapticFeedback.lightImpact();
    
    // Use the new favorites system with instant response
    ref.read(favoritesProvider.notifier).toggleFavorite(widget.video.id);
    
    // Track favorite/unfavorite engagement
    final isCurrentlyFavorited = ref.read(favoritesProvider).favorites.contains(widget.video.id);
    EngagementAnalyticsService().trackEngagement(
      videoId: widget.video.id,
      event: isCurrentlyFavorited ? EngagementEvent.unfavorite : EngagementEvent.favorite,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _handleFollow(WidgetRef ref) {
    print('🔔 Follow button tapped for creator: ${widget.video.creator.id}');
    HapticFeedback.lightImpact();
    
    // Check if user is authenticated
    final auth = FirebaseAuth.instance;
    final robustAuth = ref.read(robustAuthServiceProvider);
    
    print('🔔 Current user ID: ${robustAuth.currentUser?.id}');
    print('🔔 Firebase Auth user: ${auth.currentUser?.uid}');
    
    // Check if we're in bypass mode (mock user)
    if (robustAuth.currentUser?.id == 'dev_user_123') {
      print('🔔 Using mock follow functionality for development');
      _handleMockFollow(ref);
      return;
    } else {
      print('🔔 Using real Firebase follow functionality');
    }
    
    if (auth.currentUser == null) {
      print('🔔 User not authenticated, cannot follow');
      return;
    }
    
    // Track follow/unfollow engagement
    final isCurrentlyFollowing = ref.read(followingProvider).followingList.contains(widget.video.creator.id);
    print('🔔 Currently following: $isCurrentlyFollowing');
    print('🔔 Following list: ${ref.read(followingProvider).followingList}');
    print('🔔 Followers list: ${ref.read(followingProvider).followersList}');
    
    EngagementAnalyticsService().trackEngagement(
      videoId: widget.video.id,
      event: isCurrentlyFollowing ? EngagementEvent.unfollow : EngagementEvent.follow,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
        'creatorId': widget.video.creator.id,
      },
    );
    
    // Toggle follow and refresh the state
    ref.read(followingProvider.notifier).toggleFollow(widget.video.creator.id).then((success) {
      print('🔔 Follow toggle result: $success');
      if (success) {
        print('🔔 Follow toggle successful, updating UI');
        // Force a rebuild to update the UI
        if (mounted) {
          setState(() {});
        }
      } else {
        print('🔔 Follow toggle failed');
      }
    }).catchError((error) {
      print('🔔 Follow toggle error: $error');
    });
  }

  void _handleMockFollow(WidgetRef ref) async {
    print('🔔 Mock follow handler called');
    
    try {
      final robustAuth = ref.read(robustAuthServiceProvider.notifier);
      final isCurrentlyFollowing = ref.read(followingProvider).followingList.contains(widget.video.creator.id);
      
      print('🔔 Currently following: $isCurrentlyFollowing');
      
      // Use mock follow/unfollow
      bool success;
      if (isCurrentlyFollowing) {
        success = await robustAuth.mockUnfollowUser(widget.video.creator.id);
      } else {
        success = await robustAuth.mockFollowUser(widget.video.creator.id);
      }
      
      if (success) {
        print('🔔 Mock follow/unfollow successful, updating UI');
        
        // Update the following list locally for UI
        if (isCurrentlyFollowing) {
          ref.read(followingProvider.notifier).removeFromFollowingList(widget.video.creator.id);
        } else {
          ref.read(followingProvider.notifier).addToFollowingList(widget.video.creator.id);
        }
        
        // Force a rebuild to update the UI
        if (mounted) {
          setState(() {});
        }
      } else {
        print('🔔 Mock follow/unfollow failed');
      }
    } catch (e) {
      print('🔔 Mock follow error: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      onPanEnd: (details) {
        // Swipe up gesture to open StreamerCardView
        if (details.velocity.pixelsPerSecond.dy < -1000 && 
            details.velocity.pixelsPerSecond.dx.abs() < 500) {
          print('🔔 Swipe up detected, calling onShowStreamerCard');
          widget.onShowStreamerCard();
        }
      },
      child: Stack(
        children: [
          // Video Player Background
          if (_isInitialized && _videoPlayerController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoPlayerController!.value.size.width,
                  height: _videoPlayerController!.value.size.height,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            )
          else
            // Show thumbnail while loading
            VideoThumbnailWidget(
              videoUrl: widget.video.videoURL,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Loading video...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              errorWidget: Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Error loading video",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Pause indicator overlay
          if (!_isPlaying && widget.isCurrentVideo)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
          
          // Main UI Overlay
          _buildUIOverlay(),
          
          // Swipe up indicator
          _buildSwipeUpIndicator(),
          
          // Action buttons overlay
          _buildActionButtons(),
          
        ],
      ),
    );
  }

  Widget _buildUIOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Creator info and follow button
              Consumer(
                builder: (context, ref, child) {
                  final followingState = ref.watch(followingProvider);
                  final isFollowing = followingState.followingList.contains(widget.video.creator.id);
                  final isFollowedBy = followingState.followersList.contains(widget.video.creator.id);
                  final followRelationship = isFollowing 
                      ? (isFollowedBy 
                          ? FollowRelationship.connected 
                          : FollowRelationship.following)
                      : FollowRelationship.notFollowing;
                  final isLoading = followingState.isLoading;
                  
                  print('🔔 Follow state for ${widget.video.creator.id}: following=$isFollowing, followedBy=$isFollowedBy, relationship=$followRelationship');
                  
                  return Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onShowProfile,
                        child: Text(
                          "@${widget.video.creator.username}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Follow button - show different states based on relationship
                      if (followRelationship == FollowRelationship.notFollowing)
                        GestureDetector(
                          onTap: isLoading ? null : () {
                            print('🔔 Follow button onTap called');
                            _handleFollow(ref);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9248D2), Color(0xFF7768DF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    "Follow",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      // Show "Following" if one-way follow
                      if (followRelationship == FollowRelationship.following)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF9248D2),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            "Following",
                            style: TextStyle(
                              color: Color(0xFF9248D2),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      // Show "Connected" if mutual follow
                      if (followRelationship == FollowRelationship.connected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1670de), Color(0xFF3c8bd6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            "Connected",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // Caption
              Text(
                widget.video.caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Consumer(
      builder: (context, ref, child) {
        final favoritesState = ref.watch(favoritesProvider);
        final isFavorited = favoritesState.favorites.contains(widget.video.id);
        final isFavoriteLoading = favoritesState.isLoading;
        
        return Positioned(
          right: 16,
          bottom: 120, // Move up to avoid covering description
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom - 220, // Reduced height
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OptimizedLikeButton(
                      videoId: widget.video.id,
                      initialLikeCount: widget.video.likes,
                      initialIsLiked: widget.video.isLiked,
                      onLikeChanged: _handleLikeChanged,
                      iconKey: _likeIconKey,
                    ),
                      const SizedBox(height: 16),
                      ActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: widget.video.comments.toString(),
                        isActive: false,
                        onTap: widget.onShowComments,
                      ),
                      const SizedBox(height: 16),
                      ActionButton(
                        icon: isFavoriteLoading 
                            ? Icons.bookmark 
                            : (isFavorited ? Icons.bookmark : Icons.bookmark_border),
                        label: "Save",
                        isActive: isFavorited,
                        onTap: isFavoriteLoading ? () {} : _handleFavorite,
                        isLoading: isFavoriteLoading,
                        color: isFavorited ? const Color(0xFF9248D2) : Colors.white.withValues(alpha: 0.85),
                        useGradient: isFavorited,
                      ),
                      const SizedBox(height: 16),
                      ActionButton(
                        icon: Icons.share,
                        label: "Share",
                        isActive: false,
                        onTap: widget.onShowShare,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildSwipeUpIndicator() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Swipe up for profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    _togglePlayPause();
  }

  void _handleDoubleTap() {
    // Simple double tap - just trigger like if not already liked
    // The OptimizedLikeButton will handle the actual like logic
    HapticFeedback.lightImpact();
  }
}

