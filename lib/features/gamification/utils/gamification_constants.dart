/// Display-only helpers aligned with
/// `cloud_functions/src/gamification/level_table.js`.
/// Server remains source of truth for awarded XP and levels.
class GamificationLevelRow {
  const GamificationLevelRow({
    required this.level,
    required this.title,
    required this.xpRequired,
  });

  final int level;
  final String title;
  final int xpRequired;
}

class GamificationConstants {
  GamificationConstants._();

  /// Canonical sparse level table (same order / thresholds as backend).
  static const List<GamificationLevelRow> levels = <GamificationLevelRow>[
    GamificationLevelRow(level: 1, title: 'New Creator', xpRequired: 0),
    GamificationLevelRow(level: 2, title: 'Getting Started', xpRequired: 100),
    GamificationLevelRow(level: 3, title: 'Clip Builder', xpRequired: 250),
    GamificationLevelRow(level: 4, title: 'Consistent Creator', xpRequired: 500),
    GamificationLevelRow(level: 5, title: 'Rising Creator', xpRequired: 900),
    GamificationLevelRow(level: 10, title: 'Growth Creator', xpRequired: 2500),
    GamificationLevelRow(
      level: 20,
      title: 'Partner-Level Creator',
      xpRequired: 8000,
    ),
    GamificationLevelRow(level: 30, title: 'Elite Creator', xpRequired: 18000),
    GamificationLevelRow(level: 40, title: 'Platform Leader', xpRequired: 35000),
    GamificationLevelRow(
      level: 50,
      title: 'StreamersTip Legend',
      xpRequired: 60000,
    ),
  ];

  static const List<String> levelRewardHints = <String>[
    'Welcome to StreamersTip',
    'Profile basics unlocked',
    'Clip posting boost',
    'Consistency badge',
    'Rising creator flair',
    'Growth insights',
    'Partner-level insights',
    'Elite creator flair',
    'Platform leader title card',
    'StreamersTip legend crown',
  ];

  static int maxConfiguredLevel() => levels.last.level;

  static int levelFromTotalXp(int totalXp) {
    final int xp = totalXp < 0 ? 0 : totalXp;
    int level = levels.first.level;
    for (final GamificationLevelRow row in levels) {
      if (xp >= row.xpRequired) {
        level = row.level;
      }
    }
    return level;
  }

  static String rankTitleForLevel(int level) {
    final int lv = level < 1 ? 1 : level;
    GamificationLevelRow row = levels.first;
    for (final GamificationLevelRow candidate in levels) {
      if (candidate.level <= lv) {
        row = candidate;
      }
    }
    return row.title;
  }

  static int xpFloorForLevel(int level) {
    final int lv = level < 1 ? 1 : level;
    int floor = 0;
    for (final GamificationLevelRow row in levels) {
      if (row.level <= lv) {
        floor = row.xpRequired;
      }
    }
    return floor;
  }

  static int xpCeilingForLevel(int level) {
    final int lv = level < 1 ? 1 : level;
    for (final GamificationLevelRow row in levels) {
      if (row.level > lv) {
        return row.xpRequired;
      }
    }
    return levels.last.xpRequired + 1000;
  }

  /// XP span from current level floor to next level floor.
  static int xpSpanIntoNextLevel(int level) {
    final int floor = xpFloorForLevel(level);
    final int ceiling = xpCeilingForLevel(level);
    final int span = ceiling - floor;
    return span <= 0 ? 1 : span;
  }

  static double progressInLevel(int level, int totalXp) {
    final int floor = xpFloorForLevel(level);
    final int span = xpSpanIntoNextLevel(level);
    final int into = (totalXp - floor).clamp(0, span);
    return into / span;
  }

  static String rewardLabelForLevel(int level) {
    final int lv = level < 1 ? 1 : level;
    int index = 0;
    for (int i = 0; i < levels.length; i++) {
      if (levels[i].level <= lv) {
        index = i;
      }
    }
    if (index >= 0 && index < levelRewardHints.length) {
      return levelRewardHints[index];
    }
    return levelRewardHints.last;
  }
}
