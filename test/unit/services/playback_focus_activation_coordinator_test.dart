import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_controller_pool.dart';
import 'package:streamers_tip/services/playback_focus_activation_coordinator.dart';
import 'package:streamers_tip/services/playback_focus_coordinator.dart';

void main() {
  group('PlaybackFocusActivationCoordinator', () {
    const PlaybackFocusActivationCoordinator coordinator =
        PlaybackFocusActivationCoordinator();
    late PlaybackFocusCoordinator focus;
    late PlaybackControllerPool pool;
    late Map<String, String> controllerOwners;
    late Map<String, bool> muteStates;
    late Map<String, String> pendingFocusRequests;

    setUp(() {
      focus = PlaybackFocusCoordinator();
      pool = PlaybackControllerPool();
      controllerOwners = <String, String>{};
      muteStates = <String, bool>{};
      pendingFocusRequests = <String, String>{};
      focus.setVisibleOwner('home/forYou');
    });

    test('requestFocus queues when controller is missing', () async {
      await coordinator.requestFocus(
        videoId: 'v1',
        owner: 'home/forYou',
        focus: focus,
        pendingFocusRequests: pendingFocusRequests,
        pool: pool,
        controllerOwners: controllerOwners,
        muteStates: muteStates,
        getCurrentlyPlayingController: () => null,
        ownerMatchesVisible: focus.ownerMatchesVisibleOwner,
        setActiveOwner: focus.publishActiveOwner,
        canPlay: (_) => true,
        pauseAll: () {},
        muteAllExcept: (_) async {},
        switchActiveTo: (_, __) async {},
        safePauseAndMute: (_) async {},
        isControllerSafe: (_, __) => true,
      );

      expect(focus.pendingFocusRequests['v1'], 'home/forYou');
      expect(focus.activeVideoId, 'v1');
      expect(focus.activeOwner, 'home/forYou');
    });

    test('requestFocus calls pauseAll when owner cannot play', () async {
      var pauseAllCalled = false;

      await coordinator.requestFocus(
        videoId: 'v1',
        owner: 'home/forYou',
        focus: focus,
        pendingFocusRequests: pendingFocusRequests,
        pool: pool,
        controllerOwners: controllerOwners,
        muteStates: muteStates,
        getCurrentlyPlayingController: () => null,
        ownerMatchesVisible: focus.ownerMatchesVisibleOwner,
        setActiveOwner: focus.publishActiveOwner,
        canPlay: (_) => false,
        pauseAll: () => pauseAllCalled = true,
        muteAllExcept: (_) async {},
        switchActiveTo: (_, __) async {},
        safePauseAndMute: (_) async {},
        isControllerSafe: (_, __) => true,
      );

      expect(pauseAllCalled, isTrue);
    });

    test('switchActiveTo queues pending focus when controller unsafe',
        () async {
      await coordinator.switchActiveTo(
        newVideoId: 'v2',
        owner: 'home/forYou',
        activationEpoch: 0,
        bumpActivationEpoch: () => 1,
        isStaleEpoch: (_) => false,
        focus: focus,
        pool: pool,
        controllerOwners: controllerOwners,
        muteStates: muteStates,
        getCurrentlyPlayingController: () => null,
        setCurrentlyPlayingController: (_) {},
        ownerMatchesVisible: focus.ownerMatchesVisibleOwner,
        setActiveOwner: focus.publishActiveOwner,
        canPlay: (_) => true,
        muteAllExcept: (_) async {},
        safePauseAndMute: (_) async {},
        ensurePlayingUnmuted: (_) async {},
        isControllerSafe: (_, __) => false,
      );

      expect(focus.pendingFocusRequests['v2'], 'home/forYou');
    });
  });
}
