import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_active_owner_coordinator.dart';
import 'package:streamers_tip/services/playback_focus_coordinator.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('PlaybackActiveOwnerCoordinator', () {
    const PlaybackActiveOwnerCoordinator coordinator =
        PlaybackActiveOwnerCoordinator();

    test('setActiveOwner pauses controllers from other owners', () {
      final PlaybackFocusCoordinator focus = PlaybackFocusCoordinator();
      focus.setVisibleOwner('home');
      final Map<String, VideoPlayerController> pool =
          <String, VideoPlayerController>{
        'v1': VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/1.mp4'),
        ),
        'v2': VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/2.mp4'),
        ),
      };
      final Map<String, String> owners = <String, String>{
        'v1': 'home/forYou',
        'v2': 'discover',
      };
      final Map<String, bool> muteStates = <String, bool>{};

      coordinator.setActiveOwner(
        owner: 'home',
        focus: focus,
        controllerPool: pool,
        controllerOwners: owners,
        muteStates: muteStates,
        isControllerSafe: (_, __) => true,
      );

      expect(focus.activeOwner, 'home');
      expect(muteStates['v2'], isTrue);
      expect(muteStates.containsKey('v1'), isFalse);
    });

    test('setActiveOwner is no-op when owner is already active', () {
      final PlaybackFocusCoordinator focus = PlaybackFocusCoordinator();
      focus.setVisibleOwner('home');
      focus.publishActiveOwner('home');
      final Map<String, VideoPlayerController> pool =
          <String, VideoPlayerController>{
        'v1': VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/1.mp4'),
        ),
      };
      final Map<String, String> owners = <String, String>{'v1': 'discover'};
      final Map<String, bool> muteStates = <String, bool>{};

      coordinator.setActiveOwner(
        owner: 'home',
        focus: focus,
        controllerPool: pool,
        controllerOwners: owners,
        muteStates: muteStates,
        isControllerSafe: (_, __) => true,
      );

      expect(muteStates.containsKey('v1'), isFalse);
    });
  });
}
