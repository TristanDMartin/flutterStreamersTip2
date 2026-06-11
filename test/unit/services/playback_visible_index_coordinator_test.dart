import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_visible_index_coordinator.dart';
import 'package:streamers_tip/services/playback_feed_index_tracker.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
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
      await coordinator.onVisibleIndexChanged(
        newIndex: -1,
        video: testVideo(),
        requestGeneration: 1,
        isRequestStale: () => false,
        feedIndex: PlaybackFeedIndexTracker(),
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (_, __) {},
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getPooledController: (_) => null,
        waitForInitializing: (_) async => null,
        getOrCreateController: (_, __, {owner}) async => null,
        requestFocus: (_, __) async {},
        resolvePlayableSource: (_, {fallbackUrl}) async => Playable(
          url: fallbackUrl ?? '',
          quality: '720p',
          sourceType: 'canonical',
        ),
        isControllerReady: (_, __) => false,
      );
    });

    test('requests focus from pooled controller without create', () async {
      final PlaybackFeedIndexTracker feedIndex = PlaybackFeedIndexTracker();
      final _ReadyController pooled = _ReadyController();
      String? focusedVideoId;

      await coordinator.onVisibleIndexChanged(
        newIndex: 2,
        video: testVideo(id: 'v-pooled'),
        requestGeneration: 1,
        isRequestStale: () => false,
        feedIndex: feedIndex,
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (int index, String videoId) {
          feedIndex.syncMapping(index: index, videoId: videoId);
        },
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getPooledController: (_) => pooled,
        waitForInitializing: (_) async => null,
        getOrCreateController: (_, __, {owner}) async {
          throw StateError('should not create when pooled');
        },
        requestFocus: (String videoId, String owner) async {
          focusedVideoId = videoId;
        },
        resolvePlayableSource: (_, {fallbackUrl}) async => Playable(
          url: fallbackUrl ?? 'https://cdn.example/v.mp4',
          quality: '720p',
          sourceType: 'canonical',
        ),
        isControllerReady: (_, __) => true,
      );

      expect(feedIndex.currentFeedIndex, 2);
      expect(focusedVideoId, 'v-pooled');
    });

    test('falls back to create when pooled controller missing', () async {
      final PlaybackFeedIndexTracker feedIndex = PlaybackFeedIndexTracker();
      var createCalled = false;
      final List<String> logs = <String>[];

      await coordinator.onVisibleIndexChanged(
        newIndex: 0,
        video: testVideo(id: 'v-miss'),
        requestGeneration: 1,
        isRequestStale: () => false,
        feedIndex: feedIndex,
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (int index, String videoId) {
          feedIndex.syncMapping(index: index, videoId: videoId);
        },
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getPooledController: (_) => null,
        waitForInitializing: (_) async => null,
        getOrCreateController: (_, __, {owner}) async {
          createCalled = true;
          return VideoPlayerController.networkUrl(
            Uri.parse('https://cdn.example/v.mp4'),
          );
        },
        requestFocus: (_, __) async {},
        resolvePlayableSource: (_, {fallbackUrl}) async => Playable(
          url: 'https://cdn.example/v.mp4',
          quality: '720p',
          sourceType: 'canonical',
        ),
        isControllerReady: (_, __) => false,
        log: logs.add,
      );

      expect(createCalled, isTrue);
      expect(
        logs.any((String line) => line.contains('PRELOAD_MISS')),
        isTrue,
      );
    });

    test('stops when health gate returns unplayable', () async {
      var requestFocusCalled = false;

      await coordinator.onVisibleIndexChanged(
        newIndex: 0,
        video: testVideo(),
        requestGeneration: 1,
        isRequestStale: () => false,
        feedIndex: PlaybackFeedIndexTracker(),
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (_, __) {},
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getPooledController: (_) => null,
        waitForInitializing: (_) async => null,
        getOrCreateController: (_, __, {owner}) async {
          throw StateError('should not create');
        },
        requestFocus: (_, __) async {
          requestFocusCalled = true;
        },
        resolvePlayableSource: (_, {fallbackUrl}) async => Unplayable(
          reason: 'missing_asset',
        ),
        isControllerReady: (_, __) => false,
      );

      expect(requestFocusCalled, isFalse);
    });

    test('aborts when request generation is stale', () async {
      var requestFocusCalled = false;
      const int currentGeneration = 2;

      await coordinator.onVisibleIndexChanged(
        newIndex: 0,
        video: testVideo(id: 'v-stale'),
        requestGeneration: 1,
        isRequestStale: () => currentGeneration != 1,
        feedIndex: PlaybackFeedIndexTracker(),
        savePositionForIndex: (_) {},
        syncFeedIndexMapping: (_, __) {},
        clearDesiredFocus: (_) {},
        clearDesiredFocusForOwner: (_, {exceptVideoId}) {},
        getPooledController: (_) => null,
        waitForInitializing: (_) async => null,
        getOrCreateController: (_, __, {owner}) async => null,
        requestFocus: (_, __) async {
          requestFocusCalled = true;
        },
        resolvePlayableSource: (_, {fallbackUrl}) async => Playable(
          url: fallbackUrl ?? 'https://cdn.example/v.mp4',
          quality: '720p',
          sourceType: 'canonical',
        ),
        isControllerReady: (_, __) => false,
      );

      expect(requestFocusCalled, isFalse);
    });
  });
}

class _ReadyController extends Fake implements VideoPlayerController {
  @override
  VideoPlayerValue get value => const VideoPlayerValue(
        duration: Duration(seconds: 10),
        isInitialized: true,
      );
}
