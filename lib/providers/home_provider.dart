// cspell:ignore Favorited
import 'dart:async';
import 'dart:developer';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/feed_tab.dart';
import '../models/home_video.dart';
import '../models/user.dart' as app_user;
import '../services/video_service.dart' as video_service;
import '../services/user_service.dart';
import '../services/favorites_service.dart';
import '../services/following_feed_service.dart';
import '../services/comments_service.dart';
import '../services/unified_avatar_service.dart';
import '../services/like_service.dart';
import '../services/enhanced_like_service.dart';
import 'favorites_provider.dart';
import 'video_service_provider.dart';
import '../widgets/video_player_view_optimized.dart';

enum FeedType { forYou, following }

class HomeViewModel extends StateNotifier<HomeState> {
  final video_service.VideoService _videoService;
  final UserService _userService;
  final FavoritesService _favoritesService;
  final FollowingFeedService _followingFeedService;
  final CommentsService _commentsService;
  final LikeService _likeService = LikeService();

  HomeViewModel({
    required video_service.VideoService videoService,
    required UserService userService,
    required FavoritesService favoritesService,
    FollowingFeedService? followingFeedService,
    CommentsService? commentsService,
  })  : _videoService = videoService,
        _userService = userService,
        _favoritesService = favoritesService,
        _followingFeedService = followingFeedService ?? FollowingFeedService(),
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

  List<HomeVideo> videos(FeedType feed) {
    switch (feed) {
      case FeedType.forYou:
        return state.forYouVideos;
      case FeedType.following:
        return state.followingVideos;
    }
  }

  // MARK: - Initial Load with Instant Play

  /// Refresh videos when a new video is uploaded
  Future<void> refreshAfterUpload() async {
    log('🔄 Refreshing videos after upload...');
    try {
      // Refresh VideoService to get latest videos
      await _videoService.refresh();
      final updatedVideos = _videoService.getAllVideos();

      // Update state with fresh videos
      state = state.copyWith(forYouVideos: updatedVideos);
      log('✅ Videos refreshed after upload: ${updatedVideos.length} videos');
    } catch (e) {
      log('❌ Error refreshing videos after upload: $e');
    }
  }

  /// Refresh feed based on current tab (For You or Following)
  Future<void> refreshFeedByTab(FeedTab feedTab) async {
    log('🔄 Refreshing ${feedTab.name} feed...');
    try {
      if (feedTab == FeedTab.forYou) {
        // Refresh For You feed
        await _videoService.refresh();
        final updatedVideos = _videoService.getAllVideos();
        state = state.copyWith(forYouVideos: updatedVideos);
        log('✅ For You feed refreshed: ${updatedVideos.length} videos');
      } else {
        // Refresh Following feed
        final followingIds = await _userService.getFollowingIds();
        if (followingIds.isNotEmpty) {
          await fetchFollowingVideos(followingIds: followingIds, reset: true);
          log('✅ Following feed refreshed: ${state.followingVideos.length} videos');
        } else {
          // No following users, clear the feed
          state = state.copyWith(followingVideos: []);
          log('✅ Following feed refreshed: 0 videos (no following users)');
        }
      }
    } catch (e) {
      log('❌ Error refreshing ${feedTab.name} feed: $e');
      rethrow; // Re-throw to handle in UI
    }
  }

  /// Set loading state for instant UI feedback
  void setLoadingState(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
    log('🔄 Loading state set to: $isLoading');
  }

