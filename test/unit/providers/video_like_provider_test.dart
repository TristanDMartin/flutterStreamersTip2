import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/providers/video_like_provider.dart';

void main() {
  group('VideoLikeState', () {
    test('toggle math keeps non-negative counts', () {
      const VideoLikeState liked = VideoLikeState(isLiked: true, likeCount: 3);
      const VideoLikeState unliked =
          VideoLikeState(isLiked: false, likeCount: 0);

      expect(
        liked.copyWith(isLiked: false, likeCount: 2).likeCount,
        2,
      );
      expect(
        unliked.copyWith(isLiked: true, likeCount: 1).likeCount,
        1,
      );
      expect(
        liked.copyWith(isLiked: false, likeCount: 0).likeCount,
        0,
      );
    });
  });
}
