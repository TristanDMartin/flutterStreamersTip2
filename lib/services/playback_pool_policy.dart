/// Tunable playback pool eviction and preload policy (shared by
/// [GlobalPlaybackManager]).
class PlaybackPoolPolicy {
  const PlaybackPoolPolicy._();

  /// Maximum live controllers in the global pool.
  ///
  /// Forward feed scrolling keeps previous + current + two upcoming videos warm.
  static const int maxControllerPoolSize = 4;

  /// Legacy symmetric radius (prefer [PlaybackWarmWindowPolicy] for feed scroll).
  static const int poolRadius = 1;

  /// Soft cooldown before hard controller disposal.
  static const int cooldownSeconds = 1;

  /// Minimum age before a registered controller is eligible for disposal.
  static const int disposalEligibilityTtlSeconds = 2;

  static Duration get cooldownDuration =>
      const Duration(seconds: cooldownSeconds);

  static Duration get disposalEligibilityTtl =>
      const Duration(seconds: disposalEligibilityTtlSeconds);
}
