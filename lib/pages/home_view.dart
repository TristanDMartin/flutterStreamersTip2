import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';

import '../constants/feed_config.dart';
import '../models/feed_tab.dart';
import '../models/home_video.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/favorites_provider.dart';
import '../providers/feed_state_provider.dart';
import '../services/error_handling_service.dart';
import '../services/offline_data_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/unified_algorithm_service.dart';
import '../services/global_playback_manager.dart';
import '../services/streamers_tip_like_service.dart';
import '../services/favorites_service_optimized.dart';
import '../services/video_prefetch_service.dart';
import '../widgets/network_status_widget.dart';
import '../views/network_view.dart';
import '../widgets/streamer_card_view.dart';
import '../widgets/home_view_components/home_content_widget.dart';
import '../widgets/player_screen.dart';
import '../models/user.dart';
import '../models/streamer_card.dart';
import '../controllers/home_view_controller.dart';
import '../routing/app_navigator.dart';
import '../constants/playback_owners.dart';
import '../constants/app_colors.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with WidgetsBindingObserver {
  ProviderSubscription<bool>? _homeViewReactivateSubscription;
  final VideoPrefetchService _videoPrefetchService = VideoPrefetchService();

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

  // ✅ REMOVED: _focusTimer - no longer needed with pending focus system

  HomeViewController get _controller =>
      ref.read(homeViewControllerProvider.notifier);
  HomeViewControllerState get _controllerState =>
      ref.read(homeViewControllerProvider);

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
    _homeViewReactivateSubscription = ref.listenManual<bool>(
      homeViewReactivateProvider,
      (bool? previous, bool next) {
        if (!mounted) return;
        if (!next) return;
        log('🔄 HomeView: Reactivation requested via provider');
        _controller.handleReturnedToHome(
          isRouteCurrent: ModalRoute.of(context)?.isCurrent ?? false,
        );
        ref.read(homeViewReactivateProvider.notifier).clearReactivation();
      },
    );

    // Initialize services
    ErrorHandlingService().initialize();
    OfflineDataService();
    EngagementAnalyticsService().initialize();

    // 🎯 SINGLE ACTIVE OWNER:
    // Active owner is set centrally (MainTabView/AppNavigationObserver).
    // Avoid setting it here to prevent ownership races during startup/rebuilds.

    // 🚀 VIRAL ALGORITHM: Start tracking session for engagement analytics
    // 🔥 CRITICAL FIX: Wrap Firebase access in try-catch to prevent crashes
    try {
      if (Firebase.apps.isNotEmpty) {
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          UnifiedAlgorithmService.instance.startSession(currentUser.uid);
          log('🎯 UnifiedAlgorithm: Session started for user ${currentUser.uid}');
        }
      }
    } catch (e) {
      log('⚠️ HomeView: Error accessing FirebaseAuth: $e');
      // Continue without starting session - non-critical
    }

    // Setup favorites manager and load videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🔥 CRITICAL FIX: Check if Firebase is ready before accessing services
      if (Firebase.apps.isEmpty) {
        log('⚠️ HomeView: Firebase not ready yet, deferring video load');
        // Retry after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && Firebase.apps.isNotEmpty) {
            _setupFavoritesManager();
            _loadUserLikedVideos();
            _loadUserFavorites();
            _loadVideos();
            _controller.markAsActiveOwner();
          }
        });
        return;
      }

      _setupFavoritesManager();
      _loadUserLikedVideos(); // TikTok-style: Load liked videos for heart state
      _loadUserFavorites(); // Load user's bookmarked videos
      _loadVideos();
      // REMOVED: _initializeVideoService() - duplicate call, HomeProvider.loadVideos() already calls loadAllVideos()

      // Mark as active on initial load
      _controller.markAsActiveOwner();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  /// ✅ IMPROVEMENT: Handle return to HomeView with simplified logic
  void _handleReturnedToHome() {
    _controller.handleReturnedToHome(
      isRouteCurrent: ModalRoute.of(context)?.isCurrent ?? false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _controller.handleAppLifecycleChanged(
      appLifecycleState: state,
      isRouteCurrent: ModalRoute.of(context)?.isCurrent ?? false,
    );
  }

  /// ✅ IMPROVEMENT: Show user-friendly error messages
  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || !mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
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

  /// REMOVED: _initializeVideoService() - duplicate call
  /// HomeProvider.loadVideos() already calls VideoService.loadAllVideos()
  /// This was causing duplicate video loads and memory issues

  /// Load videos from VideoService based on current feed tab
  Future<void> _loadVideos() async {
    try {
      final homeVM = ref.read(hp.homeProvider.notifier);

      // Use the new instant play loadVideos method
      await homeVM.loadVideos();

      // 🚀 VIRAL ALGORITHM: Apply personalized ranking (disabled until ready)
      // Feed shows newest-first for now; algorithm will personalize later
      if (FeedConfig.usePersonalizationAlgorithm) {
        await _applyAlgorithmRanking();
      }

      // 🔥 FIX BLACK SCREEN: Preload first video IMMEDIATELY before setting focus
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final List<HomeVideo> videos = switch (activeFeed) {
        FeedTab.forYou => homeState.forYouVideos,
        FeedTab.following => homeState.followingVideos,
        FeedTab.threads => const <HomeVideo>[],
      };

      if (videos.isNotEmpty) {
        final firstVideo = videos.first;
        unawaited(_primeFirstVideo(firstVideo));

        log('🎬 HomeView: Preloading first video in background (non-blocking)');
        // 🔥 FIX SLOW LOADING: Don't wait for preload - videos will show immediately
        // VideoPlayer widget handles initialization and shows video when ready
        GlobalPlaybackManager.instance.preloadAround(0, videos);
      }

      // Restore focus to the current feed position instead of forcing index 0.
      _setDesiredFocusForCurrentIndex();
    } catch (e) {
      log('❌ HomeView: Error loading videos: $e');
      _showSnackBar('Couldn\'t load your feed. Pull down to retry.');
      ErrorHandlingService().handleError(e, context: 'load_videos');
    }
  }

  Future<void> _primeFirstVideo(HomeVideo video) async {
    final posterUrl = video.thumbnailURL ?? '';
    final videoUrl = video.videoURL;

    if (videoUrl.isEmpty) return;

    try {
      log('⚡ HomeView: Priming first video for warm open: ${video.id}');
      await _videoPrefetchService.prime(
        videoId: video.id,
        posterUrl: posterUrl,
        videoUrl: videoUrl,
      );
    } catch (e) {
      log('❌ HomeView: Error priming first video ${video.id}: $e');
    }
  }

  void _setDesiredFocusForCurrentIndex() {
    _setDesiredFocusForIndex(_controllerState.currentIndex);
  }

  void _setDesiredFocusForIndex(int preferredIndex) {
    if (!mounted) return;

    final route = ModalRoute.of(context);
    final isCurrent = route?.isCurrent ?? false;
    if (!isCurrent) {
      log('⏭️ HomeView: Route not current, skipping desired focus');
      return;
    }
    
    try {
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final List<HomeVideo> videos = switch (activeFeed) {
        FeedTab.forYou => homeState.forYouVideos,
        FeedTab.following => homeState.followingVideos,
        FeedTab.threads => const <HomeVideo>[],
      };

      if (videos.isNotEmpty) {
        final safeIndex = preferredIndex.clamp(0, videos.length - 1);
        final firstVideo = videos[safeIndex];
        const ownerId = PlaybackOwners.home;

        log('🎯 HomeView: Setting desired focus for video index $safeIndex: ${firstVideo.id} (owner: $ownerId)');
        // 🔥 PRODUCTION-GRADE: Use setDesiredFocus - queues if controller not ready, applies immediately if ready
        GlobalPlaybackManager.instance.setDesiredFocus(firstVideo.id, ownerId);

        if (kDebugMode) {
          GlobalPlaybackManager.instance.logCurrentState();
        }
      }
    } catch (e) {
      log('❌ HomeView: Error setting desired focus for first video: $e');
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
      final List<HomeVideo> candidateVideos = switch (activeFeed) {
        FeedTab.forYou => homeState.forYouVideos,
        FeedTab.following => homeState.followingVideos,
        FeedTab.threads => const <HomeVideo>[],
      };

      if (candidateVideos.isEmpty) return;

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
      // Ranking complete
    }
  }

  /// ✅ REMOVED: _ensureFirstVideoFocus() - replaced by _setDesiredFocusForFirstVideo()
  /// Old implementation used requestFocus() with timing issues. New implementation uses
  /// PlaybackManager's setDesiredFocus() which queues requests and applies when controller is ready.

  @override
  void dispose() {
    _homeViewReactivateSubscription?.close();
    _homeViewReactivateSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    // PageController removed - now managed by VideoPageViewWidget

    // VideoPreloaderService removed - controllers now managed by GlobalPlaybackManager
    // _videoEngagementScores removed - tracked in EngagementAnalyticsService

    // ✅ REMOVED: _focusTimer cancellation - timer no longer exists

    // ✅ FIX #4: Clean up playback manager when HomeView is disposed
    // Don't call onLeaveHomeView() - it's for route changes, not disposal
    // Just pause - position is saved automatically by GlobalPlaybackManager
    try {
      final playbackManager = GlobalPlaybackManager.instance;
      playbackManager.pauseAll();
      // Position saving happens automatically in GlobalPlaybackManager._saveCurrentPosition()
      // when onLeaveHomeView() is called, but for dispose we just pause
      log('🧹 HomeView: Cleaned up playback manager on dispose');
    } catch (e) {
      log('⚠️ HomeView: Error cleaning up playback on dispose: $e');
    }

    // 🚀 VIRAL ALGORITHM: End session and save retention data
    UnifiedAlgorithmService.instance.endSession();
    log('🎯 UnifiedAlgorithm: Session ended, retention data saved');

    super.dispose();
  }

  // Dead code removed - _openComments, _shareVideo, _handlePullToRefresh, _refreshInBackground, _scrollToTop
  // All handled by VideoPlayerViewOptimized or removed features
  // Note: _scrollToTopCallback infrastructure kept for potential future use

  // Dead code removed - _disposeInactiveTabVideos now handled by GlobalPlaybackManager.disposeAll()

  /// Handle left swipe gesture to open StreamerCardView
  void _handleLeftSwipe(DragEndDetails details) {
    // Check if it's a left swipe (negative velocity)
    if (details.velocity.pixelsPerSecond.dx < -300) {
      try {
        HapticFeedback.lightImpact();

        // Get current video and show StreamerCardView
        final homeState = ref.read(hp.homeProvider);
        final activeFeed = ref.read(activeFeedProvider);
        final List<HomeVideo> videos = switch (activeFeed) {
          FeedTab.forYou => homeState.forYouVideos,
          FeedTab.following => homeState.followingVideos,
          FeedTab.threads => const <HomeVideo>[],
        };

        final int currentIndex = _controllerState.currentIndex;
        if (currentIndex < videos.length) {
          final currentVideo = videos[currentIndex];
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

      // ✅ FIX #2: Treat StreamerCard as overlay (block + pause, not full "leave")
      try {
        GlobalPlaybackManager.instance.block(reason: 'streamerCardOverlay');
        GlobalPlaybackManager.instance.pauseAll();
      } catch (e) {
        log('❌ HomeView: Error blocking for StreamerCard: $e');
      }

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

  /// ✅ FIX #3: Properly unblock and resume after overlay dismissal
  void _dismissStreamerCard() {
    if (!mounted) return;

    setState(() {
      _showStreamerCard = false;
      _currentStreamerCard = null;
    });

    // ✅ FIX #3: Unblock playback and restore HomeView ownership
    try {
      _controller.resumeAfterOverlayDismissal();
      log('▶️ HomeView: Resumed current video after dismissing StreamerCard');
    } catch (e) {
      log('❌ HomeView: Error resuming after StreamerCard dismissal: $e');
    }
  }

  void _navigateToNetworkViewWithTab(String tabName) {
    // 🔊 AUDIO FIX: Ensure blocking happens BEFORE navigation
    // This prevents any race condition where videos might resume during navigation
    GlobalPlaybackManager.instance.block(reason: 'navigatingToNetworkView');
    GlobalPlaybackManager.instance.pauseAll();

    // Navigate to NetworkView with the specified tab
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NetworkView(initialTab: tabName),
        settings: const RouteSettings(name: '/network'),
      ),
    );
  }

  // Handler methods for extracted components
  Future<void> _handleFeedTabChange(FeedTab newTab) async {
    if (!mounted) return;

    log('🔄 HomeView: Switching from ${ref.read(activeFeedProvider).displayName} to ${newTab.displayName}');

    // Use the single source of truth provider
    await switchFeed(ref, newTab);
    if (!mounted) return;

    // Restore the user's last position for each feed to keep switches sticky.
    _controller.restoreFeedIndex(newTab);

    if (newTab == FeedTab.threads) {
      log('✅ HomeView: Threads tab active - skipping video focus');
      return;
    }

    // ✅ FIX #2: Give focus to the first video in the new feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _setDesiredFocusForCurrentIndex();
      } catch (e) {
        log('⚠️ HomeView: Error ensuring first video focus after feed switch: $e');
      }
    });

    log('✅ HomeView: Feed switched to ${newTab.displayName}');
  }

  void _handleVideoTap(HomeVideo video) {
    log('🎬 HomeView: Video tapped: ${video.id}');
    
    // Get current feed videos based on active tab
    final activeFeed = ref.read(activeFeedProvider);
    final List<HomeVideo> videos = switch (activeFeed) {
      FeedTab.forYou => ref.read(hp.homeProvider).forYouVideos,
      FeedTab.following => ref.read(hp.homeProvider).followingVideos,
      FeedTab.threads => const <HomeVideo>[],
    };

    if (activeFeed == FeedTab.threads) {
      log('⏭️ HomeView: Ignoring video tap while Threads tab is active');
      return;
    }
    
    if (videos.isEmpty) {
      log('⚠️ HomeView: No videos available to open');
      return;
    }
    
    // Find the index of the tapped video
    final index = videos.indexWhere((v) => v.id == video.id);
    final videoIndex = index >= 0 ? index : 0;
    
    AppNavigator.openPlayer(
      context,
      mode: PlayerMode.homeFeed,
      initialIndex: videoIndex,
      videoIds: videos.map((v) => v.id).toList(),
      videos: videos,
    );
  }

  void _handleLeftSwipeVideo(HomeVideo video) {
    _handleLeftSwipe(DragEndDetails(
        velocity: const Velocity(pixelsPerSecond: Offset(-300, 0))));
  }

  void _handleRightSwipe(HomeVideo video) {
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

  /// ✅ IMPROVEMENT: Navigate to DiscoverView with proper state tracking
  /// ✅ FIX #2: Use onLeaveHomeView() for real route changes (not overlays)
  Future<void> _navigateToDiscover() async {
    if (!mounted || _controllerState.isNavigatingToDiscover) return;

    HapticFeedback.lightImpact();

    // ✅ IMPROVEMENT: Track navigation to prevent race conditions
    _controller.setIsNavigatingToDiscover(true);

    // Cancel any pending timer that might resume playback
    // ✅ REMOVED: _focusTimer cancellation - timer no longer exists

    // ✅ FIX #2: Real route change - block + pause + leave
    _controller.markNavigatingAway(reason: 'leave_home_to_discover');

    if (!mounted) {
      _controller.setIsNavigatingToDiscover(false);
      return;
    }

    await AppNavigator.openDiscover(context);

    // We're back from DiscoverView
    _controller.setIsNavigatingToDiscover(false);
    if (!mounted) return;

    log('🔄 HomeView: Returned from DiscoverView - resuming videos');
    _handleReturnedToHome();
  }

  /// ✅ FIX #2: Real route change - use onLeaveHomeView() to pause and save position
  void _navigateToNetwork() {
    if (!mounted) return;

    HapticFeedback.lightImpact();

    // 🔥 CRITICAL: Cancel any pending timer that might resume playback
    // ✅ REMOVED: _focusTimer cancellation - timer no longer exists

    // ✅ FIX #2: Real route change - block + pause + leave
    _controller.markNavigatingAway(reason: 'leave_home_to_network');
    _navigateToNetworkViewWithTab('discover');
  }

  Future<void> _onPageChanged(int index) async {
    if (!mounted) return; // 🔒 SAFETY: Exit early if widget is disposed

    try {
      // TIKTOK-STYLE: Get current video for feed management (with safety checks)
      try {
        final homeState = ref.read(hp.homeProvider);
        final activeFeed = ref.read(activeFeedProvider);
        _controller.setCurrentIndexForFeed(activeFeed, index);
        final List<HomeVideo> videos = switch (activeFeed) {
          FeedTab.forYou => homeState.forYouVideos,
          FeedTab.following => homeState.followingVideos,
          FeedTab.threads => const <HomeVideo>[],
        };

        // 🔒 SAFETY: Validate videos list and index before accessing
        if (videos.isEmpty) {
          log('⚠️ HomeView: Videos list is empty, skipping index change');
          return;
        }

        if (index >= 0 && index < videos.length) {
          final currentVideo = videos[index];

          // 🔒 SAFETY: Validate video object before using
          if (currentVideo.id.isEmpty || currentVideo.videoURL.isEmpty) {
            log('⚠️ HomeView: Invalid video at index $index, skipping');
            return;
          }

          // TIKTOK-STYLE: Notify GlobalPlaybackManager of index change
          // 🔥 FIX: Wrap in try-catch to prevent crashes during swiping
          try {
            await GlobalPlaybackManager.instance
                .onVisibleIndexChanged(index, currentVideo);
          } catch (e, stackTrace) {
            log('❌ HomeView: Error in onVisibleIndexChanged: $e');
            log('Stack trace: $stackTrace');
            // Continue - don't crash
          }

          // 🔥 PAGINATION: Load more videos when user is near the end
          try {
            final homeNotifier = ref.read(hp.homeProvider.notifier);
            await homeNotifier.loadMoreVideosIfNeeded(
              currentIndex: index,
              feed: activeFeed,
            );
          } catch (e) {
            log('⚠️ HomeView: Error loading more videos: $e');
            // Continue - don't crash
          }
        } else {
          log('⚠️ HomeView: Index $index out of bounds (videos.length: ${videos.length})');
        }
      } catch (e, stackTrace) {
        // Safety: If provider access fails, log and continue
        log('❌ HomeView: Error in TikTok-style feed management: $e');
        log('Stack trace: $stackTrace');
      }

      // ✅ FIX: Removed _pauseAllOtherVideos call - onVisibleIndexChanged already calls pauseAll()
      // This prevents duplicate pause calls that could interfere with playback coordination
    } catch (e, stackTrace) {
      log('❌ HomeView: Critical error in _onPageChanged: $e');
      log('Stack trace: $stackTrace');
      // Don't crash - just log the error
    }
  }

  // ✅ IMPROVEMENT: Removed _preloadAdjacentVideos() method
  // GlobalPlaybackManager.preloadAround() already handles all preloading efficiently
  // This eliminates redundant preloading that was wasting resources

  // Dead code removed - _buildVideoContent is now handled by HomeContentWidget

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(homeViewControllerProvider);

    return NetworkStatusWidget(
      child: Scaffold(
        backgroundColor: AppColors.supportBackground,
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
                    currentIndex: controllerState.currentIndex,
                    onTabChange: (tab) {
                      final newTab = tab == 'For You'
                          ? FeedTab.forYou
                          : tab == 'Following'
                              ? FeedTab.following
                              : FeedTab.threads;
                      _handleFeedTabChange(newTab);
                    },
                    onPageChanged: _onPageChanged,
                    onVideoTap: _handleVideoTap,
                    onLeftSwipe: _handleLeftSwipeVideo,
                    onRightSwipe: _handleRightSwipe,
                    onDiscoverTap: _navigateToDiscover,
                    onNetworkTap: _navigateToNetwork,
                    onScrollControllerReady: null,
                  );
                },
              ),
            ),

            // Legacy header removed - now handled by HomeContentWidget/FeedSelectorWidget

            // Feed dropdown is now handled by HomeContentWidget

            // ✅ REMOVED: Commented-out loading indicator code (48 lines)
            // Hidden per user request - removed to reduce code bloat

            // StreamerCard full-screen modal
            if (_showStreamerCard && _currentStreamerCard != null)
              Positioned.fill(
                child: StreamerCardView(
                  userId: _currentStreamerCard!.id,
                  currentUserId:
                      firebase_auth.FirebaseAuth.instance.currentUser?.uid,
                  onDismiss: _dismissStreamerCard,
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

                    setState(() {
                      _showStreamerCard = false;
                      _currentStreamerCard = null;
                    });
                    _controller.markNavigatingAway(
                      reason: 'leave_home_to_network_from_streamer_card',
                    );
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
                      72, // Keep a subtle nav fade without eating the creator row
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.supportBackground.withValues(alpha: 0.92),
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
