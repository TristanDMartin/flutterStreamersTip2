import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home_video.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/video_service_provider.dart';
import '../services/global_playback_manager.dart';
import '../constants/playback_owners.dart';
import '../core/feature_flags.dart';
import '../services/video_actions_service.dart';
import '../services/video_deletion_service.dart';
import '../services/video_download_service.dart';
import '../services/streamers_tip_like_service.dart';
import '../services/unified_bookmark_service.dart';
import 'video_player_view_optimized.dart';
import 'insights_view.dart';
import 'package:flutter/services.dart';
import 'dart:async' show unawaited;

enum PlayerMode {
  homeFeed,
  favorites,
}

class PlayerScreen extends ConsumerStatefulWidget {
  final PlayerMode mode;
  final int initialIndex;
  final List<String> videoIds;
  final List<HomeVideo>? videos; // For home feed mode
  final String? focusCommentId;

  const PlayerScreen({
    super.key,
    required this.mode,
    required this.initialIndex,
    required this.videoIds,
    this.videos,
    this.focusCommentId,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  PageController? _pageController;
  late List<HomeVideo> _videos;
  int _currentIndex = 0;
  final Map<String, bool> _likeStates = {}; // Cache like states
  final Map<String, bool> _bookmarkStates = {}; // Cache bookmark states

  void _restoreCurrentVideoFocus({String reason = 'player_restore'}) {
    if (_videos.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _videos.length) {
      return;
    }

    final manager = GlobalPlaybackManager.instance;
    final currentVideo = _videos[_currentIndex];
    manager.setActiveOwner(PlaybackOwners.player);
    manager.clearDesiredFocusForOwner(
      PlaybackOwners.player,
      exceptVideoId: currentVideo.id,
    );
    manager.setDesiredFocus(currentVideo.id, PlaybackOwners.player);
    manager.preloadAround(_currentIndex, _videos);
    debugPrint(
      '🎬 PlayerScreen: Restored current video focus (${currentVideo.id}) after $reason',
    );
  }

  @override
  void initState() {
    super.initState();
    // 🎯 SINGLE ACTIVE OWNER: Set PlayerScreen as active owner and force unblock
    final manager = GlobalPlaybackManager.instance;
    manager.forceUnblock(); // Force clear all blocks when opening PlayerScreen
    manager.setActiveOwner(PlaybackOwners.player);
    manager.clearDesiredFocusForOwner(PlaybackOwners.home);
    _currentIndex = widget.initialIndex;
    // Don't create PageController until videos are loaded
    _loadVideos();
  }

  @override
  void dispose() {
    GlobalPlaybackManager.instance.clearDesiredFocusForOwner(
      PlaybackOwners.player,
    );
    _pageController?.dispose();
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

    // Safety check: ensure _currentIndex is within bounds
    if (_videos.isNotEmpty) {
      if (_currentIndex >= _videos.length) {
        debugPrint(
            '⚠️ PlayerScreen: _currentIndex ($_currentIndex) out of bounds, clamping to ${_videos.length - 1}');
        _currentIndex = _videos.length - 1;
      }
      // Create or recreate PageController with safe index
      _pageController?.dispose();
      _pageController = PageController(
          initialPage: _currentIndex.clamp(0, _videos.length - 1));
      debugPrint(
          '✅ PlayerScreen: PageController created with index $_currentIndex');
    } else {
      // No videos - dispose controller if it exists
      _pageController?.dispose();
      _pageController = null;
      debugPrint(
          '⚠️ PlayerScreen: No videos available, PageController not created');
    }

    // ✅ FIX: Load like and bookmark states for all videos
    await _loadVideoStates();

    setState(() {}); // Trigger rebuild to show videos

    if (_videos.isNotEmpty) {
      _restoreCurrentVideoFocus(reason: 'initial_load');
    }
  }

  /// Load like and bookmark states for all videos
  Future<void> _loadVideoStates() async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('⚠️ PlayerScreen: No user logged in, skipping state load');
      return;
    }

    debugPrint(
        '🔄 PlayerScreen: Loading like/bookmark states for ${_videos.length} videos');

    final likeService = StreamersTipLikeService();
    final bookmarkService = UnifiedBookmarkService.instance;

    // ✅ FIX: Ensure bookmark service is initialized
    try {
      await bookmarkService.initialize(currentUser.uid);
    } catch (e) {
      debugPrint(
          '⚠️ PlayerScreen: Bookmark service already initialized or error: $e');
    }

    // Load states for all videos in parallel
    final futures = _videos.map((video) async {
      try {
        // Load like state
        final isLiked = await likeService.isVideoLikedByUser(
          video.id,
          currentUser.uid,
        );
        _likeStates[video.id] = isLiked;

        // Load bookmark state
        final isBookmarked = bookmarkService.isBookmarked(video.id);
        _bookmarkStates[video.id] = isBookmarked;

        debugPrint(
          '✅ PlayerScreen: Loaded state for ${video.id} - liked: $isLiked, bookmarked: $isBookmarked',
        );
      } catch (e) {
        debugPrint('❌ PlayerScreen: Error loading state for ${video.id}: $e');
        // Default to false on error
        _likeStates[video.id] = false;
        _bookmarkStates[video.id] = false;
      }
    });

    await Future.wait(futures);
    debugPrint('✅ PlayerScreen: Finished loading states for all videos');
  }

