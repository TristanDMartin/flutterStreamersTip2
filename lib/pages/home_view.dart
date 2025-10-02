import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/share_service_optimized.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/feed_tab.dart';
import '../models/home_video.dart';
import '../widgets/video_player_view_optimized.dart';
import '../providers/home_provider.dart' as hp;
import '../services/video_service.dart';
import '../providers/favorites_provider.dart';
import '../providers/following_provider.dart';
import '../services/error_handling_service.dart';
import '../services/offline_data_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/video_performance_service.dart';
import '../widgets/network_status_widget.dart';
import '../widgets/discover_view.dart';
import '../views/network_view.dart';
import '../widgets/comments_view_optimized.dart';
import '../widgets/streamer_card_view.dart';
// import '../widgets/share_profile_view.dart'; // Removed - unused
import '../models/user.dart';
import '../models/streamer_card.dart';
import '../widgets/tiktok_account_switch_button.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentIndex = 0;

  // Feed selector (For You / Following)
  FeedTab _feedTab = FeedTab.forYou;
  bool _isFeedMenuOpen = false;

  // StreamerCard modal state
  bool _showStreamerCard = false;
  StreamerCard? _currentStreamerCard;

  // Performance state
  final Map<String, int> _videoEngagementScores = {};

  // Video data is now managed by Riverpod provider

  @override
  void initState() {
    super.initState();
    log('🏠 HomeView: initState() called');
    debugPrint('🏠 HomeView: initState() called');

    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();

    // Initialize services
    ErrorHandlingService().initialize();
    OfflineDataService();
    EngagementAnalyticsService().initialize();

    // Setup favorites manager and load videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      log('📋 HomeView: addPostFrameCallback executing');
      debugPrint('📋 HomeView: addPostFrameCallback executing');
      _setupFavoritesManager();
      _loadVideos();
      _initializeVideoService();
    });
  }

  /// Setup favorites manager - equivalent to Swift's .onAppear
  void _setupFavoritesManager() {
    // The favorites service is automatically initialized via Riverpod
    // This is equivalent to: viewModel.setFavoritesManager(favoritesManager)
    final favoritesNotifier = ref.read(favoritesProvider.notifier);

    // Force sync with Firebase when HomeView appears
    favoritesNotifier.forceSync();

    // Favorites manager setup complete
  }

  /// Initialize VideoService to load all videos
  void _initializeVideoService() {
    try {
      log('🎬 HomeView: Initializing VideoService...');
      debugPrint('🎬 HomeView: Initializing VideoService...');

      final videoService = ref.read(videoServiceProvider.notifier);
      videoService.loadAllVideos();

      log('✅ HomeView: VideoService initialized');
      debugPrint('✅ HomeView: VideoService initialized');
    } catch (e) {
      log('❌ HomeView: Error initializing VideoService: $e');
      debugPrint('❌ HomeView: Error initializing VideoService: $e');
    }
  }

  /// Load videos from VideoService based on current feed tab
  Future<void> _loadVideos() async {
    try {
      log('🚀 HomeView: _loadVideos() called');
      debugPrint('🚀 HomeView: _loadVideos() called');

      final homeVM = ref.read(hp.homeProvider.notifier);
      log('📱 HomeView: Got homeVM notifier');
      debugPrint('📱 HomeView: Got homeVM notifier');

      // Use the new instant play loadVideos method
      await homeVM.loadVideos();

      // Prewarm the first video for instant play (TikTok style)
      await _prewarmFirstVideo();

      log('✅ HomeView: Videos loaded successfully');
      debugPrint('✅ HomeView: Videos loaded successfully');
    } catch (e) {
      log('❌ HomeView: Error in _loadVideos: $e');
      debugPrint('❌ HomeView: Error in _loadVideos: $e');
      final error =
          ErrorHandlingService().handleError(e, context: 'load_videos');
      debugPrint('❌ HomeView: Error loading videos: ${error.message}');
    }
  }

  /// INSTANT FOLLOWING: Switch to Following tab instantly (videos preloaded in background)
  Future<void> _loadFollowingVideos() async {
    try {
      log('👥 INSTANT FOLLOWING: Switching to Following tab...');
      debugPrint('👥 INSTANT FOLLOWING: Switching to Following tab...');

      final homeState = ref.read(hp.homeProvider);

      // INSTANT RESPONSE: Check if following videos are already preloaded
      if (homeState.followingVideos.isNotEmpty) {
        log('👥 INSTANT FOLLOWING: Videos already preloaded: ${homeState.followingVideos.length} - instant switch!');
        await _prewarmFirstVideo();
        return;
      }

      // If no videos preloaded, show empty state instantly (no loading delay)
      log('👥 INSTANT FOLLOWING: No preloaded videos - showing empty state instantly');

      // Trigger background loading for future visits
      _triggerFollowingVideosBackgroundLoad();
    } catch (e) {
      log('❌ INSTANT FOLLOWING: Error switching to Following tab: $e');
      debugPrint('❌ INSTANT FOLLOWING: Error switching to Following tab: $e');
    }
  }

  /// Trigger background loading of following videos for future instant switching
  void _triggerFollowingVideosBackgroundLoad() {
    try {
      log('👥 INSTANT FOLLOWING: Triggering background load for future visits...');

      // Trigger background loading without blocking UI
      Future.microtask(() async {
        try {
          final homeVM = ref.read(hp.homeProvider.notifier);
          final userService = ref.read(hp.userServiceProvider);
          final followingIds = await userService.getFollowingIds();

          if (followingIds.isNotEmpty) {
            await homeVM.fetchFollowingVideos(
                followingIds: followingIds, reset: true);
            log('✅ INSTANT FOLLOWING: Background load completed - videos ready for next visit');
          }
        } catch (e) {
          log('⚠️ INSTANT FOLLOWING: Background load failed: $e (non-critical)');
        }
      });
    } catch (e) {
      log('❌ INSTANT FOLLOWING: Error triggering background load: $e');
    }
  }

  /// Prewarm the first video for instant play (TikTok style)
  Future<void> _prewarmFirstVideo() async {
    try {
      final homeState = ref.read(hp.homeProvider);
      final videos = _feedTab == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (videos.isNotEmpty) {
        final firstVideo = videos.first;
        log('🔥 Prewarming first video: ${firstVideo.id}');
        debugPrint('🔥 Prewarming first video: ${firstVideo.id}');

        // Prewarm the first video controller
        await VideoPerformanceService()
            .prewarm(firstVideo.id, firstVideo.videoURL);

        log('✅ First video prewarmed successfully');
        debugPrint('✅ First video prewarmed successfully');
      }
    } catch (e) {
      log('❌ Error prewarming first video: $e');
      debugPrint('❌ Error prewarming first video: $e');
    }
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);
  //   // VideoPlayerView handles lifecycle management
  // }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();

    // Clear performance data
    _videoEngagementScores.clear();

    super.dispose();
  }

  void _openComments(String videoId, String videoOwnerId) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CommentsViewOptimized(
          videoId: videoId,
          videoOwnerId: videoOwnerId,
        );
      },
    );
  }

  Widget _buildFeedDropdown() {
    final BorderRadius radius = BorderRadius.circular(20);
    final Color tileColor = const Color(0xFF1A1A1A).withValues(alpha: 0.95);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: radius,
        border: Border.all(
          color: const Color(0xFF9248D2).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _feedMenuItem(
            title: 'For You',
            isSelected: _feedTab == FeedTab.forYou,
            onTap: () {
              log('📱 HomeView: Switching to For You tab');
              // SMART: Dispose videos from inactive tab only
              if (_feedTab != FeedTab.forYou) {
                _disposeInactiveTabVideos(
                    'forYou'); // Clean up audio from other tab
              }

              if (mounted) {
                setState(() {
                  _feedTab = FeedTab.forYou;
                  _isFeedMenuOpen = false;
                  _currentIndex = 0; // Reset to first video
                });
              }
              _loadVideos();
            },
          ),
          Container(
            height: 1,
            color: Colors.grey.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _feedMenuItem(
            title: 'Following',
            isSelected: _feedTab == FeedTab.following,
            onTap: () {
              log('👥 HomeView: Following tab tapped!');
              debugPrint('👥 HomeView: Following tab tapped!');

              // SMART: Dispose videos from inactive tab only
              if (_feedTab != FeedTab.following) {
                _disposeInactiveTabVideos(
                    'following'); // Clean up audio from other tab
              }

              if (mounted) {
                setState(() {
                  _feedTab = FeedTab.following;
                  _isFeedMenuOpen = false;
                  _currentIndex = 0; // Reset to first video
                });
              }

              _loadFollowingVideos();
            },
          ),
        ],
      ),
    );
  }

  Widget _feedMenuItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9248D2).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              title == 'For You' ? Icons.explore : Icons.people,
              color: isSelected
                  ? const Color(0xFF9248D2)
                  : Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF9248D2) : Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF9248D2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _shareVideo(HomeVideo video) {
    HapticFeedback.lightImpact();
    ShareServiceOptimized().shareVideo(video);
  }

  /// Handle pull-to-refresh gesture - INSTANT like TikTok
  Future<void> _handlePullToRefresh() async {
    log('🔄 HomeView: INSTANT refresh triggered for ${_feedTab.name} tab');
    debugPrint(
        '🔄 HomeView: INSTANT refresh triggered for ${_feedTab.name} tab');

    // INSTANT FEEDBACK - Immediate haptic and scroll to top
    HapticFeedback.lightImpact();
    await _scrollToTop();

    // INSTANT UI UPDATE - Show loading state immediately
    final homeVM = ref.read(hp.homeProvider.notifier);
    homeVM.setLoadingState(true);

    // BACKGROUND REFRESH - Load new content without blocking UI
    _refreshInBackground(homeVM);
  }

  /// Refresh content in background for instant TikTok-like experience
  Future<void> _refreshInBackground(hp.HomeViewModel homeVM) async {
    try {
      log('🔄 HomeView: Starting background refresh for ${_feedTab.name} tab');

      // Refresh videos based on current tab in background
      await homeVM.refreshFeedByTab(_feedTab);

      log('✅ HomeView: Background refresh completed for ${_feedTab.name} tab');
      debugPrint(
          '✅ HomeView: Background refresh completed for ${_feedTab.name} tab');
    } catch (e) {
      log('❌ HomeView: Error during background refresh: $e');
      debugPrint('❌ HomeView: Error during background refresh: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh feed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Always clear loading state
      homeVM.setLoadingState(false);
    }
  }

  /// Scroll to top of feed to show newest video - INSTANT like TikTok
  Future<void> _scrollToTop() async {
    if (_pageController.hasClients) {
      // INSTANT scroll - no animation delay
      await _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 200), // Faster animation
        curve: Curves.easeOut, // Snappier curve
      );
      log('📜 HomeView: INSTANT scroll to top completed');
    }
  }

  /// SMART: Dispose videos from inactive tab only (preserves current tab videos)
  void _disposeInactiveTabVideos(String newActiveTabId) {
    log('🗑️ HomeView: DISPOSING videos from inactive tab to clean up audio streams');

    // Use GlobalVideoController to dispose videos from inactive tab only
    GlobalVideoController.disposeInactiveTabVideos(newActiveTabId);

    log('✅ HomeView: Inactive tab videos disposed, audio streams cleaned up');
  }

  /// SIMPLE: Pause all other videos when scrolling within same tab
  void _pauseAllOtherVideos(int currentIndex) {
    log('⏸️ HomeView: Pausing all other videos, current index: $currentIndex');

    // Use GlobalVideoController for immediate pause of all videos
    GlobalVideoController.pauseAllVideos();

    log('✅ HomeView: All other videos paused, only current video should play');
  }

  /// Handle left swipe gesture to open StreamerCardView
  void _handleLeftSwipe(DragEndDetails details) {
    // Check if it's a left swipe (negative velocity)
    if (details.velocity.pixelsPerSecond.dx < -300) {
      log('👈 HomeView: Left swipe detected');
      debugPrint('👈 HomeView: Left swipe detected');

      try {
        HapticFeedback.lightImpact();

        // Get current video and show StreamerCardView
        final homeState = ref.read(hp.homeProvider);
        final videos = _feedTab == FeedTab.forYou
            ? homeState.forYouVideos
            : homeState.followingVideos;

        if (_currentIndex < videos.length) {
          final currentVideo = videos[_currentIndex];
          _showStreamerCardModal(currentVideo.creator);

          log('✅ HomeView: StreamerCardView opened for user: ${currentVideo.creator.username}');
          debugPrint(
              '✅ HomeView: StreamerCardView opened for user: ${currentVideo.creator.username}');
        }
      } catch (e) {
        log('❌ HomeView: Error handling left swipe: $e');
        debugPrint('❌ HomeView: Error handling left swipe: $e');
      }
    }
  }

  /// Handle swipe up gesture on end-of-feed message to refresh
  void _handleSwipeUpRefresh(DragEndDetails details) {
    // Check if it's an upward swipe (negative velocity on Y axis)
    if (details.velocity.pixelsPerSecond.dy < -300) {
      log('⬆️ HomeView: Swipe up refresh detected');
      debugPrint('⬆️ HomeView: Swipe up refresh detected');

      try {
        HapticFeedback.lightImpact();
        _handlePullToRefresh();
      } catch (e) {
        log('❌ HomeView: Error handling swipe up refresh: $e');
        debugPrint('❌ HomeView: Error handling swipe up refresh: $e');
      }
    }
  }

  /// Build end-of-feed message with swipe-up refresh functionality
  Widget _buildEndOfFeedMessage() {
    return GestureDetector(
      onVerticalDragEnd: _handleSwipeUpRefresh,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // End of feed icon
            const Icon(
              Icons.check_circle_outline,
              size: 60,
              color: Color(0xFF9248D2), // Primary purple
            ),

            const SizedBox(height: 24),

            // End of feed title
            const Text(
              'You\'ve reached the end!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // End of feed subtitle
            Text(
              'Tap the button below to refresh ${_feedTab == FeedTab.forYou ? 'For You' : 'Following'} feed',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Tap to refresh button with instant loading state
            Consumer(
              builder: (context, ref, child) {
                final homeState = ref.watch(hp.homeProvider);
                final isLoading = homeState.isLoading;

                return GestureDetector(
                  onTap: isLoading
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _handlePullToRefresh();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isLoading
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF9248D2), // Primary purple
                                Color(0xFF7768DF), // Secondary purple
                                Color(0xFF1670DE), // Blue
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color:
                          isLoading ? Colors.grey.withValues(alpha: 0.3) : null,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: isLoading
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF9248D2)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 20,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          isLoading ? 'Refreshing...' : 'Tap to refresh',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStreamerCardModal(User user) {
    HapticFeedback.lightImpact();

    // Pause HomeView videos before showing StreamerCard
    _pauseAllHomeViewVideos();

    // Convert User to StreamerCard
    final streamerCard = StreamerCard(
      id: user.id,
      displayName: user.displayName,
      username: user.username,
      avatarURL: user.avatarURL,
      bio: user.bio ?? '',
      hashtags: user.hashtags,
    );

    if (mounted) {
      setState(() {
        _currentStreamerCard = streamerCard;
        _showStreamerCard = true;
      });
    }
  }

  void _dismissStreamerCard() {
    if (mounted) {
      setState(() {
        _showStreamerCard = false;
        _currentStreamerCard = null;
      });

      // Resume current video when dismissing StreamerCard
      try {
        final homeNotifier = ref.read(hp.homeProvider.notifier);
        homeNotifier.resumeCurrentVideo();
        log('▶️ HomeView: Resumed current video after dismissing StreamerCard');
      } catch (e) {
        log('❌ HomeView: Error resuming video after StreamerCard dismissal: $e');
      }
    }
  }

  void _pauseAllHomeViewVideos() {
    log('🚨 PAUSE METHOD: _pauseAllHomeViewVideos() called!');
    log('🚨 PAUSE METHOD: _pauseAllHomeViewVideos() called!');
    log('🔍 HomeView._pauseAllHomeViewVideos(): Starting pause process');
    log('🔍 HomeView._pauseAllHomeViewVideos(): Starting pause process');
    try {
      log('🔍 HomeView._pauseAllHomeViewVideos(): About to get homeNotifier');
      log('🔍 HomeView._pauseAllHomeViewVideos(): About to get homeNotifier');
      // Notify HomeView to pause all videos
      final homeNotifier = ref.read(hp.homeProvider.notifier);
      log('🔍 HomeView._pauseAllHomeViewVideos(): Got homeNotifier, calling pauseAllVideos()');
      log('🔍 HomeView._pauseAllHomeViewVideos(): Got homeNotifier, calling pauseAllVideos()');
      homeNotifier.pauseAllVideos();
      log('🔍 HomeView._pauseAllHomeViewVideos(): Called pauseAllVideos() successfully');
      log('🔍 HomeView._pauseAllHomeViewVideos(): Called pauseAllVideos() successfully');

      log('⏸️ HomeView: Paused all videos before navigation');
    } catch (e) {
      log('❌ HomeView: Error pausing videos: $e');
    }
  }

  void _navigateToNetworkViewWithTab(String tabName) {
    // Navigate to NetworkView with the specified tab
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NetworkView(initialTab: tabName),
      ),
    );
  }

  Widget _buildVideoContent(hp.HomeState homeState) {
    // Use videos from the provider based on current feed tab
    final videos = _feedTab == FeedTab.forYou
        ? homeState.forYouVideos
        : homeState.followingVideos;
    final isLoading =
        _feedTab == FeedTab.forYou ? homeState.isLoading : homeState.isLoading;

    // DEBUG: Log video counts
    log('🔍 HomeView: _buildVideoContent - Feed: ${_feedTab.name}, Videos: ${videos.length}, Loading: $isLoading');
    debugPrint(
        '🔍 HomeView: _buildVideoContent - Feed: ${_feedTab.name}, Videos: ${videos.length}, Loading: $isLoading');

    // Show loading state if we're loading OR if videos are empty but we haven't loaded yet
    final shouldShowLoading =
        isLoading || (!homeState.hasLoaded && videos.isEmpty);

    if (shouldShowLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading videos...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    } else if (videos.isEmpty) {
      // Show different empty states based on feed type
      if (_feedTab == FeedTab.following) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.people_outline,
                size: 80,
                color: Color(0xFF9248D2), // Primary purple
              ),
              const SizedBox(height: 16),
              const Text(
                'No videos from people you follow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Follow some creators to see their videos here',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _navigateToNetworkViewWithTab('Discover');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF9248D2), // Primary purple
                        Color(0xFF7768DF), // Secondary purple
                        Color(0xFF1670DE), // Blue
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9248D2).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.explore,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Discover creators',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // For You empty state
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 80,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No videos available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Pull to refresh or check your connection',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      return SizedBox.expand(
        child: RefreshIndicator(
          onRefresh: _handlePullToRefresh,
          color: const Color(0xFF9248D2),
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          strokeWidth: 2.0,
          displacement: 60.0, // Pull down distance before refresh triggers
          child: GestureDetector(
            onHorizontalDragEnd: _handleLeftSwipe,
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical, // TikTok-style vertical scrolling
              itemCount: videos.length + 1, // Add 1 for end-of-feed message
              onPageChanged: (index) {
                if (mounted) {
                  setState(() {
                    _currentIndex = index;
                  });

                  // SMART: Pause other videos and ensure instant autoplay
                  if (index < videos.length) {
                    _pauseAllOtherVideos(index);
                    // Trigger instant autoplay for current video
                    GlobalVideoController.resumeCurrentVideo();
                  }
                }
              },
              itemBuilder: (context, index) {
                // Show end-of-feed message when reaching the end
                if (index >= videos.length) {
                  return _buildEndOfFeedMessage();
                }

                final video = videos[index];
                final homeVM = ref.read(hp.homeProvider.notifier);
                return VideoPlayerViewOptimized(
                  key: ValueKey(video.id),
                  video: video,
                  isCurrentVideo: index == _currentIndex,
                  isFirstVideo: index == 0,
                  tabId: _feedTab == FeedTab.forYou
                      ? 'forYou'
                      : 'following', // Pass tab ID
                  homeViewModel: homeVM,
                  showSheet: false,
                  sheetType: '',
                  onShowProfile: () => _showStreamerCardModal(video.creator),
                  onShowComments: () =>
                      _openComments(video.id, video.creator.id),
                  onShowShare: () => _shareVideo(video),
                  onShowStreamerCard: () =>
                      _showStreamerCardModal(video.creator),
                  isLiked: video.isLiked,
                  isBookmarked: video.isFavorited, // cSpell:ignore Favorited
                );
              },
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(hp.homeProvider);

    return NetworkStatusWidget(
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody:
            true, // This allows content to extend behind the bottom navigation
        body: Stack(
          children: [
            // Main content - Full screen video that extends behind everything
            Positioned.fill(
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: _buildVideoContent(homeState),
              ),
            ),

            // Header overlay - positioned with proper status bar padding
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(),
            ),

            // Feed dropdown
            if (_isFeedMenuOpen)
              Positioned(
                left: 40,
                top: MediaQuery.of(context).padding.top + 56,
                child: _buildFeedDropdown(),
              ),

            // StreamerCard full-screen modal
            if (_showStreamerCard && _currentStreamerCard != null)
              Positioned.fill(
                child: StreamerCardView(
                  userId: _currentStreamerCard!.id,
                  currentUserId:
                      firebase_auth.FirebaseAuth.instance.currentUser?.uid,
                  onDismiss: _dismissStreamerCard,
                  onFollow: (userId) async {
                    // Handle follow action with NetworkView-style logic
                    HapticFeedback.lightImpact();
                    if (kDebugMode) {
                      print(
                          'HomeView: Follow action triggered for user: $userId');
                    }

                    // Capture context before async operations
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    try {
                      // Debug: Check authentication
                      final currentUser =
                          firebase_auth.FirebaseAuth.instance.currentUser;
                      if (kDebugMode) {
                        print('HomeView: Current user: ${currentUser?.uid}');
                        print('HomeView: Target user ID: $userId');
                      }

                      if (currentUser == null) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Please sign in to follow users'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        return;
                      }

                      // Get the following provider
                      final followingNotifier =
                          ref.read(followingProvider.notifier);

                      // Check follow states (NetworkView logic)
                      final isCurrentlyFollowing =
                          followingNotifier.isFollowing(userId);
                      final isFollowedBy =
                          followingNotifier.isFollowedBy(userId);
                      final isMutualFollow =
                          isCurrentlyFollowing && isFollowedBy;

                      if (kDebugMode) {
                        print(
                            'HomeView: isCurrentlyFollowing: $isCurrentlyFollowing');
                        print('HomeView: isFollowedBy: $isFollowedBy');
                        print('HomeView: isMutualFollow: $isMutualFollow');
                      }

                      if (isCurrentlyFollowing) {
                        // Unfollow the user
                        final success =
                            await followingNotifier.unfollowUser(userId);
                        if (success) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(isMutualFollow
                                    ? 'Disconnected from user'
                                    : 'Unfollowed user'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to unfollow user'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          throw Exception('Failed to unfollow user');
                        }
                      } else {
                        // Follow the user (or follow back)
                        final success =
                            await followingNotifier.followUser(userId);
                        if (success) {
                          if (mounted) {
                            final followMessage = isFollowedBy
                                ? 'Connected with user!'
                                : 'Following user';
                            final backgroundColor = Colors.green;

                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(followMessage),
                                backgroundColor: backgroundColor,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to follow user'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          throw Exception('Failed to follow user');
                        }
                      }
                    } catch (e) {
                      if (kDebugMode) {
                        print('HomeView: Error in follow action: $e');
                      }
                      if (mounted) {
                        String errorMessage = 'Error following user';
                        if (e.toString().contains('permission-denied')) {
                          errorMessage =
                              'Permission denied. Please check your authentication.';
                        } else if (e.toString().contains('network')) {
                          errorMessage =
                              'Network error. Please check your connection.';
                        } else if (e.toString().contains('not-found')) {
                          errorMessage = 'User not found (demo content).';
                        }

                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                      // Re-throw the error so StreamerCardView can handle it
                      rethrow;
                    }
                  },
                  onMessage: (userId) {
                    HapticFeedback.lightImpact();
                    if (kDebugMode) {
                      print(
                          'HomeView: Message action triggered for user: $userId');
                    }
                    // The StreamerCardView will handle the actual messaging logic
                    // This callback is just for tracking/logging purposes
                  },
                  onNavigateToTab: (tabName) {
                    // Handle tab navigation from StreamerCardView
                    HapticFeedback.lightImpact();
                    if (kDebugMode) {
                      print('HomeView: Tab navigation requested: $tabName');
                    }

                    // Navigate to NetworkView with the specified tab
                    _navigateToNetworkViewWithTab(tabName);
                  },
                  onShare: (userId) {
                    // Handle share action using ShareProfileView (same as ProfileView)
                    HapticFeedback.lightImpact();
                    if (kDebugMode) {
                      print(
                          'HomeView: Share action triggered for user: $userId');
                    }

                    // Get user information for sharing
                    final currentStreamer = _currentStreamerCard;
                    if (currentStreamer == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User information not available'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    // Create user data map for ShareProfileView (commented out for now)
                    // final userData = {
                    //   'id': currentStreamer.id,
                    //   'displayName': currentStreamer.displayName,
                    //   'username': currentStreamer.username,
                    //   'photoURL': currentStreamer.avatarURL,
                    //   'bio': currentStreamer.bio,
                    // };

                    // Navigate to ShareProfileView (same as ProfileView)
                    // Navigator.of(context).push(
                    //   MaterialPageRoute(
                    //     builder: (context) => ShareProfileView(
                    //       user: userData,
                    //       dismiss: () => Navigator.of(context).pop(),
                    //     ),
                    //   ),
                    // );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Share profile feature coming soon!')),
                    );
                  },
                ),
              ),

            // Bottom safe area overlay to prevent content from being covered by bottom nav
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: MediaQuery.of(context).padding.bottom +
                      140, // Increased height to ensure content is visible
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.8],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Feed menu button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (mounted) {
                setState(() {
                  _isFeedMenuOpen = !_isFeedMenuOpen;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: _feedTab == FeedTab.forYou
                      ? const Color(0xFF9248D2)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _feedTab == FeedTab.forYou ? 'For You' : 'Following',
                    style: TextStyle(
                      color: _feedTab == FeedTab.forYou
                          ? const Color(0xFF9248D2)
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isFeedMenuOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _feedTab == FeedTab.forYou
                        ? const Color(0xFF9248D2)
                        : Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // TikTok-style account switcher
          const TikTokAccountSwitchIcon(),
          const SizedBox(width: 12),
          // Discover button - bare icon with soft shadow
          InkResponse(
            onTap: () {
              HapticFeedback.lightImpact();
              log('🚨 DISCOVER NAVIGATION: Tap detected!');
              log('🚨 DISCOVER NAVIGATION: Tap detected!');
              // Pause HomeView videos before navigating to DiscoverView
              log('🔍 HomeView: About to navigate to DiscoverView - calling _pauseAllHomeViewVideos()');
              log('🔍 HomeView: About to navigate to DiscoverView - calling _pauseAllHomeViewVideos()');
              try {
                _pauseAllHomeViewVideos();
                log('🔍 HomeView: Called _pauseAllHomeViewVideos() - now navigating to DiscoverView');
                log('🔍 HomeView: Called _pauseAllHomeViewVideos() - now navigating to DiscoverView');
              } catch (e) {
                log('❌ HomeView: Error calling _pauseAllHomeViewVideos(): $e');
                log('❌ HomeView: Error calling _pauseAllHomeViewVideos(): $e');
              }

              // DIRECT TEST: Try to pause video immediately
              try {
                final homeState = ref.read(hp.homeProvider);
                log('🔍 HomeView: Direct test - Current home state shouldPauseAllVideos: ${homeState.shouldPauseAllVideos}');
              } catch (e) {
                log('❌ HomeView: Direct test error: $e');
              }

              log('🚨 DISCOVER NAVIGATION: About to call Navigator.push');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiscoverView()),
              );
              log('🚨 DISCOVER NAVIGATION: Navigator.push completed');
            },
            radius: 24, // keeps 44x44 tap target
            child: Container(
              padding:
                  const EdgeInsets.all(8), // transparent padding for hit area
              child: Icon(
                Icons.explore_outlined,
                color: Colors.white,
                size: 28, // 28-32pt as specified
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
