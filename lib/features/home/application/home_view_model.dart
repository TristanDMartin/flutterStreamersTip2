// cspell:ignore Favorited
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_feed_background_refresh.dart';
import 'home_feed_engagement_coordinator.dart';
import 'home_feed_startup_loader.dart';
import 'home_feed_warm_cache.dart';
import 'home_for_you_feed_loader.dart';
import 'home_following_feed_loader.dart';
import 'home_for_you_realtime_feed_listener.dart';
import '../data/home_for_you_feed_repository.dart';
import '../domain/home_feed_engagement_mapper.dart';
import '../domain/home_feed_mutator.dart';
import '../domain/home_feed_processing.dart';
import '../models/home_feed_state.dart';
import '../../../models/feed_tab.dart';
import '../../../models/home_video.dart';
import '../../../services/optimistic_video_service.dart';
import '../../../services/video_service.dart' as video_service;
import '../../../services/following_feed_service.dart';
import '../../../services/comments_service.dart';
import '../../../services/unified_avatar_service.dart';
import '../../../services/streamers_tip_like_service.dart';
import '../../../services/unified_bookmark_service.dart';
import '../../../services/algorithm_cache_service.dart';
import '../../../services/global_playback_manager.dart';
import '../../../constants/playback_owners.dart';
import 'package:streamers_tip/utils/secure_log.dart';

class HomeViewModel extends StateNotifier<HomeState> {
  final video_service.VideoService _videoService;
  final HomeFeedEngagementCoordinator _engagementCoordinator;
  final HomeFollowingFeedLoader _followingFeedLoader;
  late final HomeForYouFeedLoader _forYouFeedLoader;
  final StreamersTipLikeService _likeService = StreamersTipLikeService.instance;
  final UnifiedBookmarkService _bookmarkService =
      UnifiedBookmarkService.instance;
  final AlgorithmCacheService _algorithmCacheService = AlgorithmCacheService();
  final OptimisticVideoService _optimisticVideoService =
      OptimisticVideoService();
  final HomeForYouFeedRepository _forYouFeedRepository =
      HomeForYouFeedRepository();
  late final HomeFeedWarmCache _feedWarmCache =
      HomeFeedWarmCache(_algorithmCacheService);
  late final HomeFeedStartupLoader _startupLoader;
  late final HomeFeedBackgroundRefreshCoordinator _backgroundRefresh;
  HomeForYouRealtimeFeedListener? _forYouRealtimeFeedListener;
  String? _lastForYouFeedFingerprint;
  Future<void>? _freshVideosRefreshInFlight;

  StreamSubscription<String>? _feedRefreshSubscription;

  HomeViewModel({
    required video_service.VideoService videoService,
    FollowingFeedService? followingFeedService,
    CommentsService? commentsService,
  })  : _videoService = videoService,
        _engagementCoordinator = HomeFeedEngagementCoordinator(
          commentsService: commentsService,
        ),
        _followingFeedLoader = HomeFollowingFeedLoader(
          followingFeedService: followingFeedService,
          videoService: videoService,
        ),
        super(_initialStateFromWarmMemory()) {
    _forYouFeedLoader = HomeForYouFeedLoader(
      videoService: videoService,
      log: secureLog,
    );
    _startupLoader = HomeFeedStartupLoader(
      videoService: videoService,
      warmCache: _feedWarmCache,
      log: secureLog,
    );
    _backgroundRefresh = HomeFeedBackgroundRefreshCoordinator(
      videoService: videoService,
      log: secureLog,
    );
    updateVideoLikeState = _updateVideoLikeState;
    updateVideoFavoriteState = _updateVideoFavoriteState;
    startForYouRealtimeFeed();
  }

  @override
  void dispose() {
    _freshVideosRefreshInFlight = null;
    _forYouRealtimeFeedListener?.dispose();
    _forYouRealtimeFeedListener = null;
    _feedRefreshSubscription?.cancel();
    _feedRefreshSubscription = null;
    _optimisticVideoService.removeListener(_refreshPendingOverlay);
    super.dispose();
  }

  void _ensureForYouRealtimeFeedListener() {
    _forYouRealtimeFeedListener ??= HomeForYouRealtimeFeedListener(
      repository: _forYouFeedRepository,
      buildVideosFromSnapshot: (docs) =>
          _videoService.buildRealtimePublicFeedVideos(docs),
      onSnapshotReady: _applyForYouRealtimeSnapshot,
      log: secureLog,
    );
  }

  Future<void> _applyForYouRealtimeSnapshot(
    HomeForYouFeedSnapshotResult result,
  ) async {
    if (!mounted) {
      return;
    }
    final List<HomeVideo> mergedVideos = _mergeIncomingForYouVideos(
      result.videos,
    );
    _updateForYouFeed(
      videos: mergedVideos,
      isLoading: false,
      nextCursor: null,
      clearError: true,
    );
    if (result.videos.isNotEmpty) {
      GlobalPlaybackManager.instance.preloadStartupWindow(
        _readyVideosFromFeed(result.videos),
        requestFocusOnStart: false,
      );
    }
    secureLog(
      '🔄 HomeProvider: Live feed snapshot applied '
      '(${result.videos.length} videos)',
    );
  }

