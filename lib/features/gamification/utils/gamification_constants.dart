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
    7800,
    9000,
    10300,
    11700,
    13200,
    14800,
    16500,
    18300,
    20200,
    22200,
    24300,
    26500,
    28800,
    31200,
    33700,
    36300,
    39000,
    41800,
    44700,
    47700,
    50800,
    54000,
    57300,
    60700,
    64200,
    67800,
    71500,
    75300,
    79200,
    83200,
    87300,
    91500,
    95800,
    100200,
    104700,
    109300,
    114000,
    118800,
    123700,
    128700,
  ];

  static const List<String> _levelTitles = <String>[
    'New Creator',
    'First Upload',
    'Getting Started',
    'Showing Up',
    'Learning the Game',
    'Finding Your Voice',
    'First Momentum',
    'On the Radar',
    'Building Rhythm',
    'Consistent Beginner',
    'Rising Creator',
    'Gaining Traction',
    'Content Builder',
    'Locked In',
    'Daily Creator',
    'Algorithm Friendly',
    'Growth Mode',
    'Attention Grabber',
    'Creator in Motion',
    'Consistency Locked',
    'Growth Operator',
    'Audience Builder',
    'Engagement Driver',
    'Trend Catcher',
    'Platform Player',
    'Multi-Post Machine',
    'Content Strategist',
    'Viral Potential',
    'System Builder',
    'Creator Engine',
    'Recognized Creator',
    'Influence Builder',
    'Community Leader',
    'Content Authority',
    'Algorithm Hacker',
    'Trend Leader',
    'Viral Creator',
    'Growth Specialist',
    'Audience Magnet',
    'Platform Dominator',
    'Creator Elite',
    'Viral Operator',
    'Culture Builder',
    'Content Machine',
    'Growth Legend',
    'Platform Icon',
    'Algorithm Master',
    'Creator Titan',
    'Industry Force',
    'StreamersTip Legend',
  ];

  static const List<String> _levelRewards = <String>[
    'Starter profile boost',
    'First upload badge',
    'Creator onboarding XP boost',
    'Daily check-in mission unlocked',
    'Beginner insights unlocked',
    'Voice finder badge',
    'Momentum mission pack',
    'Discovery boost preview',
    'Rhythm streak bonus',
    'Consistency checkpoint badge',
    'Rising creator badge',
    'Traction tracker unlocked',
    'Content builder mission pack',
    'Locked-in streak boost',
    'Daily creator insights',
    'Algorithm-friendly badge',
    'Growth mode XP boost',
    'Attention grabber flair',
    'Motion streak shield',
    'Consistency locked title card',
    'Growth operator badge',
    'Audience builder insights',
    'Engagement driver mission pack',
    'Trend catcher flair',
    'Platform player boost',
    'Multi-post machine rewards',
    'Strategy mission upgrade',
    'Viral potential badge',
    'System builder unlock',
    'Creator engine checkpoint',
    'Recognized creator badge',
    'Influence builder insights',
    'Community leader flair',
    'Content authority unlock',
    'Algorithm hacker badge',
    'Trend leader boost',
    'Viral creator checkpoint',
    'Growth specialist insights',
    'Audience magnet flair',
    'Platform dominator title card',
    'Creator elite badge',
    'Viral operator boost',
    'Culture builder flair',
    'Content machine upgrade',
    'Growth legend checkpoint',
    'Platform icon badge',
    'Algorithm master unlock',
    'Creator titan flair',
    'Industry force rewards',
    'StreamersTip legend crown',
  ];

  static int maxConfiguredLevel() => cumulativeXpForLevel.length;

  static String rankTitleForLevel(int level) {
    final int idx = (level - 1).clamp(0, _levelTitles.length - 1);
    return _levelTitles[idx];
  }

  static String rewardLabelForLevel(int level) {
    final int idx = (level - 1).clamp(0, _levelRewards.length - 1);
    return _levelRewards[idx];
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
