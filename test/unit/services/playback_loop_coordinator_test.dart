import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_loop_coordinator.dart';

void main() {
  group('PlaybackLoopCoordinator', () {
    test('clampResumePosition returns zero when within last 500ms', () {
      const Duration duration = Duration(seconds: 10);
      expect(
        PlaybackLoopCoordinator.clampResumePosition(
          const Duration(seconds: 9, milliseconds: 600),
          duration,
        ),
        Duration.zero,
      );
      expect(
        PlaybackLoopCoordinator.clampResumePosition(
          const Duration(seconds: 5),
          duration,
        ),
        const Duration(seconds: 5),
      );
    });

    test('isNearEndPosition detects tail window', () {
      const Duration duration = Duration(seconds: 30);
      expect(
        PlaybackLoopCoordinator.isNearEndPosition(
          const Duration(seconds: 29, milliseconds: 600),
          duration,
        ),
        isTrue,
      );
      expect(
        PlaybackLoopCoordinator.isNearEndPosition(
          const Duration(seconds: 20),
          duration,
        ),
        isFalse,
      );
    });

    test('isFeedLoopOwner accepts home and home sub-owners only', () {
      expect(PlaybackLoopCoordinator.isFeedLoopOwner('home'), isTrue);
      expect(PlaybackLoopCoordinator.isFeedLoopOwner('home/forYou'), isTrue);
      expect(PlaybackLoopCoordinator.isFeedLoopOwner('network'), isFalse);
      expect(PlaybackLoopCoordinator.isFeedLoopOwner(null), isFalse);
    });
  });
}