  void _onVideoChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // 🎯 SINGLE ACTIVE OWNER: setActiveOwner already handles pausing non-active owners
    final manager = GlobalPlaybackManager.instance;
    manager.setActiveOwner(PlaybackOwners.player);
    if (_videos.isNotEmpty && index >= 0 && index < _videos.length) {
      final currentVideo = _videos[index];
      manager.clearDesiredFocusForOwner(
        PlaybackOwners.player,
        exceptVideoId: currentVideo.id,
      );
      manager.setDesiredFocus(currentVideo.id, PlaybackOwners.player);
    }
    // Preload next videos for smooth playback
    if (_videos.isNotEmpty) {
      manager.preloadAround(index, _videos);
    }
  }

  /// Build ProfileView-specific overlays (back button, insights button for owner videos)
  List<Widget> _buildProfileViewOverlays(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeTop = media.viewPadding.top;
    final safeBottom = media.viewPadding.bottom;
    final currentUser = fa.FirebaseAuth.instance.currentUser;

    // Safety checks: ensure videos are loaded and index is valid
    if (_videos.isEmpty ||
        _currentIndex >= _videos.length ||
        _currentIndex < 0) {
      debugPrint(
          '⚠️ PlayerScreen: Cannot build overlays - _videos.length: ${_videos.length}, _currentIndex: $_currentIndex');
      return [
        // Back button only if we can't show the full overlay
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
      ];
    }

    final video = _videos[_currentIndex];
    final isCurrentUser = currentUser?.uid == video.creator.id;

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

      // Menu button - top right (for owner videos)
      if (isCurrentUser)
        Positioned(
          top: safeTop + 16,
          right: 16,
          child: IconButton(
            onPressed: () => _showVideoOptionsMenu(context, video),
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),

      // Insights button and views counter for owner videos
      // Positioned BELOW creator info to avoid overlap
      if (isCurrentUser)
        Positioned(
          left: 12,
          bottom: safeBottom +
              120.0, // Position below creator info (20px base + 100px creator info height)
          right: 80, // Leave space for action buttons
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Insights button
                GestureDetector(
                  onTap: () => _openInsights(context, video),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ),
          ),
        ),
    ];
  }

  /// Build views counter for owner posts
  Widget _buildViewsCounter(HomeVideo video) {
    final viewsCount = video.views;
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

  /// Show video options menu (Edit, Privacy, Download, Delete)
  void _showVideoOptionsMenu(BuildContext context, HomeVideo video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      'Video Options',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),

              // Edit Post
              _buildMenuOption(
                context,
                icon: Icons.edit,
                title: 'Edit Post',
                subtitle: 'Update caption and settings',
                onTap: () {
                  Navigator.pop(context);
                  _handleEditPost(context, video);
                },
              ),

              // Privacy Settings
              _buildMenuOption(
                context,
                icon: Icons.lock_outline,
                title: 'Privacy Settings',
                subtitle: 'Change who can see this video',
                onTap: () {
                  Navigator.pop(context);
                  _handlePrivacySettings(context, video);
                },
              ),

              if (FeatureFlags.videoDownload)
                _buildMenuOption(
                  context,
                  icon: Icons.download,
                  title: 'Download',
                  subtitle: 'Save video to device',
                  onTap: () {
                    Navigator.pop(context);
                    _handleDownload(context, video);
                  },
                ),

              // Delete
              _buildMenuOption(
                context,
                icon: Icons.delete_outline,
                title: 'Delete',
                subtitle: 'Permanently remove this video',
                onTap: () {
                  Navigator.pop(context);
                  _handleDelete(context, video);
                },
                isDestructive: true,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a menu option row
  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Handle Edit Post action
  void _handleEditPost(BuildContext context, HomeVideo video) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditPostSheet(video: video),
    );
  }

  /// Handle Privacy Settings action
  void _handlePrivacySettings(BuildContext context, HomeVideo video) {
    // ✅ FIX: Show privacy settings dialog
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _PrivacySettingsDialog(
        video: video,
        currentVisibility: video.visibility,
        onPrivacyChanged: (newVisibility) async {
          try {
            final videoActionsService = VideoActionsService();
            await videoActionsService.setPrivacy(video.id, newVisibility);
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Privacy updated to $newVisibility'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update privacy: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  /// Handle Download action
  Future<void> _handleDownload(BuildContext context, HomeVideo video) async {
    if (!mounted) return;

    // Show loading dialog with progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DownloadProgressDialog(
        video: video,
        onComplete: (success, message) {
          Navigator.of(dialogContext).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: success ? Colors.green : Colors.red,
                duration: Duration(seconds: success ? 2 : 4),
              ),
            );
          }
        },
      ),
    );
  }

  /// Handle Delete action - TikTok-style delete behavior
  void _handleDelete(BuildContext playerContext, HomeVideo video) {
    showDialog<void>(
      context: playerContext,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Delete Video?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This action cannot be undone. Your video will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _performDelete(video);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Deletes locally first (instant UI), then backend via [VideoActionsService].
  Future<void> _performDelete(HomeVideo video) async {
    final int deletedIndex = _currentIndex;
    final bool wasOnlyVideo = _videos.length == 1;
    final bool wasLastVideo = deletedIndex == _videos.length - 1;
    ref.read(videoDeletionServiceProvider).applyOptimisticRemoval(
      <String>[video.id],
    );
    if (wasOnlyVideo) {
      GlobalPlaybackManager.instance.pauseAll();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video deleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      unawaited(
        _completeVideoDeletionAfterOptimistic(
          video: video,
          deletedIndex: deletedIndex,
          wasOnlyVideo: true,
        ),
      );
      return;
    }
    setState(() {
      _videos.removeAt(deletedIndex);
      if (wasLastVideo) {
        _currentIndex = _videos.length - 1;
      } else {
        _currentIndex = deletedIndex;
        if (_currentIndex >= _videos.length) {
          _currentIndex = _videos.length - 1;
        }
      }
    });
    GlobalPlaybackManager.instance.pauseAll();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (mounted &&
        _pageController != null &&
        _pageController!.hasClients &&
        _videos.isNotEmpty) {
      if (wasLastVideo) {
        await _pageController!.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController!.jumpToPage(_currentIndex);
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      _restoreCurrentVideoFocus(reason: 'delete_navigation');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video deleted'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
    unawaited(
      _completeVideoDeletionAfterOptimistic(
        video: video,
        deletedIndex: deletedIndex,
        wasOnlyVideo: false,
      ),
    );
  }

  Future<void> _completeVideoDeletionAfterOptimistic({
    required HomeVideo video,
    required int deletedIndex,
    required bool wasOnlyVideo,
  }) async {
    try {
      await ref.read(videoActionsServiceProvider).deleteVideo(video.id);
      unawaited(_refreshFeedsAfterDelete());
    } catch (e) {
      debugPrint('❌ PlayerScreen: Server delete failed, rolling back: $e');
      ref.read(videoDeletionServiceProvider).rollbackOptimisticRemoval(
        <HomeVideo>[video],
      );
      if (!mounted) {
        return;
      }
      if (wasOnlyVideo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      setState(() {
        _videos.insert(deletedIndex, video);
        _currentIndex = deletedIndex;
      });
      if (_pageController != null &&
          _pageController!.hasClients &&
          deletedIndex < _videos.length) {
        _pageController!.jumpToPage(deletedIndex);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete video: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _refreshFeedsAfterDelete() async {
    try {
      await ref.read(hp.homeProvider.notifier).refreshFeed();
      await ref.read(videoServiceProvider).refresh();
    } catch (e, st) {
      debugPrint('⚠️ PlayerScreen: Post-delete feed refresh failed: $e $st');
    }
  }

  /// Open Insights view for the current video
  void _openInsights(BuildContext context, HomeVideo video) async {
    // Block video playback before navigating to prevent audio bleeding
    final playbackManager = GlobalPlaybackManager.instance;
    playbackManager.block(reason: 'insights_view_navigation');

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InsightsView(
          videoId: video.id,
          videoTitle:
              video.caption.isNotEmpty ? video.caption : 'Untitled Video',
        ),
        fullscreenDialog: true,
      ),
    );

    // Unblock video playback after returning from Insights View
    playbackManager.unblock();

    // Request focus for the current video to resume playback
    _restoreCurrentVideoFocus(reason: 'insights_return');
  }

  /// DEPRECATED: These HUD methods are no longer used since we enabled showHUD: true on VideoPlayerViewOptimized
  /// This provides consistent functionality with HomeView (EnhancedLikeButton, real-time counters, bookmarks, etc.)
  /// Kept for reference only - can be removed in a future cleanup
  @Deprecated('Use VideoPlayerViewOptimized showHUD: true instead')
  // All HUD elements (comments, likes, share, etc.) are now handled by VideoPlayerViewOptimized
  // The deprecated methods (_buildHUDElements, _buildActionRail, etc.) have been removed

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
          // Video player with vertical swiping (like HomeView)
          if (_pageController != null && _videos.isNotEmpty)
            PageView.builder(
              controller: _pageController!,
              scrollDirection:
                  Axis.vertical, // ✅ Enable vertical swiping like HomeView
              physics:
                  const ClampingScrollPhysics(), // Better physics for mobile
              onPageChanged: _onVideoChanged,
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                // ✅ FIX: Get real like and bookmark states from cache
                final isLiked = _likeStates[video.id] ?? false;
                final isBookmarked = _bookmarkStates[video.id] ?? false;

                return VideoPlayerViewOptimized(
                  key: ValueKey(
                      video.id), // Stable key to prevent audio bleeding
                  video: video,
                  isCurrentVideo: _currentIndex == index,
                  isFirstVideo: index == 0,
                  tabId: 'playerScreen', // Generic tab ID for standalone player
                  ownerKey: PlaybackOwners.player,
                  homeViewModel: ref.read(hp.homeProvider.notifier),
                  showSheet: false,
                  sheetType: '',
                  // Callbacks are null - will use internal methods (comments, share, etc.)
                  isLiked: isLiked, // ✅ Real like state from service
                  isBookmarked:
                      isBookmarked, // ✅ Real bookmark state from service
                  showHUD:
                      true, // Enable HUD - Use VideoPlayerViewOptimized's full functionality like HomeView
                );
              },
            ),
          // Custom overlays for ProfileView-specific features
          ..._buildProfileViewOverlays(context),
        ],
      ),
    );
  }
}

