import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_controller_pool.dart';
import 'package:streamers_tip/services/playback_dispose_pool_coordinator.dart';
import 'package:streamers_tip/services/playback_feed_index_tracker.dart';
import 'package:streamers_tip/services/playback_focus_coordinator.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('PlaybackDisposePoolCoordinator', () {
    const PlaybackDisposePoolCoordinator coordinator =
        PlaybackDisposePoolCoordinator();

    test('disposeAll clears pool and focus state', () {
      final PlaybackControllerPool pool = PlaybackControllerPool();
      final PlaybackFocusCoordinator focus = PlaybackFocusCoordinator();
      final PlaybackFeedIndexTracker feedIndex = PlaybackFeedIndexTracker();
      pool.recordRegister('v1', VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/v.mp4'),
      ));
      focus.publishActiveVideo('v1');
      feedIndex.currentFeedIndex = 0;
      feedIndex.syncMapping(index: 0, videoId: 'v1');
      var tabCleared = false;

      coordinator.disposeAll(
        pool: pool,
        focus: focus,
        feedIndex: feedIndex,
        muteStates: <String, bool>{},
        warmStartedAt: <String, DateTime>{},
        focusRequestedAt: <String, DateTime>{},
        firstFrameLoggedKeys: <String>{},
        clearTabPaused: () => tabCleared = true,
        isControllerSafe: (_, __) => true,
        disposeControllerAfterPause: (_, __) {},
      );

      expect(pool.length, 0);
      expect(focus.activeVideoId, isNull);
      expect(feedIndex.currentFeedIndex, isNull);
      expect(tabCleared, isTrue);
    });
  });
}
