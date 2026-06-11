import '../../../models/home_video.dart';
import '../../../services/comments_service.dart';
import '../../../services/streamers_tip_like_service.dart';
import '../../../services/unified_bookmark_service.dart';
import '../domain/home_feed_engagement_mapper.dart';

/// Loads and maps engagement state (likes, favorites, comments) for home feeds.
class HomeFeedEngagementCoordinator {
  HomeFeedEngagementCoordinator({
    StreamersTipLikeService? likeService,
    UnifiedBookmarkService? bookmarkService,
    CommentsService? commentsService,
  })  : _likeService = likeService ?? StreamersTipLikeService.instance,
        _bookmarkService = bookmarkService ?? UnifiedBookmarkService.instance,
        _commentsService = commentsService ?? CommentsService();

  final StreamersTipLikeService _likeService;
  final UnifiedBookmarkService _bookmarkService;
  final CommentsService _commentsService;

  LikeState likeStateFor(String videoId) => _likeService.getLikeState(videoId);

  Future<void> preloadUserLikes(String userId) {
    return _likeService.loadUserLikedVideos(userId);
  }

  List<HomeVideo> mapLikeStates(List<HomeVideo> videos) {
    return applyLikeStatesToVideos(videos, _likeService.getLikeState);
  }

  HomeVideo mapLikeStateForVideo(HomeVideo video) {
    return applyLikeStateToVideo(video, _likeService.getLikeState(video.id));
  }

  /// Hydrates like/bookmark flags from in-memory caches only (non-blocking).
  void warmEngagementFromCache(List<HomeVideo> videos) {
    for (final HomeVideo video in videos) {
      mapLikeStateForVideo(video);
      _bookmarkService.isBookmarked(video.id);
    }
  }

  Future<List<HomeVideo>> syncLikeStatesForVideos(
    List<HomeVideo> videos,
    String userId,
  ) async {
    await preloadUserLikes(userId);
    return mapLikeStates(videos);
  }

  Future<List<HomeVideo>> syncFavoriteStatesForVideos(
    List<HomeVideo> videos,
    String userId,
  ) async {
    await _bookmarkService.initialize(userId);
    return applyFavoriteStatesToVideos(
      videos,
      _bookmarkService.isBookmarked,
    );
  }

  Future<List<HomeVideo>> loadLikeStatesInBatches(
    List<HomeVideo> videos,
  ) async {
    const int batchSize = 5;
    final List<HomeVideo> updatedVideos = <HomeVideo>[];
    for (int i = 0; i < videos.length; i += batchSize) {
      final List<HomeVideo> batch =
          videos.skip(i).take(batchSize).toList(growable: false);
      for (final HomeVideo video in batch) {
        try {
          updatedVideos.add(mapLikeStateForVideo(video));
        } catch (_) {
          updatedVideos.add(video);
        }
      }
      if (i + batchSize < videos.length) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    return updatedVideos;
  }

  Future<Map<String, int>> fetchCommentCountsForVideos(
    List<HomeVideo> videos,
  ) async {
    final List<String> videoIds =
        videos.map((HomeVideo video) => video.id).toSet().toList(growable: false);
    if (videoIds.isEmpty) {
      return <String, int>{};
    }
    final Map<String, int> commentCounts = <String, int>{};
    for (final String videoId in videoIds) {
      try {
        final comments =
            await _commentsService.fetchCommentsForVideo(videoId);
        commentCounts[videoId] = comments.length;
      } catch (_) {
        final HomeVideo existingVideo = videos.firstWhere(
          (HomeVideo video) => video.id == videoId,
          orElse: () => videos.first,
        );
        commentCounts[videoId] = existingVideo.comments;
      }
    }
    return commentCounts;
  }

  Future<int> fetchCommentCountForVideo(String videoId) async {
    final comments = await _commentsService.fetchCommentsForVideo(videoId);
    return comments.length;
  }
}