/// Edit Post Sheet for updating video title and hashtags
class EditPostSheet extends ConsumerStatefulWidget {
  final HomeVideo video;

  const EditPostSheet({super.key, required this.video});

  @override
  ConsumerState<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<EditPostSheet> {
  late TextEditingController _titleController;
  late TextEditingController _hashtagsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.video.caption);
    debugPrint('🏷️ EditPostSheet: Video tags: ${widget.video.tags}');
    _hashtagsController = TextEditingController(
      text: widget.video.tags.join(' '),
    );
    debugPrint(
        '🏷️ EditPostSheet: Hashtags controller text: ${_hashtagsController.text}');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Edit Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title/Caption Field
              const Text(
                'Caption',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                maxLines: 3,
                maxLength: 150,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF9248D2), width: 2),
                  ),
                  counterStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(height: 20),

              // Hashtags Field
              const Text(
                'Hashtags',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hashtagsController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '#hashtag1 #hashtag2 #hashtag3',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF9248D2), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Separate hashtags with spaces. Include # symbol.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9248D2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle saving the changes
  Future<void> _handleSave() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse hashtags
      final hashtagText = _hashtagsController.text.trim();
      debugPrint('🏷️ EditPostSheet: Saving hashtag text: "$hashtagText"');
      final hashtags = hashtagText.isEmpty
          ? <String>[]
          : hashtagText
              .split(' ')
              .where((tag) => tag.isNotEmpty)
              .map((tag) => tag.startsWith('#') ? tag : '#$tag')
              .toList();
      debugPrint('🏷️ EditPostSheet: Parsed hashtags: $hashtags');

      // Update video in Firestore
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.video.id)
          .update({
        'caption': _titleController.text.trim(),
        'tags': hashtags,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update video data in memory (VideoService state)
      final videoService = ref.read(videoServiceProvider);
      debugPrint(
          '🏷️ EditPostSheet: Updating VideoService with tags: $hashtags');
      videoService.updateVideoMetadata(
        widget.video.id,
        caption: _titleController.text.trim(),
        tags: hashtags,
      );
      debugPrint('🏷️ EditPostSheet: VideoService update completed');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully!'),
            backgroundColor: Color(0xFF9248D2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

/// Privacy Settings Dialog
class _PrivacySettingsDialog extends StatelessWidget {
  final HomeVideo video;
  final String currentVisibility;
  final Function(String) onPrivacyChanged;

  const _PrivacySettingsDialog({
    required this.video,
    required this.currentVisibility,
    required this.onPrivacyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text(
        'Change Privacy',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPrivacyOption(
            context,
            'Public',
            'Everyone can see this video',
            'public',
            Icons.public,
          ),
          const SizedBox(height: 16),
          _buildPrivacyOption(
            context,
            'Followers',
            'Only your followers can see this video',
            'followers',
            Icons.people,
          ),
          const SizedBox(height: 16),
          _buildPrivacyOption(
            context,
            'Private',
            'Only you can see this video',
            'private',
            Icons.lock,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyOption(
    BuildContext context,
    String title,
    String subtitle,
    String value,
    IconData icon,
  ) {
    final isSelected = currentVisibility.toLowerCase() == value.toLowerCase();
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onPrivacyChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9248d2).withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9248d2)
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF9248d2)
                  : Colors.grey.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF9248d2),
              ),
          ],
        ),
      ),
    );
  }
}

