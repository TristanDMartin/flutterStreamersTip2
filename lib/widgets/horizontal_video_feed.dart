import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_video.dart';
import '../providers/home_provider.dart' as hp;
import '../models/user.dart';
import 'video_player_view_optimized.dart';
import 'loading_more_view.dart';
import 'end_of_feed_view.dart';
import 'dart:async'; // Added for Timer

enum FeedType { following, forYou }

class HorizontalVideoFeed extends ConsumerStatefulWidget {
  final List<HomeVideo> videos;
  final int currentVideoIndex;
  final hp.HomeViewModel homeViewModel;
  final FeedType feedType;
  
  // Callbacks for all user interactions in the feed
  final Function(User) onShowProfile;
  final Function(HomeVideo) onShowComments;
  final Function(HomeVideo) onShowShare;
  
  // Floating comments state (only used in ProfileView context)
  final bool showFloatingComments;
  
  final Function(int) onVideoIndexChanged;
  
  const HorizontalVideoFeed({
    super.key,
    required this.videos,
    required this.currentVideoIndex,
    required this.homeViewModel,
    required this.feedType,
    required this.onShowProfile,
    required this.onShowComments,
    required this.onShowShare,
    this.showFloatingComments = false,
    required this.onVideoIndexChanged,
  });

  @override
  ConsumerState<HorizontalVideoFeed> createState() => _HorizontalVideoFeedState();
}

class _HorizontalVideoFeedState extends ConsumerState<HorizontalVideoFeed>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _floatingAnimationController;
  
  // Performance optimizations
  int _lastLoadMoreIndex = -1;
  // final bool _isPreloading = false; // Unused field commented out
  
  // StreamerCard state - moved to parent level to persist across video changes
  // final bool _showStreamerCard = false; // Unused field commented out
  // StreamerCard? _currentStreamerCard; // Unused field commented out
  final bool _showSheet = false;
  final String _sheetType = 'share'; // 'share' or 'comments'
  
  // Floating comments state
  final List<FloatingComment> _floatingComments = [];
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentVideoIndex);
    _floatingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // For demo/testing: add a floating comment every 3 seconds
    if (widget.showFloatingComments) {
      Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          _addFloatingComment(
            author: "DemoUser", 
            text: "🔥 Awesome video!", 
            avatarURL: null,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main video feed with PageView
        PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _getItemCount(),
          itemBuilder: (context, index) {
            if (index < widget.videos.length) {
              final video = widget.videos[index];
              return VideoPlayerViewOptimized(
                video: video,
                isCurrentVideo: index == widget.currentVideoIndex,
                isFirstVideo: index == 0,
                homeViewModel: widget.homeViewModel,
                showSheet: _showSheet,
                sheetType: _sheetType,
                onShowProfile: () => widget.onShowProfile(video.creator),
                onShowComments: () => widget.onShowComments(video),
                onShowShare: () => widget.onShowShare(video),
                onShowStreamerCard: () {
                  // TODO: Present streamer card page
                },
                isLiked: video.isLiked,
                isBookmarked: video.isFavorited,
              );
            } else if (index == widget.videos.length && widget.homeViewModel.isLoadingMore) {
              // Loading indicator at the end when loading more content
              return const LoadingMoreView();
            } else if (index == widget.videos.length && !widget.homeViewModel.hasMoreContent && !widget.homeViewModel.isLoadingMore && widget.videos.isNotEmpty) {
              // End of feed indicator when no more content
              return const EndOfFeedView();
            }
            
            return const SizedBox.shrink();
          },
        ),
        
        // Centered loading overlay
        if (widget.homeViewModel.isLoading)
          _buildLoadingOverlay(),
        
        // Floating comments overlay (ProfileView context)
        if (widget.showFloatingComments)
          _buildFloatingCommentsOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha:0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:0.8),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Loading...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCommentsOverlay() {
    return Positioned(
      bottom: 60, // Position above tab bar
      left: 0,
      right: 0,
      child: Column(
        children: _floatingComments.map((comment) {
          return Padding(
            padding: EdgeInsets.only(bottom: comment.offset),
            child: FloatingCommentView(comment: comment),
          );
        }).toList(),
      ),
    );
  }

  int _getItemCount() {
    int count = widget.videos.length;
    
    if (widget.homeViewModel.isLoadingMore) {
      count++; // Add loading indicator
    } else if (!widget.homeViewModel.hasMoreContent && !widget.homeViewModel.isLoadingMore && widget.videos.isNotEmpty) {
      count++; // Add end of feed indicator
    }
    
    return count;
  }

  void _onPageChanged(int index) {
    widget.onVideoIndexChanged(index);
    
    // Check if we need to load more content
    final hp.FeedType providerFeed = widget.feedType == FeedType.forYou
        ? hp.FeedType.forYou
        : hp.FeedType.following;
    if (widget.homeViewModel.shouldLoadMoreContent(index, providerFeed)) {
      if (index != _lastLoadMoreIndex) {
        _lastLoadMoreIndex = index;
        _loadMoreContent(index);
      }
    }
    
    // Preload adjacent videos
    _preloadAdjacentVideos(index);
  }

  Future<void> _loadMoreContent(int index) async {
    final hp.FeedType providerFeed = widget.feedType == FeedType.forYou
        ? hp.FeedType.forYou
        : hp.FeedType.following;
    await widget.homeViewModel.loadMoreVideosIfNeeded(
      currentIndex: index,
      feed: providerFeed,
    );
  }

  void _preloadAdjacentVideos(int currentIndex) {
    // Simplified preloading - only preload next video
    final nextIndex = currentIndex + 1;
    if (nextIndex < widget.videos.length) {
      // final video = widget.videos[nextIndex];
      // TODO: Implement video preloading logic
    // print('Preloading video: ${video.id}');
    }
  }

  void _addFloatingComment({
    required String author,
    required String text,
    String? avatarURL,
  }) {
    final comment = FloatingComment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: author,
      text: text,
      avatarURL: avatarURL,
      offset: 0,
    );
    
    setState(() {
      _floatingComments.add(comment);
    });
    
    // Animate the comment
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          final index = _floatingComments.indexWhere((c) => c.id == comment.id);
          if (index != -1) {
            _floatingComments[index] = _floatingComments[index].copyWith(offset: 40);
          }
        });
      }
    });
    
    // Remove comment after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _floatingComments.removeWhere((c) => c.id == comment.id);
        });
      }
    });
  }
}

// Floating comment model
class FloatingComment {
  final String id;
  final String author;
  final String text;
  final String? avatarURL;
  final double offset;
  
  FloatingComment({
    required this.id,
    required this.author,
    required this.text,
    this.avatarURL,
    required this.offset,
  });
  
  FloatingComment copyWith({
    String? id,
    String? author,
    String? text,
    String? avatarURL,
    double? offset,
  }) {
    return FloatingComment(
      id: id ?? this.id,
      author: author ?? this.author,
      text: text ?? this.text,
      avatarURL: avatarURL ?? this.avatarURL,
      offset: offset ?? this.offset,
    );
  }
}

// Floating comment view
class FloatingCommentView extends StatelessWidget {
  final FloatingComment comment;
  
  const FloatingCommentView({
    super.key,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          if (comment.avatarURL != null)
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(comment.avatarURL!),
            )
          else
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  comment.author.isNotEmpty ? comment.author[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          const SizedBox(width: 8),
          
          // Comment text
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha:0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  comment.author,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// StreamerCard model (placeholder)
class StreamerCard {
  final User creator;
  
  StreamerCard({required this.creator});
  
  factory StreamerCard.from(User creator) {
    return StreamerCard(creator: creator);
  }
}
