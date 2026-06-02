import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/services/playback_feed_index_tracker.dart';
import 'package:streamers_tip/services/playback_visible_index_coordinator.dart';
import 'package:streamers_tip/utils/video_health_gate.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('PlaybackVisibleIndexCoordinator', () {
    const PlaybackVisibleIndexCoordinator coordinator =
        PlaybackVisibleIndexCoordinator();

    HomeVideo testVideo({
      String id = 'video-1',
      String url = 'https://cdn.example/v.mp4',
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
      );
    }

    test('ignores invalid index', () async {
      var focusCalled = false;
      await coordinator.onVisibleIndexChanged(
        newIndex: -1,
        video: testVideo(),
        feedIndex: PlaybackFeedIndexTracker(),
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (_, __) {},
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getOrCreateController: (_, __, {owner}) async => null,
        requestFocus: (_, __) async {},
        resolvePlayableSource: (_, {fallbackUrl}) async => Playable(
          url: fallbackUrl ?? '',
          quality: '720p',
          sourceType: 'canonical',
        ),
      );
      expect(focusCalled, isFalse);
    });

    test('requests focus when playable', () async {
      final PlaybackFeedIndexTracker feedIndex = PlaybackFeedIndexTracker();
      String? focusedVideoId;
      VideoPlayableResult? resolved;

      await coordinator.onVisibleIndexChanged(
        newIndex: 1,
        video: testVideo(id: 'v-focus'),
        feedIndex: feedIndex,
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (int index, String videoId) {
          feedIndex.syncMapping(index: index, videoId: videoId);
        },
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getOrCreateController: (String videoId, String url, {owner}) async {
          return VideoPlayerController.networkUrl(Uri.parse(url));
        },
        requestFocus: (String videoId, String owner) async {
          focusedVideoId = videoId;
        },
        resolvePlayableSource: (String videoId, {fallbackUrl}) async {
          resolved = Playable(
            url: fallbackUrl ?? 'https://cdn.example/v.mp4',
            quality: '720p',
            sourceType: 'canonical',
          );
          return resolved!;
        },
      );

      expect(feedIndex.currentFeedIndex, 1);
      expect(focusedVideoId, 'v-focus');
      expect(resolved, isA<Playable>());
    });

    test('stops when health gate returns unplayable', () async {
      var requestFocusCalled = false;

      await coordinator.onVisibleIndexChanged(
        newIndex: 0,
        video: testVideo(),
        feedIndex: PlaybackFeedIndexTracker(),
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (_, __) {},
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getOrCreateController: (_, __, {owner}) async {
          throw StateError('should not create');
        },
        requestFocus: (_, __) async {
          requestFocusCalled = true;
        },
        resolvePlayableSource: (_, {fallbackUrl}) async => Unplayable(
          reason: 'missing_asset',
        ),
      );

      expect(requestFocusCalled, isFalse);
    });

    test('does not request focus when getOrCreate returns null', () async {
      var requestFocusCalled = false;

      await coordinator.onVisibleIndexChanged(
        newIndex: 0,
        video: testVideo(),
        feedIndex: PlaybackFeedIndexTracker(),
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (_, __) {},
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getOrCreateController: (_, __, {owner}) async => null,
        requestFocus: (_, __) async {
          requestFocusCalled = true;
        },
        resolvePlayableSource: (_, {fallbackUrl}) async => Playable(
          url: 'https://cdn.example/v.mp4',
          quality: '720p',
          sourceType: 'canonical',
        ),
      );

      expect(requestFocusCalled, isFalse);
    });
  });
}
