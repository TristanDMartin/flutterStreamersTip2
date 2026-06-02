import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_controller_pool.dart';
import 'package:streamers_tip/services/playback_controller_registration_coordinator.dart';
import 'package:streamers_tip/services/playback_focus_coordinator.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('PlaybackControllerRegistrationCoordinator', () {
    const PlaybackControllerRegistrationCoordinator coordinator =
        PlaybackControllerRegistrationCoordinator();
    late PlaybackControllerPool pool;
    late PlaybackFocusCoordinator focus;
    late Map<String, bool> muteStates;

    setUp(() {
      pool = PlaybackControllerPool();
      focus = PlaybackFocusCoordinator();
      muteStates = <String, bool>{};
    });

    VideoPlayerController newController() {
      return VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/v.mp4'),
      );
    }

    test('registerController adds controller to pool and applies pending focus',
        () {
      String? pendingVideoId;
      final VideoPlayerController controller = newController();

      coordinator.registerController(
        videoId: 'v1',
        controller: controller,
        pool: pool,
        focus: focus,
        muteStates: muteStates,
        videoIdToIndex: <String, int>{},
        currentFeedIndex: null,
        canEvict: (_, __, ___) => true,
        isControllerSafe: (_, __) => false,
        onLogControllerEvent: (_, __, {controllerId, reason}) {},
        onUnregister: (_) {},
        onApplyPendingFocus: (String id) => pendingVideoId = id,
        getCurrentlyPlayingController: () => null,
        setCurrentlyPlayingController: (_) {},
        scheduleDeferredPoolControllerDispose: ({
          required videoId,
          required controller,
          required pool,
          required isControllerSafe,
          log,
        }) {},
        owner: 'home/forYou',
      );

      expect(pool['v1'], same(controller));
      expect(pool.owners['v1'], 'home/forYou');
      expect(pendingVideoId, 'v1');
    });

    test('unregisterController clears active video in focus', () {
      final VideoPlayerController controller = newController();
      pool.recordRegister('v1', controller);
      pool.markAttached('v1', controller.hashCode);
      focus.publishActiveVideo('v1');
      VideoPlayerController? playing = controller;

      coordinator.unregisterController(
        videoId: 'v1',
        pool: pool,
        focus: focus,
        muteStates: muteStates,
        warmStartedAt: <String, DateTime>{},
        focusRequestedAt: <String, DateTime>{},
        firstFrameLoggedKeys: <String>{},
        isControllerSafe: (_, __) => true,
        getCurrentlyPlayingController: () => playing,
        setCurrentlyPlayingController: (VideoPlayerController? c) {
          playing = c;
        },
        disposeControllerAfterPause: ({
          required videoId,
          required controller,
          required pool,
          required isControllerSafe,
          log,
        }) {},
      );

      expect(pool.containsKey('v1'), isFalse);
      expect(focus.activeVideoId, isNull);
      expect(playing, isNull);
    });

    test('registerController evicts outside warm window when pool is full', () {
      final List<String> unregistered = <String>[];
      final Map<String, int> videoIdToIndex = <String, int>{
        'v0': 10,
        'v1': 1,
        'v2': 5,
      };
      for (int i = 0; i < 3; i++) {
        pool.recordRegister('v$i', newController());
        pool.setOwner('v$i', 'home');
      }

      coordinator.registerController(
        videoId: 'v3',
        controller: newController(),
        pool: pool,
        focus: focus,
        muteStates: muteStates,
        videoIdToIndex: videoIdToIndex,
        currentFeedIndex: 1,
        canEvict: (_, __, ___) => true,
        isControllerSafe: (_, __) => false,
        onLogControllerEvent: (_, __, {controllerId, reason}) {},
        onUnregister: unregistered.add,
        onApplyPendingFocus: (_) {},
        getCurrentlyPlayingController: () => null,
        setCurrentlyPlayingController: (_) {},
        scheduleDeferredPoolControllerDispose: ({
          required videoId,
          required controller,
          required pool,
          required isControllerSafe,
          log,
        }) {},
      );

      expect(unregistered, containsAll(<String>['v0', 'v2']));
      expect(pool.containsKey('v3'), isTrue);
    });
  });
}
