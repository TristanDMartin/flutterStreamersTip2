import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/home_video.dart';
import '../services/video_service.dart';
import '../services/user_service.dart';
import '../services/favorites_service.dart';
import '../services/following_feed_service.dart';
import 'favorites_provider.dart';
import 'video_service_provider.dart';

enum FeedType { forYou, following }

class HomeViewModel extends StateNotifier<HomeState> {
  final VideoService _videoService;
  final UserService _userService;
  final FavoritesService _favoritesService;
  final FollowingFeedService _followingFeedService;
  
  HomeViewModel({
    required VideoService videoService,
    required UserService userService,
    required FavoritesService favoritesService,
    FollowingFeedService? followingFeedService,
  }) : _videoService = videoService,
       _userService = userService,
       _favoritesService = favoritesService,
       _followingFeedService = followingFeedService ?? FollowingFeedService(),
       super(const HomeState()) {
    // Initialize the callback
    updateVideoLikeState = _updateVideoLikeState;
  }

  // MARK: - Public Properties
  
  bool get isLoading => state.isLoading;
  bool get isLoadingMore => state.isLoadingMore;
  bool get hasMoreContent => state.hasMoreContent;
  List<HomeVideo> get forYouVideos => state.forYouVideos;
  List<HomeVideo> get followingVideos => state.followingVideos;
  
  // Callback for updating video like state from child widgets
  void Function(String videoId)? updateVideoLikeState;
  
  List<HomeVideo> videos(FeedType feed) {
    switch (feed) {
      case FeedType.forYou:
        return state.forYouVideos;
      case FeedType.following:
        return state.followingVideos;
    }
  }

  // MARK: - Initial Load
  
  Future<void> loadVideos() async {
    if (state.hasLoaded) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      await fetchForYouVideos(reset: true);
      
      // Get the current user's following IDs to load their network videos
      final followingIds = await _userService.getFollowingIds();
      await fetchFollowingVideos(followingIds: followingIds, reset: true);
      
      // Sync like, favorite, and comment states after loading videos
      await syncLikeStates();
      await syncFavoriteStates();
      await syncCommentCounts();
      
      state = state.copyWith(hasLoaded: true, isLoading: false);
    } catch (e) {
      print('Error loading videos: $e');
      state = state.copyWith(isLoading: false);
    }
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
          items: page.videos,
          nextCursor: page.lastDocument == null
              ? null
              : <String, dynamic>{'lastDoc': page.lastDocument},
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
      final FollowingFeedResult res = await _followingFeedService.fetchRankedFollowingFeed(
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
      state = state.copyWith(forYouSlice: s.copyWith(isLoading: true, requestId: rid));
      try {
        final page = await _videoService.fetchForYouVideos(
          pageSize: 20,
          lastDocument: s.nextCursor?['lastDoc'],
        );
        if (state.forYouSlice?.requestId != rid) return;
        state = state.copyWith(
          forYouSlice: state.forYouSlice?.copyWith(
            items: [...s.items, ...page.videos],
            nextCursor: page.lastDocument == null
                ? null
                : <String, dynamic>{'lastDoc': page.lastDocument},
            isLoading: false,
            error: null,
          ),
        );
      } catch (e) {
        if (state.forYouSlice?.requestId != rid) return;
        state = state.copyWith(
          forYouSlice: state.forYouSlice?.copyWith(isLoading: false, error: e.toString()),
        );
      }
    } else {
      final FeedSlice? s = state.followingSlice;
      if (s == null || s.isLoading || s.nextCursor == null) return;
      final String rid = DateTime.now().microsecondsSinceEpoch.toString();
      state = state.copyWith(followingSlice: s.copyWith(isLoading: true, requestId: rid));
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
          followingSlice: state.followingSlice?.copyWith(isLoading: false, error: e.toString()),
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
          forYouVideos: videos.videos,
          lastForYouDoc: videos.lastDocument,
        );
      } else {
        state = state.copyWith(
          forYouVideos: [...state.forYouVideos, ...videos.videos],
          lastForYouDoc: videos.lastDocument,
        );
      }
    } catch (e) {
      print('Error fetching For You videos: $e');
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
            followingVideos: videos.videos,
            lastFollowingDoc: videos.lastDocument,
          );
        } else {
          state = state.copyWith(
            followingVideos: [...state.followingVideos, ...videos.videos],
            lastFollowingDoc: videos.lastDocument,
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
      print('Error fetching ranked Following feed: $e');
    }
  }

  // MARK: - Load More Content
  
  bool shouldLoadMoreContent(int currentIndex, FeedType feed) {
    final videos = this.videos(feed);
    return currentIndex >= videos.length - 2 && hasMoreContent && !isLoadingMore;
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
      print('Error loading more videos: $e');
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
      print('Error toggling like: $e');
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
      updatedVideos[index] = updatedVideos[index].copyWith(isFavorited: isFavorited);
      state = state.copyWith(forYouVideos: updatedVideos);
    }
  }

  /// Update Following video favorite state
  void _updateFollowingVideoFavorite(int index, bool isFavorited) {
    if (index >= 0 && index < followingVideos.length) {
      final updatedVideos = List<HomeVideo>.from(followingVideos);
      updatedVideos[index] = updatedVideos[index].copyWith(isFavorited: isFavorited);
      state = state.copyWith(followingVideos: updatedVideos);
    }
  }


  // MARK: - Sync States
  
  Future<void> syncLikeStates() async {
    // TODO: Implement like state synchronization
    print('Syncing like states...');
  }

  Future<void> syncFavoriteStates() async {
    // Sync favorite states from the new FavoritesService
    print('Syncing favorite states from FavoritesService...');
    
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
    // TODO: Implement comment count synchronization
    print('Syncing comment counts...');
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

