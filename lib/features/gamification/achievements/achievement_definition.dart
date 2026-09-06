enum AchievementFamily {
  getting_started,
  publishing,
  consistency,
  community,
  growth,
}

enum AchievementRarity { common, rare, epic }

class AchievementDefinition {
  const AchievementDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.family,
    required this.rarity,
    required this.iconName,
    required this.iconEmoji,
    required this.xpReward,
  });

  final String key;
  final String title;
  final String description;
  final AchievementFamily family;
  final AchievementRarity rarity;
  final String iconName;
  final String iconEmoji;
  final int xpReward;

  String get familyLabel {
    switch (family) {
      case AchievementFamily.getting_started:
        return 'Getting Started';
      case AchievementFamily.publishing:
        return 'Publishing';
      case AchievementFamily.consistency:
        return 'Consistency';
      case AchievementFamily.community:
        return 'Community';
      case AchievementFamily.growth:
        return 'Growth';
    }
  }
}

class AchievementUnlock {
  const AchievementUnlock({
    required this.key,
    this.unlockedAt,
  });

  final String key;
  final DateTime? unlockedAt;
}

class AchievementSnapshot {
  const AchievementSnapshot({
    this.pendingKeys = const <String>[],
    this.unlocked = const <String, AchievementUnlock>{},
  });

  final List<String> pendingKeys;
  final Map<String, AchievementUnlock> unlocked;

  bool isUnlocked(String key) => unlocked.containsKey(key);

  static const AchievementSnapshot empty = AchievementSnapshot();
}
