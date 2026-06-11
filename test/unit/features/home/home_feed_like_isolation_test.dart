import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_mutator.dart';
import 'package:streamers_tip/features/home/models/home_feed_state.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';

HomeVideo _video(String id, {bool isLiked = false, int likes = 0}) {
  return HomeVideo(
    id: id,
    creator: const User(
      id: 'creator',
      username: 'creator',
      displayName: 'Creator',
    ),
    videoURL: 'https://example.com/$id.mp4',
    isLiked: isLiked,
    likes: likes,
  );
}

void main() {
  group('home feed like isolation', () {
    test('updateVideoAcrossFeeds mutates only the targeted video', () {
      final HomeState state = HomeState(
        forYouVideos: <HomeVideo>[
          _video('a', likes: 1),
          _video('b', likes: 2),
        ],
      );

      final HomeState actual = updateVideoAcrossFeeds(
        state,
        'a',
        (HomeVideo video) => video.copyWith(isLiked: true, likes: 2),
      );

      expect(actual.forYouVideos[0].isLiked, isTrue);
      expect(actual.forYouVideos[0].likes, 2);
      expect(actual.forYouVideos[1].isLiked, isFalse);
      expect(actual.forYouVideos[1].likes, 2);
      expect(actual.forYouVideos[0].id, 'a');
      expect(actual.forYouVideos[1].id, 'b');
    });

    test('updateVideoInList preserves order and length', () {
      final List<HomeVideo> input = <HomeVideo>[
        _video('a'),
        _video('b'),
        _video('c'),
      ];
      final List<HomeVideo> actual = updateVideoInList(
        input,
        'b',
        (HomeVideo video) => video.copyWith(isLiked: true),
      );
      expect(actual.length, 3);
      expect(actual.map((HomeVideo v) => v.id).toList(), <String>['a', 'b', 'c']);
      expect(actual[1].isLiked, isTrue);
      expect(actual[0].isLiked, isFalse);
      expect(actual[2].isLiked, isFalse);
    });
  });
}