/// Download Progress Dialog
class _DownloadProgressDialog extends StatefulWidget {
  final HomeVideo video;
  final Function(bool success, String message) onComplete;

  const _DownloadProgressDialog({
    required this.video,
    required this.onComplete,
  });

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  bool _isDownloading = true;
  String _statusMessage = 'Preparing download...';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final downloadService = VideoDownloadService();
      final videoUrl = widget.video.videoURL;

      if (videoUrl.isEmpty) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Video URL not available';
        });
        widget.onComplete(false, 'Video URL not available');
        return;
      }

      setState(() {
        _statusMessage = 'Downloading video...';
      });

      await downloadService.downloadVideo(
        widget.video.id,
        videoUrl,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _progress = received / total;
              _statusMessage =
                  'Downloading... ${(_progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 1.0;
          _statusMessage = 'Download complete!';
        });

        await Future.delayed(const Duration(milliseconds: 500));
        widget.onComplete(true, 'Video downloaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download failed: ${e.toString()}';
        });

        String errorMessage = 'Failed to download video';
        if (e.toString().contains('permission')) {
          errorMessage =
              'Storage permission denied. Please grant permission in settings.';
        } else if (e.toString().contains('disabled')) {
          errorMessage = 'Video owner has disabled downloads';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage =
              'Network error. Please check your connection and try again.';
        }

        widget.onComplete(false, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text(
        'Downloading Video',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDownloading)
            const CircularProgressIndicator(
              color: Color(0xFF9248D2),
            )
          else
            Icon(
              _progress >= 1.0 ? Icons.check_circle : Icons.error,
              color: _progress >= 1.0 ? Colors.green : Colors.red,
              size: 48,
            ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF9248D2)),
            ),
          ),
      ],
    );
  }
}
