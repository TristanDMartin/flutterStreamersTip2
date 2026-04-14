/// Display-only helpers aligned with shared StreamersTip gamification rules.
/// Server remains source of truth for awarded XP and levels.
class GamificationConstants {
  GamificationConstants._();

  /// Minimum cumulative XP to reach each level (index 0 = level 1).
  static const List<int> cumulativeXpForLevel = <int>[
    0,
    100,
    250,
    450,
    700,
    1000,
    1350,
    1750,
    2200,
    2700,
    3300,
    4000,
    4800,
    5700,
    6700,
  ];

  static int maxConfiguredLevel() => cumulativeXpForLevel.length;

  static String rankTitleForLevel(int level) {
    if (level <= 2) return 'New Creator';
    if (level <= 4) return 'Active Creator';
    if (level <= 6) return 'Rising Creator';
    if (level <= 8) return 'Consistent Creator';
    if (level <= 10) return 'Community Builder';
    if (level <= 12) return 'Growth Creator';
    if (level <= 14) return 'Pro Creator';
    return 'Elite Creator';
  }

  /// Minimum XP for [level] (1-based). Clamped to table.
  static int xpFloorForLevel(int level) {
    final int idx = (level - 1).clamp(0, cumulativeXpForLevel.length - 1);
    return cumulativeXpForLevel[idx];
  }

  /// XP span from current level floor to next level floor.
  static int xpSpanIntoNextLevel(int level) {
    final int floor = xpFloorForLevel(level);
    final int nextFloor = level < cumulativeXpForLevel.length
        ? cumulativeXpForLevel[level]
        : floor + 1000;
    final int span = nextFloor - floor;
    return span <= 0 ? 1 : span;
  }

  static double progressInLevel(int level, int totalXp) {
    final int floor = xpFloorForLevel(level);
    final int nextFloor = level < cumulativeXpForLevel.length
        ? cumulativeXpForLevel[level]
        : floor + 1000;
    final int span = nextFloor - floor;
    if (span <= 0) return 0;
    return ((totalXp - floor) / span).clamp(0.0, 1.0);
  }
}