  void startForYouRealtimeFeed() {
    if (Firebase.apps.isEmpty) {
      return;
    }
    _ensureForYouRealtimeFeedListener();
    if (_forYouRealtimeFeedListener!.isListening) {
      return;
    }

    _feedRefreshSubscription ??=
        _optimisticVideoService.feedRefreshStream.listen((_) {
      _refreshPendingOverlay();
    });
    _optimisticVideoService.addListener(_refreshPendingOverlay);

    _forYouRealtimeFeedListener!.start();
  }

  void _refreshPendingOverlay() {
    if (!mounted) {
      return;
    }
    final List<HomeVideo> readyVideos = _videoService.getAllVideos();
    final List<HomeVideo> sourceVideos = readyVideos.isNotEmpty
        ? readyVideos
        : _readyVideosFromFeed(state.forYouVideos);
    _updateForYouFeed(
      videos: sourceVideos,
      isLoading: state.isLoading,
      nextCursor: currentForYouSlice(state).nextCursor,
      clearError: state.error == null,
      error: state.error,
    );
  }

  List<HomeVideo> _readyVideosFromFeed(List<HomeVideo> feed) {
    return filterPlayableHomeVideos(feed);
  }

  List<HomeVideo> _mergePendingUploads(List<HomeVideo> readyVideos) {
    final User? user = FirebaseAuth.instance.currentUser;
    return prepareForYouFeedDisplayList(
      sourceVideos: readyVideos,
      currentUserId: user?.uid,
      optimisticVideoService: _optimisticVideoService,
      currentUserDisplayName: user?.displayName,
      currentUserPhotoUrl: user?.photoURL,
    );
  }

  static HomeState _initialStateFromWarmMemory() {
    return const HomeState(isLoading: true);
  }

  // MARK: - Public Properties

  bool get isLoading => state.isLoading;
  bool get isLoadingMore => state.isLoadingMore;
  bool get hasMoreContent => state.hasMoreContent;
  List<HomeVideo> get forYouVideos => state.forYouVideos;
  List<HomeVideo> get followingVideos => state.followingVideos;

  // Callback for updating video like state from child widgets
  void Function(String videoId)? updateVideoLikeState;

  // Callback for updating video favorite state from child widgets
  Future<void> Function(String videoId)? updateVideoFavoriteState;

  List<HomeVideo> videos(FeedTab feed) => videosForFeed(state, feed);

  void _updateForYouFeed({
    required List<HomeVideo> videos,
    required bool isLoading,
    Map<String, dynamic>? nextCursor,
    Object? lastDocument = homeFeedStateUnset,
    String? error,
    bool clearError = false,
  }) {
    if (!mounted) {
      return;
    }
    final List<HomeVideo> displayVideos = _mergePendingUploads(videos);
    final String fingerprint = _feedFingerprint(displayVideos);
    final FeedSlice currentSlice = currentForYouSlice(state);
    if (_lastForYouFeedFingerprint == fingerprint &&
        state.isLoading == isLoading &&
        currentSlice.isLoading == isLoading &&
        state.error == error) {
      secureLog(
        '⏭️ HomeProvider: Skipping identical For You feed update '
        '(${displayVideos.length} videos)',
      );
      return;
    }
    _lastForYouFeedFingerprint = fingerprint;
    state = applyForYouFeedUpdate(
      state: state,
      mergedVideos: displayVideos,
      isLoading: isLoading,
      nextCursor: nextCursor,
      lastDocument: lastDocument,
      error: error,
      clearError: clearError,
    );
  }

  String _feedFingerprint(List<HomeVideo> videos) {
    return videos.map((HomeVideo video) {
      return '${video.id}:${video.status}:${video.videoURL}:'
          '${video.likes}:${video.comments}:${video.isLiked}:'
          '${video.isFavorited}';
    }).join('|');
  }

  List<HomeVideo> _mergeIncomingForYouVideos(List<HomeVideo> incomingVideos) {
    final List<HomeVideo> incoming =
        dedupeHomeVideosById(_readyVideosFromFeed(incomingVideos));
    if (incoming.isEmpty || state.forYouVideos.isEmpty) {
      return incoming;
    }

    final List<HomeVideo> existing =
        List<HomeVideo>.from(_readyVideosFromFeed(state.forYouVideos));
    final Map<String, HomeVideo> incomingById = <String, HomeVideo>{
      for (final HomeVideo video in incoming) video.id: video,
    };
    final Set<String> existingIds =
        existing.map((HomeVideo video) => video.id).toSet();
    final List<HomeVideo> newVideos = incoming
        .where((HomeVideo video) => !existingIds.contains(video.id))
        .toList(growable: false);
    final List<HomeVideo> updatedExisting = existing
        .map((HomeVideo video) => incomingById[video.id] ?? video)
        .toList(growable: false);
    return dedupeHomeVideosById(<HomeVideo>[
      ...newVideos,
      ...updatedExisting,
    ]);
  }

