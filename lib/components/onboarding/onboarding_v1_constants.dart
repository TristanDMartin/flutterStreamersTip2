abstract final class OnboardingV1Constants {
  static const int version = 1;
  static const int totalSteps = 5;
  static const int completedStepMarker = 999;
  static const int creatorCardRewardXp = 100;
  static const int levelOneUnlockRewardXp = 500;
}

abstract final class OnboardingStatus {
  static const String notStarted = 'not_started';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
}

abstract final class OnboardingCreatorGoals {
  static const List<String> all = <String>[
    'streaming',
    'content_creation',
    'growth',
    'networking',
    'ai_assistance',
    'monetization',
  ];

  static const Map<String, String> labels = <String, String>{
    'streaming': 'Streaming',
    'content_creation': 'Content Creation',
    'growth': 'Growth',
    'networking': 'Networking',
    'ai_assistance': 'AI Assistance',
    'monetization': 'Monetization',
  };

  static const Map<String, String> emojis = <String, String>{
    'streaming': '🎮',
    'content_creation': '🎬',
    'growth': '📈',
    'networking': '🤝',
    'ai_assistance': '✨',
    'monetization': '💰',
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
}

abstract final class OnboardingLevelOneMissions {
  static const List<({String title, String emoji})> starterMissions =
      <({String title, String emoji})>[
    (title: 'Complete Creator Card', emoji: '🪪'),
    (title: 'Upload First Clip', emoji: '📤'),
    (title: 'Follow 3 Creators', emoji: '👥'),
    (title: 'Ask Tippy A Question', emoji: '🤖'),
    (title: 'Create First Content Plan', emoji: '📅'),
  ];
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
