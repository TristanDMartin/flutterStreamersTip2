abstract final class OnboardingV1Constants {
  static const int version = 1;
  static const int totalSteps = 4;
  static const int completedStepMarker = 999;
  static const int personalizeRewardXp = 50;
  static const int creatorCardRewardXp = 100;
  static const int levelOneUnlockRewardXp = 500;
  static const int maxOnboardingXp =
      personalizeRewardXp + creatorCardRewardXp + levelOneUnlockRewardXp;

  static int earnedXpForDisplayStep(int displayStep) {
    if (displayStep >= 4) {
      return personalizeRewardXp + creatorCardRewardXp;
    }
    if (displayStep >= 3) {
      return personalizeRewardXp;
    }
    return 0;
  }
}

abstract final class OnboardingStatus {
  static const String notStarted = 'not_started';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
}

abstract final class OnboardingCreatorGoals {
  static const List<String> all = <String>[
    'growth',
    'monetization',
    'ai_assistance',
    'networking',
    'content_creation',
    'streaming',
  ];

  static const Map<String, String> labels = <String, String>{
    'streaming': 'Find community',
    'content_creation': 'Plan my content',
    'growth': 'Grow my audience',
    'networking': 'Connect with creators',
    'ai_assistance': 'Get AI coaching',
    'monetization': 'Monetize',
  };

  static const Map<String, String> emojis = <String, String>{
    'streaming': '🌍',
    'content_creation': '📅',
    'growth': '📈',
    'networking': '🤝',
    'ai_assistance': '🤖',
    'monetization': '💸',
  };
}

abstract final class OnboardingPlatforms {
  static const List<String> all = <String>[
    'twitch',
    'youtube',
    'tiktok',
    'kick',
    'instagram',
    'facebook_gaming',
  ];

  static const Map<String, String> labels = <String, String>{
    'twitch': 'Twitch',
    'youtube': 'YouTube',
    'tiktok': 'TikTok',
    'kick': 'Kick',
    'instagram': 'Instagram',
    'facebook_gaming': 'Facebook Gaming',
  };

  static const Map<String, String> emojis = <String, String>{
    'twitch': '🟣',
    'youtube': '🔴',
    'tiktok': '🎵',
    'kick': '🟢',
    'instagram': '📸',
    'facebook_gaming': '🔵',
  };

  /// Maps onboarding platform ids to [BrandIcon] keys.
  static String brandIconPlatformKey(String platformId) {
    switch (platformId) {
      case 'facebook_gaming':
        return 'facebook';
      default:
        return platformId;
    }
  }
}

abstract final class OnboardingLevelOneMissions {
  static const List<({String id, String title, String emoji})> starterMissions =
      <({String id, String title, String emoji})>[
    (id: 'creator_card', title: 'Complete Creator Card', emoji: '🪪'),
    (id: 'upload_clip', title: 'Upload Your First Clip', emoji: '📤'),
    (id: 'ask_tippy', title: 'Ask Tippy a Question', emoji: '🤖'),
    (id: 'follow_creators', title: 'Follow 3 Creators', emoji: '👥'),
  ];

  static const Map<String, int> xpRewards = <String, int>{
    'creator_card': 100,
    'upload_clip': 200,
    'ask_tippy': 100,
    'follow_creators': 75,
  };

  static int xpFor(String missionId) => xpRewards[missionId] ?? 0;

  static bool isMissionComplete({
    required String missionId,
    required bool creatorCardCompleted,
    Iterable<String> completedMissionKeys = const <String>[],
  }) {
    if (missionId == 'creator_card') {
      return creatorCardCompleted;
    }
    for (final String key in completedMissionKeys) {
      if (key.contains(missionId)) {
        return true;
      }
    }
    return false;
  }
}

abstract final class OnboardingCreatorCategories {
  static const List<String> ids = <String>[
    'gaming',
    'just-chatting',
    'music',
    'art',
    'tech',
    'fitness',
    'tutorials',
    'irl',
    'general',
  ];
}
