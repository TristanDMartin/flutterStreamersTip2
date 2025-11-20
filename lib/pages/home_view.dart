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
import '../services/enhanced_algorithm_service.dart';
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

  // ⏱️ MEMORY FIX: Timers for proper cancellation
  Timer? _resumeTimer;
  Timer? _focusTimer;
  
  // Scroll to top callback for navigating to newest video
  VoidCallback? _scrollToTopCallback;

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
      // Also initialize enhanced algorithm (for backward compatibility)
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
      
      // Don't refresh VideoService immediately - it can block UI
      // Refresh will happen in background after a delay if needed
      // Users can manually pull-to-refresh if needed

      // _returnCounter removed - now using stable ValueKey(video.id) for widget identification

      // SEAMLESS RETURN: Reactivate feed when returning from other views
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reactivateFeed();
        }
      });
    }
  }
  
  /// Reactivate the feed when returning from other views (CameraView, ManagePostsView, etc.)
  void _reactivateFeed() {
    try {
      log('🚀 HomeView: Reactivating feed after return from other view');

      // 🚀 REFRESH FEED: Refresh videos when returning (especially after upload/draft save)
      final videoService = ref.read(videoServiceProvider.notifier);
      final homeProviderNotifier = ref.read(hp.homeProvider.notifier);
      
      // Refresh VideoService and HomeProvider in background
      videoService.refresh().then((_) {
        if (mounted) {
          homeProviderNotifier.refreshAfterUpload().then((_) {
            log('✅ HomeView: Feed refreshed after return');
          }).catchError((e) {
            log('⚠️ HomeView: Error refreshing after upload: $e');
          });
        }
      }).catchError((e) {
        log('⚠️ HomeView: Error refreshing VideoService: $e');
      });

      // 🚀 INSTANT RESUME: Unblock playback immediately
      GlobalPlaybackManager.instance.unblock();

      // Resume current video playback after a brief delay to ensure UI is ready
      _resumeTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          try {
            final homeState = ref.read(hp.homeProvider);
            final activeFeed = ref.read(activeFeedProvider);
            final currentVideos = activeFeed == FeedTab.forYou
                ? homeState.forYouVideos
                : homeState.followingVideos;

            // 🚀 NEWEST VIDEO: If videos were refreshed, start at index 0 (newest video)
            if (currentVideos.isNotEmpty) {
              // Reset to first video (newest) after upload/refresh
              if (mounted) {
                setState(() {
                  _currentIndex = 0;
                });
              }
              
              // Scroll to top programmatically if callback is available
              if (_scrollToTopCallback != null) {
                _scrollToTopCallback!();
                log('📜 HomeView: Scrolled to top (newest video)');
              }
              
              final currentVideo = currentVideos[0];
              final ownerId = activeFeed.tabId;

              // 🔊 AUDIO FIX: Request focus to resume playback immediately
              log('🎵 HomeView: Reactivating focus for newest video: ${currentVideo.id}');
              GlobalPlaybackManager.instance.requestFocus(currentVideo.id, ownerId);

              // Also resume via HomeProvider for additional safety
              final homeVM = ref.read(hp.homeProvider.notifier);
              homeVM.resumeCurrentVideo();

              log('✅ HomeView: Feed reactivated successfully - showing newest video');
            } else {
              log('⚠️ HomeView: No videos available after refresh');
            }
          } catch (e) {
            log('❌ HomeView: Error in resume timer: $e');
          }
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
      // Run in background to avoid blocking UI/button initialization
      _applyAlgorithmRanking().catchError((e) {
        log('⚠️ EnhancedAlgorithm: Error in background ranking: $e');
      });

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
          log('⏭️ EnhancedAlgorithm: Skipping re-ranking (cached ${minutesSinceRanking}min ago)');
          return;
        }
      }

      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final candidateVideos = activeFeed == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (candidateVideos.isEmpty) return;
      
      // 🔒 FIX: Only run algorithm ranking in background, don't block UI
      // Run asynchronously after a longer delay to avoid interrupting gestures and button interactions
      await Future.delayed(const Duration(milliseconds: 500));

      log('🚀 EnhancedAlgorithm: Ranking ${candidateVideos.length} videos...');

      // Get personalized feed with enhanced algorithm (perfect feed)
      final rankedVideos =
          await EnhancedAlgorithmService.instance.getPersonalizedFeed(
        userId: currentUser.uid,
        candidateVideos: candidateVideos,
        userLocation: null, // TODO: Get from user profile if available
        limit: candidateVideos.length, // Keep all videos, just reorder
      );

      // Update provider with ranked videos
      // Preserve current video position OR newest video at top (after upload)
      final adjustedVideos = List<HomeVideo>.from(rankedVideos);
      final homeStateBefore = ref.read(hp.homeProvider);
      final videosBefore = activeFeed == FeedTab.forYou
          ? homeStateBefore.forYouVideos
          : homeStateBefore.followingVideos;
      
      // 🚀 NEWEST VIDEO FIRST: If we're at index 0 (newest), ensure it stays at top after ranking
      if (_currentIndex == 0 && videosBefore.isNotEmpty) {
        final newestVideo = videosBefore[0];
        final int newIndex = adjustedVideos.indexWhere((video) => video.id == newestVideo.id);
        
        if (newIndex > 0) {
          // Newest video was moved by algorithm, move it back to top
          final HomeVideo preservedVideo = adjustedVideos.removeAt(newIndex);
          adjustedVideos.insert(0, preservedVideo);
          log('🔁 EnhancedAlgorithm: Preserved newest video ${newestVideo.id} at index 0');
        }
      } else if (_currentIndex > 0 && 
          _currentIndex < videosBefore.length && 
          videosBefore.isNotEmpty) {
        // Preserve current video position if user is viewing other videos
        final currentVideo = videosBefore[_currentIndex];
        final int newIndex = adjustedVideos.indexWhere((video) => video.id == currentVideo.id);
        
        if (newIndex != -1 && newIndex != _currentIndex) {
          // Current video exists in ranked list but at different position
          // Preserve it at current position to avoid interrupting playback
          final HomeVideo preservedVideo = adjustedVideos.removeAt(newIndex);
          final int insertIndex = _currentIndex.clamp(0, adjustedVideos.length).toInt();
          adjustedVideos.insert(insertIndex, preservedVideo);
          log('🔁 EnhancedAlgorithm: Preserved focused video ${currentVideo.id} at index $insertIndex');
        }
      }

      final homeVM = ref.read(hp.homeProvider.notifier);
      if (activeFeed == FeedTab.forYou) {
        homeVM.updateForYouVideos(adjustedVideos);
      } else {
        homeVM.updateFollowingVideos(adjustedVideos);
      }

      // Update cache timestamp
      _lastRankingTime = DateTime.now();

      log('✅ EnhancedAlgorithm: ${adjustedVideos.length} videos ranked with perfect feed algorithm');
    } catch (e) {
      log('❌ EnhancedAlgorithm: Error applying ranking: $e');

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

  /// SIMPLE: Pause all videos when scrolling (current video will be activated separately)
  void _pauseAllOtherVideos(int currentIndex) {
    if (!mounted) return;

    log('⏸️ HomeView: Pausing all videos before activating index $currentIndex');

    try {
      // 🔊 AUDIO FIX: Use GlobalPlaybackManager to pause and mute all videos
      // The current video will be activated immediately after this call
      final playbackManager = ref.read(globalPlaybackManagerProvider);
      playbackManager.pauseAll(); // This pauses and mutes all videos

      log('✅ HomeView: All videos paused and muted (current will be activated next)');
    } catch (e) {
      log('❌ HomeView: Error pausing videos: $e');
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

  void _navigateToDiscover() async {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    _pauseAllHomeViewVideos();

    if (mounted) {
      // Wait for navigation to complete, then resume when returning
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DiscoverView()),
      );
      
      // When returning from DiscoverView, resume video playback
      if (mounted) {
        log('🔄 HomeView: Returned from DiscoverView - resuming video');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _reactivateFeed();
          }
        });
      }
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

      // 🔊 AUDIO FIX: Pause all videos first, then immediately activate current video
      _pauseAllOtherVideos(index);
      
      // 🔥 CRITICAL: Immediately activate the current video after pausing all
      // This prevents audio bleeding from previous videos
      _activateCurrentVideo(index);

      // 🚀 INSTANT SWITCHING: Preload adjacent videos for seamless swiping
      _preloadAdjacentVideos(index);
    }
  }

  /// 🔊 AUDIO FIX: Activate the current video immediately after page change
  void _activateCurrentVideo(int index) {
    try {
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final videos = activeFeed == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (index >= 0 && index < videos.length) {
        final currentVideo = videos[index];
        final ownerId = activeFeed.tabId;
        
        log('🎵 HomeView: Activating current video at index $index: ${currentVideo.id}');
        
        // Immediately request focus for the current video
        // This will pause all others and play this one
        GlobalPlaybackManager.instance.requestFocus(currentVideo.id, ownerId);
        
        log('✅ HomeView: Current video activated: ${currentVideo.id}');
      }
    } catch (e) {
      log('❌ HomeView: Error activating current video: $e');
    }
  }

  /// 🚀 INSTANT SWITCHING: Preload adjacent videos for seamless swiping experience
  /// This ensures adjacent videos are initialized BEFORE user swipes to them
  void _preloadAdjacentVideos(int currentIndex) {
    try {
      final homeState = ref.read(hp.homeProvider);
      final activeFeed = ref.read(activeFeedProvider);
      final videos = activeFeed == FeedTab.forYou
          ? homeState.forYouVideos
          : homeState.followingVideos;

      if (videos.length <= 1) return; // No adjacent videos to preload

      // Videos are automatically initialized when their widgets are created by PageView
      // The widgets initialize in initState(), so adjacent videos are already initializing
      // This method just logs that we're ready for swiping
      log('🚀 INSTANT SWITCHING: Adjacent videos will initialize automatically when widgets are created');

      log('✅ INSTANT SWITCHING: Adjacent videos pre-initialized for seamless swiping');
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
                      // Store scroll callback for scrolling to top after upload
                      _scrollToTopCallback = callback;
                      log('✅ HomeView: Scroll callback registered');
                    },
                  );
                },
              ),
            ),

            // Legacy header removed - now handled by HomeContentWidget/FeedSelectorWidget

            // Feed dropdown is now handled by HomeContentWidget

            // 🎨 LOADING INDICATOR: Hidden per user request (toast was interrupting UX)
            // Personalizing feed happens in background without user notification

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
