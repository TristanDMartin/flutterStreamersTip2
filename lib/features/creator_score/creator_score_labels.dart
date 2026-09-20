/// Creator Score performance band labels (display-only).
/// Thresholds match Worker creator-score-v2; names are not XP titles.
/// Firestore field remains `rankLabel` for compatibility.
class CreatorScoreLabels {
  CreatorScoreLabels._();

  static const String fallbackLabel = 'Getting Started';

  static const Set<String> legacyLabels = <String>{
    'New Creator',
    'Growing Creator',
    'Active Creator',
    'Rising Creator',
    'Elite Creator',
    'Emerging Creator',
  };

  static int clampScore(Object? value) {
    final int parsed = switch (value) {
      int n => n,
      num n => n.round(),
      String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
    return parsed.clamp(0, 100);
  }

  static String resolveLabel(Object? score) {
    final int n = clampScore(score);
    if (n >= 90) return 'Exceptional Performance';
    if (n >= 75) return 'High Performance';
    if (n >= 55) return 'Strong Momentum';
    if (n >= 35) return 'Building Momentum';
    return fallbackLabel;
  }

  /// Prefer score-derived label so legacy stored XP-colliding titles do not show.
  static String displayLabel({required Object? score, Object? rankLabel}) {
    final String fromScore = resolveLabel(score);
    final String stored =
        rankLabel is String ? rankLabel.trim() : '';
    if (stored.isEmpty || legacyLabels.contains(stored)) {
      return fromScore;
    }
    return fromScore;
  }
}
