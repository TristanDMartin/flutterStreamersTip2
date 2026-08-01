import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/video_player/widgets/video_player_black_screen_recovery.dart';
import 'package:video_player/video_player.dart';

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

    test(
      'evaluate returns none during cooldown without incrementing attempts',
      () {
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
        expect(state.attempts, 1);

        expect(
          recovery.evaluate(
            state: state,
            isCurrentVideo: true,
            hasSeenFirstFrame: false,
            isPlaying: true,
            positionAdvancing: true,
            now: now.add(const Duration(milliseconds: 500)),
          ),
          VideoPlayerBlackScreenRecoveryAction.none,
        );
        expect(state.attempts, 1);
      },
    );

    test('hasRenderableFrame requires non-zero size', () {
      expect(
        recovery.hasRenderableFrame(
          const VideoPlayerValue(
            duration: Duration(seconds: 1),
            size: Size.zero,
          ),
        ),
        isFalse,
      );
      expect(
        recovery.hasRenderableFrame(
          const VideoPlayerValue(
            duration: Duration(seconds: 1),
            size: Size(1080, 1920),
          ),
        ),
        isTrue,
      );
    });
  });
}
