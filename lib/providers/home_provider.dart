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
import '../services/global_playback_manager.dart';
import '../constants/playback_owners.dart';

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
    log('✅ Video added to feed: ${video.id}');
  }

  /// Refresh feed based on current tab (For You or Following)
  Future<void> refreshFeedByTab(FeedTab feedTab) async {
    log('🔄 Refreshing ${feedTab.name} feed...');
    try {
      if (feedTab == FeedTab.forYou) {
        final rid = DateTime.now().microsecondsSinceEpoch.toString();
        state = state.copyWith(
          activeFeed: FeedTab.forYou,
          forYouSlice: (state.forYouSlice ??
                  const FeedSlice(
                    items: <HomeVideo>[],
                    nextCursor: null,
                    isLoading: false,
                  ))
              .copyWith(
            isLoading: true,
            clearError: true,
            requestId: rid,
          ),
        );
        await _refreshForYou(rid: rid);
        log('✅ For You feed refreshed: ${state.forYouVideos.length} videos');
      } else if (feedTab == FeedTab.following) {
        final rid = DateTime.now().microsecondsSinceEpoch.toString();
        state = state.copyWith(
          activeFeed: FeedTab.following,
          followingSlice: (state.followingSlice ??
                  const FeedSlice(
                    items: <HomeVideo>[],
                    nextCursor: null,
                    isLoading: false,
                  ))
              .copyWith(
            isLoading: true,
            clearError: true,
            requestId: rid,
            clearEmptyMessage: true,
          ),
        );
        await _refreshFollowing(rid: rid);
        log('✅ Following feed refreshed: ${state.followingVideos.length} videos');
      } else {
        log('⏭️ Threads feed does not support video refresh');
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
    log('🎯 UnifiedAlgorithm: For You feed updated with ${sortedVideos.length} ranked videos (newest first)');
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
    log('🎯 UnifiedAlgorithm: Following feed updated with ${sortedVideos.length} ranked videos (newest first)');
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
    log('📊 Current state - forYouVideos: ${state.forYouVideos.length}, followingVideos: ${state.followingVideos.length}');

    if (state.hasLoaded && state.forYouVideos.isNotEmpty) {
      log('⏭️ Videos already loaded (${state.forYouVideos.length} videos), skipping...');
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

    // Wait up to 10 seconds for authentication
    for (int i = 0; i < 50; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (auth.currentUser != null) {
        log('✅ Authentication ready after ${i * 200}ms: ${auth.currentUser!.uid}');
        return;
      }
    }

    log('⚠️ Authentication timeout - proceeding without auth');
  }

  /// Load cached videos for instant display
  Future<void> _loadCachedVideos() async {
    try {
      log('🚀 Starting instant play - loading real videos from VideoService...');

      // Wait for authentication to be ready
      await _waitForAuthentication();

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
        // VideoService already returns newest first (updatedAt ?? createdAt); do not re-sort by createdAt
        // or latest website uploads (ready/published) would appear at the end
        state = state.copyWith(
          forYouVideos: realVideos,
          followingVideos: [], // Will be loaded separately for Following feed
          isLoading: false,
        );
      }

      log('✅ Loaded videos for instant display: ${state.forYouVideos.length} items');
      log('🎯 Current state - forYouVideos: ${state.forYouVideos.length}, followingVideos: ${state.followingVideos.length}, isLoading: ${state.isLoading}');

      // 🔥 INSTANT PLAY: Preload first video via PlaybackManager (VideoService.preloadVideo is a no-op)
      if (state.forYouVideos.isNotEmpty) {
        GlobalPlaybackManager.instance.preloadAround(0, state.forYouVideos);
      }
    } catch (e) {
      log('❌ Error loading cached videos: $e');
      if (state.forYouVideos.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Connection is unstable. Showing your last loaded feed.',
        );
        GlobalPlaybackManager.instance.preloadAround(0, state.forYouVideos);
      } else {
        final sampleVideos = _createSampleVideos();
        state = state.copyWith(
          forYouVideos: sampleVideos,
          followingVideos: sampleVideos.take(1).toList(),
          isLoading: false,
          error: 'You are offline. Showing fallback videos for now.',
        );
        if (sampleVideos.isNotEmpty) {
          GlobalPlaybackManager.instance.preloadAround(0, sampleVideos);
        }
      }
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

      // Refresh For You feed so new website uploads appear without pull-to-refresh
      try {
        await _videoService.refresh();
        final freshVideos = _videoService.getAllVideos();
        if (freshVideos.isNotEmpty) {
          state = state.copyWith(forYouVideos: freshVideos);
          log('✅ Background refresh: ${freshVideos.length} videos (incl. new uploads)');
        }
      } catch (e) {
        log('⚠️ Background video refresh failed (non-critical): $e');
      }

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
      log('💡 HomeProvider: keeping current feed visible during background failure');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (state.forYouVideos.isEmpty) {
          state = state.copyWith(
            forYouVideos: _createSampleVideos(),
            error: 'You are offline. Showing fallback videos for now.',
          );
          return;
        }
        state = state.copyWith(
          error: 'Connection is unstable. Showing your last loaded feed.',
        );
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

  /// Force refresh videos from database
  Future<void> forceRefreshVideos() async {
    log('🔄 Force refreshing videos...');

    // Reset state to force reload
    state = state.copyWith(
      hasLoaded: false,
      isLoading: true,
      forYouVideos: [],
      followingVideos: [],
    );

    // Reload videos
    await loadVideos();
  }

  // MARK: - Feed Switching (Hard refresh per feed)

  Future<void> switchFeed(FeedTab type) async {
    log('🔄 switchFeed: Called with type: ${type.displayName}');
    state = state.copyWith(activeFeed: type);
    
    // Threads tab doesn't need video loading
    if (type == FeedTab.threads) {
      log('🔄 switchFeed: Switching to Threads feed');
      return;
    }

    final bool hasCachedVideos = switch (type) {
      FeedTab.forYou => state.forYouVideos.isNotEmpty,
      FeedTab.following => state.followingVideos.isNotEmpty,
      FeedTab.threads => false,
    };
    final bool isAlreadyLoading = switch (type) {
      FeedTab.forYou => state.forYouSlice?.isLoading ?? false,
      FeedTab.following => state.followingSlice?.isLoading ?? false,
      FeedTab.threads => false,
    };

    if (hasCachedVideos || isAlreadyLoading) {
      log('✅ switchFeed: Reusing cached ${type.displayName} feed');
      return;
    }
    
    final String rid = DateTime.now().microsecondsSinceEpoch.toString();
    if (type == FeedTab.forYou) {
      log('🔄 switchFeed: Switching to For You feed');
      final FeedSlice slice = (state.forYouSlice ??
              const FeedSlice(
                items: <HomeVideo>[],
                nextCursor: null,
                isLoading: false,
              ))
          .copyWith(
        isLoading: true,
        clearError: true,
        requestId: rid,
      );
      state = state.copyWith(forYouSlice: slice);
      await _refreshForYou(rid: rid);
    } else {
      log('🔄 switchFeed: Switching to Following feed');
      final FeedSlice slice = (state.followingSlice ??
              const FeedSlice(
                items: <HomeVideo>[],
                nextCursor: null,
                isLoading: false,
              ))
          .copyWith(
        isLoading: true,
        clearError: true,
        requestId: rid,
        clearEmptyMessage: true,
      );
      state = state.copyWith(
        followingSlice: slice,
      );
      log('🔄 switchFeed: About to call _refreshFollowing');
      await _refreshFollowing(rid: rid);
      log('🔄 switchFeed: _refreshFollowing completed');
    }
  }

  Future<void> _refreshForYou({required String rid}) async {
    try {
      final page = await _videoService.fetchForYouVideos(
        pageSize: 20,
        lastDocument: null,
      );
      if (state.forYouSlice?.requestId != rid) return;
      final videos = page['videos'] as List<HomeVideo>;
      state = state.copyWith(
        forYouVideos: videos,
        forYouSlice: state.forYouSlice?.copyWith(
          items: videos,
          nextCursor: page['lastDocument'] == null
              ? null
              : <String, dynamic>{'lastDoc': page['lastDocument']},
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      if (state.forYouSlice?.requestId != rid) return;
      final existingItems = state.forYouSlice?.items ?? state.forYouVideos;
      state = state.copyWith(
        forYouVideos: existingItems,
        forYouSlice: state.forYouSlice?.copyWith(
          items: existingItems,
          isLoading: false,
          error: existingItems.isEmpty
              ? 'Failed to refresh videos. Check your connection.'
              : 'Connection is unstable. Keeping your current feed loaded.',
        ),
        error: existingItems.isEmpty
            ? 'Failed to refresh videos. Check your connection.'
            : 'Connection is unstable. Showing your last loaded feed.',
      );
    }
  }

  Future<void> _refreshFollowing({required String rid}) async {
    try {
      log('🔄 _refreshFollowing: Starting Following feed refresh - rid: $rid');
      final String? viewerId = FirebaseAuth.instance.currentUser?.uid;
      if (viewerId == null) {
        log('⚠️ _refreshFollowing: No authenticated user, returning empty feed');
        // Fallback to empty when unauthenticated
        if (state.followingSlice?.requestId != rid) return;
        state = state.copyWith(
          followingVideos: const <HomeVideo>[],
          lastFollowingDoc: null,
          followingSlice: state.followingSlice?.copyWith(
            items: const <HomeVideo>[],
            nextCursor: null,
            isLoading: false,
            clearError: true,
            emptyMessage: 'Follow creators to build your Following feed.',
          ),
        );
        return;
      }
      log('🔄 _refreshFollowing: Fetching Following videos for user: $viewerId');
      // Fetch videos using connections-based service
      log('🔄 _refreshFollowing: About to call _followingFeedService.fetchFollowingVideos');
      final page = await _followingFeedService.fetchFollowingVideos(
        viewerId: viewerId,
        limit: 20,
      );
      final videos = page['videos'] as List<HomeVideo>;
      final authorCount = (page['authorCount'] as int?) ?? 0;
      log('🔄 _refreshFollowing: Fetched ${videos.length} Following videos');
      if (state.followingSlice?.requestId != rid) {
        log('⚠️ _refreshFollowing: Request ID mismatch, ignoring stale response');
        return;
      }
      
      // 🔥 DEDUPLICATE: Remove duplicate videos by videoId
      final uniqueVideos = <String, HomeVideo>{};
      for (final video in videos) {
        if (video.id.isNotEmpty && !uniqueVideos.containsKey(video.id)) {
          uniqueVideos[video.id] = video;
        }
      }
      final deduplicatedVideos = uniqueVideos.values.toList();
      
      if (deduplicatedVideos.length != videos.length) {
        log('🔄 _refreshFollowing: Deduplicated ${videos.length} videos to ${deduplicatedVideos.length} unique videos');
      }
      
      final updatedSlice = state.followingSlice?.copyWith(
        items: deduplicatedVideos,
        nextCursor: page['lastDocument'] == null
            ? null
            : <String, dynamic>{'lastDoc': page['lastDocument']},
        isLoading: false,
        clearError: true,
        emptyMessage: deduplicatedVideos.isEmpty
            ? (authorCount == 0
                ? 'Follow creators to build your Following feed.'
                : 'No public videos from your connections yet.')
            : null,
        clearEmptyMessage: deduplicatedVideos.isNotEmpty,
      );

      state = state.copyWith(
        followingSlice: updatedSlice,
        followingVideos: deduplicatedVideos,
        lastFollowingDoc: page['lastDocument'],
      );
      log('✅ _refreshFollowing: Following feed updated with ${videos.length} videos');
    } catch (e, stackTrace) {
      log('❌ _refreshFollowing: Error fetching Following videos: $e');
      log('📍 Stack trace: $stackTrace');
      if (state.followingSlice?.requestId != rid) return;
      final existingItems = state.followingSlice?.items ?? state.followingVideos;
      state = state.copyWith(
        followingVideos: existingItems,
        followingSlice: state.followingSlice?.copyWith(
          items: existingItems,
          isLoading: false,
          error: 'Following feed unavailable. Please check your connection.',
        ),
      );
      log('⚠️ _refreshFollowing: Preserving cached Following feed during error');
    }
  }

  Future<void> fetchMoreActive() async {
    final FeedTab active = state.activeFeed ?? FeedTab.forYou;
    if (active == FeedTab.forYou) {
      final FeedSlice? s = state.forYouSlice;
      if (s == null || s.isLoading || s.nextCursor == null) return;
      final String rid = DateTime.now().microsecondsSinceEpoch.toString();
      state = state.copyWith(
          forYouSlice: s.copyWith(isLoading: true, requestId: rid));
      try {
        final page = await _videoService.fetchForYouVideos(
          pageSize: 10, // Spec: 10 load more
          lastDocument: s.nextCursor?['lastDoc'],
        );
        if (state.forYouSlice?.requestId != rid) return;
        final merged = [...s.items, ...(page['videos'] as List<HomeVideo>)];
        state = state.copyWith(
          forYouVideos: merged,
          forYouSlice: state.forYouSlice?.copyWith(
            items: merged,
            nextCursor: page['lastDocument'] == null
                ? null
                : <String, dynamic>{'lastDoc': page['lastDocument']},
            isLoading: false,
            clearError: true,
          ),
        );
      } catch (e) {
        if (state.forYouSlice?.requestId != rid) return;
        final existingItems = state.forYouSlice?.items ?? state.forYouVideos;
        state = state.copyWith(
          forYouVideos: existingItems,
          forYouSlice: state.forYouSlice
              ?.copyWith(
                items: existingItems,
                isLoading: false,
                error: existingItems.isEmpty
                    ? 'Failed to load more videos. Check your connection.'
                    : 'Could not load more videos right now.',
              ),
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
          followingSlice: s.copyWith(isLoading: true, requestId: rid));
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
        final errorSlice = state.followingSlice
            ?.copyWith(isLoading: false, error: e.toString());
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

      // NEW: Use connections-based Following feed (same as NetworkView Connections)
      log('👥 Fetching Following videos from Connections for user $viewerId');

      // Check if user has connections
      final hasConnections =
          await _followingFeedService.hasConnections(viewerId);
      if (!hasConnections) {
        log('👥 No connections found for Following feed');
        state = state.copyWith(followingVideos: []);
        return;
      }

      final page = await _followingFeedService.fetchFollowingVideos(
        viewerId: viewerId,
        limit: reset ? 20 : 10,
        startAfter: reset ? null : state.lastFollowingDoc,
      );
      final videos = page['videos'] as List<HomeVideo>;
      final lastDoc = page['lastDocument'];

      if (reset) {
        state = state.copyWith(
          followingVideos: videos,
          lastFollowingDoc: lastDoc,
        );
      } else {
        state = state.copyWith(
          followingVideos: [...state.followingVideos, ...videos],
          lastFollowingDoc: lastDoc,
        );
      }

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
      case FeedTab.forYou:
        // video = forYouVideos[index];
        break;
      case FeedTab.following:
        // video = followingVideos[index];
        break;
      case FeedTab.threads:
        // Threads don't have videos
        break;
    }

    // Use the new FavoritesService to handle the toggle
    await _favoritesService.toggleFavorite(videoId);

    // Update the UI state to match FavoritesService
    final isFavorited = _favoritesService.isFavorited(videoId);
    switch (arrayType) {
      case FeedTab.forYou:
        _updateForYouVideoFavorite(index, isFavorited);
        break;
      case FeedTab.following:
        _updateFollowingVideoFavorite(index, isFavorited);
        break;
      case FeedTab.threads:
        // Threads don't have videos
        break;
    }
  }

  /// Array type detection - matches Swift implementation
  (FeedTab, int)? _arrayTypeAndIndex(String videoId) {
    // Check For You videos first
    for (int i = 0; i < forYouVideos.length; i++) {
      if (forYouVideos[i].id == videoId) {
        return (FeedTab.forYou, i);
      }
    }

    // Check Following videos
    for (int i = 0; i < followingVideos.length; i++) {
      if (followingVideos[i].id == videoId) {
        return (FeedTab.following, i);
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
    // Check if video exists in current feeds before attempting optimistic update
    final videoExistsInForYou = state.forYouVideos.any((v) => v.id == videoId);
    final videoExistsInFollowing =
        state.followingVideos.any((v) => v.id == videoId);

    // Store original state for rollback (will be used in catch block if needed)
    bool originalForYouState = false;
    bool originalFollowingState = false;

    try {
      if (!videoExistsInForYou && !videoExistsInFollowing) {
        // Video not in current feeds - just update the service without UI changes
        log('⚠️ Video $videoId not in current feeds, updating service only');
        await _favoritesService.toggleFavorite(videoId);
        log('✅ Successfully toggled favorite for video: $videoId (service only)');
        return;
      }

      // Get original states for rollback
      originalForYouState = _getVideoFavoriteState(state.forYouVideos, videoId);
      originalFollowingState =
          _getVideoFavoriteState(state.followingVideos, videoId);

      // Optimistic UI update - update immediately for better UX
      if (videoExistsInForYou) {
        _updateVideoInFeed(state.forYouVideos, videoId, (video) {
          return video.copyWith(
            isFavorited: !video.isFavorited,
          );
        });
      }

      if (videoExistsInFollowing) {
        _updateVideoInFeed(state.followingVideos, videoId, (video) {
          return video.copyWith(
            isFavorited: !video.isFavorited,
          );
        });
      }

      // Update state to trigger UI rebuild
      state = state.copyWith(
        forYouVideos: List.from(state.forYouVideos),
        followingVideos: List.from(state.followingVideos),
      );

      // Update the favorites service asynchronously
      await _favoritesService.toggleFavorite(videoId);

      log('✅ Successfully toggled favorite for video: $videoId');
    } catch (e) {
      // Rollback optimistic update on error (only if video exists in feeds)
      final videoExistsInForYou =
          state.forYouVideos.any((v) => v.id == videoId);
      final videoExistsInFollowing =
          state.followingVideos.any((v) => v.id == videoId);

      if (videoExistsInForYou) {
        _updateVideoInFeed(state.forYouVideos, videoId, (video) {
          return video.copyWith(isFavorited: originalForYouState);
        });
      }

      if (videoExistsInFollowing) {
        _updateVideoInFeed(state.followingVideos, videoId, (video) {
          return video.copyWith(isFavorited: originalFollowingState);
        });
      }

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
    try {
      final video = videos.firstWhere((v) => v.id == videoId);
      return video.isFavorited;
    } catch (e) {
      // Video not found in current feed arrays - this can happen during feed transitions
      // Return false as default and let the FavoritesService handle the actual state
      log('⚠️ Video $videoId not found in current feed arrays, using default favorite state');
      return false;
    }
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

  /// Simple retry method for failed video loading
  Future<void> retryLoadVideos() async {
    log('🔄 Retrying video loading...');
    state = state.copyWith(
      clearError: true,
      hasLoaded: false,
      isLoading: state.forYouVideos.isEmpty,
    );
    await loadVideos();
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(clearError: true);
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
    dynamic lastForYouDoc,
    dynamic lastFollowingDoc,
    Map<String, dynamic>? lastFollowingCursor,
    FeedTab? activeFeed,
    FeedSlice? forYouSlice,
    FeedSlice? followingSlice,
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
      lastForYouDoc: lastForYouDoc ?? this.lastForYouDoc,
      lastFollowingDoc: lastFollowingDoc ?? this.lastFollowingDoc,
      lastFollowingCursor: lastFollowingCursor ?? this.lastFollowingCursor,
      activeFeed: activeFeed ?? this.activeFeed,
      forYouSlice: forYouSlice ?? this.forYouSlice,
      followingSlice: followingSlice ?? this.followingSlice,
      shouldPauseAllVideos: shouldPauseAllVideos ?? this.shouldPauseAllVideos,
      shouldResumeCurrentVideo:
          shouldResumeCurrentVideo ?? this.shouldResumeCurrentVideo,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static const HomeState initial = HomeState();
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
    Map<String, dynamic>? nextCursor,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? emptyMessage,
    bool clearEmptyMessage = false,
    String? requestId,
  }) {
    return FeedSlice(
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      emptyMessage:
          clearEmptyMessage ? null : (emptyMessage ?? this.emptyMessage),
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
    followingFeedService: FollowingFeedService.instance,
  );
});

// MARK: - Service Providers (placeholders)

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});
