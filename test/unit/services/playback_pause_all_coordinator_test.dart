import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_pause_all_coordinator.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('PlaybackPauseAllCoordinator', () {
    const PlaybackPauseAllCoordinator coordinator =
        PlaybackPauseAllCoordinator();

    test('pauseAll mutes every safe controller and clears playing ref', () {
      final Map<String, VideoPlayerController> pool =
          <String, VideoPlayerController>{
        'v1': VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/1.mp4'),
        ),
      };
      final Map<String, bool> muteStates = <String, bool>{};
      VideoPlayerController? playing = pool['v1'];
      final List<String> removed = <String>[];

      coordinator.pauseAll(
        controllerPool: pool,
        muteStates: muteStates,
        onControllerUnsafeRemove: removed.add,
        isControllerSafe: (_, __) => true,
        setCurrentlyPlayingController: (VideoPlayerController? c) {
          playing = c;
        },
      );

      expect(playing, isNull);
      expect(muteStates['v1'], isTrue);
      expect(removed, isEmpty);
    });
  });
}
