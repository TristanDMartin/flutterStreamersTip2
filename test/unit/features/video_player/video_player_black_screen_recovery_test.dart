import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/video_player/widgets/video_player_black_screen_recovery.dart';

void main() {
  group('VideoPlayerBlackScreenRecovery', () {
    const VideoPlayerBlackScreenRecovery recovery =
        VideoPlayerBlackScreenRecovery();

    test('evaluate returns none when first frame already seen', () {
      final VideoPlayerBlackScreenRecoveryState state =
          VideoPlayerBlackScreenRecoveryState();

      final VideoPlayerBlackScreenRecoveryAction action = recovery.evaluate(
        state: state,
        isCurrentVideo: true,
        hasSeenFirstFrame: true,
        isPlaying: true,
        positionAdvancing: true,
        now: DateTime.now(),
      );

      expect(action, VideoPlayerBlackScreenRecoveryAction.none);
      expect(state.attempts, 0);
    });

    test('evaluate escalates through recovery tiers', () {
      final VideoPlayerBlackScreenRecoveryState state =
          VideoPlayerBlackScreenRecoveryState();
      final DateTime now = DateTime(2026, 1, 1, 12);

      expect(
        recovery.evaluate(
          state: state,
          isCurrentVideo: true,
          hasSeenFirstFrame: false,
          isPlaying: true,
          positionAdvancing: true,
          now: now,
        ),
        VideoPlayerBlackScreenRecoveryAction.tier1Rebuild,
      );
      expect(
        recovery.evaluate(
          state: state,
          isCurrentVideo: true,
          hasSeenFirstFrame: false,
          isPlaying: true,
          positionAdvancing: true,
          now: now.add(const Duration(seconds: 2)),
        ),
        VideoPlayerBlackScreenRecoveryAction.tier2Remount,
      );
      expect(
        recovery.evaluate(
          state: state,
          isCurrentVideo: true,
          hasSeenFirstFrame: false,
          isPlaying: true,
          positionAdvancing: true,
          now: now.add(const Duration(seconds: 4)),
        ),
        VideoPlayerBlackScreenRecoveryAction.tier3Recreate,
      );
      expect(
        recovery.evaluate(
          state: state,
          isCurrentVideo: true,
          hasSeenFirstFrame: false,
          isPlaying: true,
          positionAdvancing: true,
          now: now.add(const Duration(seconds: 6)),
        ),
        VideoPlayerBlackScreenRecoveryAction.giveUp,
      );
    });
  });
}
