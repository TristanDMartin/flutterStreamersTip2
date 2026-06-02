import 'package:video_player/video_player.dart';

/// Session-local black screen recovery counters.
class VideoPlayerBlackScreenRecoveryState {
  int attempts = 0;
  DateTime? lastRecoveryAt;
}

enum VideoPlayerBlackScreenRecoveryAction {
  none,
  tier1Rebuild,
  tier2Remount,
  tier3Recreate,
  giveUp,
}

/// Decides which black-screen recovery tier to run after first-frame timeout.
class VideoPlayerBlackScreenRecovery {
  const VideoPlayerBlackScreenRecovery({
    this.maxAttempts = 3,
    this.cooldown = const Duration(milliseconds: 1500),
  });

  final int maxAttempts;
  final Duration cooldown;

  VideoPlayerBlackScreenRecoveryAction evaluate({
    required VideoPlayerBlackScreenRecoveryState state,
    required bool isCurrentVideo,
    required bool hasSeenFirstFrame,
    required bool isPlaying,
    required bool positionAdvancing,
    required DateTime now,
  }) {
    if (!isCurrentVideo) {
      return VideoPlayerBlackScreenRecoveryAction.none;
    }
    if (hasSeenFirstFrame) {
      return VideoPlayerBlackScreenRecoveryAction.none;
    }
    if (!isPlaying && !positionAdvancing) {
      return VideoPlayerBlackScreenRecoveryAction.none;
    }
    if (state.lastRecoveryAt != null &&
        now.difference(state.lastRecoveryAt!) < cooldown) {
      return VideoPlayerBlackScreenRecoveryAction.none;
    }
    if (state.attempts >= maxAttempts) {
      return VideoPlayerBlackScreenRecoveryAction.giveUp;
    }
    state.attempts++;
    state.lastRecoveryAt = now;
    switch (state.attempts) {
      case 1:
        return VideoPlayerBlackScreenRecoveryAction.tier1Rebuild;
      case 2:
        return VideoPlayerBlackScreenRecoveryAction.tier2Remount;
      default:
        return VideoPlayerBlackScreenRecoveryAction.tier3Recreate;
    }
  }

  void resetForControllerChange(VideoPlayerBlackScreenRecoveryState state) {
    state.attempts = 0;
    state.lastRecoveryAt = null;
  }

  void resetForTier3Retry(VideoPlayerBlackScreenRecoveryState state) {
    state.attempts = 0;
    state.lastRecoveryAt = null;
  }

  bool shouldRecheckAfterRecovery({
    required bool hasSeenFirstFrame,
    required bool isCurrentVideo,
  }) {
    return isCurrentVideo && !hasSeenFirstFrame;
  }

  bool hasRenderableFrame(VideoPlayerValue value) {
    return value.size.width > 0 && value.size.height > 0;
  }

  bool tryConsumeRecoverySlot({
    required VideoPlayerBlackScreenRecoveryState state,
    required DateTime now,
    Duration throttle = const Duration(seconds: 6),
  }) {
    if (state.lastRecoveryAt != null &&
        now.difference(state.lastRecoveryAt!) < throttle) {
      return false;
    }
    state.lastRecoveryAt = now;
    return true;
  }
}
