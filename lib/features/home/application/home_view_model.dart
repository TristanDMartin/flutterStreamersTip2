// cspell:ignore Favorited
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_first_frame_gate.dart';
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
import '../domain/home_feed_pagination.dart';
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
import 'package:streamers_tip/utils/home_feed_interaction_diagnostics.dart';
import 'package:streamers_tip/utils/interaction_diagnostics.dart';
import 'package:streamers_tip/utils/like_interaction_boundary.dart';
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
  int _avatarPreloadEpoch = 0;
  int _forYouRecycleCycle = 0;

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
    if (!HomeFirstFrameGate.instance.isFirstFrameRendered) {
      HomeFirstFrameGate.instance.runAfterFirstFrame(() {
        unawaited(_applyForYouRealtimeSnapshot(result));
      });
      return;
    }
    _applyLiveFeedSnapshot(
      incoming: result.videos,
      reason: 'live_feed_snapshot',
    );
    if (result.videos.isNotEmpty) {
      GlobalPlaybackManager.instance.preloadStartupWindow(
        _readyVideosFromFeed(state.forYouVideos),
        requestFocusOnStart: false,
      );
    }
  }

  void _applyLiveFeedSnapshot({
    required List<HomeVideo> incoming,
    required String reason,
  }) {
    if (!mounted) {
      return;
    }
    if (LikeInteractionBoundary.shouldDeferHeavyWork) {
      LikeInteractionBoundary.reportFeedRefresh(source: reason);
      final List<HomeVideo> queuedIncoming =
          List<HomeVideo>.unmodifiable(incoming);
      LikeInteractionBoundary.runOrQueue(
        () => _applyLiveFeedSnapshot(
          incoming: queuedIncoming,
          reason: '${reason}_queued_after_interaction',
        ),
        reason: reason,
      );
      return;
    }
    final List<HomeVideo> current = List<HomeVideo>.from(state.forYouVideos);
    HomeFeedInteractionDiagnostics.logFeedReplaceAttempt(
      reason: reason,
      incomingCount: incoming.length,
      currentCount: current.length,
    );
    if (current.isNotEmpty && incoming.length < current.length) {
      InteractionDiagnostics.logBlockedFeedReplacement(
        incomingCount: incoming.length,
        currentCount: current.length,
      );
      final List<HomeVideo> patched = mergeHomeFeedPreserveOrder(
        existing: current,
        incoming: incoming,
      );
      if (!_feedListsEquivalent(current, patched)) {
        _updateForYouFeed(
          videos: patched,
          isLoading: false,
          nextCursor: currentForYouSlice(state).nextCursor,
          clearError: true,
        );
        secureLog(
          '✅ HomeProvider: Patched feed from partial snapshot ($reason) '
          'incoming=${incoming.length} current=${current.length} '
          'result=${patched.length}',
        );
      }
      return;
    }
    if (shouldRejectShrinkingFeedReplacement(
      current: current,
      incoming: incoming,
      reason: reason,
    )) {
      HomeFeedInteractionDiagnostics.logFeedReplaceBlocked(reason: reason);
      secureLog(
        '⏭️ HomeProvider: Blocked feed replacement ($reason) '
        'incoming=${incoming.length} current=${current.length}',
      );
      return;
    }
    final List<HomeVideo> mergedVideos = _mergeIncomingForYouVideos(incoming);
    if (mergedVideos.length < current.length) {
      HomeFeedInteractionDiagnostics.logFeedReplaceBlocked(
        reason: 'merge_shrink_guard',
      );
      secureLog(
        '⏭️ HomeProvider: Blocked shrinking merge ($reason) '
        'merged=${mergedVideos.length} current=${current.length}',
      );
      return;
    }
    _updateForYouFeed(
      videos: mergedVideos,
      isLoading: false,
      nextCursor: currentForYouSlice(state).nextCursor,
      clearError: true,
    );
    HomeFeedInteractionDiagnostics.logFeedReplaceApplied(
      reason: reason,
      resultCount: mergedVideos.length,
    );
    secureLog(
      '🔄 HomeProvider: Live feed snapshot applied '
      '(${mergedVideos.length} videos, reason=$reason)',
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
    final List<HomeVideo> serviceVideos = _videoService.getAllVideos();
    if (serviceVideos.isEmpty) {
      return;
    }
    _applyLiveFeedSnapshot(
      incoming: serviceVideos,
      reason: 'optimistic_overlay_refresh',
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
    final CachedFeedResult? warm = AlgorithmCacheService().peekForYouWarmFeed();
    if (warm != null && warm.videos.isNotEmpty) {
      return HomeState(
        forYouVideos: warm.videos,
        isLoading: false,
        hasLoaded: true,
        hasMoreContent: true,
      );
    }
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
          '${video.caption}:${video.overlayCaption}:'
          '${video.comments}:${video.isFavorited}';
    }).join('|');
  }

  bool _feedListsEquivalent(List<HomeVideo> a, List<HomeVideo> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }

  List<HomeVideo> _mergeIncomingForYouVideos(List<HomeVideo> incomingVideos) {
    final List<HomeVideo> incoming =
        dedupeHomeVideosById(_readyVideosFromFeed(incomingVideos));
    final List<HomeVideo> existing = dedupeHomeVideosById(state.forYouVideos);
    return mergeHomeFeedPreserveOrder(
      existing: existing,
      incoming: incoming,
    );
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

  void _appendRecycledForYouFeed({
    required int currentIndex,
    String reason = 'end_of_feed',
  }) {
    final List<HomeVideo> current = List<HomeVideo>.from(state.forYouVideos);
    if (current.length < 2) {
      secureLog(
        'END_FEED_RECYCLE_SKIPPED reason=$reason count=${current.length}',
      );
      return;
    }

    final int safeIndex = currentIndex.clamp(0, current.length - 1);
    final Set<String> recentIds = <String>{};
    for (int index = safeIndex; index >= 0 && recentIds.length < 3; index--) {
      recentIds.add(current[index].id);
    }
    final String currentVideoId = current[safeIndex].id;
    final List<HomeVideo> ranked = List<HomeVideo>.from(current);
    ranked.sort((HomeVideo a, HomeVideo b) {
      final bool aRecent = recentIds.contains(a.id);
      final bool bRecent = recentIds.contains(b.id);
      if (aRecent != bRecent) {
        return aRecent ? 1 : -1;
      }
      final int aEngagement = a.likes + a.comments + a.views;
      final int bEngagement = b.likes + b.comments + b.views;
      if (aEngagement != bEngagement) {
        return bEngagement.compareTo(aEngagement);
      }
      final int aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final int bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    final List<HomeVideo> recycled = <HomeVideo>[];
    String? previousId = currentVideoId;
    for (final HomeVideo video in ranked) {
      if (video.id == previousId) {
        continue;
      }
      recycled.add(video);
      previousId = video.id;
      if (recycled.length >= current.length.clamp(2, 12)) {
        break;
      }
    }

    if (recycled.isEmpty) {
      secureLog(
        'END_FEED_RECYCLE_SKIPPED reason=$reason no_candidate '
        'currentVideoId=$currentVideoId',
      );
      return;
    }

    _forYouRecycleCycle++;
    final List<HomeVideo> appended = <HomeVideo>[...current, ...recycled];
    final FeedSlice slice = currentForYouSlice(state).copyWith(
      items: appended,
      nextCursor: HomeFeedPagination.exhaustedCursor,
      isLoading: false,
      clearError: true,
    );
    _lastForYouFeedFingerprint = _feedFingerprint(appended);
    state = state.copyWith(
      forYouVideos: appended,
      forYouSlice: slice,
      isLoading: false,
      hasLoaded: true,
      hasMoreContent: true,
      clearError: true,
    );
    secureLog(
      'END_FEED_RECYCLE_APPEND feed=forYou cycle=$_forYouRecycleCycle '
      'sessionCycleId=forYou_$_forYouRecycleCycle '
      'from=${current.length} appended=${recycled.length} '
      'total=${appended.length}',
    );
    final int preloadIndex = (safeIndex + 1).clamp(0, appended.length - 1);
    GlobalPlaybackManager.instance.preloadAround(
      preloadIndex,
      appended,
      direction: 1,
      controllerOwner: PlaybackOwners.home,
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
        final List<HomeVideo> existingVideos =
            List<HomeVideo>.from(state.forYouVideos);
        if (existingVideos.isNotEmpty) {
          GlobalPlaybackManager.instance.preloadAround(
            0,
            existingVideos,
            direction: 1,
            controllerOwner: PlaybackOwners.home,
          );
          GlobalPlaybackManager.instance.setDesiredFocus(
            existingVideos.first.id,
            PlaybackOwners.home,
          );
        }
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
        _warmTopForYouPlaybackAfterRefresh();
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

  void _warmTopForYouPlaybackAfterRefresh() {
    if (!mounted || state.forYouVideos.isEmpty) {
      return;
    }
    final List<HomeVideo> videos = List<HomeVideo>.from(state.forYouVideos);
    GlobalPlaybackManager.instance.preloadAround(
      0,
      videos,
      direction: 1,
      controllerOwner: PlaybackOwners.home,
    );
    unawaited(
      GlobalPlaybackManager.instance.onVisibleIndexChanged(0, videos.first),
    );
    secureLog(
      'TOP_REFRESH_PLAYBACK_READY index=0 videoId=${videos.first.id} '
      'preloadNext=${videos.length > 1} preloadNext2=${videos.length > 2}',
    );
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
      HomeFirstFrameGate.instance.runAfterFirstFrame(() {
        unawaited(runDeferredBackgroundRefresh());
      });
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
    state = state.copyWith(isLoading: true);

    try {
      // Warm-first: paint disk/memory feed before waiting on network.
      await warmStartFromCache();
      if (!mounted) {
        return;
      }
      if (state.forYouVideos.isNotEmpty) {
        secureLog(
          '⚡ Warm feed painted (${state.forYouVideos.length}) — '
          'network refresh deferred after first frame',
        );
        state = state.copyWith(isLoading: false, hasLoaded: true);
        GlobalPlaybackManager.instance.preloadStartupWindow(state.forYouVideos);
        HomeFirstFrameGate.instance.runAfterFirstFrame(() {
          unawaited(runDeferredBackgroundRefresh());
        });
        return;
      }

      await _loadCachedVideos();
      if (!mounted) {
        return;
      }
      state = state.copyWith(hasLoaded: true);
      HomeFirstFrameGate.instance.runAfterFirstFrame(() {
        unawaited(runDeferredBackgroundRefresh());
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
  }

  /// Runs after first frame: network refresh, likes, avatars.
  Future<void> runDeferredBackgroundRefresh() async {
    if (!mounted) {
      return;
    }
    try {
      await _awaitDeferredBackgroundRefreshGate();
      if (!mounted) {
        return;
      }
      await _fetchFreshVideosInBackground();
      if (!mounted) {
        return;
      }
      await _preloadAvatars();
    } catch (e) {
      secureLog('❌ HomeProvider: Deferred background refresh failed: $e');
    }
  }

  Future<void> _awaitDeferredBackgroundRefreshGate() async {
    if (!LikeInteractionBoundary.hasFirstUserInteraction) {
      final Completer<void> gateCompleter = Completer<void>();
      LikeInteractionBoundary.runAfterFirstInteraction(
        () {
          if (!gateCompleter.isCompleted) {
            gateCompleter.complete();
          }
        },
        fallbackTimeout: const Duration(seconds: 8),
      );
      try {
        await gateCompleter.future.timeout(const Duration(seconds: 9));
      } on TimeoutException {
        // Proceed after fallback timeout.
      }
    }
    await LikeInteractionBoundary.waitUntilIdle();
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
    // Prefer painting warm feed before the network round-trip when possible.
    if (state.forYouVideos.isEmpty) {
      await _restoreWarmForYouFeed(userId);
    }
    try {
      final HomeFeedStartupSuccess result =
          await _startupLoader.loadFreshStartupFeed(cacheUserId: userId);
      if (shouldKeepWarmFeedOverEmptyNetwork(
        currentVideos: state.forYouVideos,
        networkVideos: result.videos,
      )) {
        secureLog(
          '⚡ Keeping warm feed (${state.forYouVideos.length}) after empty '
          'network startup result',
        );
        state = state.copyWith(
          isLoading: false,
          error: result.error ??
              'Could not refresh videos. Showing your last loaded feed.',
        );
        GlobalPlaybackManager.instance.preloadStartupWindow(state.forYouVideos);
        return;
      }
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
          // Auth/network often catches up right after cold-start timeout.
          HomeFirstFrameGate.instance.runAfterFirstFrame(() {
            unawaited(_retryStartupFeedAfterEmptyError());
          });
      }
    }
  }

  Future<void> _retryStartupFeedAfterEmptyError() async {
    if (!mounted || state.forYouVideos.isNotEmpty) {
      return;
    }
    try {
      final User? user =
          await HomeFeedStartupLoader.waitForFirebaseSignedInUser();
      if (!mounted || user == null) {
        return;
      }
      secureLog('🔄 HomeProvider: Retrying startup feed after empty error');
      state = state.copyWith(isLoading: true, error: null, hasLoaded: false);
      await _loadCachedVideos();
      if (!mounted) {
        return;
      }
      if (state.forYouVideos.isNotEmpty) {
        state = state.copyWith(hasLoaded: true, error: null);
        GlobalPlaybackManager.instance.preloadStartupWindow(state.forYouVideos);
      } else {
        state = state.copyWith(hasLoaded: true, isLoading: false);
      }
    } catch (e) {
      secureLog('⚠️ HomeProvider: Startup feed retry failed: $e');
      if (mounted && state.forYouVideos.isEmpty) {
        state = state.copyWith(isLoading: false, hasLoaded: true);
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

  /// Preload avatars for current + next + next+1 (non-blocking for playback).
  Future<void> _preloadAvatars() async {
    if (LikeInteractionBoundary.shouldDeferHeavyWork) {
      LikeInteractionBoundary.runOrQueue(
        () => unawaited(_preloadAvatars()),
        reason: 'preload_avatars',
      );
      return;
    }
    try {
      final List<String> avatarUrls = <String>[];
      void collectFromFeed(List<HomeVideo> videos) {
        final int limit = videos.length < 3 ? videos.length : 3;
        for (int i = 0; i < limit; i++) {
          final String? url = videos[i].creator.avatarURL;
          if (url != null && url.isNotEmpty && !avatarUrls.contains(url)) {
            avatarUrls.add(url);
          }
        }
      }

      if (state.forYouVideos.isNotEmpty) {
        collectFromFeed(state.forYouVideos);
      }
      if (state.followingVideos.isNotEmpty) {
        collectFromFeed(state.followingVideos);
      }

      if (avatarUrls.isNotEmpty) {
        final int epoch = ++_avatarPreloadEpoch;
        unawaited(Future<void>.delayed(const Duration(milliseconds: 2500), () {
          if (!mounted || epoch != _avatarPreloadEpoch) {
            return Future<void>.value();
          }
          return UnifiedAvatarService().preloadAvatars(avatarUrls).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              secureLog(
                '⏰ Avatar preloading timeout - continuing without preloaded avatars',
              );
            },
          );
        }));
        secureLog(
          '✅ Queued ${avatarUrls.length} avatars for warm-window preload',
        );
      }
    } catch (e) {
      secureLog('⚠️ Failed to preload avatars: $e (non-critical)');
    }
  }

  Future<void> _applyBackgroundVideoRefresh(
    HomeFeedBackgroundRefreshVideos refreshed,
  ) async {
    void applySnapshot() {
      if (!mounted) {
        return;
      }
      final Stopwatch applyWatch = Stopwatch()..start();
      _applyLiveFeedSnapshot(
        incoming: refreshed.videos,
        reason: 'background_video_refresh',
      );
      HomeFeedInteractionDiagnostics.logBgRefreshPhase(
        'APPLY_DONE',
        ms: applyWatch.elapsedMilliseconds,
      );
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && state.forYouVideos.isNotEmpty) {
        unawaited(
          _cacheForYouFeed(
            userId: userId,
            videos: state.forYouVideos,
          ),
        );
      }
    }

    if (LikeInteractionBoundary.shouldDeferHeavyWork) {
      HomeFeedInteractionDiagnostics.logBgRefreshPhase(
        'APPLY_SKIPPED',
        reason: 'scroll',
      );
      LikeInteractionBoundary.runOrQueue(
        applySnapshot,
        reason: 'background_video_refresh',
      );
      return;
    }
    applySnapshot();
  }

  Future<void> _syncEngagementStatesWhenIdle() async {
    if (LikeInteractionBoundary.shouldDeferHeavyWork) {
      HomeFeedInteractionDiagnostics.logBgRefreshPhase(
        'SYNC_SKIPPED',
        reason: 'scroll',
      );
      LikeInteractionBoundary.runOrQueue(
        () => unawaited(_syncEngagementStatesWhenIdle()),
        reason: 'engagement_sync',
      );
      return;
    }
    await Future.wait(<Future<void>>[
      syncFavoriteStates(),
      syncCommentCounts(),
    ]).timeout(_backgroundRefresh.engagementSyncTimeout);
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
    final Stopwatch refreshWatch = Stopwatch()..start();
    HomeFeedInteractionDiagnostics.logBgRefreshPhase('START');
    try {
      secureLog('🔄 Fetching fresh videos in background...');
      try {
        final HomeFeedBackgroundRefreshVideos? refreshed =
            await _backgroundRefresh.fetchRefreshedVideos();
        HomeFeedInteractionDiagnostics.logBgRefreshPhase(
          'FETCH_DONE',
          ms: refreshWatch.elapsedMilliseconds,
        );
        if (!mounted) {
          return;
        }
        if (refreshed != null) {
          await _applyBackgroundVideoRefresh(refreshed);
        }
      } catch (e) {
        secureLog('⚠️ Background video refresh failed (non-critical): $e');
      }
      try {
        await _syncEngagementStatesWhenIdle();
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
        rankHomeVideosForFeed(page.videos),
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

  Future<void> _bootstrapExpandForYouFeed(
      List<HomeVideo> existingVideos) async {
    if (existingVideos.isEmpty) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final HomeForYouFeedPage page = await _forYouFeedLoader.refresh(
        previousVideos: existingVideos,
        previousCursor: currentForYouSlice(state).nextCursor,
        previousLastDocument: state.lastForYouDoc,
      );
      final List<HomeVideo> mergedVideos = _mergeIncomingForYouVideos(
        page.videos,
      );
      final bool grew = mergedVideos.length > existingVideos.length ||
          _feedFingerprint(mergedVideos) != _feedFingerprint(existingVideos);
      _updateForYouFeed(
        videos: mergedVideos,
        isLoading: false,
        nextCursor: grew ? page.nextCursor : HomeFeedPagination.exhaustedCursor,
        lastDocument: page.lastDocument,
        clearError: page.clearError,
        error: page.error,
      );
      if (mergedVideos.isNotEmpty) {
        final String? userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          unawaited(
            _cacheForYouFeed(
              userId: userId,
              videos: mergedVideos,
              nextCursor: page.nextCursor,
            ),
          );
        } else {
          unawaited(
            _algorithmCacheService.cacheLastKnownForYouFeed(
              videos: mergedVideos,
            ),
          );
        }
      }
    } catch (e) {
      secureLog('⚠️ HomeProvider: Bootstrap feed expand failed: $e');
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> fetchMoreActive() async {
    final FeedTab active = state.activeFeed ?? FeedTab.forYou;
    if (active == FeedTab.forYou) {
      final FeedSlice s = currentForYouSlice(state);
      if (s.isLoading) {
        return;
      }
      if (s.nextCursor == null || s.nextCursor?['bootstrap'] == true) {
        await _bootstrapExpandForYouFeed(s.items);
        return;
      }
      if (HomeFeedPagination.isExhausted(s.nextCursor)) {
        return;
      }
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
    final List<HomeVideo> feedVideos = videos(feed);
    if (feedVideos.isEmpty || isLoadingMore) {
      return false;
    }
    final int triggerIndex =
        (feedVideos.length - 3).clamp(0, feedVideos.length - 1);
    return currentIndex >= triggerIndex;
  }

  Future<void> loadMoreVideosIfNeeded({
    required int currentIndex,
    required FeedTab feed,
  }) async {
    if (!shouldLoadMoreContent(currentIndex, feed)) return;

    final List<HomeVideo> beforeVideos = videos(feed);
    final int beforeLength = beforeVideos.length;
    state = state.copyWith(isLoadingMore: true);

    try {
      if (state.activeFeed != feed) {
        state = state.copyWith(activeFeed: feed);
      }
      if (feed != FeedTab.threads) {
        await fetchMoreActive();
      }
      final List<HomeVideo> afterVideos = videos(feed);
      final bool atFinalVideo = currentIndex >= afterVideos.length - 1;
      final bool didAppend = afterVideos.length > beforeLength;
      if (feed == FeedTab.forYou && atFinalVideo && !didAppend) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) {
          return;
        }
        _appendRecycledForYouFeed(
          currentIndex: currentIndex,
          reason: 'load_more_exhausted',
        );
      }
    } catch (e) {
      secureLog('Error loading more videos: $e');
      if (feed == FeedTab.forYou) {
        _appendRecycledForYouFeed(
          currentIndex: currentIndex,
          reason: 'load_more_error',
        );
      }
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
    if (state.forYouVideos.isEmpty && state.followingVideos.isEmpty) {
      return;
    }
    HomeFeedInteractionDiagnostics.logFeedReplaceAttempt(
      reason: 'like_sync',
      incomingCount: 0,
      currentCount: state.forYouVideos.length,
    );
    HomeFeedInteractionDiagnostics.logFeedReplaceBlocked(reason: 'like_sync');
    secureLog(
      '⏭️ syncLikeStates: skipped full feed touch '
      '(use per-video like provider; likes load on startup)',
    );
  }

  Future<void> syncFavoriteStates() async {
    if (LikeInteractionBoundary.shouldDeferHeavyWork) {
      LikeInteractionBoundary.runOrQueue(
        () => unawaited(syncFavoriteStates()),
        reason: 'syncFavoriteStates',
      );
      return;
    }
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
    if (LikeInteractionBoundary.shouldDeferHeavyWork) {
      LikeInteractionBoundary.runOrQueue(
        () => unawaited(syncCommentCounts()),
        reason: 'syncCommentCounts',
      );
      return;
    }
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
