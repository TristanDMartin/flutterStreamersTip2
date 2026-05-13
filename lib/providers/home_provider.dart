// cspell:ignore Favorited
import 'dart:async';
import 'dart:developer';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/feed_tab.dart';
import '../models/home_video.dart';
import '../services/video_service.dart' as video_service;
import '../services/following_feed_service.dart';
import '../services/comments_service.dart';
import '../services/unified_avatar_service.dart';
import '../services/streamers_tip_like_service.dart';
import '../services/unified_bookmark_service.dart';
import '../services/algorithm_cache_service.dart';
import 'video_service_provider.dart';
import '../services/global_playback_manager.dart';
import '../constants/playback_owners.dart';

const Object _homeStateUnset = Object();
const Object _feedSliceUnset = Object();

class HomeViewModel extends StateNotifier<HomeState> {
  final video_service.VideoService _videoService;
  final FollowingFeedService _followingFeedService;
  final CommentsService _commentsService;
  final StreamersTipLikeService _likeService = StreamersTipLikeService.instance;
  final UnifiedBookmarkService _bookmarkService =
      UnifiedBookmarkService.instance;
  final AlgorithmCacheService _algorithmCacheService = AlgorithmCacheService();

  HomeViewModel({
    required video_service.VideoService videoService,
    FollowingFeedService? followingFeedService,
    CommentsService? commentsService,
  })  : _videoService = videoService,
        _followingFeedService =
            followingFeedService ?? FollowingFeedService.instance,
        _commentsService = commentsService ?? CommentsService(),
        super(const HomeState()) {
    // Initialize the callbacks
    updateVideoLikeState = _updateVideoLikeState;
    updateVideoFavoriteState = _updateVideoFavoriteState;
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

  List<HomeVideo> videos(FeedTab feed) {
    switch (feed) {
      case FeedTab.forYou:
        return state.forYouVideos;
      case FeedTab.following:
        return state.followingVideos;
      case FeedTab.threads:
        return []; // Threads don't have videos
    }
  }

  FeedSlice get _currentForYouSlice =>
      state.forYouSlice ??
      const FeedSlice(items: <HomeVideo>[], nextCursor: null, isLoading: false);

  void _updateForYouFeed({
    required List<HomeVideo> videos,
    required bool isLoading,
    Map<String, dynamic>? nextCursor,
    Object? lastDocument = _homeStateUnset,
    String? error,
    bool clearError = false,
  }) {
    state = state.copyWith(
      forYouVideos: videos,
      isLoading: isLoading,
      hasMoreContent: nextCursor != null,
      lastForYouDoc: lastDocument,
      forYouSlice: _currentForYouSlice.copyWith(
        items: videos,
        nextCursor: nextCursor,
        isLoading: isLoading,
        error: error,
        clearError: clearError,
      ),
      error: error,
      clearError: clearError,
    );
  }

  FeedSlice get _currentFollowingSlice =>
      state.followingSlice ??
      const FeedSlice(items: <HomeVideo>[], nextCursor: null, isLoading: false);

  void _updateFollowingFeed({
    required List<HomeVideo> videos,
    required bool isLoading,
    Map<String, dynamic>? nextCursor,
    Object? lastDocument = _homeStateUnset,
    String? error,
    bool clearError = false,
  }) {
    state = state.copyWith(
      followingVideos: videos,
      lastFollowingDoc: lastDocument,
      followingSlice: _currentFollowingSlice.copyWith(
        items: videos,
        nextCursor: nextCursor,
        isLoading: isLoading,
        error: error,
        clearError: clearError,
      ),
    );
  }

  // MARK: - Initial Load with Instant Play

  /// Add new video to feed instantly (no refresh). Used after publish.
  void addVideoToFeed(HomeVideo video) {
    _videoService.addVideo(video);
    final current = List<HomeVideo>.from(state.forYouVideos);
    final existing = current.indexWhere((v) => v.id == video.id);
    if (existing >= 0) {
      current[existing] = video;
    } else {
      current.insert(0, video);
    }
    state = state.copyWith(forYouVideos: current);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      unawaited(_cacheForYouFeed(userId: userId, videos: current));
    }
    log('✅ Video added to feed: ${video.id}');
  }

