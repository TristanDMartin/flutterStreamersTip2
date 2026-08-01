import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_processing.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';

void main() {
  HomeVideo video({
    required String id,
    String url = 'https://cdn.example/v.mp4',
    Timestamp? createdAt,
    bool isDeleted = false,
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
      videoURL: url,
      createdAt: createdAt,
      isDeleted: isDeleted,
    );
  }

  group('dedupeHomeVideosById', () {
    test('keeps first occurrence', () {
      final List<HomeVideo> input = <HomeVideo>[
        video(id: 'a'),
        video(id: 'a'),
        video(id: 'b'),
      ];
      final List<HomeVideo> actual = dedupeHomeVideosById(input);
      expect(actual.map((HomeVideo v) => v.id).toList(), <String>['a', 'b']);
    });
  });

  group('rankHomeVideosForFeed', () {
    test('playable videos sort before non-playable', () {
      final HomeVideo playable =
          video(id: 'p', url: 'https://cdn.example/p.mp4');
      final HomeVideo pending = video(id: 'n', url: '');
      final List<HomeVideo> actual = rankHomeVideosForFeed(<HomeVideo>[
        pending,
        playable,
      ]);
      expect(actual.first.id, 'p');
    });
  });

  group('filterPlayableHomeVideos', () {
    test('drops stale cached deleted videos', () {
      final List<HomeVideo> actual = filterPlayableHomeVideos(<HomeVideo>[
        video(id: 'deleted', isDeleted: true),
        video(id: 'visible'),
      ]);
      expect(actual.map((HomeVideo v) => v.id), <String>['visible']);
    });
  });

  group('shouldKeepWarmFeedOverEmptyNetwork', () {
    test('keeps warm when network is empty', () {
      expect(
        shouldKeepWarmFeedOverEmptyNetwork(
          currentVideos: <HomeVideo>[video(id: 'warm')],
          networkVideos: const <HomeVideo>[],
        ),
        isTrue,
      );
    });

    test('replaces when network has videos', () {
      expect(
        shouldKeepWarmFeedOverEmptyNetwork(
          currentVideos: <HomeVideo>[video(id: 'warm')],
          networkVideos: <HomeVideo>[video(id: 'fresh')],
        ),
        isFalse,
      );
    });

    test('allows empty honest state when nothing warm', () {
      expect(
        shouldKeepWarmFeedOverEmptyNetwork(
          currentVideos: const <HomeVideo>[],
          networkVideos: const <HomeVideo>[],
        ),
        isFalse,
      );
    });
  });

  group('shouldForceFeedIndexSyncDuringScroll', () {
    test('forces sync when current index is now out of bounds', () {
      expect(
        shouldForceFeedIndexSyncDuringScroll(
          currentIndex: 4,
          nextVideoCount: 3,
        ),
        isTrue,
      );
    });

    test('does not force sync for in-bounds identity reshuffle', () {
      expect(
        shouldForceFeedIndexSyncDuringScroll(
          currentIndex: 1,
          nextVideoCount: 5,
        ),
        isFalse,
      );
    });
  });
}
