import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_feed_index_tracker.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('PlaybackFeedIndexTracker', () {
    test('syncMapping replaces stale index and reverse mappings', () {
      final PlaybackFeedIndexTracker tracker = PlaybackFeedIndexTracker();
      final List<String> clearedFocus = <String>[];

      tracker.syncMapping(
        index: 0,
        videoId: 'video-a',
        onClearStaleFocus: clearedFocus.add,
      );
      tracker.syncMapping(
        index: 0,
        videoId: 'video-b',
        onClearStaleFocus: clearedFocus.add,
      );
      tracker.syncMapping(
        index: 2,
        videoId: 'video-a',
        onClearStaleFocus: clearedFocus.add,
      );

      expect(tracker.videoIdAt(0), 'video-b');
      expect(tracker.videoIdAt(2), 'video-a');
      expect(tracker.videoIdToIndex['video-a'], 2);
      expect(clearedFocus, <String>['video-a']);
    });

    test('savePositionForIndex stores initialized controller position', () {
      final PlaybackFeedIndexTracker tracker = PlaybackFeedIndexTracker();
      tracker.syncMapping(index: 1, videoId: 'video-a');
      tracker.currentFeedIndex = 1;

      tracker.savePositionForIndex(
        index: 1,
        resolveController: (_) => _FakeController(isInitialized: true),
        isControllerSafe: (_, __) => true,
      );

      expect(tracker.lastPositionAt(1), const Duration(seconds: 5));
    });

    test('savePositionForIndex clamps near-end position to zero', () {
      final PlaybackFeedIndexTracker tracker = PlaybackFeedIndexTracker();
      tracker.syncMapping(index: 0, videoId: 'video-a');

      tracker.savePositionForIndex(
        index: 0,
        resolveController: (_) => _FakeController(
          isInitialized: true,
          playbackPosition: const Duration(seconds: 29, milliseconds: 700),
        ),
        isControllerSafe: (_, __) => true,
      );

      expect(tracker.lastPositionAt(0), Duration.zero);
    });

    test('clear resets all mappings', () {
      final PlaybackFeedIndexTracker tracker = PlaybackFeedIndexTracker();
      tracker.syncMapping(index: 0, videoId: 'video-a');
      tracker.currentFeedIndex = 0;
      tracker.lastKnownPositions[0] = const Duration(seconds: 1);

      tracker.clear();

      expect(tracker.currentFeedIndex, isNull);
      expect(tracker.indexToVideoId, isEmpty);
      expect(tracker.videoIdToIndex, isEmpty);
      expect(tracker.lastKnownPositions, isEmpty);
    });
  });
}

class _FakeController extends Fake implements VideoPlayerController {
  _FakeController({
    required this.isInitialized,
    this.playbackPosition = const Duration(seconds: 5),
  });

  final bool isInitialized;
  final Duration playbackPosition;

  @override
  VideoPlayerValue get value => VideoPlayerValue(
        duration: const Duration(seconds: 30),
        position: playbackPosition,
        isInitialized: isInitialized,
      );
}
