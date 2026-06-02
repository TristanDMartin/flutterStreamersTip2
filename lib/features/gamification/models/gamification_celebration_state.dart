/// Server-driven celebration flags from `users/{uid}/gamification/state`.
class GamificationCelebrationState {
  const GamificationCelebrationState({
    required this.showLevelUpModal,
    required this.level,
    required this.previousLevel,
    this.leveledUpAt,
  });

  final bool showLevelUpModal;
  final int level;
  final int previousLevel;
  final DateTime? leveledUpAt;

  factory GamificationCelebrationState.fromFirestoreMap(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null || raw['showLevelUpModal'] != true) {
      return const GamificationCelebrationState(
        showLevelUpModal: false,
        level: 1,
        previousLevel: 1,
      );
    }
    return GamificationCelebrationState(
      showLevelUpModal: true,
      level: _readInt(raw['level']) ?? 1,
      previousLevel: _readInt(raw['previousLevel']) ?? 1,
      leveledUpAt: _readDate(raw['leveledUpAt']),
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic ts = value;
      if (ts != null && ts.runtimeType.toString().contains('Timestamp')) {
        return (ts as dynamic).toDate() as DateTime;
      }
    } catch (_) {}
    return null;
  }
}
