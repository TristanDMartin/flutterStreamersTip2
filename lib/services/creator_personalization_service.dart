import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads onboarding [creatorGoals] / platforms and maps them to in-app surfaces.
class CreatorPersonalizationService {
  CreatorPersonalizationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<CreatorPersonalizationProfile> fetchProfile(String userId) async {
    if (userId.isEmpty) {
      return CreatorPersonalizationProfile.empty;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('users').doc(userId).get();
    return CreatorPersonalizationProfile.fromUserMap(doc.data());
  }

  Stream<CreatorPersonalizationProfile> watchProfile(String userId) {
    if (userId.isEmpty) {
      return Stream<CreatorPersonalizationProfile>.value(
        CreatorPersonalizationProfile.empty,
      );
    }
    CreatorPersonalizationProfile? previous;
    return _firestore.collection('users').doc(userId).snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              CreatorPersonalizationProfile.fromUserMap(snapshot.data()),
        ).where((CreatorPersonalizationProfile profile) {
      if (previous != null && previous == profile) {
        return false;
      }
      previous = profile;
      return true;
    });
  }
}

enum CreatorPersonalizationSurface {
  tippy,
  contentPlanner,
  network,
  discover,
}

/// Analytics [uiSurface] values for personalized CTA taps.
abstract final class PersonalizationCtaSurfaces {
  static const String discoverBanner = 'discover_banner';
  static const String homeEmptyState = 'home_empty_state';
  static const String commandCenterPrimary = 'command_center_primary';
  static const String commandCenterQuickTippy = 'command_center_quick_tippy';
  static const String commandCenterQuickPlanner =
      'command_center_quick_planner';
}

