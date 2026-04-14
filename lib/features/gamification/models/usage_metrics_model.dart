/// Usage meters (e.g. monthly upload quota) — values from backend only.
class UsageMetricsModel {
  final int? crossPostsUsed;
  final int? crossPostsLimit;
  final int? aiCreditsUsed;
  final int? aiCreditsLimit;

  const UsageMetricsModel({
    this.crossPostsUsed,
    this.crossPostsLimit,
    this.aiCreditsUsed,
    this.aiCreditsLimit,
  });

  factory UsageMetricsModel.fromFirestoreMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const UsageMetricsModel();
    }
    int? ri(String k) {
      final Object? v = raw[k];
      if (v is int) return v;
      if (v is double) return v.round();
      return null;
    }

    return UsageMetricsModel(
      crossPostsUsed: ri('crossPostsUsed') ?? ri('cross_posts_used'),
      crossPostsLimit: ri('crossPostsLimit') ?? ri('cross_posts_limit'),
      aiCreditsUsed: ri('aiCreditsUsed') ?? ri('ai_credits_used'),
      aiCreditsLimit: ri('aiCreditsLimit') ?? ri('ai_credits_limit'),
    );
  }
}
