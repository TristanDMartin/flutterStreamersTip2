import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/services/playback_controller_pool.dart';
import 'package:streamers_tip/services/playback_ensure_ready_coordinator.dart';
import 'package:streamers_tip/utils/video_health_gate.dart';

void main() {
  group('PlaybackEnsureReadyCoordinator', () {
    const PlaybackEnsureReadyCoordinator coordinator =
        PlaybackEnsureReadyCoordinator();

    HomeVideo video({String id = 'v1'}) {
      return HomeVideo(
        id: id,
        creator: const User(
          id: 'u1',
          username: 'u',
          displayName: 'U',
          bio: '',
          hashtags: <String>[],
        ),
        videoURL: 'https://cdn.example/v.mp4',
      );
    }

    test('returns early for invalid index', () async {
      var createCalled = false;

      await coordinator.ensureControllerReady(
        index: -1,
        video: video(),
        pool: PlaybackControllerPool(),
        initializingControllers: <String>{},
        lastKnownPositions: <int, Duration>{},
        isControllerSafe: (_, __) => true,
        waitForInitializing: (_) async => null,
        resolvePlayableSource: (_, {fallbackUrl}) async => Playable(
          url: fallbackUrl ?? '',
          quality: '720p',
          sourceType: 'canonical',
        ),
        getOrCreateController: (_, __, {owner}) async {
          createCalled = true;
          return null;
        },
        syncFeedIndexMapping: (_, __) {},
      );

      expect(createCalled, isFalse);
    });

    test('skips create when health gate returns unplayable', () async {
      var createCalled = false;

      await coordinator.ensureControllerReady(
        index: 0,
        video: video(),
        pool: PlaybackControllerPool(),
        initializingControllers: <String>{},
        lastKnownPositions: <int, Duration>{},
        isControllerSafe: (_, __) => false,
        waitForInitializing: (_) async => null,
        resolvePlayableSource: (_, {fallbackUrl}) async => Unplayable(
          reason: 'missing',
        ),
        getOrCreateController: (_, __, {owner}) async {
          createCalled = true;
          return null;
        },
        syncFeedIndexMapping: (_, __) {},
      );

      expect(createCalled, isFalse);
    });
  });
}
