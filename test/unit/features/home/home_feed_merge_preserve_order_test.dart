import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_mutator.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';

HomeVideo _video(String id) {
  return HomeVideo(
    id: id,
    creator: const User(
      id: 'creator',
      username: 'creator',
      displayName: 'Creator',
    ),
    videoURL: 'https://example.com/$id.mp4',
  );
}

void main() {
  group('mergeHomeFeedPreserveOrder', () {
    test('keeps eight existing when incoming has one overlapping id', () {
      final List<HomeVideo> existing = List<HomeVideo>.generate(
        8,
        (int i) => _video('v$i'),
      );
      final List<HomeVideo> incoming = <HomeVideo>[
        _video('v0').copyWith(likes: 99),
      ];

      final List<HomeVideo> actual = mergeHomeFeedPreserveOrder(
        existing: existing,
        incoming: incoming,
      );

      expect(actual.length, 8);
      expect(actual.first.id, 'v0');
      expect(actual.first.likes, 99);
      expect(actual.last.id, 'v7');
    });

    test('does not clear feed when incoming is empty', () {
      final List<HomeVideo> existing = <HomeVideo>[_video('a'), _video('b')];
      final List<HomeVideo> actual = mergeHomeFeedPreserveOrder(
        existing: existing,
        incoming: const <HomeVideo>[],
      );
      expect(actual.length, 2);
    });

    test('does not replace owner local-pending with empty processing stub', () {
      final HomeVideo pendingLocal = HomeVideo(
        id: 'pending-1',
        creator: const User(
          id: 'owner',
          username: 'owner',
          displayName: 'Owner',
        ),
        videoURL: 'file:///tmp/cap.mp4',
        status: 'uploading',
      );
      final HomeVideo processingStub = HomeVideo(
        id: 'pending-1',
        creator: const User(
          id: 'owner',
          username: 'owner',
          displayName: 'Owner',
        ),
        videoURL: '',
        status: 'processing',
      );
      final List<HomeVideo> actual = mergeHomeFeedPreserveOrder(
        existing: <HomeVideo>[pendingLocal, _video('ready-1')],
        incoming: <HomeVideo>[processingStub],
      );
      expect(actual.first.id, 'pending-1');
      expect(actual.first.videoURL, 'file:///tmp/cap.mp4');
      expect(actual.first.status, 'uploading');
    });
  });

  group('reconcileLiveHomeFeedSnapshot', () {
    test('drops deleted remote ids while keeping other cards', () {
      final List<HomeVideo> actual = reconcileLiveHomeFeedSnapshot(
        existing: <HomeVideo>[_video('keep'), _video('gone'), _video('also')],
        incoming: <HomeVideo>[_video('keep'), _video('also')],
        removedIds: <String>{'gone'},
      );
      expect(actual.map((HomeVideo v) => v.id).toList(), <String>[
        'keep',
        'also',
      ]);
    });

    test('keeps owner local-pending even when listed as removed', () {
      final HomeVideo pendingLocal = HomeVideo(
        id: 'pending-1',
        creator: const User(
          id: 'owner',
          username: 'owner',
          displayName: 'Owner',
        ),
        videoURL: 'file:///tmp/cap.mp4',
        status: 'uploading',
      );
      final List<HomeVideo> actual = reconcileLiveHomeFeedSnapshot(
        existing: <HomeVideo>[pendingLocal, _video('ready-1')],
        incoming: <HomeVideo>[_video('ready-1')],
        removedIds: <String>{'pending-1'},
      );
      expect(actual.first.id, 'pending-1');
      expect(actual.length, 2);
    });
  });

  group('shouldRejectShrinkingFeedReplacement', () {
    test('merges one-video snapshot instead of blocking replacement', () {
      final List<HomeVideo> current = List<HomeVideo>.generate(
        8,
        (int i) => _video('v$i'),
      );
      final bool blocked = shouldRejectShrinkingFeedReplacement(
        current: current,
        incoming: <HomeVideo>[_video('v0')],
        reason: 'live_feed_snapshot',
      );
      expect(blocked, isFalse);
    });

    test('blocks like_sync from touching feed', () {
      final bool blocked = shouldRejectShrinkingFeedReplacement(
        current: List<HomeVideo>.generate(8, (int i) => _video('v$i')),
        incoming: List<HomeVideo>.generate(8, (int i) => _video('v$i')),
        reason: 'like_sync',
      );
      expect(blocked, isTrue);
    });

    test('allows first populate when current is empty', () {
      final bool blocked = shouldRejectShrinkingFeedReplacement(
        current: const <HomeVideo>[],
        incoming: <HomeVideo>[_video('a')],
        reason: 'live_feed_snapshot',
      );
      expect(blocked, isFalse);
    });
  });
}
