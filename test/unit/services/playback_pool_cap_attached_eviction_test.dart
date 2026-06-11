import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_controller_pool.dart';
import 'package:streamers_tip/services/playback_controller_registration_coordinator.dart';
import 'package:streamers_tip/services/playback_feed_index_tracker.dart';
import 'package:streamers_tip/services/playback_focus_coordinator.dart';
import 'package:streamers_tip/services/playback_pool_cap_coordinator.dart';
import 'package:video_player/video_player.dart';

class _FakeController extends Fake implements VideoPlayerController {
  bool wasDisposed = false;

  @override
  VideoPlayerValue get value => const VideoPlayerValue(
        duration: Duration(seconds: 30),
        isInitialized: true,
      );

  @override
  Future<void> dispose() async {
    wasDisposed = true;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> pause() async {}
}

void main() {
  test(
    'unregisterController does not dispose while view still attached',
    () {
      final PlaybackControllerRegistrationCoordinator registration =
          const PlaybackControllerRegistrationCoordinator();
      final PlaybackControllerPool pool = PlaybackControllerPool();
      final PlaybackFocusCoordinator focus = PlaybackFocusCoordinator();
      final _FakeController controller = _FakeController();
      pool.recordRegister('v-attached', controller);
      pool.markAttached('v-attached', controller.hashCode);
      registration.unregisterController(
        videoId: 'v-attached',
        pool: pool,
        focus: focus,
        muteStates: <String, bool>{},
        warmStartedAt: <String, DateTime>{},
        focusRequestedAt: <String, DateTime>{},
        firstFrameLoggedKeys: <String>{},
        isControllerSafe: (_, __) => true,
        getCurrentlyPlayingController: () => null,
        setCurrentlyPlayingController: (_) {},
        disposeControllerAfterPause: ({
          required String videoId,
          required VideoPlayerController controller,
          required PlaybackControllerPool pool,
          required bool Function(String videoId, VideoPlayerController controller)
              isControllerSafe,
          void Function(String message)? log,
        }) {
          controller.dispose();
        },
      );
      expect(controller.wasDisposed, isFalse);
      expect(pool.containsKey('v-attached'), isFalse);
    },
  );

  test('enforcePoolCap does not pick attached controller as victim', () {
    const PlaybackPoolCapCoordinator coordinator =
        PlaybackPoolCapCoordinator();
    final PlaybackControllerPool pool = PlaybackControllerPool();
    final PlaybackFeedIndexTracker feedIndex = PlaybackFeedIndexTracker();
    feedIndex.currentFeedIndex = 0;
    feedIndex.syncMapping(index: 0, videoId: 'v0');
    feedIndex.syncMapping(index: 1, videoId: 'v1');
    feedIndex.syncMapping(index: 5, videoId: 'v5');
    final _FakeController attached = _FakeController();
    final List<String> unregistered = <String>[];
    for (final String id in <String>['v0', 'v1', 'v2', 'v3', 'v5']) {
      pool.recordRegister(
        id,
        id == 'v5' ? attached : _FakeController(),
      );
    }
    pool.markAttached('v5', attached.hashCode);
    coordinator.enforcePoolCap(
      pool: pool,
      feedIndex: feedIndex,
      activeVideoId: 'v0',
      isActiveVideo: (String id) => id == 'v0',
      onUnregister: (String id) {
        unregistered.add(id);
        pool.removePoolEntry(id);
      },
      onPoolAudit: (_, __, {String? reason}) {},
      maxSize: 3,
      reason: 'test',
    );
    expect(unregistered, isNot(contains('v5')));
    expect(attached.wasDisposed, isFalse);
  });
}
