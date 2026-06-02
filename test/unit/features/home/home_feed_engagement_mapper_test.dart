import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_engagement_mapper.dart';
import 'package:streamers_tip/features/home/domain/home_following_feed_merge.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/services/streamers_tip_like_service.dart';

void main() {
  HomeVideo video({
    required String id,
    int likes = 0,
    bool isLiked = false,
    int comments = 0,
    bool isFavorited = false,
  }) {
    return HomeVideo(
      id: id,
      creator: const User(
        id: 'u1',
        username: 'u',
        displayName: 'U',
        bio: '',
        hashtags: <String>[],
      ),
      videoURL: 'https://cdn.example/$id.mp4',
      likes: likes,
      isLiked: isLiked,
      comments: comments,
      isFavorited: isFavorited,
    );
  }

  group('applyLikeStateToVideo', () {
    test('uses service count when liked', () {
      final HomeVideo input = video(id: 'v1', likes: 1);
      final LikeState likeState = LikeState(
        isLiked: true,
        likeCount: 5,
        timestamp: DateTime.now(),
      );
      final HomeVideo actual = applyLikeStateToVideo(input, likeState);
      expect(actual.isLiked, isTrue);
      expect(actual.likes, 5);
    });

    test('keeps card count when unliked and count is zero', () {
      final HomeVideo input = video(id: 'v1', likes: 3);
      final LikeState likeState = LikeState(
        isLiked: false,
        likeCount: 0,
        timestamp: DateTime.now(),
      );
      final HomeVideo actual = applyLikeStateToVideo(input, likeState);
      expect(actual.likes, 3);
    });
  });

  group('dedupeFollowingFeedVideos', () {
    test('preserves first occurrence order', () {
      final List<HomeVideo> actual = dedupeFollowingFeedVideos(
        existing: <HomeVideo>[video(id: 'a'), video(id: 'b')],
        newVideos: <HomeVideo>[video(id: 'b'), video(id: 'c')],
      );
      expect(actual.map((HomeVideo v) => v.id).toList(), <String>['a', 'b', 'c']);
    });
  });

  group('mergeFollowingFeedPage', () {
    test('reset replaces existing items', () {
      final List<HomeVideo> actual = mergeFollowingFeedPage(
        existing: <HomeVideo>[video(id: 'old')],
        pageVideos: <HomeVideo>[video(id: 'new')],
        reset: true,
      );
      expect(actual.single.id, 'new');
    });
  });
}