  void _updateFollowingFeed({
    required List<HomeVideo> videos,
    required bool isLoading,
    Map<String, dynamic>? nextCursor,
    Object? lastDocument = homeFeedStateUnset,
    String? error,
    bool clearError = false,
  }) {
    state = applyFollowingFeedUpdate(
      state: state,
      videos: videos,
      isLoading: isLoading,
      nextCursor: nextCursor,
      lastDocument: lastDocument,
      error: error,
      clearError: clearError,
    );
  }

  // MARK: - Initial Load with Instant Play

  /// Add new video to feed instantly (no refresh). Used after publish.
  void addVideoToFeed(HomeVideo video) {
    _videoService.addVideo(video);
    final List<HomeVideo> current =
        List<HomeVideo>.from(_readyVideosFromFeed(state.forYouVideos));
    final int existing = current.indexWhere((HomeVideo v) => v.id == video.id);
    if (existing >= 0) {
      current[existing] = video;
    } else {
      current.insert(0, video);
    }
    _updateForYouFeed(
      videos: current,
      isLoading: false,
      nextCursor: currentForYouSlice(state).nextCursor,
      clearError: true,
    );
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      unawaited(_cacheForYouFeed(userId: userId, videos: current));
    }
    secureLog('✅ Video added to feed: ${video.id}');
  }

  /// Refresh feed based on current tab (For You or Following)
  Future<void> refreshFeedByTab(FeedTab feedTab) async {
    secureLog('🔄 Refreshing ${feedTab.name} feed...');
    try {
      if (feedTab == FeedTab.forYou) {
        final rid = DateTime.now().microsecondsSinceEpoch.toString();
        _updateForYouFeed(
          videos: state.forYouVideos,
          isLoading: true,
          nextCursor: currentForYouSlice(state).nextCursor,
          clearError: true,
        );
        state = state.copyWith(
          activeFeed: FeedTab.forYou,
          forYouSlice: currentForYouSlice(state).copyWith(requestId: rid),
        );
        await _refreshForYou(rid: rid);
        secureLog(
            '✅ For You feed refreshed: ${state.forYouVideos.length} videos');
      } else if (feedTab == FeedTab.following) {
        secureLog('⏭️ Progression tab has no video feed to refresh');
      } else {
        secureLog('⏭️ Threads feed does not support video refresh');
      }
    } catch (e) {
      secureLog('❌ Error refreshing ${feedTab.name} feed: $e');
      rethrow; // Re-throw to handle in UI
    }
  }

  /// Update For You videos with ranked/personalized feed
  /// 🚀 NEWEST FIRST: Ensures newest videos remain at top even after algorithm ranking
  void updateForYouVideos(List<HomeVideo> videos) {
    // 🚀 NEWEST FIRST: Re-sort to ensure newest videos are at top
    final sortedVideos = List<HomeVideo>.from(videos);
    sortedVideos.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime); // Reverse order for newest first
    });

    _updateForYouFeed(
      videos: sortedVideos,
      isLoading: state.isLoading,
      nextCursor: currentForYouSlice(state).nextCursor,
      clearError: state.error == null,
      error: state.error,
    );
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      unawaited(_cacheForYouFeed(userId: userId, videos: sortedVideos));
    }
    secureLog(
      '🎯 UnifiedAlgorithm: For You feed updated with ${sortedVideos.length} ranked videos (newest first)',
    );
  }

  /// Update Following videos with ranked/personalized feed
  /// 🚀 NEWEST FIRST: Ensures newest videos remain at top even after algorithm ranking
  void updateFollowingVideos(List<HomeVideo> videos) {
    // 🚀 NEWEST FIRST: Re-sort to ensure newest videos are at top
    final sortedVideos = List<HomeVideo>.from(videos);
    sortedVideos.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime); // Reverse order for newest first
    });

    state = state.copyWith(followingVideos: sortedVideos);
    secureLog(
      '🎯 UnifiedAlgorithm: Following feed updated with ${sortedVideos.length} ranked videos (newest first)',
    );
  }

  /// Pause all videos (single path via GlobalPlaybackManager)
  void pauseAllVideos() {
    try {
      GlobalPlaybackManager.instance.pauseAll();
      GlobalPlaybackManager.instance.block(reason: 'home_provider_pause');
    } catch (e) {
      secureLog('❌ HomeProvider: pauseAllVideos: $e');
    }
  }

  /// Resume: set home as active owner so current video can play
  void resumeCurrentVideo() {
    try {
      GlobalPlaybackManager.instance.setActiveOwner(PlaybackOwners.home);
    } catch (e) {
      secureLog('❌ HomeProvider: resumeCurrentVideo: $e');
    }
  }

  Future<void> loadVideos() async {
    if (!mounted) {
      return;
    }
    secureLog('🔄 loadVideos() called - hasLoaded: ${state.hasLoaded}');
    secureLog(
      '📊 Current state - forYouVideos: ${state.forYouVideos.length}, followingVideos: ${state.followingVideos.length}',
    );

    if (state.forYouVideos.isNotEmpty) {
      secureLog(
        '⚡ Videos already visible (${state.forYouVideos.length}) — refresh in background',
      );
      state = state.copyWith(isLoading: false, hasLoaded: true);
      GlobalPlaybackManager.instance.preloadStartupWindow(state.forYouVideos);
      unawaited(
        Future<void>(() async {
          try {
            await _fetchFreshVideosInBackground();
            if (!mounted) return;
            await _loadUserLikeStates();
            if (!mounted) return;
            _preloadAvatars();
          } catch (e) {
            secureLog('❌ HomeProvider: Background refresh failed: $e');
          }
        }),
      );
      return;
    }

    if (state.hasLoaded && state.forYouVideos.isNotEmpty) {
      secureLog(
        '⏭️ Videos already loaded (${state.forYouVideos.length} videos), skipping...',
      );
      return;
    }

    // If hasLoaded but videos are empty, force reload
    if (state.hasLoaded && state.forYouVideos.isEmpty) {
      secureLog(
          '⚠️ Videos marked as loaded but list is empty - forcing reload');
      state = state.copyWith(hasLoaded: false);
    }

    secureLog('🚀 Starting video loading...');

    // Show loading state initially
    state = state.copyWith(isLoading: true);

    try {
      await _loadCachedVideos();
      state = state.copyWith(hasLoaded: true);
      // Run non-blocking in background so first video can play immediately
      Future(() async {
        try {
          await _fetchFreshVideosInBackground();
          if (!mounted) return;
          await _loadUserLikeStates();
          if (!mounted) return;
          _preloadAvatars();
        } catch (e) {
          secureLog('❌ HomeProvider: Background load failed: $e');
        }
      });
      secureLog('✅ loadVideos() completed successfully');
    } catch (e) {
      secureLog('❌ Error loading videos: $e');
      final cachedVideos = state.forYouVideos;
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        forYouVideos: cachedVideos,
        error: cachedVideos.isEmpty
            ? 'Failed to load videos. Check your connection.'
            : 'Connection is unstable. Showing your last loaded feed.',
      );
    }
  }

  /// Hydrate feed from memory/disk as early as possible (before Firebase).
  void ensureInstantFeedReady() {
    if (state.forYouVideos.isNotEmpty) return;

    final List<HomeVideo>? memoryVideos = _startupLoader.peekMemoryWarmFeed();
    if (memoryVideos != null) {
      secureLog(
        '⚡ HomeProvider: Instant feed from memory cache '
        '(${memoryVideos.length} videos)',
      );
      _applyWarmForYouFeed(memoryVideos);
      return;
    }

    if (!state.isLoading) {
      state = state.copyWith(isLoading: true);
    }
    unawaited(warmStartFromCache());
    startForYouRealtimeFeed();
  }

  Future<void> warmStartFromCache() async {
    if (state.forYouVideos.isNotEmpty) return;
    final List<HomeVideo>? memoryVideos = _startupLoader.peekMemoryWarmFeed();
    if (memoryVideos != null) {
      _applyWarmForYouFeed(memoryVideos);
      return;
    }
    if (!state.isLoading) {
      state = state.copyWith(isLoading: true);
    }
    final String? userId = _startupLoader.resolveWarmStartUserId();
    final bool restored = await _restoreWarmForYouFeed(userId);
    if (!restored && state.forYouVideos.isEmpty && state.isLoading) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadCachedVideos() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    try {
      final HomeFeedStartupSuccess result =
          await _startupLoader.loadFreshStartupFeed(cacheUserId: userId);
      _updateForYouFeed(
        videos: result.videos,
        isLoading: false,
        nextCursor: null,
        lastDocument: null,
        clearError: result.clearError,
        error: result.error,
      );
      state = state.copyWith(followingVideos: const <HomeVideo>[]);
      if (result.cacheUserId != null && result.videos.isNotEmpty) {
        unawaited(
          _cacheForYouFeed(
            userId: result.cacheUserId!,
            videos: result.videos,
          ),
        );
      }
      secureLog(
        '✅ Loaded videos for instant display: ${state.forYouVideos.length} items',
      );
      if (state.forYouVideos.isNotEmpty) {
        GlobalPlaybackManager.instance.preloadStartupWindow(state.forYouVideos);
      }
    } catch (e) {
      secureLog('❌ Error loading fresh startup videos: $e');
      final HomeFeedStartupRecovery recovery =
          await _startupLoader.recoverStartupFailure(
        userId: userId,
        existingVideos: state.forYouVideos,
      );
      switch (recovery.kind) {
        case HomeFeedStartupRecoveryKind.restoredFromWarmCache:
          _applyWarmForYouFeed(recovery.videos);
          state = state.copyWith(
            isLoading: false,
            error: recovery.errorMessage,
          );
        case HomeFeedStartupRecoveryKind.keepExistingVisible:
          state = state.copyWith(
            isLoading: false,
            error: recovery.errorMessage,
          );
          GlobalPlaybackManager.instance.preloadStartupWindow(
            state.forYouVideos,
          );
        case HomeFeedStartupRecoveryKind.showEmptyError:
          _updateForYouFeed(
            videos: const <HomeVideo>[],
            isLoading: false,
            nextCursor: null,
            lastDocument: null,
            error: recovery.errorMessage,
          );
          state = state.copyWith(followingVideos: const <HomeVideo>[]);
      }
    }
  }

  Future<void> _cacheForYouFeed({
    required String userId,
    required List<HomeVideo> videos,
    Map<String, dynamic>? nextCursor,
  }) async {
    await _startupLoader.persistWarmFeed(
      userId: userId,
      videos: videos,
      nextCursor: nextCursor,
    );
  }

  Future<bool> _restoreWarmForYouFeed(String? userId) async {
    final List<HomeVideo>? cachedVideos =
        await _startupLoader.restoreDiskWarmFeed(userId);
    if (cachedVideos == null) {
      return false;
    }
    _applyWarmForYouFeed(cachedVideos);
    return true;
  }

  void _applyWarmForYouFeed(List<HomeVideo> cachedVideos) {
    _updateForYouFeed(
      videos: cachedVideos,
      isLoading: false,
      nextCursor: null,
      lastDocument: null,
      clearError: true,
    );
    state = state.copyWith(
      followingVideos: const [],
      hasLoaded: true,
    );
    GlobalPlaybackManager.instance.preloadStartupWindow(cachedVideos);
  }

  /// Preload avatars for instant display (conservative to prevent buffer overflow)
  Future<void> _preloadAvatars() async {
    try {
      final avatarUrls = <String>[];

      // Only preload first video to prevent buffer overflow
      if (state.forYouVideos.isNotEmpty) {
        final firstVideo = state.forYouVideos.first;
        if (firstVideo.creator.avatarURL?.isNotEmpty == true) {
          avatarUrls.add(firstVideo.creator.avatarURL!);
        }
      }

      // Only preload first following video if different from For You
      if (state.followingVideos.isNotEmpty) {
        final firstFollowingVideo = state.followingVideos.first;
        if (firstFollowingVideo.creator.avatarURL?.isNotEmpty == true &&
            !avatarUrls.contains(firstFollowingVideo.creator.avatarURL!)) {
          avatarUrls.add(firstFollowingVideo.creator.avatarURL!);
        }
      }

      // Preload avatars for instant display with timeout
      if (avatarUrls.isNotEmpty) {
        await UnifiedAvatarService().preloadAvatars(avatarUrls).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            secureLog(
              '⏰ Avatar preloading timeout - continuing without preloaded avatars',
            );
          },
        );
        secureLog(
            '✅ Preloaded ${avatarUrls.length} avatars for instant display');
      }
    } catch (e) {
      secureLog('⚠️ Failed to preload avatars: $e (non-critical)');
    }
  }

  /// Load user's like states for all videos
  Future<void> _loadUserLikeStates() async {
    try {
      secureLog('💖 Loading user like states for all videos...');

      // Load like states for For You videos
      await _loadLikeStatesForFeed(state.forYouVideos, 'For You');

      // Load like states for Following videos
      await _loadLikeStatesForFeed(state.followingVideos, 'Following');

      secureLog('✅ User like states loaded successfully');
    } catch (e) {
      secureLog('⚠️ Failed to load user like states: $e (non-critical)');
    }
  }

  /// Load like states for a specific feed
  Future<void> _loadLikeStatesForFeed(
    List<HomeVideo> videos,
    String feedName,
  ) async {
    if (videos.isEmpty) {
      return;
    }
    try {
      secureLog(
        '💖 Loading like states for $feedName feed (${videos.length} videos)',
      );
      final List<HomeVideo> updatedVideos =
          await _engagementCoordinator.loadLikeStatesInBatches(videos);
      if (!mounted) {
        return;
      }
      if (feedName == 'For You') {
        state = state.copyWith(forYouVideos: updatedVideos);
      } else if (feedName == 'Following') {
        state = state.copyWith(followingVideos: updatedVideos);
      }
      secureLog(
        '✅ Loaded like states for $feedName feed '
        '(${updatedVideos.length} videos)',
      );
    } catch (e) {
      secureLog('❌ Error loading like states for $feedName feed: $e');
    }
  }

  /// Fetch fresh videos in background with improved error handling
  Future<void> _fetchFreshVideosInBackground() async {
    final Future<void>? inFlight = _freshVideosRefreshInFlight;
    if (inFlight != null) {
      secureLog('⏭️ HomeProvider: Background refresh already in flight');
      return inFlight;
    }

    late final Future<void> refreshFuture;
    refreshFuture = _fetchFreshVideosInBackgroundImpl().whenComplete(() {
      if (identical(_freshVideosRefreshInFlight, refreshFuture)) {
        _freshVideosRefreshInFlight = null;
      }
    });
    _freshVideosRefreshInFlight = refreshFuture;
    return refreshFuture;
  }

  Future<void> _fetchFreshVideosInBackgroundImpl() async {
    if (!mounted) {
      return;
    }
    try {
      secureLog('🔄 Fetching fresh videos in background...');
      try {
        final HomeFeedBackgroundRefreshVideos? refreshed =
            await _backgroundRefresh.fetchRefreshedVideos();
        if (!mounted) {
          return;
        }
        if (refreshed != null) {
          final List<HomeVideo> mergedVideos = _mergeIncomingForYouVideos(
            refreshed.videos,
          );
          _updateForYouFeed(
            videos: mergedVideos,
            isLoading: false,
            nextCursor: null,
            lastDocument: null,
            clearError: true,
          );
          final String? userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            unawaited(
              _cacheForYouFeed(userId: userId, videos: mergedVideos),
            );
          }
        }
      } catch (e) {
        secureLog('⚠️ Background video refresh failed (non-critical): $e');
      }
      try {
        await _backgroundRefresh.syncEngagementStates(
          syncLikeStates: syncLikeStates,
          syncFavoriteStates: syncFavoriteStates,
          syncCommentCounts: syncCommentCounts,
        );
      } catch (e) {
        secureLog('⚠️ Video state sync failed: $e (non-critical)');
      }
      if (!mounted) {
        return;
      }
      secureLog(
        '✅ Fresh videos loading completed: ${state.forYouVideos.length} forYou, '
        '${state.followingVideos.length} following',
      );
    } catch (e) {
      secureLog('❌ Error fetching fresh videos: $e');
      secureLog(
        '💡 HomeProvider: keeping current feed visible during background failure',
      );
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final bool forYouIsEmpty = state.forYouVideos.isEmpty;
        _updateForYouFeed(
          videos: forYouIsEmpty ? const <HomeVideo>[] : state.forYouVideos,
          isLoading: false,
          nextCursor:
              forYouIsEmpty ? null : currentForYouSlice(state).nextCursor,
          lastDocument: forYouIsEmpty ? null : homeFeedStateUnset,
          error: forYouIsEmpty
              ? 'Unable to load videos right now. Check your connection and try again.'
              : 'Connection is unstable. Showing your last loaded feed.',
        );
      });
    }
  }

  // MARK: - Feed Switching (Hard refresh per feed)

  Future<void> switchFeed(FeedTab type) async {
    secureLog('🔄 switchFeed: Called with type: ${type.displayName}');
    state = state.copyWith(activeFeed: type);

    // Threads / Progression tabs don't load home video feeds
    if (type == FeedTab.threads || type == FeedTab.following) {
      secureLog('🔄 switchFeed: ${type.displayName} — no video feed load');
      return;
    }

    final bool hasCachedVideos = state.forYouVideos.isNotEmpty;
    final bool isAlreadyLoading = state.forYouSlice?.isLoading ?? false;

    if (hasCachedVideos || isAlreadyLoading) {
      secureLog('✅ switchFeed: Reusing cached For You feed');
      return;
    }

    final String rid = DateTime.now().microsecondsSinceEpoch.toString();
    secureLog('🔄 switchFeed: Switching to For You feed');
    _updateForYouFeed(
      videos: state.forYouVideos,
      isLoading: true,
      nextCursor: currentForYouSlice(state).nextCursor,
      clearError: true,
    );
    state = state.copyWith(
      forYouSlice: currentForYouSlice(state).copyWith(requestId: rid),
    );
    await _refreshForYou(rid: rid);
  }

  Future<void> _refreshForYou({required String rid}) async {
    final List<HomeVideo> previousVideos =
        List<HomeVideo>.from(state.forYouVideos);
    final Map<String, dynamic>? previousCursor =
        currentForYouSlice(state).nextCursor;
    final Object? previousLastDocument = state.lastForYouDoc;

    try {
      final HomeForYouFeedPage page = await _forYouFeedLoader.refresh(
        previousVideos: previousVideos,
        previousCursor: previousCursor,
        previousLastDocument: previousLastDocument,
      );
      if (state.forYouSlice?.requestId != rid) {
        return;
      }
      final List<HomeVideo> mergedVideos = _mergeIncomingForYouVideos(
        page.videos,
      );
      _updateForYouFeed(
        videos: mergedVideos,
        isLoading: false,
        nextCursor: page.nextCursor,
        lastDocument: page.lastDocument,
        clearError: page.clearError,
        error: page.error,
      );
      if (page.clearError && page.error == null) {
        final String? userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          unawaited(
            _cacheForYouFeed(
              userId: userId,
              videos: mergedVideos,
              nextCursor: page.nextCursor,
            ),
          );
        }
      }
    } catch (e) {
      if (state.forYouSlice?.requestId != rid) return;
      final existingItems = state.forYouSlice?.items ?? state.forYouVideos;
      _updateForYouFeed(
        videos: existingItems,
        isLoading: false,
        nextCursor: currentForYouSlice(state).nextCursor,
        error: existingItems.isEmpty
            ? 'Failed to refresh videos. Check your connection.'
            : 'Connection is unstable. Showing your last loaded feed.',
      );
    }
  }

  Future<void> fetchMoreActive() async {
    final FeedTab active = state.activeFeed ?? FeedTab.forYou;
    if (active == FeedTab.forYou) {
      final FeedSlice s = currentForYouSlice(state);
      if (s.isLoading || s.nextCursor == null) return;
      final String rid = DateTime.now().microsecondsSinceEpoch.toString();
      state = state.copyWith(
        forYouSlice: s.copyWith(isLoading: true, requestId: rid),
      );
      try {
        final HomeForYouFeedPage page = await _forYouFeedLoader.loadMore(
          existingVideos: s.items,
          lastDocument: s.nextCursor?['lastDoc'],
        );
        if (state.forYouSlice?.requestId != rid) return;
        _updateForYouFeed(
          videos: page.videos,
          isLoading: false,
          nextCursor: page.nextCursor,
          lastDocument: page.lastDocument,
          clearError: true,
        );
      } catch (e) {
        if (state.forYouSlice?.requestId != rid) return;
        final existingItems = state.forYouSlice?.items ?? state.forYouVideos;
        _updateForYouFeed(
          videos: existingItems,
          isLoading: false,
          nextCursor: s.nextCursor,
          error: existingItems.isEmpty
              ? 'Failed to load more videos. Check your connection.'
              : 'Could not load more videos right now.',
        );
      }
    } else if (active == FeedTab.following) {
      final FeedSlice? s = state.followingSlice;
      if (s == null || s.isLoading || s.nextCursor == null) return;
      final String rid = DateTime.now().microsecondsSinceEpoch.toString();
      state = state.copyWith(
        followingSlice: s.copyWith(isLoading: true, requestId: rid),
      );
      try {
        final String? viewerId = FirebaseAuth.instance.currentUser?.uid;
        if (viewerId == null) return;
        final HomeFollowingFeedPage page = await _followingFeedLoader.loadMore(
          viewerId: viewerId,
          existingVideos: s.items,
          nextCursor: s.nextCursor,
        );
        if (state.followingSlice?.requestId != rid) return;
        final FeedSlice? pagedSlice = state.followingSlice?.copyWith(
          items: page.videos,
          nextCursor: page.nextCursor,
          isLoading: false,
          clearError: true,
        );
        state = state.copyWith(
          followingSlice: pagedSlice,
          followingVideos: page.videos,
          lastFollowingDoc: page.lastDocument,
        );
      } catch (e) {
        if (state.followingSlice?.requestId != rid) return;
        final errorSlice = state.followingSlice?.copyWith(
          isLoading: false,
          error: e.toString(),
        );
        state = state.copyWith(
          followingSlice: errorSlice,
          followingVideos: errorSlice?.items ?? state.followingVideos,
        );
      }
    } else {
      return;
    }
  }

  // MARK: - Fetch Videos

  Future<void> fetchForYouVideos({bool reset = false}) async {
    if (reset) {
      await refreshFeedByTab(FeedTab.forYou);
      return;
    }

    final FeedTab previousFeed = state.activeFeed ?? FeedTab.forYou;
    try {
      state = state.copyWith(activeFeed: FeedTab.forYou);
      await fetchMoreActive();
    } finally {
      state = state.copyWith(activeFeed: previousFeed);
    }
  }

  Future<void> fetchFollowingVideos({
    required List<String> followingIds,
    bool reset = false,
  }) async {
    await refreshFollowingFeed(
      reset: reset,
      fallbackFollowingIds: followingIds,
    );
  }

  Future<void> refreshFollowingFeed({
    bool reset = true,
    List<String> fallbackFollowingIds = const <String>[],
  }) async {
    try {
      final String? viewerId = FirebaseAuth.instance.currentUser?.uid;
      if (viewerId != null) {
        secureLog(
          '👥 Fetching Following videos from Connections for user $viewerId',
        );
      }
      final HomeFollowingFeedPage page = await _followingFeedLoader.refresh(
        viewerId: viewerId,
        fallbackFollowingIds: fallbackFollowingIds,
        reset: reset,
        existingVideos: state.followingVideos,
        lastFollowingDoc: state.lastFollowingDoc,
      );
      if (viewerId != null && !page.hadConnections) {
        secureLog('👥 No connections found for Following feed');
      }
      _updateFollowingFeed(
        videos: page.videos,
        isLoading: false,
        nextCursor: page.nextCursor,
        lastDocument: page.lastDocument,
        clearError: true,
      );
      if (page.videos.isNotEmpty) {
        secureLog(
          '✅ Following feed updated: ${page.videos.length} videos from '
          'Connections',
        );
      }
    } catch (e) {
      secureLog('Error fetching ranked Following feed: $e');
    }
  }

  // MARK: - Load More Content

  bool shouldLoadMoreContent(int currentIndex, FeedTab feed) {
    final videos = this.videos(feed);
    return currentIndex >= videos.length - 2 &&
        hasMoreContent &&
        !isLoadingMore;
  }

  Future<void> loadMoreVideosIfNeeded({
    required int currentIndex,
    required FeedTab feed,
  }) async {
    if (!shouldLoadMoreContent(currentIndex, feed)) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      if (state.activeFeed != feed) {
        state = state.copyWith(activeFeed: feed);
      }
      if (feed != FeedTab.threads) {
        await fetchMoreActive();
      }
    } catch (e) {
      secureLog('Error loading more videos: $e');
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // MARK: - Video Actions

  Future<void> toggleLike(String videoId) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }
      final bool success = await _likeService.toggleLike(videoId, user.uid);
      if (success) {
        await setVideoLikeStateFromService(videoId);
      }
    } catch (e) {
      secureLog('Error toggling like: $e');
    }
  }

  /// Bookmark toggle — same persistence path as fullscreen player rail.
  Future<void> toggleFavorite(String videoId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await _bookmarkService.initialize(user.uid);
    final BookmarkResult result =
        await _bookmarkService.toggleBookmark(videoId);
    if (!result.success || result.isBookmarked == null) {
      return;
    }
    final bool favorited = result.isBookmarked!;
    _updateVideoAcrossFeeds(
      videoId,
      (HomeVideo video) => video.copyWith(isFavorited: favorited),
    );
  }

  // MARK: - Sync States

  Future<void> syncLikeStates() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      secureLog('syncLikeStates: no user');
      return;
    }
    await _engagementCoordinator.preloadUserLikes(user.uid);
    _replaceVideoFeeds(
      (HomeVideo video) => applyLikeStateToVideo(
          video, _engagementCoordinator.likeStateFor(video.id)),
    );
    secureLog('Syncing like states: done');
  }

  Future<void> syncFavoriteStates() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      secureLog('syncFavoriteStates: no user');
      return;
    }
    await _bookmarkService.initialize(user.uid);
    secureLog('Syncing favorite states from UnifiedBookmarkService...');
    _replaceVideoFeeds(
      (HomeVideo video) => video.copyWith(
        isFavorited: _bookmarkService.isBookmarked(video.id),
      ),
    );
  }

  Future<void> syncCommentCounts() async {
    secureLog('Syncing comment counts...');
    try {
      final List<HomeVideo> allVideos = <HomeVideo>[
        ...state.forYouVideos,
        ...state.followingVideos,
      ];
      if (allVideos.isEmpty) {
        secureLog('No videos to sync comment counts for');
        return;
      }
      final Map<String, int> commentCounts =
          await _engagementCoordinator.fetchCommentCountsForVideos(allVideos);
      final List<HomeVideo> updatedForYouVideos = applyCommentCountsToVideos(
        state.forYouVideos,
        commentCounts,
      );
      final List<HomeVideo> updatedFollowingVideos = applyCommentCountsToVideos(
        state.followingVideos,
        commentCounts,
      );
      if (feedsHaveCommentCountChanges(
        beforeForYou: state.forYouVideos,
        afterForYou: updatedForYouVideos,
        beforeFollowing: state.followingVideos,
        afterFollowing: updatedFollowingVideos,
      )) {
        state = state.copyWith(
          forYouVideos: updatedForYouVideos,
          followingVideos: updatedFollowingVideos,
        );
        secureLog('Comment counts synchronized successfully');
      } else {
        secureLog('Comment counts are already up to date');
      }
    } catch (e) {
      secureLog('Error syncing comment counts: $e');
    }
  }

  /// Update comment count for a specific video
  Future<void> updateVideoCommentCount(String videoId) async {
    try {
      final int newCommentCount =
          await _engagementCoordinator.fetchCommentCountForVideo(videoId);
      _updateVideoAcrossFeeds(videoId, (HomeVideo video) {
        return video.copyWith(comments: newCommentCount);
      });
      secureLog('Updated comment count for video $videoId: $newCommentCount');
    } catch (e) {
      secureLog('Error updating comment count for video $videoId: $e');
    }
  }

  // MARK: - Private Methods

  void _updateVideoLikeState(String videoId) {
    state = updateVideoAcrossFeeds(
      state,
      videoId,
      (HomeVideo video) => video.copyWith(
        isLiked: !video.isLiked,
        likes: video.isLiked ? video.likes - 1 : video.likes + 1,
      ),
    );
  }

  /// Set video like state from enhanced service (for proper sync)
  Future<void> setVideoLikeStateFromService(String videoId) async {
    try {
      state = updateVideoAcrossFeeds(
        state,
        videoId,
        _engagementCoordinator.mapLikeStateForVideo,
      );
    } catch (e) {
      secureLog('Error syncing like state from service: $e');
    }
  }

  Future<void> _updateVideoFavoriteState(String videoId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      await _bookmarkService.initialize(user.uid);
      final BookmarkResult result =
          await _bookmarkService.toggleBookmark(videoId);
      if (!result.success || result.isBookmarked == null) {
        secureLog('❌ Bookmark toggle failed for $videoId: ${result.error}');
        return;
      }
      final bool favorited = result.isBookmarked!;
      state = updateVideoAcrossFeeds(
        state,
        videoId,
        (HomeVideo video) => video.copyWith(isFavorited: favorited),
      );
      secureLog('✅ Successfully toggled favorite for video: $videoId');
    } catch (e) {
      secureLog('❌ Error toggling favorite for video $videoId: $e');
      rethrow;
    }
  }

  void _updateVideoAcrossFeeds(
    String videoId,
    HomeVideo Function(HomeVideo) update,
  ) {
    state = updateVideoAcrossFeeds(state, videoId, update);
  }

  void _replaceVideoFeeds(HomeVideo Function(HomeVideo) update) {
    state = replaceVideosInFeeds(state, update);
  }

  // MARK: - Refresh

  Future<void> refreshFeed() async {
    state = state.copyWith(
      hasLoaded: false,
      forYouSlice: null,
      followingSlice: null,
      lastForYouDoc: null,
      lastFollowingDoc: null,
    );
    await refreshFeedByTab(FeedTab.forYou);
  }

  /// Simple retry method for failed video loading
  Future<void> retryLoadVideos() async {
    secureLog('🔄 Retrying video loading...');
    state = state.copyWith(
      clearError: true,
      hasLoaded: false,
      isLoading: false,
      forYouSlice: null,
      lastForYouDoc: null,
    );
    await loadVideos();
  }
}
