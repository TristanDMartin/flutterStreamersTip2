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
import '../constants/playback_owners.dart';
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

/// Lifecycle state for HomeView playback management
enum HomeViewLifecycleState {
  idle, // Not visible or active
  activeOwner, // HomeView owns playback
  background, // Not visible but will likely return soon
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

  // ⏱️ MEMORY FIX: Timer for proper cancellation
  Timer? _focusTimer;

  // ✅ IMPROVEMENT: Enum-based lifecycle state management
  HomeViewLifecycleState _lifecycleState = HomeViewLifecycleState.idle;
  DateTime? _lastReactivateAt;
  static const Duration _reactivationCooldown = Duration(milliseconds: 500);

  // ✅ IMPROVEMENT: Track navigation to prevent race conditions
  bool _isNavigatingToDiscover = false;

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

    // 🎯 SINGLE ACTIVE OWNER: Set HomeView as active owner
    // setActiveOwner handles pausing/muting non-active owners and allows this owner to play
    GlobalPlaybackManager.instance.setActiveOwner(PlaybackOwners.home);

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

      // Mark as active on initial load
      _markAsActiveOwner();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ IMPROVEMENT: Simplified lifecycle management with extracted helpers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_handleNavigatingAway()) return;
      _handleReturnedToHome();
    });
  }

  /// ✅ IMPROVEMENT: Check if we're navigating away and handle accordingly
  /// Returns true if we're navigating away, false otherwise
  bool _handleNavigatingAway() {
    final route = ModalRoute.of(context);
    final isActiveRoute = route != null && route.isCurrent;

    if (isActiveRoute) return false;

    // We are leaving HomeView
    if (_lifecycleState == HomeViewLifecycleState.activeOwner) {
      log('🔇 HomeView: Navigating away - resetting state and pausing videos');
      _markAsBackground();
      GlobalPlaybackManager.instance.pauseAll();
    }

    return true;
  }

  /// ✅ IMPROVEMENT: Handle return to HomeView with simplified logic
  void _handleReturnedToHome() {
    // Don't double-handle if navigation callback is already handling it
    if (_isNavigatingToDiscover) return;

    final route = ModalRoute.of(context);
    final playbackManager = GlobalPlaybackManager.instance;
    final isActiveRoute = route != null && route.isCurrent;
    final isHomeActiveOwner =
        playbackManager.activeOwner == PlaybackOwners.home;

    if (!isActiveRoute) return;

    // If we're already the active owner, just mark as active (normal state)
    if (isHomeActiveOwner) {
      _markAsActiveOwner();
      return;
    }

    // Check if we can reactivate now
    if (!_canReactivateNow()) return;

    log('🔄 HomeView: Detected return from another view - reactivating feed');

    // Set home as active owner
    playbackManager.setActiveOwner(PlaybackOwners.home);
    _markAsActiveOwner();

    // ✅ IMPROVEMENT: Flattened nested postFrameCallback
    // Resume current video immediately (no nested callback)
    if (mounted) {
      _resumeCurrentVideoInstantly();
    }
  }

  /// ✅ IMPROVEMENT: Check if reactivation is allowed based on state and cooldown
  bool _canReactivateNow() {
    if (_lifecycleState != HomeViewLifecycleState.background) return false;
    if (_lastReactivateAt == null) return true;
    return DateTime.now().difference(_lastReactivateAt!) >
        _reactivationCooldown;
  }

  /// ✅ IMPROVEMENT: Mark HomeView as the active owner
  void _markAsActiveOwner() {
    _lifecycleState = HomeViewLifecycleState.activeOwner;
    _lastReactivateAt = DateTime.now();
  }

  /// ✅ IMPROVEMENT: Mark HomeView as background (will return soon)
  void _markAsBackground() {
    _lifecycleState = HomeViewLifecycleState.background;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // TIKTOK-STYLE: Notify GlobalPlaybackManager of lifecycle change
    GlobalPlaybackManager.instance.onAppLifecycleChanged(state);

    if (state == AppLifecycleState.resumed) {
      log('🔄 HomeView: App resumed - reactivating feed');

      // 🚀 TIKTOK-STYLE: Use instant resume instead of deprecated _reactivateFeed()
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final playbackManager = GlobalPlaybackManager.instance;
          playbackManager.setActiveOwner(PlaybackOwners.home);
          _resumeCurrentVideoInstantly();
        }
      });
    }
  }

  /// 🚀 TIKTOK-STYLE: Instantly resume current video when returning (no reload, no delay)
  void _resumeCurrentVideoInstantly() {
    if (!mounted) {
      log('⚠️ HomeView: Cannot resume video - widget not mounted');
      return;
    }

    try {
      log('🚀 HomeView: Instantly resuming current video (TikTok-style)');

      final playbackManager = GlobalPlaybackManager.instance;
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final currentVideos = activeFeed == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (currentVideos.isEmpty) {
        log('⚠️ HomeView: No videos available to resume');
        return;
      }

      // Ensure index is within bounds
      final safeIndex = _currentIndex.clamp(0, currentVideos.length - 1);
      if (safeIndex != _currentIndex) {
        log('⚠️ HomeView: Index $_currentIndex out of bounds, using $safeIndex');
        if (mounted) {
          setState(() {
            _currentIndex = safeIndex;
          });
        }
      }

      final currentVideo = currentVideos[safeIndex];

      // Validate video before resuming
      if (currentVideo.id.isEmpty || currentVideo.videoURL.isEmpty) {
        log('⚠️ HomeView: Invalid video at index $safeIndex, cannot resume');
        return;
      }

      final ownerId = activeFeed.tabId;

      // 🚀 TIKTOK-STYLE: Instantly request focus (no delay, no reload)
      log('🎵 HomeView: Instantly requesting focus for current video: ${currentVideo.id}');
      playbackManager.requestFocus(currentVideo.id, ownerId);

      log('✅ HomeView: Current video resumed instantly');
    } catch (e, stackTrace) {
      log('❌ HomeView: Error resuming current video: $e');
      log('Stack trace: $stackTrace');
      _showSnackBar('Unable to resume video playback');
    }
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

      // ✅ IMPROVEMENT: Schedule focus with proper timer cancellation
      // Note: Removed _prewarmFirstVideo() - it was duplicate and used wrong owner ID
      // _ensureFirstVideoFocus() handles this correctly with proper owner ID
      _scheduleFocusFirstVideo();
    } catch (e) {
      log('❌ HomeView: Error loading videos: $e');
      _showSnackBar('Couldn\'t load your feed. Pull down to retry.');
      ErrorHandlingService().handleError(e, context: 'load_videos');
    }
  }

  /// ✅ IMPROVEMENT: Schedule focus timer with proper cancellation
  void _scheduleFocusFirstVideo() {
    _focusTimer?.cancel(); // Cancel previous timer if exists
    _focusTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _ensureFirstVideoFocus();
    });
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

  /// ✅ REMOVED: _prewarmFirstVideo() - duplicate of _ensureFirstVideoFocus()
  /// It also used wrong owner ID ('home' instead of activeFeed.tabId)
  /// _ensureFirstVideoFocus() handles this correctly

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

    // ⏱️ MEMORY FIX: Cancel timer to prevent memory leaks
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
      // ✅ IMPROVEMENT: Mark as background instead of resetting boolean flag
      _markAsBackground();

      // TIKTOK-STYLE: Notify GlobalPlaybackManager that we're leaving HomeView
      // This calls pauseAll() and block() to prevent audio bleeding
      GlobalPlaybackManager.instance.onLeaveHomeView();

      log('✅ HomeView: All videos paused and muted successfully');
    } catch (e) {
      log('❌ HomeView: Error pausing videos: $e');
      _showSnackBar('Error pausing videos');
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

  /// ✅ IMPROVEMENT: Navigate to DiscoverView with proper state tracking
  Future<void> _navigateToDiscover() async {
    if (!mounted || _isNavigatingToDiscover) return;

    HapticFeedback.lightImpact();

    // ✅ IMPROVEMENT: Track navigation to prevent race conditions
    _isNavigatingToDiscover = true;

    // Cancel any pending timer that might resume playback
    _focusTimer?.cancel();

    _pauseAllHomeViewVideos();
    _markAsBackground();

    // Navigate to DiscoverView
    if (!mounted) {
      _isNavigatingToDiscover = false;
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DiscoverView(),
        settings: const RouteSettings(name: 'DiscoverView'),
      ),
    );

    // We're back from DiscoverView
    _isNavigatingToDiscover = false;
    if (!mounted) return;

    log('🔄 HomeView: Returned from DiscoverView - resuming videos');
    final playbackManager = GlobalPlaybackManager.instance;

    // Unblock first (DiscoverView may have blocked playback)
    playbackManager.unblock();

    // Set home as active owner
    playbackManager.setActiveOwner(PlaybackOwners.home);
    _markAsActiveOwner();

    // Resume current video
    _resumeCurrentVideoInstantly();
  }

  void _navigateToNetwork() {
    if (!mounted) return;

    HapticFeedback.lightImpact();

    // 🔥 CRITICAL: Cancel any pending timer that might resume playback
    _focusTimer?.cancel();

    _pauseAllHomeViewVideos();
    _navigateToNetworkViewWithTab('discover');
  }

  void _onPageChanged(int index) {
    if (!mounted) return; // 🔒 SAFETY: Exit early if widget is disposed

    try {
      setState(() {
        _currentIndex = index;
      });

      // TIKTOK-STYLE: Get current video for feed management (with safety checks)
      try {
        final homeState = ref.read(hp.homeProvider);
        final activeFeed = ref.read(activeFeedProvider);
        final videos = activeFeed == FeedTab.forYou
            ? homeState.forYouVideos
            : homeState.followingVideos;

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
          GlobalPlaybackManager.instance
              .onVisibleIndexChanged(index, currentVideo);

          // TIKTOK-STYLE: Preload adjacent videos for smooth transitions
          GlobalPlaybackManager.instance.preloadAround(index, videos);
          // ✅ IMPROVEMENT: Removed redundant _preloadAdjacentVideos() call
          // preloadAround() already handles all preloading efficiently
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
