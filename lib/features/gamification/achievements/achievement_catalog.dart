import 'achievement_definition.dart';

/// Canonical launch catalog from `contracts/achievements.v1.json`.
abstract final class AchievementCatalog {
  static const String contractId = "achievements.v1";
  static const int schemaVersion = 1;
  static const int maxLevel = 15;
  static const String unlockPath = "users/{uid}/gamificationAchievements/{key}";
  static const String legacyDoNotWritePath = "users/{uid}/achievements/{key}";
  static const Map<String, String> readAliases = <String, String>{
  'seven_day_streak': 'streak_7',
  'ten_posts': 'posts_10',
  'profile_completed': 'profile_complete',
  'first_platform_connected': 'first_platform',
  'first_crosspost': 'first_cross_post',
  'platforms_3_connected': 'platforms_3',
  'first_steps': 'onboarding_done',
  'first_lesson_completed': 'first_lesson',
  };
  static const List<String> launchKeys = <String>[
  'onboarding_done',
  'profile_complete',
  'first_platform',
  'platforms_3',
  'first_video',
  'posts_10',
  'posts_50',
  'posts_100',
  'first_plan',
  'first_scheduled_post',
  'first_cross_post',
  'streak_3',
  'streak_7',
  'streak_30',
  'first_mission_complete',
  'missions_10',
  'first_comment',
  'comments_25',
  'first_follower',
  'level_5',
  'level_10',
  'level_15',
  ];
  static const List<AchievementDefinition> launchDefinitions =
      <AchievementDefinition>[
  AchievementDefinition(
    key: 'onboarding_done',
    title: "First Steps",
    description: "Complete Tippy onboarding.",
    family: AchievementFamily.getting_started,
    rarity: AchievementRarity.common,
    iconName: 'sparkles',
    iconEmoji: "🎯",
    xpReward: 0,
  ),
  AchievementDefinition(
    key: 'profile_complete',
    title: "Profile Complete",
    description: "Finish setting up your creator profile.",
    family: AchievementFamily.getting_started,
    rarity: AchievementRarity.common,
    iconName: 'sparkles',
    iconEmoji: "✨",
    xpReward: 0,
  ),
  AchievementDefinition(
    key: 'first_platform',
    title: "First Platform Connected",
    description: "Connect your first streaming platform.",
    family: AchievementFamily.getting_started,
    rarity: AchievementRarity.common,
    iconName: 'plug',
    iconEmoji: "🔌",
    xpReward: 0,
  ),
  AchievementDefinition(
    key: 'platforms_3',
    title: "3 Platforms Connected",
    description: "Connect three platforms.",
    family: AchievementFamily.getting_started,
    rarity: AchievementRarity.rare,
    iconName: 'plug',
    iconEmoji: "📡",
    xpReward: 50,
  ),
  AchievementDefinition(
    key: 'first_video',
    title: "First Video",
    description: "You published your first video on StreamersTip.",
    family: AchievementFamily.publishing,
    rarity: AchievementRarity.common,
    iconName: 'play',
    iconEmoji: "🎬",
    xpReward: 15,
  ),
  AchievementDefinition(
    key: 'posts_10',
    title: "10 Posts",
    description: "Publish 10 posts or threads.",
    family: AchievementFamily.publishing,
    rarity: AchievementRarity.rare,
    iconName: 'upload',
    iconEmoji: "📊",
    xpReward: 25,
  ),
  AchievementDefinition(
    key: 'posts_50',
    title: "50 Posts",
    description: "Publish 50 posts or threads.",
    family: AchievementFamily.publishing,
    rarity: AchievementRarity.epic,
    iconName: 'upload',
    iconEmoji: "🚀",
    xpReward: 75,
  ),
  AchievementDefinition(
    key: 'posts_100',
    title: "100 Posts",
    description: "Publish 100 posts or threads.",
    family: AchievementFamily.publishing,
    rarity: AchievementRarity.epic,
    iconName: 'upload',
    iconEmoji: "💯",
    xpReward: 100,
  ),
  AchievementDefinition(
    key: 'first_plan',
    title: "First Content Plan",
    description: "Create your first content plan.",
    family: AchievementFamily.publishing,
    rarity: AchievementRarity.common,
    iconName: 'calendar',
    iconEmoji: "📅",
    xpReward: 10,
  ),
  AchievementDefinition(
    key: 'first_scheduled_post',
    title: "First Scheduled Post",
    description: "Schedule your first post.",
    family: AchievementFamily.publishing,
    rarity: AchievementRarity.common,
    iconName: 'calendar',
    iconEmoji: "🗓️",
    xpReward: 10,
  ),
  AchievementDefinition(
    key: 'first_cross_post',
    title: "First Crosspost",
    description: "Cross-post for the first time.",
    family: AchievementFamily.publishing,
    rarity: AchievementRarity.common,
    iconName: 'upload',
    iconEmoji: "🌐",
    xpReward: 10,
  ),
  AchievementDefinition(
    key: 'streak_3',
    title: "3-Day Streak",
    description: "Stay active for 3 days in a row.",
    family: AchievementFamily.consistency,
    rarity: AchievementRarity.common,
    iconName: 'zap',
    iconEmoji: "🔥",
    xpReward: 0,
  ),
  AchievementDefinition(
    key: 'streak_7',
    title: "7-Day Streak",
    description: "Stay active for 7 days in a row.",
    family: AchievementFamily.consistency,
    rarity: AchievementRarity.rare,
    iconName: 'zap',
    iconEmoji: "🔥",
    xpReward: 0,
  ),
  AchievementDefinition(
    key: 'streak_30',
    title: "30-Day Streak",
    description: "Stay active for 30 days in a row.",
    family: AchievementFamily.consistency,
    rarity: AchievementRarity.epic,
    iconName: 'zap',
    iconEmoji: "💎",
    xpReward: 0,
  ),
  AchievementDefinition(
    key: 'first_mission_complete',
    title: "First Mission",
    description: "Complete your first mission.",
    family: AchievementFamily.consistency,
    rarity: AchievementRarity.common,
    iconName: 'target',
    iconEmoji: "🎯",
    xpReward: 15,
  ),
  AchievementDefinition(
    key: 'missions_10',
    title: "10 Missions",
    description: "Complete 10 missions.",
    family: AchievementFamily.consistency,
    rarity: AchievementRarity.rare,
    iconName: 'target',
    iconEmoji: "🏅",
    xpReward: 40,
  ),
  AchievementDefinition(
    key: 'first_comment',
    title: "First Comment",
    description: "Leave your first comment.",
    family: AchievementFamily.community,
    rarity: AchievementRarity.common,
    iconName: 'message',
    iconEmoji: "💬",
    xpReward: 5,
  ),
  AchievementDefinition(
    key: 'comments_25',
    title: "Community Contributor",
    description: "Leave 25 comments.",
    family: AchievementFamily.community,
    rarity: AchievementRarity.rare,
    iconName: 'message',
    iconEmoji: "🗣️",
    xpReward: 25,
  ),
  AchievementDefinition(
    key: 'first_follower',
    title: "First Follower",
    description: "Gain your first follower.",
    family: AchievementFamily.community,
    rarity: AchievementRarity.common,
    iconName: 'users',
    iconEmoji: "👋",
    xpReward: 15,
  ),
  AchievementDefinition(
    key: 'level_5',
    title: "Level 5",
    description: "Reach level 5.",
    family: AchievementFamily.growth,
    rarity: AchievementRarity.rare,
    iconName: 'star',
    iconEmoji: "⭐",
    xpReward: 50,
  ),
  AchievementDefinition(
    key: 'level_10',
    title: "Level 10",
    description: "Reach level 10.",
    family: AchievementFamily.growth,
    rarity: AchievementRarity.epic,
    iconName: 'star',
    iconEmoji: "🌟",
    xpReward: 100,
  ),
  AchievementDefinition(
    key: 'level_15',
    title: "Level 15",
    description: "Reach level 15.",
    family: AchievementFamily.growth,
    rarity: AchievementRarity.epic,
    iconName: 'star',
    iconEmoji: "👑",
    xpReward: 250,
  ),
      ];
  static final Map<String, AchievementDefinition> byKey =
      <String, AchievementDefinition>{
    for (final AchievementDefinition def in launchDefinitions) def.key: def,
  };
  static String canonicalizeKey(String key) => readAliases[key] ?? key;
  static bool isLaunchKey(String key) =>
      launchKeys.contains(canonicalizeKey(key));
  static List<String> canonicalizePending(Iterable<String> raw) {
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final String item in raw) {
      final String canonical = canonicalizeKey(item);
      if (!isLaunchKey(canonical) || seen.contains(canonical)) {
        continue;
      }
      seen.add(canonical);
      out.add(canonical);
    }
    return out;
  }
  static AchievementDefinition? definitionFor(String key) =>
      byKey[canonicalizeKey(key)];
}
