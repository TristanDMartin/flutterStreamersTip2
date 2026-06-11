/// Asymmetric preload/eviction window for TikTok-style forward feed scrolling.
class PlaybackWarmWindowPolicy {
  const PlaybackWarmWindowPolicy._();

  /// Max controllers kept live in the global pool.
  static const int maxControllerPoolSize = 4;

  /// Forward-biased warm slots while scrolling down.
  /// Keeps previous + current + next + next+1 ready.
  static const int forwardScrollForwardRadius = 2;
  static const int forwardScrollBackwardRadius = 1;

  /// Backward-biased warm slots while scrolling up, while preserving next.
  static const int backwardScrollForwardRadius = 1;
  static const int backwardScrollBackwardRadius = 2;

  /// Neutral/startup bias — keep current + two upcoming + previous when present.
  static const int neutralForwardRadius = 2;
  static const int neutralBackwardRadius = 1;

  static ({int backward, int forward}) radiiForDirection(int direction) {
    if (direction < 0) {
      return (
        backward: backwardScrollBackwardRadius,
        forward: backwardScrollForwardRadius,
      );
    }
    return (
      backward: forwardScrollBackwardRadius,
      forward: forwardScrollForwardRadius,
    );
  }

  static bool isWithinWarmWindow({
    required int videoIndex,
    required int currentIndex,
    required int backwardRadius,
    required int forwardRadius,
  }) {
    final int delta = videoIndex - currentIndex;
    if (delta < 0) {
      return -delta <= backwardRadius;
    }
    return delta <= forwardRadius;
  }

  static bool isOutsideWarmWindow({
    required int videoIndex,
    required int currentIndex,
    required int direction,
  }) {
    final ({int backward, int forward}) radii = radiiForDirection(direction);
    return !isWithinWarmWindow(
      videoIndex: videoIndex,
      currentIndex: currentIndex,
      backwardRadius: radii.backward,
      forwardRadius: radii.forward,
    );
  }
}