  /// Pause all videos when leaving HomeView
  void pauseAllVideos() {
    log('🚨 HomeProvider: pauseAllVideos() called!');
    log('⏸️ Pausing all HomeView videos');

    // Set a flag to indicate videos should be paused
    // The VideoPlayerViewOptimized widgets will check this flag
    log('🔍 DEBUG: About to set shouldPauseAllVideos=true');
    state = state.copyWith(shouldPauseAllVideos: true);
    log('🔍 DEBUG: Set shouldPauseAllVideos=true, new state: ${state.shouldPauseAllVideos}');

    // Also try direct pause approach
    log('🔍 DEBUG: About to call _directPauseAllVideos()');
    _directPauseAllVideos();
    log('🔍 DEBUG: Called _directPauseAllVideos()');

    // ALSO call global controller for immediate response
    try {
      // This will provide immediate pause without waiting for Consumer
      log('🔊 HomeProvider: Calling GlobalVideoController.pauseAllVideos()');
      GlobalVideoController.pauseAllVideos();
      log('🔊 HomeProvider: GlobalVideoController.pauseAllVideos() completed');
    } catch (e) {
      log('❌ HomeProvider: Error calling GlobalVideoController: $e');
    }

    // Reset the flag after a short delay to allow for future navigation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        state = state.copyWith(shouldPauseAllVideos: false);
      }
    });

    log('✅ Pause signal sent to all videos');
  }

  /// Direct pause approach - try to pause videos immediately
  void _directPauseAllVideos() {
    try {
      // This is a more aggressive approach - we'll use a global notifier
      // that all VideoPlayerViewOptimized widgets can listen to
      log('🔊 Direct pause: Broadcasting pause signal globally');

      // Use a more direct approach with a global pause signal
      _broadcastPauseSignal();
    } catch (e) {
      log('❌ Direct pause failed: $e');
    }
  }

  /// Broadcast pause signal globally
  void _broadcastPauseSignal() {
    // This will be handled by the VideoPlayerViewOptimized widgets
    // that are listening to the homeProvider state changes
    log('📡 Broadcasting global pause signal');
  }

  /// Resume current video when returning to HomeView
  void resumeCurrentVideo() {
    log('▶️ Resuming HomeView current video');

    // Set a flag to indicate videos should resume
    // The VideoPlayerViewOptimized widgets will check this flag
    state = state.copyWith(shouldResumeCurrentVideo: true);

    // ALSO call global controller for immediate response
    try {
      log('🔊 HomeProvider: Calling GlobalVideoController.resumeCurrentVideo()');
      GlobalVideoController.resumeCurrentVideo();
    } catch (e) {
      log('❌ HomeProvider: Error calling GlobalVideoController resume: $e');
    }

    // Reset the flag after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        state = state.copyWith(shouldResumeCurrentVideo: false);
      }
    });

    log('✅ Resume signal sent to current video');
  }

  Future<void> loadVideos() async {
    log('🔄 loadVideos() called - hasLoaded: ${state.hasLoaded}');

    if (state.hasLoaded) {
      log('⏭️ Videos already loaded, skipping...');
      return;
    }

    log('🚀 Starting video loading...');

    // Show loading state initially
    state = state.copyWith(isLoading: true);

    try {
      // Try to load cached data first for instant display
      await _loadCachedVideos();

      // Fetch fresh data in background
      await _fetchFreshVideosInBackground();

      // CRITICAL FIX: Load user's like states for all videos
      await _loadUserLikeStates();

      // Preload avatars for instant display
      _preloadAvatars();

      state = state.copyWith(hasLoaded: true, isLoading: false);
      log('✅ loadVideos() completed successfully');
    } catch (e) {
      log('❌ Error loading videos: $e');
      state = state.copyWith(isLoading: false, hasLoaded: true);
    }
  }

  /// Load cached videos for instant display
  Future<void> _loadCachedVideos() async {
    try {
      log('🚀 Starting instant play - loading real videos from VideoService...');

      // Load real videos from VideoService instead of sample videos
      await _videoService.loadAllVideos();
      final realVideos = _videoService.getAllVideos();

      log('📱 Loaded ${realVideos.length} real videos from VideoService');

      if (realVideos.isEmpty) {
        log('⚠️ No real videos found, creating sample videos as fallback');
        final sampleVideos = _createSampleVideos();
        state = state.copyWith(
          forYouVideos: sampleVideos,
          followingVideos: sampleVideos.take(1).toList(),
          isLoading: false,
        );
      } else {
        // Use real videos from VideoService for For You feed
        state = state.copyWith(
          forYouVideos: realVideos,
          followingVideos: [], // Will be loaded separately for Following feed
          isLoading: false,
        );
      }

      log('✅ Loaded videos for instant display: ${state.forYouVideos.length} items');
      log('🎯 Current state - forYouVideos: ${state.forYouVideos.length}, followingVideos: ${state.followingVideos.length}, isLoading: ${state.isLoading}');

      // TIKTOK-STYLE: Start preloading videos immediately for instant playback
      _preloadVideos();
    } catch (e) {
      log('❌ Error loading cached videos: $e');
      // Fallback to sample videos if real videos fail to load
      final sampleVideos = _createSampleVideos();
      state = state.copyWith(
        forYouVideos: sampleVideos,
        followingVideos: sampleVideos.take(1).toList(),
        isLoading: false,
      );
    }
  }

  /// TIKTOK-STYLE: Preload videos for instant playback
  Future<void> _preloadVideos() async {
    try {
      // Preload first 3 videos for instant playback like TikTok
      final videosToPreload = state.forYouVideos.take(3).toList();

      for (final video in videosToPreload) {
        try {
          // Preload video controller for instant playback
          await _videoService.preloadVideo(video.videoURL);
          log('🎬 Preloaded video: ${video.id}');
        } catch (e) {
          log('⚠️ Failed to preload video ${video.id}: $e');
        }
      }

      log('✅ TIKTOK-STYLE: Preloaded ${videosToPreload.length} videos for instant playback');
    } catch (e) {
      log('⚠️ Video preloading failed: $e (non-critical)');
    }
  }

  /// INSTANT FOLLOWING: Preload following videos in background for instant tab switching
  Future<void> _preloadFollowingVideosInBackground() async {
    try {
      log('👥 INSTANT FOLLOWING: Starting background preload of following videos...');

      // Get user's following IDs
      final followingIds = await _userService.getFollowingIds().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          log('⏰ Following IDs fetch timeout - skipping preload');
          return <String>[];
        },
      );

      if (followingIds.isEmpty) {
        log('👥 INSTANT FOLLOWING: No following users found - skipping preload');
        return;
      }

      log('👥 INSTANT FOLLOWING: Found ${followingIds.length} following users - preloading videos...');

      // Preload following videos in background (non-blocking)
      fetchFollowingVideos(followingIds: followingIds, reset: true).then((_) {
        log('✅ INSTANT FOLLOWING: Background preload completed - ${state.followingVideos.length} videos ready');
      }).catchError((e) {
        log('⚠️ INSTANT FOLLOWING: Background preload failed: $e (non-critical)');
      });
    } catch (e) {
      log('⚠️ INSTANT FOLLOWING: Error in background preload: $e (non-critical)');
    }
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
            log('⏰ Avatar preloading timeout - continuing without preloaded avatars');
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
      List<HomeVideo> videos, String feedName) async {
    if (videos.isEmpty) return;

    try {
      log('💖 Loading like states for $feedName feed (${videos.length} videos)');

      final updatedVideos = <HomeVideo>[];

      // Process videos in batches to avoid overwhelming the system
      const batchSize = 5;
      for (int i = 0; i < videos.length; i += batchSize) {
        final batch = videos.skip(i).take(batchSize).toList();

        // Load like states for this batch
        for (final video in batch) {
          try {
            final isLiked = await _likeService.isVideoLiked(video.id);
            final likeCount = await _likeService.getLikeCount(video.id);

            updatedVideos.add(video.copyWith(
              isLiked: isLiked,
              likes: likeCount,
            ));
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

      log('✅ Loaded like states for $feedName feed (${updatedVideos.length} videos)');
    } catch (e) {
      log('❌ Error loading like states for $feedName feed: $e');
    }
  }

  /// Fetch fresh videos in background with improved error handling
  Future<void> _fetchFreshVideosInBackground() async {
    try {
      log('🔄 Fetching fresh videos in background...');

      // Don't reload videos here since they're already loaded in _loadCachedVideos
      // This prevents duplicate videos from being loaded
      log('✅ Background refresh skipped - videos already loaded in cache');

      // INSTANT FOLLOWING: Preload following videos in background for instant switching
      _preloadFollowingVideosInBackground();

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

      log('✅ Fresh videos loading completed: ${state.forYouVideos.length} forYou, ${state.followingVideos.length} following');
    } catch (e) {
      log('❌ Error fetching fresh videos: $e');
      log('💡 This may indicate network issues, Firestore configuration problems, or database connectivity issues');
      log('💡 App will continue with sample videos - check Firebase configuration and network connectivity');

      // Ensure we still have sample videos if everything fails
      // FRAME OPTIMIZATION: Use SchedulerBinding to defer fallback state updates
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (state.forYouVideos.isEmpty) {
          state = state.copyWith(forYouVideos: _createSampleVideos());
        }
        if (state.followingVideos.isEmpty) {
          state = state.copyWith(
              followingVideos: _createSampleVideos().take(3).toList());
        }
      });
    }
  }

  /// Create sample videos for instant display with TikTok-style fast videos
  List<HomeVideo> _createSampleVideos() {
    return [
      const HomeVideo(
        id: '1',
        creator: app_user.User(
          id: 'user1',
          username: 'streamer1',
          displayName: 'Streamer One',
          avatarURL: 'https://picsum.photos/200/300?random=1',
        ),
        videoURL:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        thumbnailURL: 'https://picsum.photos/seed/video1/300/200',
        likes: 1250,
        comments: 89,
        views: 15420,
        caption: 'Beautiful butterfly in nature! #nature #butterfly',
        isLiked: false,
        isFavorited: false,
        isDraft: false,
        mlScore: 0.95,
        categoryId: 'nature',
      ),
      const HomeVideo(
        id: '2',
        creator: app_user.User(
          id: 'user2',
          username: 'streamer2',
          displayName: 'Streamer Two',
          avatarURL: 'https://i.pravatar.cc/200?img=2',
        ),
        videoURL:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        thumbnailURL: 'https://i.pravatar.cc/400?img=2',
        likes: 890,
        comments: 45,
        views: 9870,
        caption: 'Check out this cool trick! 🔥',
        isLiked: true,
        isFavorited: false,
        isDraft: false,
        mlScore: 0.87,
        categoryId: 'entertainment',
      ),
    ];
  }

  // MARK: - Feed Switching (Hard refresh per feed)

  Future<void> switchFeed(FeedType type) async {
    state = state.copyWith(activeFeed: type);
    final String rid = DateTime.now().microsecondsSinceEpoch.toString();
    if (type == FeedType.forYou) {
      final FeedSlice slice = FeedSlice(
        items: <HomeVideo>[],
        nextCursor: null,
        isLoading: true,
        requestId: rid,
      );
      state = state.copyWith(forYouSlice: slice);
      await _refreshForYou(rid: rid);
    } else {
      final FeedSlice slice = FeedSlice(
        items: <HomeVideo>[],
        nextCursor: null,
        isLoading: true,
        requestId: rid,
      );
      state = state.copyWith(followingSlice: slice);
      await _refreshFollowing(rid: rid);
    }
  }

  Future<void> _refreshForYou({required String rid}) async {
    try {
      final page = await _videoService.fetchForYouVideos(
        pageSize: 20,
        lastDocument: null,
      );
      // Stale-while-revalidate guard
      if (state.forYouSlice?.requestId != rid) return;
      state = state.copyWith(
        forYouSlice: state.forYouSlice?.copyWith(
          items: page['videos'] as List<HomeVideo>,
          nextCursor: page['lastDocument'] == null
              ? null
              : <String, dynamic>{'lastDoc': page['lastDocument']},
          isLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      if (state.forYouSlice?.requestId != rid) return;
      state = state.copyWith(
        forYouSlice: state.forYouSlice?.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _refreshFollowing({required String rid}) async {
    try {
      final String? viewerId = FirebaseAuth.instance.currentUser?.uid;
      if (viewerId == null) {
        // Fallback to empty when unauthenticated
        if (state.followingSlice?.requestId != rid) return;
        state = state.copyWith(
          followingSlice: state.followingSlice?.copyWith(
            items: const <HomeVideo>[],
            nextCursor: null,
            isLoading: false,
            error: null,
          ),
        );
        return;
      }
      final FollowingFeedResult res =
          await _followingFeedService.fetchRankedFollowingFeed(
        viewerId: viewerId,
        pageSize: 20,
        afterCursor: null,
      );
      if (state.followingSlice?.requestId != rid) return;
      state = state.copyWith(
        followingSlice: state.followingSlice?.copyWith(
          items: res.items,
          nextCursor: res.nextCursor,
          isLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      if (state.followingSlice?.requestId != rid) return;
      state = state.copyWith(
        followingSlice: state.followingSlice?.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> fetchMoreActive() async {
    final FeedType active = state.activeFeed ?? FeedType.forYou;
    if (active == FeedType.forYou) {
      final FeedSlice? s = state.forYouSlice;
      if (s == null || s.isLoading || s.nextCursor == null) return;
      final String rid = DateTime.now().microsecondsSinceEpoch.toString();
      state = state.copyWith(
          forYouSlice: s.copyWith(isLoading: true, requestId: rid));
      try {
        final page = await _videoService.fetchForYouVideos(
          pageSize: 20,
          lastDocument: s.nextCursor?['lastDoc'],
        );
        if (state.forYouSlice?.requestId != rid) return;
        state = state.copyWith(
          forYouSlice: state.forYouSlice?.copyWith(
            items: [...s.items, ...(page['videos'] as List<HomeVideo>)],
            nextCursor: page['lastDocument'] == null
                ? null
                : <String, dynamic>{'lastDoc': page['lastDocument']},
            isLoading: false,
            error: null,
          ),
        );
      } catch (e) {
        if (state.forYouSlice?.requestId != rid) return;
        state = state.copyWith(
          forYouSlice: state.forYouSlice
              ?.copyWith(isLoading: false, error: e.toString()),
        );
      }
    } else {
      final FeedSlice? s = state.followingSlice;
      if (s == null || s.isLoading || s.nextCursor == null) return;
      final String rid = DateTime.now().microsecondsSinceEpoch.toString();
      state = state.copyWith(
          followingSlice: s.copyWith(isLoading: true, requestId: rid));
      try {
        final String? viewerId = FirebaseAuth.instance.currentUser?.uid;
        if (viewerId == null) return;
        final res = await _followingFeedService.fetchRankedFollowingFeed(
          viewerId: viewerId,
          pageSize: 20,
          afterCursor: s.nextCursor,
        );
        if (state.followingSlice?.requestId != rid) return;
        state = state.copyWith(
          followingSlice: state.followingSlice?.copyWith(
            items: [...s.items, ...res.items],
            nextCursor: res.nextCursor,
            isLoading: false,
            error: null,
          ),
        );
      } catch (e) {
        if (state.followingSlice?.requestId != rid) return;
        state = state.copyWith(
          followingSlice: state.followingSlice
              ?.copyWith(isLoading: false, error: e.toString()),
        );
      }
    }
  }

  // MARK: - Fetch Videos

  Future<void> fetchForYouVideos({bool reset = false}) async {
    try {
      final videos = await _videoService.fetchForYouVideos(
        pageSize: 10,
        lastDocument: reset ? null : state.lastForYouDoc,
      );

      if (reset) {
        state = state.copyWith(
          forYouVideos: videos['videos'] as List<HomeVideo>,
          lastForYouDoc: videos['lastDocument'],
        );
      } else {
        state = state.copyWith(
          forYouVideos: [
            ...state.forYouVideos,
            ...(videos['videos'] as List<HomeVideo>)
          ],
          lastForYouDoc: videos['lastDocument'],
        );
      }
    } catch (e) {
      log('Error fetching For You videos: $e');
    }
  }

  Future<void> fetchFollowingVideos({
    required List<String> followingIds,
    bool reset = false,
  }) async {
    try {
      final String? viewerId = FirebaseAuth.instance.currentUser?.uid;
      if (viewerId == null) {
        // fallback to old behavior if not signed in
        final videos = await _videoService.fetchFollowingVideos(
          followingIds: followingIds,
          pageSize: 10,
          lastDocument: reset ? null : state.lastFollowingDoc,
        );
        if (reset) {
          state = state.copyWith(
            followingVideos: videos['videos'] as List<HomeVideo>,
            lastFollowingDoc: videos['lastDocument'],
          );
        } else {
          state = state.copyWith(
            followingVideos: [
              ...state.followingVideos,
              ...(videos['videos'] as List<HomeVideo>)
            ],
            lastFollowingDoc: videos['lastDocument'],
          );
        }
        return;
      }

      final result = await _followingFeedService.fetchRankedFollowingFeed(
        viewerId: viewerId,
        pageSize: 20,
        afterCursor: reset ? null : state.lastFollowingCursor,
      );

      if (reset) {
        state = state.copyWith(
          followingVideos: result.items,
          lastFollowingCursor: result.nextCursor,
        );
      } else {
        state = state.copyWith(
          followingVideos: [...state.followingVideos, ...result.items],
          lastFollowingCursor: result.nextCursor,
        );
      }
    } catch (e) {
      log('Error fetching ranked Following feed: $e');
    }
  }

  // MARK: - Load More Content

  bool shouldLoadMoreContent(int currentIndex, FeedType feed) {
    final videos = this.videos(feed);
    return currentIndex >= videos.length - 2 &&
        hasMoreContent &&
        !isLoadingMore;
  }

  Future<void> loadMoreVideosIfNeeded({
    required int currentIndex,
    required FeedType feed,
  }) async {
    if (!shouldLoadMoreContent(currentIndex, feed)) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      switch (feed) {
        case FeedType.forYou:
          await fetchForYouVideos(reset: false);
          break;
        case FeedType.following:
          final followingIds = await _userService.getFollowingIds();
          await fetchFollowingVideos(followingIds: followingIds, reset: false);
          break;
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
      final success = await _videoService.toggleLike(videoId);
      if (success) {
        // Update local state
        _updateVideoLikeState(videoId);
      }
    } catch (e) {
      log('Error toggling like: $e');
    }
  }

  /// Complete implementation matching Swift pattern
  Future<void> toggleFavorite(String videoId) async {
    final arrayInfo = _arrayTypeAndIndex(videoId);
    if (arrayInfo == null) return;

    final (arrayType, index) = arrayInfo;

    // Get the video to update (for potential future use)
    switch (arrayType) {
      case FeedType.forYou:
        // video = forYouVideos[index];
        break;
      case FeedType.following:
        // video = followingVideos[index];
        break;
    }

    // Use the new FavoritesService to handle the toggle
    await _favoritesService.toggleFavorite(videoId);

    // Update the UI state to match FavoritesService
    final isFavorited = _favoritesService.isFavorited(videoId);
    switch (arrayType) {
      case FeedType.forYou:
        _updateForYouVideoFavorite(index, isFavorited);
        break;
      case FeedType.following:
        _updateFollowingVideoFavorite(index, isFavorited);
        break;
    }
  }

  /// Array type detection - matches Swift implementation
  (FeedType, int)? _arrayTypeAndIndex(String videoId) {
    // Check For You videos first
    for (int i = 0; i < forYouVideos.length; i++) {
      if (forYouVideos[i].id == videoId) {
        return (FeedType.forYou, i);
      }
    }

    // Check Following videos
    for (int i = 0; i < followingVideos.length; i++) {
      if (followingVideos[i].id == videoId) {
        return (FeedType.following, i);
      }
    }

    return null;
  }

  /// Update For You video favorite state
  void _updateForYouVideoFavorite(int index, bool isFavorited) {
    if (index >= 0 && index < forYouVideos.length) {
      final updatedVideos = List<HomeVideo>.from(forYouVideos);
      updatedVideos[index] =
          updatedVideos[index].copyWith(isFavorited: isFavorited);
      state = state.copyWith(forYouVideos: updatedVideos);
    }
  }

  /// Update Following video favorite state
  void _updateFollowingVideoFavorite(int index, bool isFavorited) {
    if (index >= 0 && index < followingVideos.length) {
      final updatedVideos = List<HomeVideo>.from(followingVideos);
      updatedVideos[index] =
          updatedVideos[index].copyWith(isFavorited: isFavorited);
      state = state.copyWith(followingVideos: updatedVideos);
    }
  }

  // MARK: - Sync States

  Future<void> syncLikeStates() async {
    // Sync like states from the backend
    // This would typically fetch user's liked videos and update local state
    log('Syncing like states...');
  }

  Future<void> syncFavoriteStates() async {
    // Sync favorite states from the new FavoritesService
    log('Syncing favorite states from FavoritesService...');

    // Update For You videos
    final updatedForYouVideos = forYouVideos.map((video) {
      final isFavorited = _favoritesService.isFavorited(video.id);
      return video.copyWith(isFavorited: isFavorited);
    }).toList();

    // Update Following videos
    final updatedFollowingVideos = followingVideos.map((video) {
      final isFavorited = _favoritesService.isFavorited(video.id);
      return video.copyWith(isFavorited: isFavorited);
    }).toList();

    state = state.copyWith(
      forYouVideos: updatedForYouVideos,
      followingVideos: updatedFollowingVideos,
    );
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
          final comments =
              await _commentsService.fetchCommentsForVideo(videoId);
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

      // Update videos in both feeds with new comment counts
      final updatedForYouVideos = state.forYouVideos.map((video) {
        final newCommentCount = commentCounts[video.id] ?? video.comments;
        return video.comments != newCommentCount
            ? video.copyWith(comments: newCommentCount)
            : video;
      }).toList();

      final updatedFollowingVideos = state.followingVideos.map((video) {
        final newCommentCount = commentCounts[video.id] ?? video.comments;
        return video.comments != newCommentCount
            ? video.copyWith(comments: newCommentCount)
            : video;
      }).toList();

      // Update state if there are changes
      final hasChanges = updatedForYouVideos.any((video) =>
              video.comments !=
              state.forYouVideos
                  .firstWhere(
                    (v) => v.id == video.id,
                    orElse: () => video,
                  )
                  .comments) ||
          updatedFollowingVideos.any((video) =>
              video.comments !=
              state.followingVideos
                  .firstWhere(
                    (v) => v.id == video.id,
                    orElse: () => video,
                  )
                  .comments);

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

      // Update in both feeds
      final updatedForYouVideos = state.forYouVideos.map((video) {
        return video.id == videoId
            ? video.copyWith(comments: newCommentCount)
            : video;
      }).toList();

      final updatedFollowingVideos = state.followingVideos.map((video) {
        return video.id == videoId
            ? video.copyWith(comments: newCommentCount)
            : video;
      }).toList();

      state = state.copyWith(
        forYouVideos: updatedForYouVideos,
        followingVideos: updatedFollowingVideos,
      );

      log('Updated comment count for video $videoId: $newCommentCount');
    } catch (e) {
      log('Error updating comment count for video $videoId: $e');
    }
  }

  // MARK: - Private Methods

  void _updateVideoLikeState(String videoId) {
    // Update like state in both feeds
    _updateVideoInFeed(state.forYouVideos, videoId, (video) {
      return video.copyWith(
        isLiked: !video.isLiked,
        likes: video.isLiked ? video.likes - 1 : video.likes + 1,
      );
    });

    _updateVideoInFeed(state.followingVideos, videoId, (video) {
      return video.copyWith(
        isLiked: !video.isLiked,
        likes: video.isLiked ? video.likes - 1 : video.likes + 1,
      );
    });
  }

  /// Set video like state from enhanced service (for proper sync)
  Future<void> setVideoLikeStateFromService(String videoId) async {
    try {
      final enhancedLikeService = EnhancedLikeService();
      final isLiked = await enhancedLikeService.isVideoLiked(videoId);
      final likeCount = await enhancedLikeService.getLikeCount(videoId);

      // Update like state in both feeds with correct values
      _updateVideoInFeed(state.forYouVideos, videoId, (video) {
        return video.copyWith(
          isLiked: isLiked,
          likes: likeCount,
        );
      });

      _updateVideoInFeed(state.followingVideos, videoId, (video) {
        return video.copyWith(
          isLiked: isLiked,
          likes: likeCount,
        );
      });
    } catch (e) {
      log('Error syncing like state from service: $e');
    }
  }

  Future<void> _updateVideoFavoriteState(String videoId) async {
    // Store original state for rollback
    final originalForYouState =
        _getVideoFavoriteState(state.forYouVideos, videoId);
    final originalFollowingState =
        _getVideoFavoriteState(state.followingVideos, videoId);

    try {
      // Optimistic UI update - update immediately for better UX
      _updateVideoInFeed(state.forYouVideos, videoId, (video) {
        return video.copyWith(
          isFavorited: !video.isFavorited,
        );
      });

      _updateVideoInFeed(state.followingVideos, videoId, (video) {
        return video.copyWith(
          isFavorited: !video.isFavorited,
        );
      });

      // Update state to trigger UI rebuild
      state = state.copyWith(
        forYouVideos: List.from(state.forYouVideos),
        followingVideos: List.from(state.followingVideos),
      );

      // Update the favorites service asynchronously
      await _favoritesService.toggleFavorite(videoId);

      log('✅ Successfully toggled favorite for video: $videoId');
    } catch (e) {
      // Rollback optimistic update on error
      _updateVideoInFeed(state.forYouVideos, videoId, (video) {
        return video.copyWith(isFavorited: originalForYouState);
      });

      _updateVideoInFeed(state.followingVideos, videoId, (video) {
        return video.copyWith(isFavorited: originalFollowingState);
      });

      // Update state to trigger UI rebuild
      state = state.copyWith(
        forYouVideos: List.from(state.forYouVideos),
        followingVideos: List.from(state.followingVideos),
      );

      log('❌ Error toggling favorite for video $videoId: $e');
      rethrow; // Re-throw to be handled by the calling widget
    }
  }

  bool _getVideoFavoriteState(List<HomeVideo> videos, String videoId) {
    final video = videos.firstWhere(
      (v) => v.id == videoId,
      orElse: () => throw StateError('Video not found: $videoId'),
    );
    return video.isFavorited;
  }

  void _updateVideoInFeed(
    List<HomeVideo> videos,
    String videoId,
    HomeVideo Function(HomeVideo) update,
  ) {
    final index = videos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      final updatedVideos = List<HomeVideo>.from(videos);
      updatedVideos[index] = update(updatedVideos[index]);

      if (videos == state.forYouVideos) {
        state = state.copyWith(forYouVideos: updatedVideos);
      } else if (videos == state.followingVideos) {
        state = state.copyWith(followingVideos: updatedVideos);
      }
    }
  }

  // MARK: - Refresh

  Future<void> refreshFeed() async {
    state = state.copyWith(
      hasLoaded: false,
      lastForYouDoc: null,
      lastFollowingDoc: null,
    );
    await loadVideos();
  }

  /// Reset video state to force reinitialization when returning to HomeView
  void resetVideoState() {
    log('🔄 HomeProvider: Resetting video state for seamless return');

    // Reset pause/resume flags to allow fresh initialization
    state = state.copyWith(
      shouldPauseAllVideos: false,
      shouldResumeCurrentVideo: false,
    );

    log('✅ HomeProvider: Video state reset - ready for reinitialization');
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
  final String? lastForYouDoc;
  final String? lastFollowingDoc;
  final Map<String, dynamic>? lastFollowingCursor;
  final FeedType? activeFeed;
  final FeedSlice? forYouSlice;
  final FeedSlice? followingSlice;
  final bool shouldPauseAllVideos;
  final bool shouldResumeCurrentVideo;

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
  });

  HomeState copyWith({
    List<HomeVideo>? forYouVideos,
    List<HomeVideo>? followingVideos,
    bool? hasNotification,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreContent,
    bool? hasLoaded,
    String? lastForYouDoc,
    String? lastFollowingDoc,
    Map<String, dynamic>? lastFollowingCursor,
    FeedType? activeFeed,
    FeedSlice? forYouSlice,
    FeedSlice? followingSlice,
    bool? shouldPauseAllVideos,
    bool? shouldResumeCurrentVideo,
  }) {
    return HomeState(
      forYouVideos: forYouVideos ?? this.forYouVideos,
      followingVideos: followingVideos ?? this.followingVideos,
      hasNotification: hasNotification ?? this.hasNotification,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      lastForYouDoc: lastForYouDoc ?? this.lastForYouDoc,
      lastFollowingDoc: lastFollowingDoc ?? this.lastFollowingDoc,
      lastFollowingCursor: lastFollowingCursor ?? this.lastFollowingCursor,
      activeFeed: activeFeed ?? this.activeFeed,
      forYouSlice: forYouSlice ?? this.forYouSlice,
      followingSlice: followingSlice ?? this.followingSlice,
      shouldPauseAllVideos: shouldPauseAllVideos ?? this.shouldPauseAllVideos,
      shouldResumeCurrentVideo:
          shouldResumeCurrentVideo ?? this.shouldResumeCurrentVideo,
    );
  }

  static const HomeState initial = HomeState();
}

class FeedSlice {
  final List<HomeVideo> items;
  final Map<String, dynamic>? nextCursor;
  final bool isLoading;
  final String? error;
  final String? requestId;

  const FeedSlice({
    required this.items,
    required this.nextCursor,
    required this.isLoading,
    this.error,
    this.requestId,
  });

  FeedSlice copyWith({
    List<HomeVideo>? items,
    Map<String, dynamic>? nextCursor,
    bool? isLoading,
    String? error,
    String? requestId,
  }) {
    return FeedSlice(
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      requestId: requestId ?? this.requestId,
    );
  }
}

// MARK: - Provider

final homeProvider = StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final videoService = ref.read(videoServiceProvider);
  final userService = ref.read(userServiceProvider);
  final favoritesService = ref.read(favoritesServiceProvider);

  return HomeViewModel(
    videoService: videoService,
    userService: userService,
    favoritesService: favoritesService,
    followingFeedService: FollowingFeedService(),
  );
});

// MARK: - Service Providers (placeholders)

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});
