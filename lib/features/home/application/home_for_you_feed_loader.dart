import '../../../models/home_video.dart';
import '../../../services/video_service.dart' as video_service;
import '../domain/home_following_feed_merge.dart';

/// One page of For You feed results for the home tab.
class HomeForYouFeedPage {
  const HomeForYouFeedPage({
    required this.videos,
    this.lastDocument,
    this.nextCursor,
    this.error,
    this.clearError = false,
  });

  final List<HomeVideo> videos;
  final Object? lastDocument;
  final Map<String, dynamic>? nextCursor;
  final String? error;
  final bool clearError;
}

/// Paginated refresh and load-more for the home For You feed.
class HomeForYouFeedLoader {
  HomeForYouFeedLoader({
    required video_service.VideoService videoService,
    void Function(String message)? log,
  })  : _videoService = videoService,
        _log = log ?? _noopLog;

  final video_service.VideoService _videoService;
  final void Function(String message) _log;

  static const int refreshPageSize = 20;
  static const int loadMorePageSize = 10;

  Future<HomeForYouFeedPage> refresh({
    required List<HomeVideo> previousVideos,
    required Map<String, dynamic>? previousCursor,
    required Object? previousLastDocument,
  }) async {
    final Map<String, dynamic> page = await _videoService.fetchForYouVideos(
      pageSize: refreshPageSize,
      lastDocument: null,
    );
    List<HomeVideo> videos = page['videos'] as List<HomeVideo>;
    Object? lastDocument = page['lastDocument'];
    Map<String, dynamic>? nextCursor =
        nextCursorFromLastDocument(lastDocument);

    if (videos.isEmpty) {
      _log(
        '⚠️ For You refresh returned 0 videos from paginated query; '
        'trying broad feed loader before changing visible feed',
      );
      await _videoService.refresh();
      final List<HomeVideo> fallbackVideos = _videoService.getAllVideos();
      if (fallbackVideos.isNotEmpty) {
        _log(
          '✅ For You refresh recovered ${fallbackVideos.length} videos '
          'from broad feed loader',
        );
        return HomeForYouFeedPage(
          videos: fallbackVideos,
          clearError: true,
        );
      }
      if (previousVideos.isNotEmpty) {
        _log(
          '⚠️ For You refresh still empty; keeping '
          '${previousVideos.length} existing videos visible',
        );
        return HomeForYouFeedPage(
          videos: previousVideos,
          lastDocument: previousLastDocument,
          nextCursor: previousCursor,
          error: 'Could not refresh videos. Showing your last loaded feed.',
        );
      }
    }

    return HomeForYouFeedPage(
      videos: videos,
      lastDocument: lastDocument,
      nextCursor: nextCursor,
      clearError: true,
    );
  }

  Future<HomeForYouFeedPage> loadMore({
    required List<HomeVideo> existingVideos,
    required Object? lastDocument,
  }) async {
    final Map<String, dynamic> page = await _videoService.fetchForYouVideos(
      pageSize: loadMorePageSize,
      lastDocument: lastDocument,
    );
    final List<HomeVideo> newVideos = page['videos'] as List<HomeVideo>;
    final Object? pageLastDocument = page['lastDocument'];
    return HomeForYouFeedPage(
      videos: <HomeVideo>[...existingVideos, ...newVideos],
      lastDocument: pageLastDocument,
      nextCursor: nextCursorFromLastDocument(pageLastDocument),
      clearError: true,
    );
  }

  static void _noopLog(String message) {}
}
