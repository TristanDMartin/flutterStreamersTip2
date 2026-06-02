/// Tunable playback pool eviction and preload policy (shared by
/// [GlobalPlaybackManager]).
class PlaybackPoolPolicy {
  const PlaybackPoolPolicy._();

  /// Soft cooldown before hard controller disposal.
  static const int cooldownSeconds = 1;

  /// Minimum age before a registered controller is eligible for disposal.
  static const int disposalEligibilityTtlSeconds = 2;

  static Duration get cooldownDuration =>
      const Duration(seconds: cooldownSeconds);

  static Duration get disposalEligibilityTtl =>
      const Duration(seconds: disposalEligibilityTtlSeconds);
}
