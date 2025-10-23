import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/video_service_provider.dart';
import 'video_player_view_optimized.dart';
import 'insights_view.dart';
import 'video_options_bottom_sheet.dart';

enum PlayerMode {
  homeFeed,
  favorites,
}

class PlayerScreen extends ConsumerStatefulWidget {
  final PlayerMode mode;
  final int initialIndex;
  final List<String> videoIds;
  final List<HomeVideo>? videos; // For home feed mode

  const PlayerScreen({
    super.key,
    required this.mode,
    required this.initialIndex,
    required this.videoIds,
    this.videos,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late PageController _pageController;
  late List<HomeVideo> _videos;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Video controllers are disposed by their respective VideoPlayerViewSimple widgets
    super.dispose();
  }

  Future<void> _loadVideos() async {
    debugPrint(
        '🎬 PlayerScreen: Loading videos - mode: ${widget.mode}, videoIds: ${widget.videoIds}, videos: ${widget.videos?.length ?? 0}');

    if (widget.mode == PlayerMode.favorites) {
      final videoService = ref.read(videoServiceProvider);
      _videos = await videoService.getVideosByIds(widget.videoIds);
      debugPrint(
          '🎬 PlayerScreen: Loaded ${_videos.length} videos from favorites');
    } else {
      _videos = widget.videos ?? [];
      debugPrint(
          '🎬 PlayerScreen: Using provided videos: ${_videos.length} videos');

      if (_videos.isEmpty) {
        debugPrint(
            '⚠️ PlayerScreen: No videos provided! widget.videos is null or empty');
        debugPrint('🎬 PlayerScreen: widget.videos = ${widget.videos}');
        debugPrint('🎬 PlayerScreen: widget.videoIds = ${widget.videoIds}');
      }
    }

    setState(() {}); // Trigger rebuild to show videos
  }

  void _onVideoChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Build HUD elements with proper screen edge anchoring (same as HomeView)
  List<Widget> _buildHUDElements(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeBottom = media.viewPadding.bottom;
    final safeTop = media.viewPadding.top;

    // Constants - TikTok-style spacing
    const railWidth = 64.0;
    const leftInset = 12.0;
    const rightInset = railWidth + 16;
    const paddingAboveNav =
        50.0; // Match right action buttons TikTok-style spacing

    // Position caption block right above bottom navigation
    final bottomPosition = safeBottom + paddingAboveNav;

    return [
      // Back button - top left
      Positioned(
        top: safeTop + 16,
        left: 16,
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),

      // Action rail - right edge
      Positioned(
        right: 12,
        bottom: safeBottom + paddingAboveNav,
        child: _buildActionRail(context),
      ),

      // Caption block - bottom left (screen edge anchored)
      Positioned(
        left: leftInset,
        right: rightInset,
        bottom: bottomPosition,
        child: _buildCaptionBlock(context),
      ),
    ];
  }

  /// Build action rail (like, comment, bookmark, share, more options)
  Widget _buildActionRail(BuildContext context) {
    const gap = 16.0;
    final currentUser = fa.FirebaseAuth.instance.currentUser;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like button
        _buildActionButton(
          icon: Icons.favorite_border,
          count: _videos.isNotEmpty
              ? _videos[_currentIndex].likes.toString()
              : '0',
          onTap: () {
            // TODO: Implement like functionality
          },
        ),
        const SizedBox(height: gap),

        // Comment button
        _buildActionButton(
          icon: Icons.chat_bubble_outline,
          count: _videos.isNotEmpty
              ? _videos[_currentIndex].comments.toString()
              : '0',
          onTap: () {
            // TODO: Implement comment functionality
          },
        ),
        const SizedBox(height: gap),

        // Bookmark button
        _buildActionButton(
          icon: Icons.bookmark_border,
          count: '0',
          onTap: () {
            // TODO: Implement bookmark functionality
          },
        ),
        const SizedBox(height: gap),

        // Share button
        _buildActionButton(
          icon: Icons.share,
          count: 'Share',
          onTap: () {
            // TODO: Implement share functionality
          },
        ),
        const SizedBox(height: gap),

        // More Options button (context-aware)
        _buildActionButton(
          icon: Icons.more_horiz,
          count: '',
          onTap: () => _showMoreOptions(context, currentUser),
        ),
      ],
    );
  }

  /// Build individual action button
  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build caption block with username and video caption
  Widget _buildCaptionBlock(BuildContext context) {
    if (_videos.isEmpty) return const SizedBox.shrink();

    final video = _videos[_currentIndex];
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    final isCurrentUser = currentUser?.uid == video.creator.id;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.25,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Creator row: avatar + username + follow pill (only for non-owner posts)
          if (!isCurrentUser) ...[
            Row(
              children: [
                // User avatar
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to user profile
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: video.creator.avatarURL != null
                        ? NetworkImage(video.creator.avatarURL!)
                        : null,
                    child: video.creator.avatarURL == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Username
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      // TODO: Navigate to user profile
                    },
                    child: Text(
                      '@${video.creator.username}',
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
                // Follow pill
                GestureDetector(
                  onTap: () {
                    // TODO: Implement follow functionality
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Video caption
          Flexible(
            child: Text(
              video.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.2,
              ),
            ),
          ),

          if (isCurrentUser) ...[
            const SizedBox(height: 12),
            _buildBottomInfoRow(context, video),
          ],
        ],
      ),
    );
  }

  /// Build bottom info row with Insights button and views counter (owner posts only)
  Widget _buildBottomInfoRow(BuildContext context, HomeVideo video) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Insights button
        GestureDetector(
          onTap: () => _openInsights(context, video),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Views counter
        _buildViewsCounter(video),
      ],
    );
  }

  /// Build views counter for owner posts
  Widget _buildViewsCounter(HomeVideo video) {
    // TODO: Get real views count from analytics
    final viewsCount = video.views; // Use video.views for now
    final formattedViews = _formatViewsCount(viewsCount);

    return Text(
      '$formattedViews views',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  /// Format views count (e.g., 1.2K, 2.3M)
  String _formatViewsCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  /// Open Insights view for the current video
  void _openInsights(BuildContext context, HomeVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InsightsView(
          videoId: video.id,
          videoTitle:
              video.caption.isNotEmpty ? video.caption : 'Untitled Video',
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Show More Options bottom sheet
  void _showMoreOptions(BuildContext context, fa.User? currentUser) async {
    if (_videos.isEmpty || currentUser == null) return;
    final video = _videos[_currentIndex];
    try {
      final userDocSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (!userDocSnap.exists) return;
      final userData = userDocSnap.data();
      if (userData == null) return;
      final user = User.fromMap(userData);
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => VideoOptionsBottomSheet(
          video: video,
          currentUser: user,
          onVideoDeleted: () {
            setState(() {
              _videos.removeAt(_currentIndex);
              if (_videos.isEmpty) {
                Navigator.of(context).pop();
              } else if (_currentIndex >= _videos.length) {
                _currentIndex = _videos.length - 1;
                _pageController.jumpToPage(_currentIndex);
              }
            });
          },
          onVideoUpdated: () {
            setState(() {});
          },
        ),
      );
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🎬 PlayerScreen: Building - _videos.length = ${_videos.length}');

    if (_videos.isEmpty) {
      debugPrint('⚠️ PlayerScreen: No videos available - showing empty state');
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No videos available',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                'Mode: ${widget.mode}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                'Video IDs: ${widget.videoIds}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                'Provided videos: ${widget.videos?.length ?? 0}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onVideoChanged,
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              return VideoPlayerViewOptimized(
                video: video,
                isCurrentVideo: _currentIndex == index,
                isFirstVideo: index == 0,
                tabId: 'playerScreen', // Generic tab ID for standalone player
                homeViewModel: ref.read(hp.homeProvider.notifier),
                showSheet: false,
                sheetType: '',
                onShowProfile: () {},
                onShowComments: () {},
                onShowShare: () {},
                onShowStreamerCard: () {},
                isLiked: false,
                isBookmarked: false,
                showHUD: false, // Disable HUD - PlayerScreen provides its own
              );
            },
          ),
          // HUD Layout - Screen Edge Anchoring (same as HomeView)
          ..._buildHUDElements(context),
        ],
      ),
    );
  }
}
