import '../../../models/home_video.dart';
import '../../../services/following_feed_service.dart';
import '../../../services/video_service.dart' as video_service;
import '../domain/home_following_feed_merge.dart';

/// One page of following-feed results for the home tab.
class HomeFollowingFeedPage {
  const HomeFollowingFeedPage({
    required this.videos,
    this.lastDocument,
    this.nextCursor,
    this.hadConnections = true,
  });

  final List<HomeVideo> videos;
  final Object? lastDocument;
  final Map<String, dynamic>? nextCursor;
  final bool hadConnections;
}

/// Loads and paginates the home Following feed.
class HomeFollowingFeedLoader {
  HomeFollowingFeedLoader({
    FollowingFeedService? followingFeedService,
    required video_service.VideoService videoService,
  })  : _followingFeedService =
            followingFeedService ?? FollowingFeedService.instance,
        _videoService = videoService;

  final FollowingFeedService _followingFeedService;
  final video_service.VideoService _videoService;

  Future<HomeFollowingFeedPage> refresh({
    required String? viewerId,
    required List<String> fallbackFollowingIds,
    required bool reset,
    required List<HomeVideo> existingVideos,
    required Object? lastFollowingDoc,
  }) async {
    if (viewerId == null) {
      final Map<String, dynamic> page =
          await _videoService.fetchFollowingVideos(
        followingIds: fallbackFollowingIds,
        pageSize: 10,
        lastDocument: reset ? null : lastFollowingDoc,
      );
      final List<HomeVideo> videos = page['videos'] as List<HomeVideo>;
      final Object? lastDocument = page['lastDocument'];
      return HomeFollowingFeedPage(
        videos: mergeFollowingFeedPage(
          existing: existingVideos,
          pageVideos: videos,
          reset: reset,
        ),
        lastDocument: lastDocument,
        nextCursor: nextCursorFromLastDocument(lastDocument),
      );
    }

    final bool hasConnections =
        await _followingFeedService.hasConnections(viewerId);
    if (!hasConnections) {
      return const HomeFollowingFeedPage(
        videos: <HomeVideo>[],
        lastDocument: null,
        nextCursor: null,
        hadConnections: false,
      );
    }

    final Map<String, dynamic> page =
        await _followingFeedService.fetchFollowingVideos(
      viewerId: viewerId,
      limit: reset ? 20 : 10,
      startAfter: reset ? null : lastFollowingDoc,
    );
    final List<HomeVideo> videos = page['videos'] as List<HomeVideo>;
    final Object? lastDocument = page['lastDocument'];
    return HomeFollowingFeedPage(
      videos: mergeFollowingFeedPage(
        existing: existingVideos,
        pageVideos: videos,
        reset: reset,
      ),
      lastDocument: lastDocument,
      nextCursor: nextCursorFromLastDocument(lastDocument),
    );
  }

  Future<HomeFollowingFeedPage> loadMore({
    required String viewerId,
    required List<HomeVideo> existingVideos,
    required Map<String, dynamic>? nextCursor,
  }) async {
    final Map<String, dynamic> page =
        await _followingFeedService.fetchFollowingVideos(
      viewerId: viewerId,
      limit: 10,
      startAfter: nextCursor,
    );
    final List<HomeVideo> newVideos = page['videos'] as List<HomeVideo>;
    final Object? lastDocument = page['lastDocument'];
    return HomeFollowingFeedPage(
      videos: dedupeFollowingFeedVideos(
        existing: existingVideos,
        newVideos: newVideos,
      ),
      lastDocument: lastDocument,
      nextCursor: nextCursorFromLastDocument(lastDocument),
    );
  }
}
