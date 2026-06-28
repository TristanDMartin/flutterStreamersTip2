import 'package:flutter/foundation.dart';

import 'device_capability_service.dart';
import 'playback_home_feed_mode.dart';

/// Tunable playback pool eviction and preload policy (shared by
/// [GlobalPlaybackManager]).
class PlaybackPoolPolicy {
  const PlaybackPoolPolicy._();

  /// Maximum live Home feed controllers: previous + current + next.
  static int get maxControllerPoolSize => _configuredMaxControllerPoolSize;

  static int _configuredMaxControllerPoolSize =
      PlaybackHomeFeedConfig.maxPoolSize;

  /// Backward warm radius around the visible index.
  static const int poolRadius = 1;

  /// Forward warm radius around the visible index.
  static const int forwardPoolRadius = 1;

  /// Backward pin radius after a swipe-up (scroll back) intent.
  static const int backwardPinRadius = 1;

  /// Expanded preload radius during fast vertical swipes.
  static const int fastSwipePreloadRadius = 1;

  /// Max simultaneous pin-set entries: previous + current + next.
  static int get maxPinnedControllers =>
      PlaybackHomeFeedConfig.maxPinnedControllers;

  /// Max simultaneous controller initializations (ExoPlayer spin-up).
  static const int maxConcurrentControllerInits = 1;

  /// Cooldown tombstones must not retain live controllers (always 0).
  static const int maxCooldownControllers = 0;

  /// Stuck init markers are cleared after this duration.
  static const int stuckInitTimeoutMs = 1500;

  static Duration get stuckInitTimeout =>
      const Duration(milliseconds: stuckInitTimeoutMs);

  /// Max queued controller creates beyond the single active init slot.
  static const int maxPendingInitRequests = 3;

  /// Tombstone duration after immediate dispose (no live controller held).
  static const int cooldownSeconds = 1;

  /// Minimum age before a registered controller is eligible for disposal.
  static const int disposalEligibilityTtlSeconds = 2;

  /// Overlap window before pausing the outgoing feed video during swipes.
  static const int transitionGraceWindowMs = 150;

  static Duration get transitionGraceWindow =>
      const Duration(milliseconds: transitionGraceWindowMs);

  static Duration get cooldownDuration =>
      const Duration(seconds: cooldownSeconds);

  static Duration get disposalEligibilityTtl =>
      const Duration(seconds: disposalEligibilityTtlSeconds);

  /// Whether cooldown entries may be hard-disposed under pool pressure.
  static bool shouldDisposeCooldownImmediately(int poolLength) {
    return poolLength > maxControllerPoolSize;
  }

  /// Whether the pool can accept one more offscreen neighbor preload.
  static bool canPreloadNeighbor({
    required int poolSize,
    required int pinnedCount,
  }) {
    return poolSize < maxControllerPoolSize &&
        pinnedCount < maxPinnedControllers;
  }

  /// Tune pool cap from device heap and home-feed rollout phase.
  static Future<void> configureForDevice() async {
    try {
      await DeviceCapabilityService.instance.isLowMemoryDevice();
      _configuredMaxControllerPoolSize = PlaybackHomeFeedConfig.maxPoolSize;
    } catch (_) {
      _configuredMaxControllerPoolSize = PlaybackHomeFeedConfig.maxPoolSize;
    }
  }

  @visibleForTesting
  static void resetConfiguredPoolSizeForTest({int size = 4}) {
    _configuredMaxControllerPoolSize = size;
  }
}