class PersonalizationHomeEmptyCopy {
  const PersonalizationHomeEmptyCopy({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.surface,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final CreatorPersonalizationSurface surface;
}

class CreatorPersonalizationProfile {
  const CreatorPersonalizationProfile({
    required this.creatorGoals,
    required this.platforms,
    required this.rankedDiscoverCategoryIds,
    required this.primarySurface,
    required this.interestWeights,
  });

  final List<String> creatorGoals;
  final List<String> platforms;
  final List<String> rankedDiscoverCategoryIds;
  final CreatorPersonalizationSurface? primarySurface;
  final Map<String, double> interestWeights;

  static const CreatorPersonalizationProfile empty = CreatorPersonalizationProfile(
    creatorGoals: <String>[],
    platforms: <String>[],
    rankedDiscoverCategoryIds: <String>[],
    primarySurface: null,
    interestWeights: <String, double>{},
  );

  bool get hasGoals => creatorGoals.isNotEmpty;

  bool get hasPlatforms => platforms.isNotEmpty;

  bool get isActive => hasGoals || hasPlatforms;

  @override
  bool operator ==(Object other) {
    if (other is! CreatorPersonalizationProfile) {
      return false;
    }
    return _listEquals(creatorGoals, other.creatorGoals) &&
        _listEquals(platforms, other.platforms) &&
        _listEquals(rankedDiscoverCategoryIds, other.rankedDiscoverCategoryIds) &&
        primarySurface == other.primarySurface &&
        _mapEquals(interestWeights, other.interestWeights);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(creatorGoals),
        Object.hashAll(platforms),
        Object.hashAll(rankedDiscoverCategoryIds),
        primarySurface,
        Object.hashAll(interestWeights.entries),
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static bool _mapEquals(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final MapEntry<String, double> entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool get prefersTippy =>
      creatorGoals.contains('ai_assistance') ||
      primarySurface == CreatorPersonalizationSurface.tippy;

  bool get prefersContentPlanner =>
      creatorGoals.contains('content_creation') ||
      primarySurface == CreatorPersonalizationSurface.contentPlanner;

  bool get prefersNetwork =>
      creatorGoals.contains('networking') ||
      primarySurface == CreatorPersonalizationSurface.network;

  factory CreatorPersonalizationProfile.fromUserMap(
    Map<String, dynamic>? data,
  ) {
    if (data == null || data.isEmpty) {
      return CreatorPersonalizationProfile.empty;
    }
    final List<String> goals = _readStringList(
      data['creatorGoals'] ??
          (data['onboarding'] as Map?)?['creatorGoals'] ??
          (data['onboarding'] as Map?)?['creatorGoal'],
    );
    final List<String> platforms = _readStringList(
      (data['onboarding'] as Map?)?['platforms'],
    );
    final List<String> rankedCategories =
        CreatorPersonalizationLogic.rankedDiscoverCategoryIds(
      goals: goals,
      platforms: platforms,
    );
    return CreatorPersonalizationProfile(
      creatorGoals: goals,
      platforms: platforms,
      rankedDiscoverCategoryIds: rankedCategories,
      primarySurface: CreatorPersonalizationLogic.primarySurface(goals),
      interestWeights: CreatorPersonalizationLogic.interestWeights(
        goals: goals,
        platforms: platforms,
      ),
    );
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is! List) {
      return <String>[];
    }
    return raw
        .map((Object? value) => value.toString().trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }
}

abstract final class CreatorPersonalizationLogic {
  static const Map<String, List<String>> _goalDiscoverCategories =
      <String, List<String>>{
    'growth': <String>['tutorials', 'just-chatting', 'gaming'],
    'monetization': <String>['tutorials', 'tech', 'fashion'],
    'ai_assistance': <String>['tech', 'tutorials', 'just-chatting'],
    'networking': <String>['just-chatting', 'podcasts', 'gaming'],
    'content_creation': <String>['tutorials', 'art', 'music'],
    'streaming': <String>['gaming', 'just-chatting', 'music'],
  };

  static const Map<String, List<String>> _platformDiscoverCategories =
      <String, List<String>>{
    'twitch': <String>['gaming', 'just-chatting'],
    'youtube': <String>['tutorials', 'tech', 'music'],
    'tiktok': <String>['music', 'art', 'fitness'],
    'kick': <String>['gaming', 'just-chatting'],
    'instagram': <String>['fashion', 'art', 'fitness'],
    'facebook_gaming': <String>['gaming', 'just-chatting'],
  };

  static CreatorPersonalizationSurface? primarySurface(List<String> goals) {
    if (goals.contains('ai_assistance')) {
      return CreatorPersonalizationSurface.tippy;
    }
    if (goals.contains('content_creation')) {
      return CreatorPersonalizationSurface.contentPlanner;
    }
    if (goals.contains('networking')) {
      return CreatorPersonalizationSurface.network;
    }
    if (goals.contains('growth') || goals.contains('streaming')) {
      return CreatorPersonalizationSurface.discover;
    }
    if (goals.contains('monetization')) {
      return CreatorPersonalizationSurface.contentPlanner;
    }
    return null;
  }

  static List<String> rankedDiscoverCategoryIds({
    required List<String> goals,
    required List<String> platforms,
  }) {
    final Map<String, double> scores = <String, double>{};
    for (final String goal in goals) {
      final List<String>? categories = _goalDiscoverCategories[goal];
      if (categories == null) {
        continue;
      }
      for (final String categoryId in categories) {
        scores[categoryId] = (scores[categoryId] ?? 0) + 3;
      }
    }
    for (final String platform in platforms) {
      final List<String>? categories =
          _platformDiscoverCategories[platform.toLowerCase()];
      if (categories == null) {
        continue;
      }
      for (final String categoryId in categories) {
        scores[categoryId] = (scores[categoryId] ?? 0) + 2;
      }
    }
    final List<MapEntry<String, double>> ranked =
        scores.entries.toList(growable: false)
          ..sort(
            (MapEntry<String, double> a, MapEntry<String, double> b) =>
                b.value.compareTo(a.value),
          );
    return ranked.map((MapEntry<String, double> e) => e.key).toList();
  }

  static Map<String, double> interestWeights({
    required List<String> goals,
    required List<String> platforms,
  }) {
    final Map<String, double> weights = <String, double>{};
    void bump(String key, double amount) {
      weights[key] = (weights[key] ?? 0) + amount;
    }
    if (goals.contains('growth')) {
      bump('growth', 2);
      bump('streamingTips', 1.5);
    }
    if (goals.contains('content_creation')) {
      bump('editing', 2);
      bump('creatorTools', 1.5);
    }
    if (goals.contains('ai_assistance')) {
      bump('creatorTools', 2);
      bump('streamingTips', 1);
    }
    if (goals.contains('networking')) {
      bump('growth', 1.5);
    }
    if (goals.contains('streaming') || platforms.contains('twitch')) {
      bump('gaming', 2);
      bump('esports', 1);
    }
    if (platforms.contains('youtube')) {
      bump('growth', 1);
      bump('editing', 1);
    }
    return weights;
  }

  static double recommendedContentScore({
    required String contentId,
    required Map<String, dynamic> userInterests,
    required Map<String, double> goalWeights,
    String category = 'general',
    String destinationType = 'website_page',
  }) {
    double read(String key) {
      final Object? value = userInterests[key] ?? goalWeights[key];
      return value is num ? value.toDouble() : 0.0;
    }

    double scoreForCategory(String slug) {
      switch (slug) {
        case 'creator_tools':
        case 'creator-tools':
        case 'tools':
        case 'tool':
          return read('creatorTools') + read('streamingTips') + read('editing');
        case 'academy':
        case 'guides':
        case 'guide':
          return read('growth') + read('gaming') + read('streamingTips');
        case 'peripherals':
          return read('streamingTips') + read('gaming') + read('esports');
        case 'growth':
        case 'planning':
        case 'content-planner':
          return read('growth') + read('content_creation') + read('monetization');
        default:
          return 0;
      }
    }

    final double byId = scoreForCategory(contentId.replaceAll('_', '-'));
    if (byId > 0) {
      return byId;
    }
    final double byCategory = scoreForCategory(category.toLowerCase());
    if (byCategory > 0) {
      return byCategory;
    }
    switch (destinationType.toLowerCase()) {
      case 'tool':
        return read('creatorTools') + read('streamingTips');
      case 'academy':
      case 'guide':
        return read('growth') + read('streamingTips');
      case 'growth':
        return read('growth') + read('monetization');
      case 'peripherals':
        return read('streamingTips') + read('gaming');
      default:
        return 0;
    }
  }

  static List<T> reorderByRank<T>({
    required List<T> items,
    required String Function(T item) idForItem,
    required List<String> rankedIds,
    T? pinFirst,
    bool Function(T item)? isPinned,
  }) {
    if (rankedIds.isEmpty) {
      return items;
    }
    final Map<String, int> rankIndex = <String, int>{
      for (int i = 0; i < rankedIds.length; i++) rankedIds[i]: i,
    };
    int score(T item) {
      if (isPinned != null && isPinned(item)) {
        return -1;
      }
      final String id = idForItem(item).toLowerCase();
      return rankIndex[id] ?? 999;
    }
    final List<T> sorted = List<T>.from(items)
      ..sort((T a, T b) => score(a).compareTo(score(b)));
    return sorted;
  }

  static List<String> tippyQuickPromptsForGoals(List<String> goals) {
    final List<String> prompts = <String>[];
    if (goals.contains('ai_assistance')) {
      prompts.add('Coach me through my next posting session');
    }
    if (goals.contains('content_creation')) {
      prompts.add('Turn my idea into a 7-day content plan');
    }
    if (goals.contains('growth')) {
      prompts.add('How do I grow engagement this week?');
    }
    if (goals.contains('networking')) {
      prompts.add('Who should I collaborate with in my niche?');
    }
    if (goals.contains('streaming')) {
      prompts.add('What should I stream or clip next?');
    }
    if (goals.contains('monetization')) {
      prompts.add('How can I monetize my next content drop?');
    }
    return prompts;
  }

  static List<String> mergeQuickPrompts({
    required List<String> basePrompts,
    required List<String> goalPrompts,
    int maxCount = 4,
  }) {
    final List<String> merged = <String>[];
    final Set<String> seen = <String>{};
    for (final String prompt in <String>[...goalPrompts, ...basePrompts]) {
      if (seen.add(prompt)) {
        merged.add(prompt);
      }
      if (merged.length >= maxCount) {
        break;
      }
    }
    return merged;
  }

  static PersonalizationHomeEmptyCopy? homeEmptyCopy(
    CreatorPersonalizationProfile profile,
  ) {
    if (!profile.isActive || profile.primarySurface == null) {
      return null;
    }
    switch (profile.primarySurface!) {
      case CreatorPersonalizationSurface.tippy:
        return const PersonalizationHomeEmptyCopy(
          emoji: '🤖',
          title: 'Your feed is quiet — plan your next move',
          subtitle:
              'You told us AI coaching matters. Ask Tippy for hooks, '
              'captions, or a posting rhythm.',
          ctaLabel: 'Open Tippy',
          surface: CreatorPersonalizationSurface.tippy,
        );
      case CreatorPersonalizationSurface.contentPlanner:
        return const PersonalizationHomeEmptyCopy(
          emoji: '📅',
          title: 'Start with a content plan',
          subtitle:
              'Your focus is creation — map the week before the feed fills up.',
          ctaLabel: 'Open Content Planner',
          surface: CreatorPersonalizationSurface.contentPlanner,
        );
      case CreatorPersonalizationSurface.network:
        return const PersonalizationHomeEmptyCopy(
          emoji: '🤝',
          title: 'Grow through your network',
          subtitle:
              'Community is your goal — find creators to connect with while '
              'your feed loads.',
          ctaLabel: 'Explore Network',
          surface: CreatorPersonalizationSurface.network,
        );
      case CreatorPersonalizationSurface.discover:
        return const PersonalizationHomeEmptyCopy(
          emoji: '📈',
          title: 'Discover creators in your niche',
          subtitle:
              'We picked categories from your goals — explore while new '
              'posts arrive.',
          ctaLabel: 'Browse Discover',
          surface: CreatorPersonalizationSurface.discover,
        );
    }
  }

  static List<String> tippyContextLines({
    required List<String> goals,
    required List<String> platforms,
  }) {
    final List<String> lines = <String>[];
    if (goals.isNotEmpty) {
      final List<String> labels = goals
          .map((String goal) => _goalLabels[goal] ?? goal)
          .toList(growable: false);
      lines.add('Onboarding creator goals: ${labels.join('; ')}.');
    }
    if (platforms.isNotEmpty) {
      final List<String> labels = platforms
          .map((String platform) => _platformLabels[platform] ?? platform)
          .toList(growable: false);
      lines.add('Primary platforms: ${labels.join(', ')}.');
      for (final String platform in platforms.take(3)) {
        final String? guidance = _platformGuidance[platform.toLowerCase()];
        if (guidance != null) {
          lines.add(guidance);
        }
      }
    }
    if (goals.contains('ai_assistance')) {
      lines.add(
        'Prioritize actionable coaching, scripts, and next-step plans.',
      );
    }
    if (goals.contains('content_creation')) {
      lines.add(
        'Suggest concrete content ideas, hooks, and weekly cadence.',
      );
    }
    return lines;
  }

  static const Map<String, String> _goalLabels = <String, String>{
    'growth': 'Grow audience and engagement',
    'monetization': 'Monetize content',
    'ai_assistance': 'AI coaching and workflow help',
    'networking': 'Build creator connections',
    'content_creation': 'Plan and create content',
    'streaming': 'Improve live streaming',
  };

  static const Map<String, String> _platformLabels = <String, String>{
    'twitch': 'Twitch',
    'youtube': 'YouTube',
    'tiktok': 'TikTok',
    'kick': 'Kick',
    'instagram': 'Instagram',
    'facebook_gaming': 'Facebook Gaming',
  };

  static const Map<String, String> _platformGuidance = <String, String>{
    'twitch':
        'Twitch context: categories, stream titles, raids, clips, panels, '
        'and live engagement.',
    'youtube':
        'YouTube context: thumbnails, hooks, Shorts vs long-form, and '
        'upload cadence.',
    'tiktok':
        'TikTok context: hooks in the first second, trends, and vertical '
        'pacing.',
    'kick':
        'Kick context: live categories, discoverability, and clip highlights.',
    'instagram':
        'Instagram context: Reels hooks, aesthetic consistency, and CTAs.',
    'facebook_gaming':
        'Facebook Gaming context: live discovery, community posts, and clips.',
  };
}
