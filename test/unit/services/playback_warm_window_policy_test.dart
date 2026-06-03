import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_warm_window_policy.dart';
import 'package:streamers_tip/services/playback_preload_order.dart';

void main() {
  group('PlaybackWarmWindowPolicy', () {
    test('forward scroll keeps current + next + next+1', () {
      final ({int backward, int forward}) radii =
          PlaybackWarmWindowPolicy.radiiForDirection(1);
      expect(radii.backward, 0);
      expect(radii.forward, 2);

      final List<int> indices = computePlaybackPreloadIndices(
        index: 0,
        videoCount: 5,
        direction: 1,
        backwardRadius: radii.backward,
        forwardRadius: radii.forward,
      );
      expect(indices, <int>[0, 1, 2]);
    });

    test('backward scroll keeps current + previous + previous-1', () {
      final ({int backward, int forward}) radii =
          PlaybackWarmWindowPolicy.radiiForDirection(-1);
      expect(radii.backward, 2);
      expect(radii.forward, 0);

      final List<int> indices = computePlaybackPreloadIndices(
        index: 4,
        videoCount: 5,
        direction: -1,
        backwardRadius: radii.backward,
        forwardRadius: radii.forward,
      );
      expect(indices, <int>[4, 3, 2]);
    });

    test('isOutsideWarmWindow respects asymmetric radii', () {
      expect(
        PlaybackWarmWindowPolicy.isOutsideWarmWindow(
          videoIndex: 0,
          currentIndex: 2,
          direction: 1,
        ),
        isTrue,
      );
      expect(
        PlaybackWarmWindowPolicy.isOutsideWarmWindow(
          videoIndex: 3,
          currentIndex: 2,
          direction: 1,
        ),
        isFalse,
      );
    });

    test('forward warm slot at current+2 is inside window at index 0', () {
      expect(
        PlaybackWarmWindowPolicy.isOutsideWarmWindow(
          videoIndex: 2,
          currentIndex: 0,
          direction: 1,
        ),
        isFalse,
      );
      expect((2 - 0).abs() > 1, isTrue);
    });
  });
}
