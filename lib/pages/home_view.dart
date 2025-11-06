import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/feed_tab.dart';
import '../models/home_video.dart';
import '../providers/home_provider.dart' as hp;
import '../services/video_service.dart';
import '../providers/favorites_provider.dart';
import '../providers/following_provider.dart';
import '../providers/feed_state_provider.dart';
import '../services/error_handling_service.dart';
import '../services/offline_data_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/unified_algorithm_service.dart';
import '../services/global_playback_manager.dart';
import '../services/streamers_tip_like_service.dart';
import '../services/favorites_service_optimized.dart';
import '../widgets/network_status_widget.dart';
import '../widgets/discover_view.dart';
import '../views/network_view.dart';
import '../widgets/streamer_card_view.dart';
import '../widgets/home_view_components/home_content_widget.dart';
import '../models/user.dart';
import '../models/streamer_card.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Callback infrastructure for scroll to top - now handled by HomeContentWidget

  // VideoPreloaderService removed - conflicts with GlobalPlaybackManager
  // Using direct controller creation for better memory management
  // GlobalPlaybackCoordinator removed - merged into GlobalPlaybackManager

  // Feed selector (For You / Following) - now managed by feed_state_provider
  // Remove local state to use single source of truth

  // StreamerCard modal state
  bool _showStreamerCard = false;
  StreamerCard? _currentStreamerCard;

  // 🚀 VIRAL ALGORITHM: Ranking cache to prevent excessive re-ranking
  DateTime? _lastRankingTime;
  bool _isRanking = false;

  // ⏱️ MEMORY FIX: Timers for proper cancellation
  Timer? _resumeTimer;
  Timer? _focusTimer;

  // _returnCounter removed - now using stable ValueKey(video.id) instead
  // _videoEngagementScores removed - tracked in EngagementAnalyticsService instead

  // Video data is now managed by Riverpod provider

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      log('🏠 HomeView: initState() called');
    }

    WidgetsBinding.instance.addObserver(this);

    // Initialize services
    ErrorHandlingService().initialize();
    OfflineDataService();
    EngagementAnalyticsService().initialize();

    // 🔊 AUDIO FIX: Ensure playback manager is unblocked on app startup
    GlobalPlaybackManager.instance.unblock();

    // 🚀 VIRAL ALGORITHM: Start tracking session for engagement analytics
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      UnifiedAlgorithmService.instance.startSession(currentUser.uid);
      log('🎯 UnifiedAlgorithm: Session started for user ${currentUser.uid}');
    }

    // Setup favorites manager and load videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupFavoritesManager();
      _loadUserLikedVideos(); // TikTok-style: Load liked videos for heart state
      _loadUserFavorites(); // Load user's bookmarked videos
      _loadVideos();
      _initializeVideoService();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      log('🔄 HomeView: App resumed - reactivating feed');

      // _returnCounter removed - now using stable ValueKey(video.id) for widget identification

      // SEAMLESS RETURN: Reactivate feed when returning from other views
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reactivateFeed();
        }
      });
    }
  }

  /// Reactivate the feed when returning from other views (CameraView, etc.)
  void _reactivateFeed() {
    try {
      log('🚀 HomeView: Reactivating feed after return from other view');

      // SEAMLESS RETURN: Reload videos to ensure fresh controllers
      _loadVideos();

      // Resume current video playback after a brief delay
      _resumeTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          final homeVM = ref.read(hp.homeProvider.notifier);
          homeVM.resumeCurrentVideo();

          // Ensure the current video is playing
          final homeState = ref.read(hp.homeProvider);
          final activeFeed = ref.read(activeFeedProvider);
          final currentVideos = activeFeed == FeedTab.forYou
              ? homeState.forYouVideos
              : homeState.followingVideos;

          if (_currentIndex < currentVideos.length) {
            _pauseAllOtherVideos(_currentIndex);

            // Ensure current video gets focus for TikTok-style autoplay
            final currentVideo = currentVideos[_currentIndex];
            final ownerId = activeFeed.tabId;

            // 🔊 AUDIO FIX: Use GlobalPlaybackManager for focus
            log('🎵 HomeView: Reactivating focus for current video: ${currentVideo.id}');
            GlobalPlaybackManager.instance
                .requestFocus(currentVideo.id, ownerId);
          }

          log('✅ HomeView: Feed reactivated successfully');
        }
      });
    } catch (e) {
      log('❌ HomeView: Error reactivating feed: $e');
    }
  }

  /// Setup favorites manager - equivalent to Swift's .onAppear
  /// TikTok-Style: Load user's liked videos when app opens
  ///
  /// This ensures that when videos appear in the feed, their hearts are
  /// already filled if the user has previously liked them.
  ///
  /// Benefits:
  /// - Hearts show correct state immediately (no delay)
  /// - Works across app restarts (persisted in Firestore)
  /// - Works across devices (same user profile)
  /// - Survives logouts (re-syncs on next login)
  Future<void> _loadUserLikedVideos() async {
    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        log('⚠️ HomeView: No user logged in, skipping liked videos load');
        return;
      }

      log('🔄 HomeView: Loading liked videos for user ${currentUser.uid}');

      await StreamersTipLikeService.instance
          .loadUserLikedVideos(currentUser.uid);

      log('✅ HomeView: Liked videos loaded successfully');
    } catch (e) {
      log('❌ HomeView: Error loading liked videos: $e');
      // Don't block app startup if this fails
    }
  }

  /// Load user's bookmarked videos for favorites tab
  Future<void> _loadUserFavorites() async {
    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        log('⚠️ HomeView: No user logged in, skipping favorites load');
        return;
      }

      log('🔄 HomeView: Loading favorites for user ${currentUser.uid}');

      await FavoritesServiceOptimized().forceSync();

      log('✅ HomeView: Favorites loaded successfully');
    } catch (e) {
      log('❌ HomeView: Error loading favorites: $e');
      // Don't block app startup if this fails
    }
  }

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
      final videoService = ref.read(videoServiceProvider.notifier);
      videoService.loadAllVideos();
      if (kDebugMode) {
        log('✅ HomeView: VideoService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        log('❌ HomeView: Error initializing VideoService: $e');
      }
    }
  }

  /// Load videos from VideoService based on current feed tab
  Future<void> _loadVideos() async {
    try {
      final homeVM = ref.read(hp.homeProvider.notifier);

      // Use the new instant play loadVideos method
      await homeVM.loadVideos();

      // 🚀 VIRAL ALGORITHM: Apply personalized ranking to loaded videos
      await _applyAlgorithmRanking();

      // Prewarm the first video for instant play (TikTok style)
      await _prewarmFirstVideo();

      // Ensure first video gets focus for TikTok-style autoplay
      // Add a delay to ensure video controllers are fully initialized
      _focusTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _ensureFirstVideoFocus();
        }
      });
    } catch (e) {
      ErrorHandlingService().handleError(e, context: 'load_videos');
    }
  }

  /// Apply unified algorithm ranking to videos (VIRAL BOOST)
  Future<void> _applyAlgorithmRanking() async {
    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 🚀 CACHE: Skip if ranked within last 5 minutes
      if (_lastRankingTime != null) {
        final minutesSinceRanking =
            DateTime.now().difference(_lastRankingTime!).inMinutes;
        if (minutesSinceRanking < 5) {
          log('⏭️ UnifiedAlgorithm: Skipping re-ranking (cached ${minutesSinceRanking}min ago)');
          return;
        }
      }

      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final candidateVideos = activeFeed == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (candidateVideos.isEmpty) return;

      // 🎨 LOADING INDICATOR: Show user-friendly feedback
      if (mounted) {
        setState(() => _isRanking = true);
      }

      log('🎯 UnifiedAlgorithm: Ranking ${candidateVideos.length} videos...');

      // Get personalized feed with all 7 systems applied
      final rankedVideos =
          await UnifiedAlgorithmService.instance.getPersonalizedFeed(
        userId: currentUser.uid,
        candidateVideos: candidateVideos,
        limit: candidateVideos.length, // Keep all videos, just reorder
      );

      // Update provider with ranked videos
      final homeVM = ref.read(hp.homeProvider.notifier);
      if (activeFeed == FeedTab.forYou) {
        homeVM.updateForYouVideos(rankedVideos);
      } else {
        homeVM.updateFollowingVideos(rankedVideos);
      }

      // Update cache timestamp
      _lastRankingTime = DateTime.now();

      log('✅ UnifiedAlgorithm: ${rankedVideos.length} videos ranked and ready for viral boost');
    } catch (e) {
      log('❌ UnifiedAlgorithm: Error applying ranking: $e');

      // 💬 ERROR FEEDBACK: Show user-friendly message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Using standard feed (personalization temporarily unavailable)'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
      // Non-critical error, continue with original order
    } finally {
      // Hide loading indicator
      if (mounted) {
        setState(() => _isRanking = false);
      }
    }
  }

  /// Prewarm the first video for instant play (TikTok style)
  Future<void> _prewarmFirstVideo() async {
    try {
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final videos = activeFeed == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (videos.isNotEmpty) {
        final firstVideo = videos.first;
        // 🔊 AUDIO FIX: Use GlobalPlaybackManager for prewarming
        GlobalPlaybackManager.instance.requestFocus(firstVideo.id, 'home');
      }
    } catch (e) {
      if (kDebugMode) {
        log('❌ Error prewarming first video: $e');
      }
    }
  }

  /// Ensure first video gets focus for TikTok-style autoplay on app startup
  void _ensureFirstVideoFocus() {
    try {
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final videos = activeFeed == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (videos.isNotEmpty) {
        final firstVideo = videos.first;
        final ownerId = activeFeed.tabId;

        // 🔊 AUDIO FIX: Use GlobalPlaybackManager for focus
        GlobalPlaybackManager.instance.requestFocus(firstVideo.id, ownerId);

        if (kDebugMode) {
          GlobalPlaybackManager.instance.logCurrentState();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        log('❌ Error ensuring first video focus: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // PageController removed - now managed by VideoPageViewWidget

    // VideoPreloaderService removed - controllers now managed by GlobalPlaybackManager
    // _videoEngagementScores removed - tracked in EngagementAnalyticsService

    // ⏱️ MEMORY FIX: Cancel timers to prevent memory leaks
    _resumeTimer?.cancel();
    _focusTimer?.cancel();

    // 🚀 VIRAL ALGORITHM: End session and save retention data
    UnifiedAlgorithmService.instance.endSession();
    log('🎯 UnifiedAlgorithm: Session ended, retention data saved');

    super.dispose();
  }

  // Dead code removed - _openComments, _shareVideo, _handlePullToRefresh, _refreshInBackground, _scrollToTop
  // All handled by VideoPlayerViewOptimized or removed features
  // Note: _scrollToTopCallback infrastructure kept for potential future use

  // Dead code removed - _disposeInactiveTabVideos now handled by GlobalPlaybackManager.disposeAll()

  /// SIMPLE: Pause all other videos when scrolling within same tab
  void _pauseAllOtherVideos(int currentIndex) {
    if (!mounted) return;

    log('⏸️ HomeView: Pausing all other videos, current index: $currentIndex');

    try {
      // 🔊 AUDIO FIX: Use GlobalPlaybackManager to pause all videos
      final playbackManager = ref.read(globalPlaybackManagerProvider);
      playbackManager.pauseAll();

      log('✅ HomeView: All other videos paused, only current video should play');
    } catch (e) {
      log('❌ HomeView: Error pausing other videos: $e');
    }
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
        final activeFeed = ref.read(activeFeedProvider);
        final videos = activeFeed == FeedTab.forYou
            ? homeState.forYouVideos
            : homeState.followingVideos;

        if (_currentIndex < videos.length) {
          final currentVideo = videos[_currentIndex];
          _showStreamerCardModal(currentVideo.creator);
        }
      } catch (e) {
        if (kDebugMode) {
          log('❌ Error handling left swipe: $e');
        }
      }
    }
  }

  // Dead code removed - _handleSwipeUpRefresh was only used in removed _buildEndOfFeedMessage

  // Dead code removed - _buildEndOfFeedMessage UI not rendered in current implementation

  void _showStreamerCardModal(User user) {
    // Use async to prevent blocking the main thread
    Future.microtask(() {
      if (!mounted) return;

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
    });
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
    log('⏸️ HomeView: Pausing all videos before navigation');
    if (!mounted) {
      log('⚠️ HomeView: Widget not mounted, skipping pause');
      return;
    }

    try {
      // 🔊 AUDIO FIX: Use GlobalPlaybackManager for consistent audio control
      final playbackManager = ref.read(globalPlaybackManagerProvider);
      playbackManager.pauseAllForTabSwitch(); // Pause + mute

      log('✅ HomeView: All videos paused and muted successfully');
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

  // Handler methods for extracted components
  void _handleFeedTabChange(FeedTab newTab) {
    if (!mounted) return;

    log('🔄 HomeView: Switching from ${ref.read(activeFeedProvider).displayName} to ${newTab.displayName}');

    // Use the single source of truth provider
    switchFeed(ref, newTab);

    // Reset current index and trigger video loading
    if (mounted) {
      setState(() {
        _currentIndex = 0;
      });
    }

    // 🔥 FIX: Videos are already loaded by HomeProvider.switchFeed()
    // No need to duplicate the loading logic here

    log('✅ HomeView: Feed switched to ${newTab.displayName}');
  }

  void _handleVideoTap(HomeVideo video) {
    // Handle video tap - could open full screen or other actions
    log('🎬 HomeView: Video tapped: ${video.id}');
  }

  void _handleLeftSwipeVideo(HomeVideo video) {
    _handleLeftSwipe(DragEndDetails(
        velocity: const Velocity(pixelsPerSecond: Offset(-300, 0))));
  }

  void _handleRightSwipe(HomeVideo video) {
    // Handle right swipe - show StreamerCardView for current video's creator
    log('👉 HomeView: Right swipe on video: ${video.id}');
    debugPrint('👉 HomeView: Right swipe detected - showing StreamerCardView');

    try {
      HapticFeedback.lightImpact();

      // Show StreamerCardView for the video's creator
      _showStreamerCardModal(video.creator);
    } catch (e) {
      if (kDebugMode) {
        log('❌ Error handling right swipe: $e');
      }
    }
  }

  void _navigateToDiscover() {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    _pauseAllHomeViewVideos();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DiscoverView()),
      );
    }
  }

  void _navigateToNetwork() {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    _pauseAllHomeViewVideos();
    _navigateToNetworkViewWithTab('discover');
  }

  void _onPageChanged(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });

      // 🚀 INSTANT SWITCHING: Preload adjacent videos for seamless swiping
      _preloadAdjacentVideos(index);

      // Pause all other videos when scrolling within same tab
      _pauseAllOtherVideos(index);
    }
  }

  /// 🚀 INSTANT SWITCHING: Preload adjacent videos for seamless swiping experience
  void _preloadAdjacentVideos(int currentIndex) {
    try {
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final videos = activeFeed == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (videos.length <= 1) return; // No adjacent videos to preload

      // Preload next video (index + 1)
      if (currentIndex + 1 < videos.length) {
        final nextVideo = videos[currentIndex + 1];
        log('🚀 INSTANT SWITCHING: Preloading next video: ${nextVideo.id}');
        // Trigger preloading in background without blocking UI
        Future.microtask(() {
          GlobalPlaybackManager.instance
              .requestFocus(nextVideo.id, activeFeed.tabId);
        });
      }

      // Preload previous video (index - 1) if exists
      if (currentIndex > 0) {
        final prevVideo = videos[currentIndex - 1];
        log('🚀 INSTANT SWITCHING: Preloading previous video: ${prevVideo.id}');
        // Trigger preloading in background without blocking UI
        Future.microtask(() {
          GlobalPlaybackManager.instance
              .requestFocus(prevVideo.id, activeFeed.tabId);
        });
      }

      log('✅ INSTANT SWITCHING: Adjacent videos preloaded for seamless swiping');
    } catch (e) {
      log('⚠️ INSTANT SWITCHING: Error preloading adjacent videos: $e (non-critical)');
    }
  }

  // Dead code removed - _buildVideoContent is now handled by HomeContentWidget

  @override
  Widget build(BuildContext context) {
    return NetworkStatusWidget(
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody:
            true, // This allows content to extend behind the bottom navigation
        body: Stack(
          children: [
            // Main content using extracted components
            Positioned.fill(
              child: Consumer(
                builder: (context, ref, child) {
                  final activeFeed = ref.watch(activeFeedProvider);
                  return HomeContentWidget(
                    key: ValueKey(activeFeed
                        .tabId), // Stable key to prevent audio bleeding
                    activeTab: activeFeed.displayName,
                    currentIndex: _currentIndex,
                    onTabChange: (tab) {
                      final newTab =
                          tab == 'For You' ? FeedTab.forYou : FeedTab.following;
                      _handleFeedTabChange(newTab);
                    },
                    onPageChanged: _onPageChanged,
                    onVideoTap: _handleVideoTap,
                    onLeftSwipe: _handleLeftSwipeVideo,
                    onRightSwipe: _handleRightSwipe,
                    onDiscoverTap: _navigateToDiscover,
                    onNetworkTap: _navigateToNetwork,
                    onScrollControllerReady: (callback) {
                      // Scroll callback now handled by HomeContentWidget
                      log('✅ HomeView: Scroll callback registered');
                    },
                  );
                },
              ),
            ),

            // Legacy header removed - now handled by HomeContentWidget/FeedSelectorWidget

            // Feed dropdown is now handled by HomeContentWidget

            // 🎨 LOADING INDICATOR: Show when ranking videos
            if (_isRanking)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9248D2).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
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
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Personalizing your feed...',
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

  // _buildHeader method removed - now handled by FeedSelectorWidget
}
