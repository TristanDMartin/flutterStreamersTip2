import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_preload_order.dart';

void main() {
  group('computePlaybackPreloadIndices', () {
    test('forward bias with radius 2 visits next two before previous', () {
      final List<int> actual = computePlaybackPreloadIndices(
        index: 5,
        videoCount: 10,
        direction: 1,
        backwardRadius: 1,
        forwardRadius: 2,
      );
      expect(actual, <int>[5, 6, 7, 4]);
    });

    test('backward bias visits previous before next', () {
      final List<int> actual = computePlaybackPreloadIndices(
        index: 5,
        videoCount: 10,
        direction: -1,
        backwardRadius: 1,
        forwardRadius: 1,
      );
      expect(actual, <int>[5, 4, 6]);
    });

    test('clamps at list bounds', () {
      final List<int> actual = computePlaybackPreloadIndices(
        index: 0,
        videoCount: 3,
        direction: 1,
        backwardRadius: 2,
        forwardRadius: 2,
      );
      expect(actual, <int>[0, 1, 2]);
    });
  });

  group('PlaybackPreloadBurstGuard', () {
    test('allows first request', () {
      final PlaybackPreloadBurstGuard guard = PlaybackPreloadBurstGuard();
      final bool actual = guard.shouldSkipDuplicateBurst(
        index: 0,
        centerVideoId: 'v1',
        now: DateTime(2026, 1, 1, 12),
      );
      expect(actual, isFalse);
    });

    test('skips duplicate within burst window', () {
      final PlaybackPreloadBurstGuard guard = PlaybackPreloadBurstGuard();
      final DateTime t0 = DateTime(2026, 1, 1, 12, 0, 0);
      guard.recordRequest(index: 0, centerVideoId: 'v1', now: t0);
      final bool actual = guard.shouldSkipDuplicateBurst(
        index: 0,
        centerVideoId: 'v1',
        now: t0.add(const Duration(milliseconds: 50)),
      );
      expect(actual, isTrue);
    });

    test('allows after burst window', () {
      final PlaybackPreloadBurstGuard guard = PlaybackPreloadBurstGuard();
      final DateTime t0 = DateTime(2026, 1, 1, 12, 0, 0);
      guard.recordRequest(index: 0, centerVideoId: 'v1', now: t0);
      final bool actual = guard.shouldSkipDuplicateBurst(
        index: 0,
        centerVideoId: 'v1',
        now: t0.add(const Duration(milliseconds: 200)),
      );
      expect(actual, isFalse);
    });
  });
}
