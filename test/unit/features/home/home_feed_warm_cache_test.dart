import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/application/home_feed_warm_cache.dart';
import 'package:streamers_tip/features/home/domain/home_feed_processing.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';

void main() {
  group('HomeFeedWarmCache.sanitizeCursor', () {
    test('keeps primitive cursor fields', () {
      final Map<String, dynamic>? actual = HomeFeedWarmCache.sanitizeCursor(
        <String, dynamic>{
          'lastId': 'abc',
          'page': 2,
          'done': false,
        },
      );
      expect(actual, <String, dynamic>{
        'lastId': 'abc',
        'page': 2,
        'done': false,
      });
    });

    test('drops non-primitive values', () {
      final Map<String, dynamic>? actual = HomeFeedWarmCache.sanitizeCursor(
        <String, dynamic>{'doc': Object()},
      );
      expect(actual, isNull);
    });
  });

  group('keepHomeVideosWithRenderableOwners', () {
    test('drops last-known cards whose owner is gone', () {
      final HomeVideo kept = HomeVideo(
        id: 'keep',
        creator: const User(
          id: 'active-owner',
          username: 'alive',
          displayName: 'Alive',
        ),
        videoURL: 'https://stream.mux.com/keep.m3u8',
        status: 'ready',
      );
      final HomeVideo gone = HomeVideo(
        id: 'gone',
        creator: const User(
          id: 'deleted-owner',
          username: 'ghost',
          displayName: 'Ghost',
        ),
        videoURL: 'https://stream.mux.com/gone.m3u8',
        status: 'ready',
      );
      final List<HomeVideo> actual = keepHomeVideosWithRenderableOwners(
        videos: <HomeVideo>[kept, gone],
        renderableOwnerIds: <String>{'active-owner'},
      );
      expect(
        actual.map((HomeVideo video) => video.id).toList(),
        <String>['keep'],
      );
    });
  });
}
