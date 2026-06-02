import '../../../models/home_video.dart';
import '../../../services/streamers_tip_like_service.dart';

/// Applies cached like state onto a single [HomeVideo].
HomeVideo applyLikeStateToVideo(HomeVideo video, LikeState likeState) {
  final int likeCount = likeState.likeCount > 0 || likeState.isLiked
      ? likeState.likeCount
      : video.likes;
  return video.copyWith(isLiked: likeState.isLiked, likes: likeCount);
}

/// Maps like state onto each video using [resolveLikeState].
List<HomeVideo> applyLikeStatesToVideos(
  List<HomeVideo> videos,
  LikeState Function(String videoId) resolveLikeState,
) {
  return videos
      .map(
        (HomeVideo video) =>
            applyLikeStateToVideo(video, resolveLikeState(video.id)),
      )
      .toList(growable: false);
}

/// Maps bookmark state onto each video using [isBookmarked].
List<HomeVideo> applyFavoriteStatesToVideos(
  List<HomeVideo> videos,
  bool Function(String videoId) isBookmarked,
) {
  return videos
      .map(
        (HomeVideo video) =>
            video.copyWith(isFavorited: isBookmarked(video.id)),
      )
      .toList(growable: false);
}

/// Applies fetched comment counts; keeps existing count when missing.
List<HomeVideo> applyCommentCountsToVideos(
  List<HomeVideo> videos,
  Map<String, int> commentCounts,
) {
  return videos
      .map((HomeVideo video) {
        final int? newCommentCount = commentCounts[video.id];
        if (newCommentCount == null || newCommentCount == video.comments) {
          return video;
        }
        return video.copyWith(comments: newCommentCount);
      })
      .toList(growable: false);
}

bool feedsHaveCommentCountChanges({
  required List<HomeVideo> beforeForYou,
  required List<HomeVideo> afterForYou,
  required List<HomeVideo> beforeFollowing,
  required List<HomeVideo> afterFollowing,
}) {
  bool feedChanged(List<HomeVideo> before, List<HomeVideo> after) {
    for (final HomeVideo video in after) {
      final HomeVideo previous = before.firstWhere(
        (HomeVideo v) => v.id == video.id,
        orElse: () => video,
      );
      if (previous.comments != video.comments) {
        return true;
      }
    }
    return false;
  }

  return feedChanged(beforeForYou, afterForYou) ||
      feedChanged(beforeFollowing, afterFollowing);
}