  /// Refresh feed based on current tab (For You or Following)
  Future<void> refreshFeedByTab(FeedTab feedTab) async {
    log('🔄 Refreshing ${feedTab.name} feed...');
    try {
      if (feedTab == FeedTab.forYou) {
        final rid = DateTime.now().microsecondsSinceEpoch.toString();
        _updateForYouFeed(
          videos: state.forYouVideos,
          isLoading: true,
          nextCursor: _currentForYouSlice.nextCursor,
          clearError: true,
        );
        state = state.copyWith(
          activeFeed: FeedTab.forYou,
          forYouSlice: _currentForYouSlice.copyWith(requestId: rid),
        );
        await _refreshForYou(rid: rid);
        log('✅ For You feed refreshed: ${state.forYouVideos.length} videos');
      } else if (feedTab == FeedTab.following) {
        log('⏭️ Progression tab has no video feed to refresh');
      } else {
        log('⏭️ Threads feed does not support video refresh');
      }
    } catch (e) {
      log('❌ Error refreshing ${feedTab.name} feed: $e');
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

    state = state.copyWith(forYouVideos: sortedVideos);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      unawaited(_cacheForYouFeed(userId: userId, videos: sortedVideos));
    }
    log(
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
    log(
      '🎯 UnifiedAlgorithm: Following feed updated with ${sortedVideos.length} ranked videos (newest first)',
    );
  }

  /// Pause all videos (single path via GlobalPlaybackManager)
  void pauseAllVideos() {
    try {
      GlobalPlaybackManager.instance.pauseAll();
      GlobalPlaybackManager.instance.block(reason: 'home_provider_pause');
    } catch (e) {
      log('❌ HomeProvider: pauseAllVideos: $e');
    }
  }

  /// Resume: set home as active owner so current video can play
  void resumeCurrentVideo() {
    try {
      GlobalPlaybackManager.instance.setActiveOwner(PlaybackOwners.home);
    } catch (e) {
      log('❌ HomeProvider: resumeCurrentVideo: $e');
    }
  }

  Future<void> loadVideos() async {
    log('🔄 loadVideos() called - hasLoaded: ${state.hasLoaded}');
    log(
      '📊 Current state - forYouVideos: ${state.forYouVideos.length}, followingVideos: ${state.followingVideos.length}',
    );

    if (state.hasLoaded && state.forYouVideos.isNotEmpty) {
      log(
        '⏭️ Videos already loaded (${state.forYouVideos.length} videos), skipping...',
      );
      return;
    }

    // If hasLoaded but videos are empty, force reload
    if (state.hasLoaded && state.forYouVideos.isEmpty) {
      log('⚠️ Videos marked as loaded but list is empty - forcing reload');
      state = state.copyWith(hasLoaded: false);
    }

    log('🚀 Starting video loading...');

    // Show loading state initially
    state = state.copyWith(isLoading: true);

    try {
      await _loadCachedVideos();
      state = state.copyWith(hasLoaded: true);
      // Run non-blocking in background so first video can play immediately
      Future(() async {
        try {
          await _fetchFreshVideosInBackground();
          await _loadUserLikeStates();
          _preloadAvatars();
        } catch (e) {
          log('❌ HomeProvider: Background load failed: $e');
        }
      });
      log('✅ loadVideos() completed successfully');
    } catch (e) {
      log('❌ Error loading videos: $e');
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

  /// Wait for authentication to be ready
  Future<void> _waitForAuthentication() async {
    final auth = FirebaseAuth.instance;

    // If already authenticated, return immediately
    if (auth.currentUser != null) {
      log('✅ Authentication ready: ${auth.currentUser!.uid}');
      return;
    }

    log('⏳ Waiting for authentication...');

    // Keep startup moving. App shell normally calls this after auth is ready,
    // so this is only a short grace period, not a full-screen wait.
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (auth.currentUser != null) {
        log(
          '✅ Authentication ready after ${i * 200}ms: ${auth.currentUser!.uid}',
        );
        return;
      }
    }

    log('⚠️ Authentication not ready after 1600ms - proceeding without auth');
  }

  /// Load cached videos for instant display
  Future<void> _loadCachedVideos() async {
    try {
      log(
        '🚀 Starting instant play - loading real videos from VideoService...',
      );

      // Wait for authentication to be ready
      await _waitForAuthentication();
      final String? userId = FirebaseAuth.instance.currentUser?.uid;

      if (await _restoreWarmForYouFeed(userId)) return;

      // Load real videos from VideoService instead of sample videos
      await _videoService.loadAllVideos().timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          log('⏰ HomeProvider: Video load timed out; ending startup wait');
        },
      );
      final realVideos = _videoService.getAllVideos();

      log('📱 Loaded ${realVideos.length} real videos from VideoService');

      if (realVideos.isEmpty) {
        log('⚠️ No real videos found, keeping feed honest with an empty state');
        _updateForYouFeed(
          videos: const <HomeVideo>[],
          isLoading: false,
          nextCursor: null,
          lastDocument: null,
          error: 'No videos are available right now.',
        );
        state = state.copyWith(followingVideos: const []);
      } else {
        // VideoService already returns newest first (updatedAt ?? createdAt); do not re-sort by createdAt
        // or latest website uploads (ready/published) would appear at the end
        _updateForYouFeed(
          videos: realVideos,
          isLoading: false,
          nextCursor: null,
          lastDocument: null,
          clearError: true,
        );
        state = state.copyWith(followingVideos: const []);
        if (userId != null) {
          unawaited(_cacheForYouFeed(userId: userId, videos: realVideos));
        }
      }

      log(
        '✅ Loaded videos for instant display: ${state.forYouVideos.length} items',
      );
      log(
        '🎯 Current state - forYouVideos: ${state.forYouVideos.length}, followingVideos: ${state.followingVideos.length}, isLoading: ${state.isLoading}',
      );

      // 🔥 INSTANT PLAY: Preload first video via PlaybackManager (VideoService.preloadVideo is a no-op)
      if (state.forYouVideos.isNotEmpty) {
        GlobalPlaybackManager.instance.preloadStartupWindow(
          state.forYouVideos,
        );
      }
    } catch (e) {
      log('❌ Error loading cached videos: $e');
      if (state.forYouVideos.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Connection is unstable. Showing your last loaded feed.',
        );
        GlobalPlaybackManager.instance.preloadStartupWindow(
          state.forYouVideos,
        );
      } else {
        _updateForYouFeed(
          videos: const <HomeVideo>[],
          isLoading: false,
          nextCursor: null,
          lastDocument: null,
          error: 'Unable to load videos right now. Please try again.',
        );
        state = state.copyWith(followingVideos: const []);
      }
    }
  }

  Future<void> _cacheForYouFeed({
    required String userId,
    required List<HomeVideo> videos,
    Map<String, dynamic>? nextCursor,
  }) async {
    if (videos.isEmpty) return;
    final visibleVideos = videos.take(30).toList(growable: false);
    await _algorithmCacheService.cacheForYouFeed(
      userId: userId,
      videos: visibleVideos,
      nextCursor: _cacheableCursor(nextCursor),
    );
    await _algorithmCacheService.cacheLastKnownForYouFeed(
      videos: visibleVideos,
    );
  }

  Future<bool> _restoreWarmForYouFeed(String? userId) async {
    CachedFeedResult? cachedFeed;
    if (userId != null) {
      cachedFeed = await _algorithmCacheService.getCachedForYouFeed(userId);
    }
    cachedFeed ??= await _algorithmCacheService.getLastKnownForYouFeed();
    if (cachedFeed == null) return false;

    final cachedVideos = cachedFeed.videos;
    if (cachedVideos.isEmpty) return false;

    log(
      '⚡ HomeProvider: Warm start from cached For You feed (${cachedVideos.length} videos)',
    );
    _updateForYouFeed(
      videos: cachedVideos,
      isLoading: false,
      nextCursor: null,
      lastDocument: null,
      clearError: true,
    );
    state = state.copyWith(followingVideos: const []);
    GlobalPlaybackManager.instance.preloadStartupWindow(cachedVideos);
    return true;
  }

  Map<String, dynamic>? _cacheableCursor(Map<String, dynamic>? cursor) {
    if (cursor == null) return null;

    final safeCursor = <String, dynamic>{};
    for (final entry in cursor.entries) {
      final value = entry.value;
      if (value == null || value is String || value is num || value is bool) {
        safeCursor[entry.key] = value;
      }
    }
    return safeCursor.isEmpty ? null : safeCursor;
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
            log(
              '⏰ Avatar preloading timeout - continuing without preloaded avatars',
            );
          },
        );
        log('✅ Preloaded ${avatarUrls.length} avatars for instant display');
      }
    } catch (e) {
      log('⚠️ Failed to preload avatars: $e (non-critical)');
    }
  }

  /// Load user's like states for all videos
  Future<void> _loadUserLikeStates() async {
    try {
      log('💖 Loading user like states for all videos...');

      // Load like states for For You videos
      await _loadLikeStatesForFeed(state.forYouVideos, 'For You');

      // Load like states for Following videos
      await _loadLikeStatesForFeed(state.followingVideos, 'Following');

      log('✅ User like states loaded successfully');
    } catch (e) {
      log('⚠️ Failed to load user like states: $e (non-critical)');
    }
  }

  /// Load like states for a specific feed
  Future<void> _loadLikeStatesForFeed(
    List<HomeVideo> videos,
    String feedName,
  ) async {
    if (videos.isEmpty) return;

    try {
      log(
        '💖 Loading like states for $feedName feed (${videos.length} videos)',
      );

      final updatedVideos = <HomeVideo>[];

      // Process videos in batches to avoid overwhelming the system
      const batchSize = 5;
      for (int i = 0; i < videos.length; i += batchSize) {
        final batch = videos.skip(i).take(batchSize).toList();

        // Load like states for this batch
        for (final video in batch) {
          try {
            final likeState = _likeService.getLikeState(video.id);
            final isLiked = likeState.isLiked;
            final likeCount = likeState.likeCount > 0 || isLiked
                ? likeState.likeCount
                : video.likes;

            updatedVideos.add(
              video.copyWith(isLiked: isLiked, likes: likeCount),
            );
          } catch (e) {
            // If like state loading fails, use the original video
            log('⚠️ Failed to load like state for video ${video.id}: $e');
            updatedVideos.add(video);
          }
        }

        // Small delay between batches to prevent overwhelming the system
        if (i + batchSize < videos.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Update the state with videos that have like states
      if (feedName == 'For You') {
        state = state.copyWith(forYouVideos: updatedVideos);
      } else if (feedName == 'Following') {
        state = state.copyWith(followingVideos: updatedVideos);
      }

      log(
        '✅ Loaded like states for $feedName feed (${updatedVideos.length} videos)',
      );
    } catch (e) {
      log('❌ Error loading like states for $feedName feed: $e');
    }
  }

  /// Fetch fresh videos in background with improved error handling
  Future<void> _fetchFreshVideosInBackground() async {
    try {
      log('🔄 Fetching fresh videos in background...');

      // Refresh For You feed so new website uploads appear without pull-to-refresh
      try {
        await _videoService.refresh();
        final freshVideos = _videoService.getAllVideos();
        if (freshVideos.isNotEmpty) {
          _updateForYouFeed(
            videos: freshVideos,
            isLoading: false,
            nextCursor: null,
            lastDocument: null,
            clearError: true,
          );
          log(
            '✅ Background refresh: ${freshVideos.length} videos (incl. new uploads)',
          );
          final String? userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            unawaited(_cacheForYouFeed(userId: userId, videos: freshVideos));
          }
        }
      } catch (e) {
        log('⚠️ Background video refresh failed (non-critical): $e');
      }

      // Sync like, favorite, and comment states after loading videos (non-blocking)
      try {
        await Future.wait([
          syncLikeStates(),
          syncFavoriteStates(),
          syncCommentCounts(),
        ]).timeout(const Duration(seconds: 5));
        log('✅ Video states synced successfully');
      } catch (e) {
        log('⚠️ Video state sync failed: $e (non-critical)');
      }

      log(
        '✅ Fresh videos loading completed: ${state.forYouVideos.length} forYou, ${state.followingVideos.length} following',
      );
    } catch (e) {
      log('❌ Error fetching fresh videos: $e');
      log(
        '💡 HomeProvider: keeping current feed visible during background failure',
      );
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (state.forYouVideos.isEmpty) {
          _updateForYouFeed(
            videos: const <HomeVideo>[],
            isLoading: false,
            nextCursor: null,
            lastDocument: null,
            error:
                'Unable to load videos right now. Check your connection and try again.',
          );
          return;
        }
        _updateForYouFeed(
          videos: state.forYouVideos,
          isLoading: false,
          nextCursor: _currentForYouSlice.nextCursor,
          error: 'Connection is unstable. Showing your last loaded feed.',
        );
      });
    }
  }

  // MARK: - Feed Switching (Hard refresh per feed)

  Future<void> switchFeed(FeedTab type) async {
    log('🔄 switchFeed: Called with type: ${type.displayName}');
    state = state.copyWith(activeFeed: type);

    // Threads / Progression tabs don't load home video feeds
    if (type == FeedTab.threads || type == FeedTab.following) {
      log('🔄 switchFeed: ${type.displayName} — no video feed load');
      return;
    }

    final bool hasCachedVideos = state.forYouVideos.isNotEmpty;
    final bool isAlreadyLoading = state.forYouSlice?.isLoading ?? false;

    if (hasCachedVideos || isAlreadyLoading) {
      log('✅ switchFeed: Reusing cached For You feed');
      return;
    }

    final String rid = DateTime.now().microsecondsSinceEpoch.toString();
    log('🔄 switchFeed: Switching to For You feed');
    _updateForYouFeed(
      videos: state.forYouVideos,
      isLoading: true,
      nextCursor: _currentForYouSlice.nextCursor,
      clearError: true,
    );
    state = state.copyWith(
      forYouSlice: _currentForYouSlice.copyWith(requestId: rid),
    );
    await _refreshForYou(rid: rid);
  }

  Future<void> _refreshForYou({required String rid}) async {
    try {
      final page = await _videoService.fetchForYouVideos(
        pageSize: 20,
        lastDocument: null,
      );
      if (state.forYouSlice?.requestId != rid) return;
      final videos = page['videos'] as List<HomeVideo>;
      final nextCursor = page['lastDocument'] == null
          ? null
          : <String, dynamic>{'lastDoc': page['lastDocument']};
      _updateForYouFeed(
        videos: videos,
        isLoading: false,
        nextCursor: nextCursor,
        lastDocument: page['lastDocument'],
        clearError: true,
      );
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        unawaited(
          _cacheForYouFeed(
            userId: userId,
            videos: videos,
            nextCursor: nextCursor,
          ),
        );
      }
    } catch (e) {
      if (state.forYouSlice?.requestId != rid) return;
      final existingItems = state.forYouSlice?.items ?? state.forYouVideos;
      _updateForYouFeed(
        videos: existingItems,
        isLoading: false,
        nextCursor: _currentForYouSlice.nextCursor,
        error: existingItems.isEmpty
            ? 'Failed to refresh videos. Check your connection.'
            : 'Connection is unstable. Showing your last loaded feed.',
      );
    }
  }

  Future<void> fetchMoreActive() async {
    final FeedTab active = state.activeFeed ?? FeedTab.forYou;
    if (active == FeedTab.forYou) {
      final FeedSlice s = _currentForYouSlice;
      if (s.isLoading || s.nextCursor == null) return;
      final String rid = DateTime.now().microsecondsSinceEpoch.toString();
      state = state.copyWith(
        forYouSlice: s.copyWith(isLoading: true, requestId: rid),
      );
      try {
        final page = await _videoService.fetchForYouVideos(
          pageSize: 10, // Spec: 10 load more
          lastDocument: s.nextCursor?['lastDoc'],
        );
        if (state.forYouSlice?.requestId != rid) return;
        final merged = [...s.items, ...(page['videos'] as List<HomeVideo>)];
        final nextCursor = page['lastDocument'] == null
            ? null
            : <String, dynamic>{'lastDoc': page['lastDocument']};
        _updateForYouFeed(
          videos: merged,
          isLoading: false,
          nextCursor: nextCursor,
          lastDocument: page['lastDocument'],
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
        // Fetch more videos using connections-based service
        final page = await _followingFeedService.fetchFollowingVideos(
          viewerId: viewerId,
          limit: 10,
          startAfter: s.nextCursor,
        );
        if (state.followingSlice?.requestId != rid) return;
        final newVideos = page['videos'] as List<HomeVideo>;
        final uniqueVideos = <String, HomeVideo>{};
        for (final video in s.items) {
          if (video.id.isNotEmpty) uniqueVideos[video.id] = video;
        }
        for (final video in newVideos) {
          if (video.id.isNotEmpty && !uniqueVideos.containsKey(video.id)) {
            uniqueVideos[video.id] = video;
          }
        }
        final deduplicatedVideos = uniqueVideos.values.toList();
        final pagedSlice = state.followingSlice?.copyWith(
          items: deduplicatedVideos,
          nextCursor: page['lastDocument'] == null
              ? null
              : <String, dynamic>{'lastDoc': page['lastDocument']},
          isLoading: false,
          clearError: true,
        );

        state = state.copyWith(
          followingSlice: pagedSlice,
          followingVideos: deduplicatedVideos,
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
      if (viewerId == null) {
        final videos = await _videoService.fetchFollowingVideos(
          followingIds: fallbackFollowingIds,
          pageSize: 10,
          lastDocument: reset ? null : state.lastFollowingDoc,
        );
        final mergedVideos = reset
            ? videos['videos'] as List<HomeVideo>
            : <HomeVideo>[
                ...state.followingVideos,
                ...(videos['videos'] as List<HomeVideo>),
              ];
        _updateFollowingFeed(
          videos: mergedVideos,
          isLoading: false,
          nextCursor: videos['lastDocument'] == null
              ? null
              : <String, dynamic>{'lastDoc': videos['lastDocument']},
          lastDocument: videos['lastDocument'],
          clearError: true,
        );
        return;
      }

      // NEW: Use connections-based Following feed (same as NetworkView Connections)
      log('👥 Fetching Following videos from Connections for user $viewerId');

      // Check if user has connections
      final hasConnections = await _followingFeedService.hasConnections(
        viewerId,
      );
      if (!hasConnections) {
        log('👥 No connections found for Following feed');
        _updateFollowingFeed(
          videos: const <HomeVideo>[],
          isLoading: false,
          nextCursor: null,
          lastDocument: null,
          clearError: true,
        );
        return;
      }

      final page = await _followingFeedService.fetchFollowingVideos(
        viewerId: viewerId,
        limit: reset ? 20 : 10,
        startAfter: reset ? null : state.lastFollowingDoc,
      );
      final videos = page['videos'] as List<HomeVideo>;
      final lastDoc = page['lastDocument'];
      final mergedVideos =
          reset ? videos : <HomeVideo>[...state.followingVideos, ...videos];

      _updateFollowingFeed(
        videos: mergedVideos,
        isLoading: false,
        nextCursor:
            lastDoc == null ? null : <String, dynamic>{'lastDoc': lastDoc},
        lastDocument: lastDoc,
        clearError: true,
      );

      log('✅ Following feed updated: ${videos.length} videos from Connections');
    } catch (e) {
      log('Error fetching ranked Following feed: $e');
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
      log('Error loading more videos: $e');
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
      log('Error toggling like: $e');
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
      log('syncLikeStates: no user');
      return;
    }
    await _likeService.loadUserLikedVideos(user.uid);
    _replaceVideoFeeds((HomeVideo video) {
      final LikeState likeState = _likeService.getLikeState(video.id);
      return video.copyWith(
        isLiked: likeState.isLiked,
        likes: likeState.likeCount > 0 || likeState.isLiked
            ? likeState.likeCount
            : video.likes,
      );
    });
    log('Syncing like states: done');
  }

  Future<void> syncFavoriteStates() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      log('syncFavoriteStates: no user');
      return;
    }
    await _bookmarkService.initialize(user.uid);
    log('Syncing favorite states from UnifiedBookmarkService...');
    _replaceVideoFeeds((HomeVideo video) {
      return video.copyWith(
        isFavorited: _bookmarkService.isBookmarked(video.id),
      );
    });
  }

  Future<void> syncCommentCounts() async {
    log('Syncing comment counts...');

    try {
      // Get all unique video IDs from both feeds
      final allVideos = [...state.forYouVideos, ...state.followingVideos];
      final videoIds = allVideos.map((video) => video.id).toSet().toList();

      if (videoIds.isEmpty) {
        log('No videos to sync comment counts for');
        return;
      }

      // Fetch comment counts for all videos
      final commentCounts = <String, int>{};

      for (final videoId in videoIds) {
        try {
          final comments = await _commentsService.fetchCommentsForVideo(
            videoId,
          );
          commentCounts[videoId] = comments.length;
        } catch (e) {
          log('Error fetching comments for video $videoId: $e');
          // Keep existing comment count if fetch fails
          final existingVideo = allVideos.firstWhere(
            (video) => video.id == videoId,
            orElse: () => allVideos.first,
          );
          commentCounts[videoId] = existingVideo.comments;
        }
      }

      final updatedForYouVideos = _mapVideos(state.forYouVideos, (video) {
        final newCommentCount = commentCounts[video.id] ?? video.comments;
        return video.comments != newCommentCount
            ? video.copyWith(comments: newCommentCount)
            : video;
      });

      final updatedFollowingVideos = _mapVideos(state.followingVideos, (video) {
        final newCommentCount = commentCounts[video.id] ?? video.comments;
        return video.comments != newCommentCount
            ? video.copyWith(comments: newCommentCount)
            : video;
      });

      // Update state if there are changes
      final hasChanges = updatedForYouVideos.any(
            (video) =>
                video.comments !=
                state.forYouVideos
                    .firstWhere((v) => v.id == video.id, orElse: () => video)
                    .comments,
          ) ||
          updatedFollowingVideos.any(
            (video) =>
                video.comments !=
                state.followingVideos
                    .firstWhere((v) => v.id == video.id, orElse: () => video)
                    .comments,
          );

      if (hasChanges) {
        state = state.copyWith(
          forYouVideos: updatedForYouVideos,
          followingVideos: updatedFollowingVideos,
        );
        log('Comment counts synchronized successfully');
      } else {
        log('Comment counts are already up to date');
      }
    } catch (e) {
      log('Error syncing comment counts: $e');
    }
  }

  /// Update comment count for a specific video
  Future<void> updateVideoCommentCount(String videoId) async {
    try {
      final comments = await _commentsService.fetchCommentsForVideo(videoId);
      final newCommentCount = comments.length;

      _updateVideoAcrossFeeds(videoId, (video) {
        return video.copyWith(comments: newCommentCount);
      });

      log('Updated comment count for video $videoId: $newCommentCount');
    } catch (e) {
      log('Error updating comment count for video $videoId: $e');
    }
  }

  // MARK: - Private Methods

  void _updateVideoLikeState(String videoId) {
    _updateVideoAcrossFeeds(videoId, (video) {
      return video.copyWith(
        isLiked: !video.isLiked,
        likes: video.isLiked ? video.likes - 1 : video.likes + 1,
      );
    });
  }

  /// Set video like state from enhanced service (for proper sync)
  Future<void> setVideoLikeStateFromService(String videoId) async {
    try {
      final likeState = _likeService.getLikeState(videoId);
      final isLiked = likeState.isLiked;
      final likeCount = likeState.likeCount;

      _updateVideoAcrossFeeds(videoId, (video) {
        return video.copyWith(
          isLiked: isLiked,
          likes: likeCount > 0 || isLiked ? likeCount : video.likes,
        );
      });
    } catch (e) {
      log('Error syncing like state from service: $e');
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
        log('❌ Bookmark toggle failed for $videoId: ${result.error}');
        return;
      }
      final bool favorited = result.isBookmarked!;
      _updateVideoAcrossFeeds(
        videoId,
        (HomeVideo video) => video.copyWith(isFavorited: favorited),
      );
      log('✅ Successfully toggled favorite for video: $videoId');
    } catch (e) {
      log('❌ Error toggling favorite for video $videoId: $e');
      rethrow;
    }
  }

  void _updateVideoInFeedTab(
    FeedTab feed,
    String videoId,
    HomeVideo Function(HomeVideo) update,
  ) {
    final List<HomeVideo> videos = switch (feed) {
      FeedTab.forYou => state.forYouVideos,
      FeedTab.following => state.followingVideos,
      FeedTab.threads => const <HomeVideo>[],
    };
    final index = videos.indexWhere((v) => v.id == videoId);
    if (index == -1) return;

    _updateVideoAtIndex(feed, index, update);
  }

  void _updateVideoAcrossFeeds(
    String videoId,
    HomeVideo Function(HomeVideo) update,
  ) {
    _updateVideoInFeedTab(FeedTab.forYou, videoId, update);
    _updateVideoInFeedTab(FeedTab.following, videoId, update);
  }

  void _updateVideoAtIndex(
    FeedTab feed,
    int index,
    HomeVideo Function(HomeVideo) update,
  ) {
    final List<HomeVideo> videos = switch (feed) {
      FeedTab.forYou => state.forYouVideos,
      FeedTab.following => state.followingVideos,
      FeedTab.threads => const <HomeVideo>[],
    };
    if (index < 0 || index >= videos.length) return;

    final updatedVideos = List<HomeVideo>.from(videos);
    updatedVideos[index] = update(updatedVideos[index]);
    _setVideosForFeed(feed, updatedVideos);
  }

  List<HomeVideo> _mapVideos(
    List<HomeVideo> videos,
    HomeVideo Function(HomeVideo) update,
  ) {
    return videos.map(update).toList();
  }

  void _replaceVideoFeeds(HomeVideo Function(HomeVideo) update) {
    state = state.copyWith(
      forYouVideos: _mapVideos(state.forYouVideos, update),
      followingVideos: _mapVideos(state.followingVideos, update),
    );
  }

  void _setVideosForFeed(FeedTab feed, List<HomeVideo> videos) {
    switch (feed) {
      case FeedTab.forYou:
        state = state.copyWith(forYouVideos: videos);
      case FeedTab.following:
        state = state.copyWith(followingVideos: videos);
      case FeedTab.threads:
        return;
    }
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
    log('🔄 Retrying video loading...');
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

// MARK: - State Class

class HomeState {
  final List<HomeVideo> forYouVideos;
  final List<HomeVideo> followingVideos;
  final bool hasNotification;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreContent;
  final bool hasLoaded;
  final dynamic lastForYouDoc;
  final dynamic lastFollowingDoc;
  final Map<String, dynamic>? lastFollowingCursor;
  final FeedTab? activeFeed;
  final FeedSlice? forYouSlice;
  final FeedSlice? followingSlice;
  final bool shouldPauseAllVideos;
  final bool shouldResumeCurrentVideo;
  final String? error; // Simple error message for network issues

  const HomeState({
    this.forYouVideos = const [],
    this.followingVideos = const [],
    this.hasNotification = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
    this.hasLoaded = false,
    this.lastForYouDoc,
    this.lastFollowingDoc,
    this.lastFollowingCursor,
    this.activeFeed,
    this.forYouSlice,
    this.followingSlice,
    this.shouldPauseAllVideos = false,
    this.shouldResumeCurrentVideo = false,
    this.error,
  });

  HomeState copyWith({
    List<HomeVideo>? forYouVideos,
    List<HomeVideo>? followingVideos,
    bool? hasNotification,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreContent,
    bool? hasLoaded,
    Object? lastForYouDoc = _homeStateUnset,
    Object? lastFollowingDoc = _homeStateUnset,
    Object? lastFollowingCursor = _homeStateUnset,
    Object? activeFeed = _homeStateUnset,
    Object? forYouSlice = _homeStateUnset,
    Object? followingSlice = _homeStateUnset,
    bool? shouldPauseAllVideos,
    bool? shouldResumeCurrentVideo,
    String? error,
    bool clearError = false,
  }) {
    return HomeState(
      forYouVideos: forYouVideos ?? this.forYouVideos,
      followingVideos: followingVideos ?? this.followingVideos,
      hasNotification: hasNotification ?? this.hasNotification,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      lastForYouDoc: identical(lastForYouDoc, _homeStateUnset)
          ? this.lastForYouDoc
          : lastForYouDoc,
      lastFollowingDoc: identical(lastFollowingDoc, _homeStateUnset)
          ? this.lastFollowingDoc
          : lastFollowingDoc,
      lastFollowingCursor: identical(lastFollowingCursor, _homeStateUnset)
          ? this.lastFollowingCursor
          : lastFollowingCursor as Map<String, dynamic>?,
      activeFeed: identical(activeFeed, _homeStateUnset)
          ? this.activeFeed
          : activeFeed as FeedTab?,
      forYouSlice: identical(forYouSlice, _homeStateUnset)
          ? this.forYouSlice
          : forYouSlice as FeedSlice?,
      followingSlice: identical(followingSlice, _homeStateUnset)
          ? this.followingSlice
          : followingSlice as FeedSlice?,
      shouldPauseAllVideos: shouldPauseAllVideos ?? this.shouldPauseAllVideos,
      shouldResumeCurrentVideo:
          shouldResumeCurrentVideo ?? this.shouldResumeCurrentVideo,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static const HomeState initial = HomeState();
}

class HomeFeedViewData {
  const HomeFeedViewData({
    required this.feed,
    required this.videos,
    required this.isLoading,
    required this.error,
  });

  final FeedTab feed;
  final List<HomeVideo> videos;
  final bool isLoading;
  final String? error;

  bool get supportsVideoFeed => feed.supportsVideoFeed;
  bool get supportsRefresh => feed.supportsRefresh;
  bool get hasError => error != null && error!.isNotEmpty;
}

extension HomeStateFeedAccess on HomeState {
  HomeFeedViewData feedData(FeedTab feed) {
    switch (feed) {
      case FeedTab.forYou:
        return HomeFeedViewData(
          feed: feed,
          videos: forYouVideos,
          isLoading: isLoading,
          error: error,
        );
      case FeedTab.following:
        return HomeFeedViewData(
          feed: feed,
          videos: followingVideos,
          isLoading: followingSlice?.isLoading ?? false,
          error: followingSlice?.error,
        );
      case FeedTab.threads:
        return const HomeFeedViewData(
          feed: FeedTab.threads,
          videos: <HomeVideo>[],
          isLoading: false,
          error: null,
        );
    }
  }
}

class FeedSlice {
  final List<HomeVideo> items;
  final Map<String, dynamic>? nextCursor;
  final bool isLoading;
  final String? error;
  final String? emptyMessage;
  final String? requestId;

  const FeedSlice({
    required this.items,
    required this.nextCursor,
    required this.isLoading,
    this.error,
    this.emptyMessage,
    this.requestId,
  });

  FeedSlice copyWith({
    List<HomeVideo>? items,
    Object? nextCursor = _feedSliceUnset,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? emptyMessage,
    bool clearEmptyMessage = false,
    Object? requestId = _feedSliceUnset,
  }) {
    return FeedSlice(
      items: items ?? this.items,
      nextCursor: identical(nextCursor, _feedSliceUnset)
          ? this.nextCursor
          : nextCursor as Map<String, dynamic>?,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      emptyMessage:
          clearEmptyMessage ? null : (emptyMessage ?? this.emptyMessage),
      requestId: identical(requestId, _feedSliceUnset)
          ? this.requestId
          : requestId as String?,
    );
  }
}

// MARK: - Provider

final homeProvider = StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final video_service.VideoService videoService =
      ref.read(videoServiceProvider);
  return HomeViewModel(
    videoService: videoService,
    followingFeedService: FollowingFeedService.instance,
  );
});
