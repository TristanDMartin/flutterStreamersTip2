import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/home_video.dart';
import '../providers/home_provider.dart';
import '../providers/following_provider.dart';
import '../services/performance_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/robust_auth_service.dart';
import '../services/like_service.dart';
import '../widgets/action_button.dart';
import '../widgets/optimized_like_button.dart';
import '../widgets/comments_view_optimized.dart';
import '../widgets/optimized_favorite_button.dart';
import '../widgets/optimized_share_button.dart';

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
  });

  @override
  ConsumerState<VideoPlayerViewOptimized> createState() => _VideoPlayerViewOptimizedState();
}

class _VideoPlayerViewOptimizedState extends ConsumerState<VideoPlayerViewOptimized> {
  VideoPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasIncrementedView = false;
  
  // Like state - simplified
  final GlobalKey _likeIconKey = GlobalKey();
  
  // Track last tap position for floating hearts
  Offset _lastTapPosition = Offset.zero;
  
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    // Track performance
    PerformanceService().trackVideoPlayback(widget.video.id, PlaybackEvent.pause);
    
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    // Start performance tracking
    PerformanceService().startVideoLoad(widget.video.id);
    
    try {
      // Create new controller
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoURL));
      await _videoPlayerController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = widget.isCurrentVideo;
        });
        
        if (_isPlaying) {
          _videoPlayerController!.play();
        }
        
        // Complete performance tracking
        PerformanceService().completeVideoLoad(widget.video.id, success: true);
      }
    } catch (e) {
      // Error initializing video: $e
      PerformanceService().completeVideoLoad(widget.video.id, success: false);
    }
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null || !_isInitialized) return;
    
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
        // TODO: Implement view increment logic
        // Incrementing view for video: ${widget.video.id}
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

  void _handleFavoriteChanged() {
    // Optional callback when favorite state changes
    setState(() {});
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
    _togglePlayPause();
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
    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      onDoubleTapDown: _handleDoubleTapDown,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Video player - Full screen
            if (_isInitialized && _videoPlayerController != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover, // This ensures the video covers the entire screen
                  child: SizedBox(
                    width: _videoPlayerController!.value.size.width,
                    height: _videoPlayerController!.value.size.height,
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                ),
              ),
            
            // UI Overlay
            _buildUIOverlay(),
            
            // Action buttons overlay
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildUIOverlay() {
    // Position bottom info block above bottom navigation
    const bottomNavH = 92.0; // bottom tab bar height
    const railWidth = 64.0; // action rail width
    
    return Positioned(
      left: 12,
      right: railWidth + 16, // leave room for the rail
      bottom: bottomNavH + 12, // just above the tab bar
      child: Padding(
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
                    child: CircleAvatar(
                      radius: 16, // Smaller radius as specified
                      backgroundImage: NetworkImage(widget.video.creator.avatarURL ?? ''),
                    ),
                  ),
                  const SizedBox(width: 8), // 8-12pt gap as specified
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
                  const SizedBox(width: 8), // 8-12pt gap as specified
                  // Follow pill next to username
                  Consumer(
                    builder: (context, ref, child) {
                      final isFollowing = ref.watch(followingProvider).followingList.contains(widget.video.creator.id);
                      return GestureDetector(
                        onTap: () => _handleFollow(ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isFollowing ? Colors.grey[600] : const Color(0xFF9248D2),
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height - 92.0 - MediaQuery.of(context).padding.bottom - 100, // bottomNavH + safeArea + creatorRowHeight + extra padding
                ),
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
    // Position action rail in middle third of screen
    final screenHeight = MediaQuery.of(context).size.height;
    final topPosition = screenHeight * 0.30; // ~upper-middle as specified
    
    return Positioned(
      right: 12, // 12-16 as specified
      top: topPosition,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
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
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (BuildContext context) {
                  return CommentsViewOptimized(videoId: widget.video.id);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          OptimizedFavoriteButton(
            videoId: widget.video.id,
            initialIsFavorited: widget.video.isFavorited,
            onFavoriteChanged: _handleFavoriteChanged,
            size: 24,
            activeColor: const Color(0xFF9248D2),
            inactiveColor: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 16),
          OptimizedShareButton(
            video: widget.video,
            size: 24,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ],
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
