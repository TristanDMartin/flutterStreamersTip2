import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../services/unified_avatar_service.dart';
import '../widgets/comments_view_optimized.dart';
import '../widgets/streamer_share_sheet.dart';

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
  
  // Track last tap position for floating hearts
  Offset _lastTapPosition = Offset.zero;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    
    // React when the page becomes current/non-current
    if (oldWidget.isCurrentVideo != widget.isCurrentVideo) {
      if (widget.isCurrentVideo) {
        _videoPlayerController!.play();
        setState(() => _isPlaying = true);
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
          _videoPlayerController!.play();
          setState(() => _isPlaying = true);
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
        
        // Test network connectivity before attempting to load
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 5);
          final request = await client.getUrl(videoUri);
          final response = await request.close();
          client.close();
          
          if (response.statusCode != 200) {
            throw Exception('Video server returned status: ${response.statusCode}');
          }
        } catch (e) {
          throw Exception('Network connectivity test failed: $e');
        }
      
      // Try warm controller first (TikTok style)
      _videoPlayerController = VideoPerformanceService().getReady(widget.video.videoURL);
      
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
                const Duration(seconds: 30), // Increased timeout from 10 to 30 seconds
                onTimeout: () {
                  throw Exception('Video initialization timeout - server may be slow');
                },
              );
            }
        
        await _videoPlayerController!.setLooping(true);
        await _videoPlayerController!.setVolume(0); // Start muted for autoplay compliance
      }
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = widget.isCurrentVideo;
        });
        
        // Small delay to ensure smooth transition
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (_isPlaying && mounted) {
          _videoPlayerController!.play();
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

  void _handleFavoriteChanged() {
    // Optional callback when favorite state changes
    setState(() {});
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
        return CommentsViewOptimized(videoId: widget.video.id);
      },
    );
  }

  void _handleBookmark() {
    // Handle bookmark button tap
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
          onDismiss: () => Navigator.of(context).pop(),
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
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            // Video player with optimized rendering
            _isInitialized && _videoPlayerController != null
                ? _buildVideoPlayer()
                : _buildPosterPlaceholder(),
            
            // UI Overlay
            _buildUIOverlay(),
            
            // Action buttons overlay
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    // Use thumbnail if available, otherwise show gradient
    if (widget.video.thumbnailURL != null && widget.video.thumbnailURL!.isNotEmpty) {
      return Image.network(
        widget.video.thumbnailURL!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('⚠️ VideoPlayer: Failed to load thumbnail: $error');
          return _buildLoadingPlaceholder();
        },
        // Optimize memory usage
        cacheWidth: 400,
        cacheHeight: 400,
        filterQuality: FilterQuality.medium,
      );
    } else {
      return _buildLoadingPlaceholder();
    }
  }

  Widget _buildLoadingPlaceholder() {
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
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            strokeWidth: 2,
          ),
        ),
      ),
    );
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
    if (_videoPlayerController == null) return _buildGradientPlaceholder();
    
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
    
    // Constants
    const navHeight = 72.0;
    const railWidth = 64.0;
    const leftInset = 12.0;
    const rightInset = railWidth + 16;
    
    // Position caption block directly above bottom navigation
    final bottomPosition = safeBottom + navHeight + 35.0;
    
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
                  child: UnifiedAvatarService().getAvatar(
                    imageUrl: widget.video.creator.avatarURL ?? '',
                    radius: 16,
                  ),
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
    
    // Button specifications
    const btnSize = 44.0;
    const gap = 16.0;
    const count = 4;
    const groupHeight = (count * btnSize) + ((count - 1) * gap);
    
    // Calculate position - TikTok style (higher up on screen)
    const rightInset = 12.0;
    const targetCenterY = 0.70; // 65% from top of screen
    
    final screenHeight = media.size.height;
    final desiredCenterY = screenHeight * targetCenterY;
    final top = (desiredCenterY - groupHeight / 2).clamp(0.0, screenHeight - groupHeight);
    
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
          
          // Bookmark button
          _buildActionButton(
            icon: widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            count: widget.video.isFavorited ? '1' : '0',
            onTap: _handleBookmark,
            isActive: widget.isBookmarked,
          ),
          const SizedBox(height: 16),
          
          // Share button
          _buildActionButton(
            icon: Icons.share,
            count: 'Share',
            onTap: _handleShare,
          ),
          const SizedBox(height: 16),
          
          // Creator avatar
          GestureDetector(
            onTap: widget.onShowProfile,
            child: UnifiedAvatarService().getAvatar(
              imageUrl: widget.video.creator.avatarURL ?? '',
              radius: 20,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    const btnSize = 44.0;
    return SizedBox(
      width: btnSize,
      height: btnSize,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(btnSize / 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF9248D2) : Colors.white.withValues(alpha: 0.85),
              size: 24,
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