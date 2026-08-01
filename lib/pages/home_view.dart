import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:streamers_tip/utils/app_log.dart';
import 'package:streamers_tip/utils/like_interaction_boundary.dart';
import 'package:streamers_tip/utils/secure_log.dart';
import 'package:streamers_tip/utils/home_feed_interaction_diagnostics.dart';
import 'package:streamers_tip/utils/interaction_diagnostics.dart';

import '../constants/feed_config.dart';
import '../models/feed_tab.dart';
import '../models/home_video.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/discover_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/feed_state_provider.dart';
import '../providers/main_tab_provider.dart';
import '../providers/creator_command_provider.dart';
import '../services/error_handling_service.dart';
import '../services/offline_data_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/unified_algorithm_service.dart';
import '../features/home/application/home_feed_surface_warm.dart';
import '../services/global_playback_manager.dart';
import '../services/streamers_tip_like_service.dart';
import '../services/unified_bookmark_service.dart';
import '../services/video_prefetch_service.dart';
import '../widgets/network_status_widget.dart';
import '../views/network_view.dart';
import '../widgets/streamer_card_view.dart';
import '../services/optimistic_video_service.dart';
import '../widgets/home_view_components/home_content_widget.dart';
import '../widgets/home_view_components/video_page_view_widget.dart';
import '../widgets/player_screen.dart';
import '../widgets/creator_command_center_overlay.dart';
import '../widgets/share_profile_view.dart';
import '../models/user.dart';
import '../models/creator_profile_snapshot.dart';
import '../models/streamer_card.dart';
import '../models/creator_command_snapshot.dart';
import '../controllers/home_view_controller.dart';
import '../routing/app_navigator.dart';
import '../utils/home_video_playback.dart';
import '../features/home/application/home_first_frame_gate.dart';
import '../constants/playback_owners.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with WidgetsBindingObserver {
  ProviderSubscription<bool>? _homeViewReactivateSubscription;
  ProviderSubscription<String?>? _homeFeedScrollRequestSubscription;
  HomeFeedPageControls? _feedPageControls;
  late final HomeViewController _homeController;
  late final HomeViewReactivateNotifier _homeReactivateNotifier;
  final VideoPrefetchService _videoPrefetchService = VideoPrefetchService();
  bool _showStreamerCard = false;
  StreamerCard? _currentStreamerCard;
  DateTime? _lastRankingTime;
  CreatorCommandCenterState _commandCenterState =
      CreatorCommandCenterState.closed;
  final Set<String> _activePlaybackOverlays = <String>{};
  int _lastObservedFeedIndex = 0;
  bool _homeServicesStarted = false;
  String? _firebaseStartupError;
  Timer? _firebaseReadyRetryTimer;
  static const int _firebaseReadyRetryLimit = 10;
  static const Duration _firebaseReadyRetryDelay = Duration(milliseconds: 500);

  HomeViewController get _controller => _homeController;
  HomeViewControllerState get _controllerState =>
      ref.read(homeViewControllerProvider);

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      secureLog('🏠 HomeView: initState() called');
    }

    WidgetsBinding.instance.addObserver(this);
    _homeController = ref.read(homeViewControllerProvider.notifier);
    _lastObservedFeedIndex = 0;
    _homeReactivateNotifier = ref.read(homeViewReactivateProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(homeViewControllerProvider.notifier)
          .resetFeedPositionForColdOpen();
      HomeFirstFrameGate.instance.runAfterFirstFrame(() {
        if (!mounted) return;
        LikeInteractionBoundary.runAfterFirstInteraction(
          () {
            if (!mounted) return;
            ref.read(discoverProvider);
            unawaited(
              ref.read(discoverProvider.notifier).loadTrendingCreators(),
            );
          },
          fallbackTimeout: const Duration(seconds: 20),
        );
      });
    });
    _homeViewReactivateSubscription = ref.listenManual<bool>(
      homeViewReactivateProvider,
      (bool? previous, bool next) {
        if (!mounted) return;
        if (!next) return;
        secureLog('🔄 HomeView: Reactivation requested via provider');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          _handleReturnedToHome();
          _homeReactivateNotifier.clearReactivation();
        });
      },
    );
    _homeFeedScrollRequestSubscription = ref.listenManual<String?>(
      homeFeedScrollRequestProvider,
      (String? previous, String? next) {
        if (next == null || next.isEmpty) {
          return;
        }
        _tryScrollToUploadedVideo(next);
      },
    );

    // Lightweight sync init only; heavy analytics deferred until first frame.
    ErrorHandlingService().initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(hp.homeProvider.notifier).ensureInstantFeedReady();
      if (ref.read(hp.homeProvider).forYouVideos.isNotEmpty) {
        _setDesiredFocusForCurrentIndex();
      }
      _startHomeServicesWhenFirebaseReady();
      HomeFirstFrameGate.instance.armFallbackUnblock();
      HomeFirstFrameGate.instance.runAfterFirstFrame(() {
        if (!mounted) return;
        OfflineDataService();
        EngagementAnalyticsService().initialize();
        _startUnifiedAlgorithmSession();
      });
    });
  }

  void _startUnifiedAlgorithmSession() {
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        UnifiedAlgorithmService.instance.startSession(currentUser.uid);
        secureLog(
          '🎯 UnifiedAlgorithm: Session started for user ${currentUser.uid}',
        );
      }
    } catch (e) {
      secureLog('⚠️ HomeView: Error starting algorithm session: $e');
    }
  }

  void _startHomeServicesWhenFirebaseReady({int attempt = 0}) {
    if (!context.mounted) return;
    if (_homeServicesStarted) return;

    if (Firebase.apps.isEmpty) {
      if (attempt >= _firebaseReadyRetryLimit) {
        secureLog('⚠️ HomeView: Firebase not ready after startup retries');
        setState(() {
          _firebaseStartupError =
              'Still connecting. We will load your feed shortly.';
        });
        _firebaseReadyRetryTimer?.cancel();
        _firebaseReadyRetryTimer = Timer(_firebaseReadyRetryDelay * 2, () {
          _startHomeServicesWhenFirebaseReady(attempt: 0);
        });
        return;
      }

      secureLog(
        '⚠️ HomeView: Firebase not ready yet, retrying feed startup '
        '(${attempt + 1}/$_firebaseReadyRetryLimit)',
      );
      _firebaseReadyRetryTimer?.cancel();
      _firebaseReadyRetryTimer = Timer(_firebaseReadyRetryDelay, () {
        _startHomeServicesWhenFirebaseReady(attempt: attempt + 1);
      });
      return;
    }

    _homeServicesStarted = true;
    _firebaseReadyRetryTimer?.cancel();
    _firebaseReadyRetryTimer = null;
    if (_firebaseStartupError != null && mounted) {
      setState(() => _firebaseStartupError = null);
    }

    if (!context.mounted) return;
    final bool hasCachedFeed =
        ref.read(hp.homeProvider).forYouVideos.isNotEmpty;
    _setupFavoritesManager();
    unawaited(_loadUserLikedVideos());
    unawaited(_loadUserFavorites());
    if (hasCachedFeed) {
      unawaited(
          ref.read(hp.homeProvider.notifier).runDeferredBackgroundRefresh());
    } else {
      unawaited(_loadVideosWhenAuthReady());
    }
    _controller.markAsActiveOwner();
    ref.read(hp.homeProvider.notifier).startForYouRealtimeFeed();
  }

  Future<void> _loadVideosWhenAuthReady() async {
    if (!context.mounted) return;
    if (firebase_auth.FirebaseAuth.instance.currentUser == null) {
      try {
        await firebase_auth.FirebaseAuth.instance
            .authStateChanges()
            .where((firebase_auth.User? user) => user != null)
            .first
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        secureLog('⚠️ HomeView: Auth not ready; loading feed anyway');
      } catch (e) {
        secureLog('⚠️ HomeView: Auth wait failed before feed load: $e');
      }
    }
    if (!context.mounted) return;
    await _loadVideos();
  }

  /// ✅ IMPROVEMENT: Handle return to HomeView with simplified logic
  void _handleReturnedToHome() {
    if (!context.mounted) return;
    final bool isHomeTabVisible = ref.read(mainTabActiveIndexProvider) == 0;
    final bool isRouteCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    _controller.handleReturnedToHome(
      isRouteCurrent: isHomeTabVisible && isRouteCurrent,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _commandCenterState = CreatorCommandCenterState.closed;
      _firebaseReadyRetryTimer?.cancel();
      _firebaseReadyRetryTimer = null;
    }
    final bool isHomeTabVisible = ref.read(mainTabActiveIndexProvider) == 0;
    final bool isRouteCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    _controller.handleAppLifecycleChanged(
      appLifecycleState: state,
      isRouteCurrent: isHomeTabVisible && isRouteCurrent,
    );
  }

  Widget _buildFirebaseStartupErrorBanner() {
    final String message = _firebaseStartupError ?? '';
    return Material(
      color: Colors.orange.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText.rich(
                TextSpan(
                  text: message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _firebaseStartupError = null);
                _homeServicesStarted = false;
                _startHomeServicesWhenFirebaseReady();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
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
        secureLog('⚠️ HomeView: No user logged in, skipping liked videos load');
        return;
      }

      secureLog(
          '🔄 HomeView: Loading liked videos for user ${currentUser.uid}');

      await StreamersTipLikeService.instance.loadUserLikedVideos(
        currentUser.uid,
      );

      secureLog('✅ HomeView: Liked videos loaded successfully');
    } catch (e) {
      secureLog('❌ HomeView: Error loading liked videos: $e');
      // Don't block app startup if this fails
    }
  }

  /// Load user's bookmarked videos for favorites tab
  Future<void> _loadUserFavorites() async {
    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        secureLog('⚠️ HomeView: No user logged in, skipping favorites load');
        return;
      }

      secureLog('🔄 HomeView: Loading favorites for user ${currentUser.uid}');

      await UnifiedBookmarkService.instance.initialize(currentUser.uid);

      secureLog('✅ HomeView: Favorites loaded successfully');
    } catch (e) {
      secureLog('❌ HomeView: Error loading favorites: $e');
      // Don't block app startup if this fails
    }
  }

  void _setupFavoritesManager() {
    if (!context.mounted) return;
    final favoritesNotifier = ref.read(favoritesProvider.notifier);

    // Force sync with Firebase when HomeView appears
    favoritesNotifier.forceSync();

    // Favorites manager setup complete
  }

  /// Load videos from VideoService based on current feed tab
  Future<void> _loadVideos() async {
    if (!context.mounted) return;
    try {
      final homeVM = ref.read(hp.homeProvider.notifier);

      await homeVM.loadVideos();

      if (!context.mounted) return;

      if (FeedConfig.usePersonalizationAlgorithm) {
        await _applyAlgorithmRanking();
      }

      if (!context.mounted) return;

      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final List<HomeVideo> videos = homeState.feedData(activeFeed).videos;

      if (videos.isNotEmpty) {
        final firstVideo = videos.first;
        unawaited(_primeFirstVideo(firstVideo));

        secureLog(
            '🎬 HomeView: Preloading warm window from index 0 (non-blocking)');
        HomeFeedSurfaceWarm().warmAround(
          index: 0,
          videos: videos,
          direction: 1,
        );
      }

      if (context.mounted) {
        _setDesiredFocusForCurrentIndex();
      }
    } catch (e) {
      secureLog('❌ HomeView: Error loading videos: $e');
      if (!mounted) return;
      ErrorHandlingService().handleError(e, context: 'load_videos');
    }
  }

  Future<void> _primeFirstVideo(HomeVideo video) async {
    final posterUrl = video.thumbnailURL ?? '';
    final videoUrl = video.videoURL;

    if (videoUrl.isEmpty) return;

    try {
      secureLog('⚡ HomeView: Priming first video for warm open: ${video.id}');
      await _videoPrefetchService.prime(
        videoId: video.id,
        posterUrl: posterUrl,
        videoUrl: videoUrl,
      );
    } catch (e) {
      secureLog('❌ HomeView: Error priming first video ${video.id}: $e');
    }
  }

  void _setDesiredFocusForCurrentIndex() {
    _setDesiredFocusForIndex(_controllerState.currentIndex);
  }

  void _setDesiredFocusForIndex(int preferredIndex) {
    if (!context.mounted) return;

    final route = ModalRoute.of(context);
    final isCurrent = route?.isCurrent ?? false;
    if (!isCurrent) {
      secureLog('⏭️ HomeView: Route not current, skipping desired focus');
      return;
    }

    try {
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final List<HomeVideo> videos = homeState.feedData(activeFeed).videos;

      if (videos.isNotEmpty) {
        final safeIndex = preferredIndex.clamp(0, videos.length - 1);
        final firstVideo = videos[safeIndex];
        const ownerId = PlaybackOwners.home;

        secureLog(
          '🎯 HomeView: Setting desired focus for video index $safeIndex: ${firstVideo.id} (owner: $ownerId)',
        );
        // 🔥 PRODUCTION-GRADE: Use setDesiredFocus - queues if controller not ready, applies immediately if ready
        unawaited(
          GlobalPlaybackManager.instance.requestFocus(firstVideo.id, ownerId),
        );

        if (kDebugMode) {
          GlobalPlaybackManager.instance.logCurrentState();
        }
      }
    } catch (e) {
      secureLog('❌ HomeView: Error setting desired focus for first video: $e');
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
          secureLog(
            '⏭️ UnifiedAlgorithm: Skipping re-ranking (cached ${minutesSinceRanking}min ago)',
          );
          return;
        }
      }

      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final List<HomeVideo> candidateVideos = switch (activeFeed) {
        FeedTab.forYou => homeState.forYouVideos,
        // Progression and Threads are not Home video feeds.
        FeedTab.following => const <HomeVideo>[],
        FeedTab.threads => const <HomeVideo>[],
      };

      if (candidateVideos.isEmpty) return;

      secureLog(
          '🎯 UnifiedAlgorithm: Ranking ${candidateVideos.length} videos...');

      // Get personalized feed with all 7 systems applied
      final rankedVideos =
          await UnifiedAlgorithmService.instance.getPersonalizedFeed(
        userId: currentUser.uid,
        candidateVideos: candidateVideos,
        limit: candidateVideos.length, // Keep all videos, just reorder
      );

      // Update provider with ranked videos
      final homeVM = ref.read(hp.homeProvider.notifier);
      homeVM.updateForYouVideos(rankedVideos);

      // Update cache timestamp
      _lastRankingTime = DateTime.now();

      secureLog(
        '✅ UnifiedAlgorithm: ${rankedVideos.length} videos ranked and ready for viral boost',
      );
    } catch (e) {
      secureLog('❌ UnifiedAlgorithm: Error applying ranking: $e');

      // 💬 ERROR FEEDBACK: Show user-friendly message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Using standard feed (personalization temporarily unavailable)',
            ),
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

  @override
  void dispose() {
    _firebaseReadyRetryTimer?.cancel();
    _firebaseReadyRetryTimer = null;
    _homeViewReactivateSubscription?.close();
    _homeFeedScrollRequestSubscription?.close();
    _homeViewReactivateSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    try {
      final playbackManager = GlobalPlaybackManager.instance;
      playbackManager.pauseAll();
      secureLog('🧹 HomeView: Cleaned up playback manager on dispose');
    } catch (e) {
      secureLog('⚠️ HomeView: Error cleaning up playback on dispose: $e');
    }

    // 🚀 VIRAL ALGORITHM: End session and save retention data
    UnifiedAlgorithmService.instance.endSession();
    secureLog('🎯 UnifiedAlgorithm: Session ended, retention data saved');

    super.dispose();
  }

  void _handleFeedPageControlsReady(HomeFeedPageControls controls) {
    _feedPageControls = controls;
    final String? pendingScrollId = ref.read(homeFeedScrollRequestProvider) ??
        OptimisticVideoService().peekPendingHomeScrollVideoId();
    if (pendingScrollId != null && pendingScrollId.isNotEmpty) {
      _tryScrollToUploadedVideo(pendingScrollId);
    }
  }

  void _tryScrollToUploadedVideo(String videoId) {
    if (!mounted || videoId.isEmpty) {
      return;
    }
    final hp.HomeState homeState = ref.read(hp.homeProvider);
    final List<HomeVideo> videos = homeState.forYouVideos;
    final int index =
        videos.indexWhere((HomeVideo video) => video.id == videoId);
    if (index < 0) {
      secureLog('⏳ HomeView: Waiting for uploaded video in feed: $videoId');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(homeFeedScrollRequestProvider.notifier).clear();
      OptimisticVideoService().consumePendingHomeScrollVideoId();
      _controller.setCurrentIndexForFeed(FeedTab.forYou, index);
      _feedPageControls?.jumpToIndex(index);
      unawaited(_onPageChanged(index));
    });
    secureLog('✅ HomeView: Showing uploaded video at index $index ($videoId)');
  }

  /// Handle left swipe gesture to open StreamerCardView
  void _handleLeftSwipe(DragEndDetails details) {
    // Check if it's a left swipe (negative velocity)
    if (details.velocity.pixelsPerSecond.dx < -300) {
      try {
        HapticFeedback.lightImpact();

        // Get current video and show StreamerCardView
        final homeState = ref.read(hp.homeProvider);
        final activeFeed = ref.read(activeFeedProvider);
        final List<HomeVideo> videos = homeState.feedData(activeFeed).videos;

        final int currentIndex = _controllerState.currentIndex;
        if (currentIndex < videos.length) {
          final currentVideo = videos[currentIndex];
          _showStreamerCardModal(currentVideo.creator);
        }
      } catch (e) {
        if (kDebugMode) {
          secureLog('❌ Error handling left swipe: $e');
        }
      }
    }
  }

  void _showStreamerCardModal(User user) {
    Future.microtask(() {
      if (!mounted) return;

      HapticFeedback.lightImpact();

      try {
        _setPlaybackOverlayActive('streamerCardOverlay', true);
      } catch (e) {
        secureLog('❌ HomeView: Error blocking for StreamerCard: $e');
      }

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

    try {
      _setPlaybackOverlayActive('streamerCardOverlay', false);
      secureLog(
          '▶️ HomeView: Resumed current video after dismissing StreamerCard');
    } catch (e) {
      secureLog('❌ HomeView: Error resuming after StreamerCard dismissal: $e');
    }
  }

  void _navigateToNetworkViewWithTab(String tabName) {
    _closeCommandCenter();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NetworkView(initialTab: tabName),
        settings: const RouteSettings(name: '/network'),
      ),
    );
  }

  Future<void> _handleFeedTabChange(FeedTab newTab) async {
    if (!mounted) return;

    secureLog(
      '🔄 HomeView: Switching from ${ref.read(activeFeedProvider).displayName} to ${newTab.displayName}',
    );

    // Use the single source of truth provider
    await switchFeed(ref, newTab);
    if (newTab != FeedTab.forYou) {
      _closeCommandCenter();
    }
    if (!mounted) return;

    // Restore the user's last position for each feed to keep switches sticky.
    _controller.restoreFeedIndex(newTab);

    if (newTab == FeedTab.threads || newTab == FeedTab.following) {
      secureLog('✅ HomeView: ${newTab.displayName} tab — skipping video focus');
      return;
    }

    // ✅ FIX #2: Give focus to the first video in the new feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _setDesiredFocusForCurrentIndex();
      } catch (e) {
        secureLog(
          '⚠️ HomeView: Error ensuring first video focus after feed switch: $e',
        );
      }
    });

    secureLog('✅ HomeView: Feed switched to ${newTab.displayName}');
  }

  void _handleVideoTap(HomeVideo video) {
    secureLog('🎬 HomeView: Video tapped: ${video.id}');

    // Get current feed videos based on active tab
    final activeFeed = ref.read(activeFeedProvider);
    final List<HomeVideo> videos =
        ref.read(hp.homeProvider).feedData(activeFeed).videos;

    if (activeFeed == FeedTab.threads) {
      secureLog('⏭️ HomeView: Ignoring video tap while Threads tab is active');
      return;
    }

    if (videos.isEmpty) {
      secureLog('⚠️ HomeView: No videos available to open');
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
    _handleLeftSwipe(
      DragEndDetails(
        velocity: const Velocity(pixelsPerSecond: Offset(-300, 0)),
      ),
    );
  }

  void _handleRightSwipe(HomeVideo video) {
    try {
      HapticFeedback.lightImpact();

      // Show StreamerCardView for the video's creator
      _showStreamerCardModal(video.creator);
    } catch (e) {
      if (kDebugMode) {
        secureLog('❌ Error handling right swipe: $e');
      }
    }
  }

  /// ✅ IMPROVEMENT: Navigate to DiscoverView with proper state tracking
  /// ✅ FIX #2: Use onLeaveHomeView() for real route changes (not overlays)
  Future<void> _navigateToDiscover() async {
    if (!mounted || _controllerState.isNavigatingToDiscover) return;

    HapticFeedback.lightImpact();
    _closeCommandCenter();
    _controller.setIsNavigatingToDiscover(true);
    _controller.prepareForRouteNavigation(reason: 'leave_home_to_discover');

    if (!mounted) {
      _controller.setIsNavigatingToDiscover(false);
      return;
    }

    await AppNavigator.openDiscover(context);

    // We're back from DiscoverView
    _controller.setIsNavigatingToDiscover(false);
    if (!mounted) return;

    secureLog('🔄 HomeView: Returned from DiscoverView - resuming videos');
    // Always run the Discover return path after await — do not gate on
    // ModalRoute.isCurrent (shell root is `/`, which can race with observer).
    _controller.resumeFromTabReturn(fromDiscover: true);
  }

  /// ✅ FIX #2: Real route change - use onLeaveHomeView() to pause and save position
  void _navigateToNetwork() {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    _closeCommandCenter();
    _controller.prepareForRouteNavigation(reason: 'leave_home_to_network');
    _navigateToNetworkViewWithTab('discover');
  }

  void _toggleCommandCenter() {
    if (!mounted || ref.read(activeFeedProvider) != FeedTab.forYou) {
      return;
    }
    final bool willOpen =
        _commandCenterState == CreatorCommandCenterState.closed;
    setState(() {
      _commandCenterState = willOpen
          ? CreatorCommandCenterState.expanded
          : CreatorCommandCenterState.closed;
    });
    if (willOpen) {
      unawaited(markCreatorCommandScoreSeen(ref));
    }
    _setPlaybackOverlayActive('commandCenterOverlay', willOpen);
  }

  void _expandCommandCenter() {
    if (!mounted) return;
    final bool wasClosed =
        _commandCenterState == CreatorCommandCenterState.closed;
    setState(() {
      _commandCenterState = CreatorCommandCenterState.expanded;
    });
    unawaited(markCreatorCommandScoreSeen(ref));
    if (wasClosed) {
      _setPlaybackOverlayActive('commandCenterOverlay', true);
    }
  }

  void _closeCommandCenter() {
    if (!mounted) return;
    if (_commandCenterState == CreatorCommandCenterState.closed) {
      return;
    }
    setState(() {
      _commandCenterState = CreatorCommandCenterState.closed;
    });
    _setPlaybackOverlayActive('commandCenterOverlay', false);
  }

  void _handleFeedSelectorOpenChanged(bool isOpen) {
    _setPlaybackOverlayActive('feedDropdownOverlay', isOpen);
  }

  void _setPlaybackOverlayActive(String reason, bool isActive) {
    final bool wasEmpty = _activePlaybackOverlays.isEmpty;
    if (isActive) {
      _activePlaybackOverlays.add(reason);
    } else {
      _activePlaybackOverlays.remove(reason);
    }

    if (isActive && wasEmpty) {
      _controller.prepareForOverlay(reason: reason);
      return;
    }

    if (!isActive && _activePlaybackOverlays.isEmpty && !wasEmpty) {
      _controller.resumeAfterOverlayDismissal();
    }
  }

  void _applyScrollDirectionToCommandCenter(HomeFeedScrollDirection direction) {
    if (!mounted || ref.read(activeFeedProvider) != FeedTab.forYou) {
      return;
    }
    if (direction == HomeFeedScrollDirection.down &&
        _commandCenterState == CreatorCommandCenterState.expanded) {
      setState(() {
        _commandCenterState = CreatorCommandCenterState.collapsed;
      });
    } else if (direction == HomeFeedScrollDirection.up &&
        _commandCenterState == CreatorCommandCenterState.collapsed) {
      setState(() {
        _commandCenterState = CreatorCommandCenterState.expanded;
      });
    }
  }

  void _scheduleAfterScrollIdle(VoidCallback work, {required String reason}) {
    if (!LikeInteractionBoundary.shouldDeferHeavyWork) {
      work();
      return;
    }
    InteractionDiagnostics.logPageChangedDeferred(reason: reason);
    LikeInteractionBoundary.runOrQueue(work, reason: reason);
  }

  Future<void> _runDeferredPageChangedWork({
    required int index,
    required int previousIndex,
    required FeedTab activeFeed,
  }) async {
    if (!mounted) {
      return;
    }
    try {
      if (_controllerState.currentIndex != index ||
          ref.read(activeFeedProvider) != activeFeed) {
        return;
      }
      final homeState = ref.read(hp.homeProvider);
      final List<HomeVideo> videos = homeState.feedData(activeFeed).videos;
      if (videos.isEmpty || index < 0 || index >= videos.length) {
        return;
      }
      final HomeVideo currentVideo = videos[index];
      if (currentVideo.id.isEmpty) {
        return;
      }
      if (!isHomeVideoPlayable(currentVideo)) {
        GlobalPlaybackManager.instance.pauseAll();
        secureLog(
          '⏸️ HomeView: Processing card at index $index — playback paused',
        );
        return;
      }
      final int direction =
          index > previousIndex ? 1 : (index < previousIndex ? -1 : 0);
      HomeFeedSurfaceWarm().warmAround(
        index: index,
        videos: videos,
        direction: direction == 0 ? 1 : direction,
      );
      try {
        await ref.read(hp.homeProvider.notifier).loadMoreVideosIfNeeded(
              currentIndex: index,
              feed: activeFeed,
            );
      } catch (e) {
        secureLog('⚠️ HomeView: Error loading more videos: $e');
      }
    } catch (e, stackTrace) {
      secureLog('❌ HomeView: Error in deferred page changed work: $e');
      secureLog('Stack trace: $stackTrace');
    }
  }

  Future<void> _activateVisibleVideo({
    required int index,
    required FeedTab activeFeed,
  }) async {
    if (!mounted || ref.read(activeFeedProvider) != activeFeed) {
      return;
    }
    final List<HomeVideo> videos =
        ref.read(hp.homeProvider).feedData(activeFeed).videos;
    if (index < 0 || index >= videos.length) {
      return;
    }
    final HomeVideo currentVideo = videos[index];
    if (currentVideo.id.isEmpty || !isHomeVideoPlayable(currentVideo)) {
      GlobalPlaybackManager.instance.pauseAll();
      return;
    }
    try {
      await GlobalPlaybackManager.instance.onVisibleIndexChanged(
        index,
        currentVideo,
      );
    } catch (e, stackTrace) {
      secureLog('❌ HomeView: Error activating visible video: $e');
      secureLog('Stack trace: $stackTrace');
    }
  }

  Future<void> _onPageChanged(int index) async {
    if (!mounted) return;
    final Stopwatch pageWatch = Stopwatch()..start();
    try {
      final int previousIndex = _lastObservedFeedIndex;
      _lastObservedFeedIndex = index;
      if (index > previousIndex) {
        _applyScrollDirectionToCommandCenter(HomeFeedScrollDirection.down);
      } else if (index < previousIndex) {
        _applyScrollDirectionToCommandCenter(HomeFeedScrollDirection.up);
      }
      final FeedTab activeFeed = ref.read(activeFeedProvider);
      _controller.setCurrentIndexForFeed(activeFeed, index);
      unawaited(
        _activateVisibleVideo(index: index, activeFeed: activeFeed),
      );
      _scheduleAfterScrollIdle(
        () {
          unawaited(
            _runDeferredPageChangedWork(
              index: index,
              previousIndex: previousIndex,
              activeFeed: activeFeed,
            ),
          );
        },
        reason: 'page_changed_$index',
      );
    } catch (e, stackTrace) {
      secureLog('❌ HomeView: Critical error in _onPageChanged: $e');
      secureLog('Stack trace: $stackTrace');
    } finally {
      HomeFeedInteractionDiagnostics.logPageChanged(
        source: 'home_view',
        index: index,
        ms: pageWatch.elapsedMilliseconds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(homeViewControllerProvider);
    final Color homeBg = Theme.of(context).scaffoldBackgroundColor;
    return NetworkStatusWidget(
      child: Material(
        color: homeBg,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Consumer(
                  builder: (context, ref, child) {
                    final activeFeed = ref.watch(activeFeedProvider);
                    return HomeContentWidget(
                      key: ValueKey(activeFeed.tabId),
                      activeTab: activeFeed,
                      currentIndex: controllerState.currentIndex,
                      showCommandCenterTrigger: activeFeed == FeedTab.forYou,
                      onCommandCenterTap: _toggleCommandCenter,
                      onFeedSelectorOpenChanged: _handleFeedSelectorOpenChanged,
                      onTabChange: _handleFeedTabChange,
                      onPageChanged: _onPageChanged,
                      onVideoTap: _handleVideoTap,
                      onLeftSwipe: _handleLeftSwipeVideo,
                      onRightSwipe: _handleRightSwipe,
                      onDiscoverTap: _navigateToDiscover,
                      onNetworkTap: _navigateToNetwork,
                      onScrollControllerReady: _handleFeedPageControlsReady,
                    );
                  },
                ),
              ),
              if (_firebaseStartupError != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: _buildFirebaseStartupErrorBanner(),
                ),
              CreatorCommandCenterOverlay(
                state: _commandCenterState,
                onDismiss: _closeCommandCenter,
                onExpand: _expandCommandCenter,
              ),
              if (_showStreamerCard && _currentStreamerCard != null)
                Positioned.fill(
                  child: StreamerCardView(
                    userId: _currentStreamerCard!.id,
                    initialCreator: CreatorProfileSnapshot.fromStreamerCard(
                      _currentStreamerCard!,
                    ),
                    currentUserId:
                        firebase_auth.FirebaseAuth.instance.currentUser?.uid,
                    onDismiss: _dismissStreamerCard,
                    onNavigateToTab: (tabName) {
                      HapticFeedback.lightImpact();
                      if (kDebugMode) {
                        appLog('HomeView: Tab navigation requested: $tabName');
                      }

                      setState(() {
                        _showStreamerCard = false;
                        _currentStreamerCard = null;
                      });
                      _setPlaybackOverlayActive('streamerCardOverlay', false);
                      _controller.prepareForRouteNavigation(
                        reason: 'leave_home_to_network_from_streamer_card',
                      );
                      _navigateToNetworkViewWithTab(tabName);
                    },
                    onShare: (userId) {
                      HapticFeedback.lightImpact();
                      if (kDebugMode) {
                        appLog(
                          'HomeView: Share action triggered for user: $userId',
                        );
                      }

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

                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => ShareProfileView(
                            user: <String, dynamic>{
                              'id': currentStreamer.id,
                              'displayName': currentStreamer.displayName,
                              'username': currentStreamer.username,
                              'avatarURL': currentStreamer.avatarURL,
                              'bio': currentStreamer.bio,
                              'hashtags': currentStreamer.hashtags,
                            },
                            dismiss: () => Navigator.of(context).pop(),
                          ),
                          settings: const RouteSettings(name: '/share_profile'),
                        ),
                      );
                    },
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: MediaQuery.of(context).padding.bottom + 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          homeBg.withValues(alpha: 0.92),
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
      ),
    );
  }
}
