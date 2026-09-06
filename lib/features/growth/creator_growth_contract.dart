/// Canonical Creator Growth contract — mirrors website
/// `types/creatorGrowthContract.ts` and `contracts/creator-growth.v1.json`.
/// Flutter displays server values. It must not compute Score / XP / Level / Streak.
abstract final class CreatorGrowthContract {
  static const String id = 'creator-growth.v1';
  static const int schemaVersion = 1;
  static const String entitlementsApi = '/api/user/entitlements';
  static const String trackApi = '/api/track';
  static const String weeklyReportApi = '/api/reports/weekly';
  static const String creatorScoreCurrentPath =
      'users/{uid}/creatorScore/current';
  static const String creatorMemoryPath = 'users/{uid}/creatorMemory/main';
  static const String tippyBrainPath = 'users/{uid}/creatorMemory/main';
  static const String gamificationStatePath = 'users/{uid}/gamification/state';
  static const String achievementsPath =
      'users/{uid}/gamificationAchievements/{key}';
  static const String achievementAcknowledgeApi =
      '/gamification/achievements/{key}/acknowledge';
  static const String missionsPath =
      'users/{uid}/gamificationMissions/{missionId}';
  static const List<String> forbiddenTopLevelCollections = <String>[
    'creatorProfiles',
    'creatorGrowth',
    'creatorScores',
    'creatorMissions',
    'creatorAchievements',
    'creatorReferrals',
    'growthReports',
    'creatorActivity',
  ];
  static const List<String> canonicalProductEvents = <String>[
    'onboarding_started',
    'onboarding_completed',
    'creator_profile_completed',
    'tippy_checkup_started',
    'tippy_checkup_completed',
    'growth_plan_created',
    'mission_started',
    'mission_completed',
    'creator_score_viewed',
    'creator_score_shared',
    'profile_shared',
    'referral_sent',
    'referral_accepted',
    'weekly_report_opened',
    'paywall_viewed',
    'upgrade_started',
    'subscription_started',
  ];
  static const Map<String, String> productEventAliases = <String, String>{
    'tippy_onboarding_started': 'onboarding_started',
    'tippy_onboarding_completed': 'onboarding_completed',
    'content_plan_created': 'growth_plan_created',
    'growth_report_viewed': 'weekly_report_opened',
    'upgrade_modal_viewed': 'paywall_viewed',
  };

  static bool isForbiddenTopLevelCollection(String name) {
    return forbiddenTopLevelCollections.contains(name);
  }

  static String canonicalizeProductEventName(String name) {
    return productEventAliases[name] ?? name;
  }

  static bool isCanonicalProductEvent(String name) {
    final String canonical = canonicalizeProductEventName(name);
    return canonicalProductEvents.contains(canonical);
  }
}
