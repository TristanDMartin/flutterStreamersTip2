/// Creator Threads Contract v2 — keep in sync with
/// `contracts/threads.v2.json` and
/// `streamerstipReact/types/threadsContract.ts`.
library;

const String kThreadsContractVersion = '2.0.0';
const int kThreadsSchemaVersion = 2;

const String kThreadsProductName = 'Creator Threads';
const String kThreadsProductSubtitle =
    'Ask questions, share what’s working, and build alongside other creators.';

const List<String> kThreadTypes = <String>[
  'question',
  'feedback_request',
  'creator_win',
  'debate',
  'collaboration',
  'build_in_public',
];

const Map<String, String> kThreadTypeLabels = <String, String>{
  'question': 'Ask a question',
  'feedback_request': 'Request feedback',
  'creator_win': 'Share a win',
  'debate': 'Start a debate',
  'collaboration': 'Find collaborators',
  'build_in_public': 'Post an update',
};

const String kLegacyDefaultThreadType = 'question';

const List<String> kThreadStatuses = <String>[
  'open',
  'answered',
  'resolved',
  'still_need_help',
  'locked',
  'deleted',
];

const Map<String, String> kThreadStatusLabels = <String, String>{
  'open': 'Open',
  'answered': 'Answered',
  'resolved': 'Resolved',
  'still_need_help': 'Still need help',
  'locked': 'Locked',
  'deleted': 'Deleted',
};

const Map<String, String> _legacyStatusAliases = <String, String>{
  'published': 'open',
  'active': 'open',
  'closed': 'resolved',
  'archived': 'resolved',
};

const List<String> kMomentumStates = <String>[
  'new',
  'picking_up',
  'trending',
  'active_now',
  'resolved',
];

const Map<String, String> kMomentumLabels = <String, String>{
  'new': 'New',
  'picking_up': 'Picking up',
  'trending': 'Trending',
  'active_now': 'Active now',
  'resolved': 'Resolved',
};

const Map<String, String> kMomentumIcons = <String, String>{
  'new': 'fiber_new',
  'picking_up': 'local_fire_department',
  'trending': 'trending_up',
  'active_now': 'bolt',
  'resolved': 'check_circle',
};

const List<String> kReactionTypes = <String>[
  'helpful',
  'relatable',
  'great_idea',
  'congratulations',
  'agree',
  'different_take',
];

const Map<String, String> kReactionLabels = <String, String>{
  'helpful': 'Helpful',
  'relatable': 'Relatable',
  'great_idea': 'Great idea',
  'congratulations': 'Congratulations',
  'agree': 'Agree',
  'different_take': 'Different take',
};

const Map<String, List<String>> kReactionsByThreadType =
    <String, List<String>>{
  'question': <String>['helpful', 'relatable', 'great_idea'],
  'feedback_request': <String>['helpful', 'great_idea', 'relatable'],
  'creator_win': <String>[
    'congratulations',
    'relatable',
    'great_idea',
    'helpful',
  ],
  'debate': <String>['agree', 'different_take', 'helpful', 'relatable'],
  'collaboration': <String>['helpful', 'great_idea', 'relatable'],
  'build_in_public': <String>[
    'helpful',
    'relatable',
    'great_idea',
    'congratulations',
  ],
};

const List<String> kFeedFilters = <String>[
  'for_you',
  'following',
  'trending',
  'unanswered',
  'live',
];

const Map<String, String> kFeedFilterLabels = <String, String>{
  'for_you': 'For You',
  'following': 'Following',
  'trending': 'Trending',
  'unanswered': 'Unanswered',
  'live': 'Live',
};

const List<String> kFeedModules = <String>[
  'continue_conversation',
  'creator_goals',
  'need_your_input',
  'trending_in_space',
  'creator_wins',
  'featured',
];

const Map<String, String> kFeedModuleLabels = <String, String>{
  'continue_conversation': 'Continue the conversation',
  'creator_goals': 'For your creator goals',
  'need_your_input': 'Creators need your input',
  'trending_in_space': 'Trending in your space',
  'creator_wins': 'Creator wins',
  'featured': 'Community spotlight',
};

const List<String> kCanonicalCategoryIds = <String>[
  'growth',
  'streaming',
  'content_ideas',
  'video_feedback',
  'gear_setup',
  'gaming',
  'monetization',
  'collaboration',
  'creator_life',
];

const Map<String, String> kCategoryLabels = <String, String>{
  'growth': 'Growth',
  'streaming': 'Streaming',
  'content_ideas': 'Content Ideas',
  'video_feedback': 'Video Feedback',
  'gear_setup': 'Gear & Setup',
  'gaming': 'Gaming',
  'monetization': 'Monetization',
  'collaboration': 'Collaboration',
  'creator_life': 'Creator Life',
};

const Map<String, String> _legacyCategoryAliases = <String, String>{
  'general': 'creator_life',
  'general_gaming': 'gaming',
  'streaming_tips': 'streaming',
  'lfg': 'collaboration',
  'competitive': 'gaming',
  'growth_advice': 'growth',
  'setup': 'gear_setup',
  'video': 'video_feedback',
  'clip': 'video_feedback',
};

const Map<String, String> kGamificationEvents = <String, String>{
  'threadCreated': 'content.thread_created',
  'threadParticipated': 'community.thread_participated',
  'helpfulReactionReceived': 'community.helpful_reaction_received',
  'answerMarkedHelpful': 'community.answer_marked_helpful',
  'unansweredHelped': 'community.unanswered_helped',
};

const List<String> kAnalyticsEvents = <String>[
  'thread_viewed',
  'thread_created',
  'thread_reply_created',
  'reaction_added',
  'reaction_removed',
  'resolution_set',
  'thread_followed',
  'category_followed',
  'module_impressed',
  'module_clicked',
  'feed_filter_selected',
  'tippy_starter_used',
  'tippy_summary_viewed',
  'comment_promoted_to_thread',
];

/// Tippy conversation-starter presets (ids match JSON contract).
class TippyStarterPreset {
  const TippyStarterPreset({
    required this.id,
    required this.label,
    required this.threadType,
    required this.defaultCategoryId,
    required this.prompt,
    required this.structure,
  });

  final String id;
  final String label;
  final String threadType;
  final String defaultCategoryId;
  final String prompt;
  final List<String> structure;
}

const List<TippyStarterPreset> kTippyStarterPresets = <TippyStarterPreset>[
  TippyStarterPreset(
    id: 'ask_feedback',
    label: 'Ask for feedback',
    threadType: 'feedback_request',
    defaultCategoryId: 'video_feedback',
    prompt: 'What are you working on?',
    structure: <String>[
      'What I’m trying to do',
      'What I’ve tried',
      'Where I’m stuck',
    ],
  ),
  TippyStarterPreset(
    id: 'share_win',
    label: 'Share a win',
    threadType: 'creator_win',
    defaultCategoryId: 'growth',
    prompt: 'What happened?',
    structure: <String>[
      'The result',
      'What changed',
      'What others can learn',
    ],
  ),
  TippyStarterPreset(
    id: 'start_debate',
    label: 'Start a debate',
    threadType: 'debate',
    defaultCategoryId: 'creator_life',
    prompt: 'What should creators weigh in on?',
    structure: <String>[
      'The question',
      'Position A',
      'Position B',
    ],
  ),
  TippyStarterPreset(
    id: 'get_help',
    label: 'Get help',
    threadType: 'question',
    defaultCategoryId: 'growth',
    prompt: 'What do you need help with?',
    structure: <String>[
      'The question',
      'Context',
      'What you already tried',
    ],
  ),
  TippyStarterPreset(
    id: 'post_update',
    label: 'Post an update',
    threadType: 'build_in_public',
    defaultCategoryId: 'content_ideas',
    prompt: 'What are you building?',
    structure: <String>[
      'Project',
      'This week’s update',
      'What’s next',
    ],
  ),
];

/// Momentum thresholds from contract (clients use only via adapter/server).
class ThreadsMomentumThresholds {
  static const int newMaxAgeHours = 24;
  static const int pickingUpMinReplies = 5;
  static const int pickingUpWindowHours = 6;
  static const int pickingUpMinParticipants = 3;
  static const int trendingMinReplies = 12;
  static const int trendingWindowHours = 24;
  static const int trendingMinParticipants = 8;
  static const int trendingMinSaves = 3;
  static const int activeNowMinReplies = 3;
  static const int activeNowWindowMinutes = 30;
  static const int activeNowMinParticipants = 2;
}

String _normalizeKey(Object? raw) {
  return (raw?.toString() ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_');
}

String normalizeThreadType(Object? raw) {
  final String key = _normalizeKey(raw);
  if (kThreadTypes.contains(key)) {
    return key;
  }
  return kLegacyDefaultThreadType;
}

String threadTypeLabel(Object? type) {
  final String normalized = normalizeThreadType(type);
  return kThreadTypeLabels[normalized] ?? kThreadTypeLabels[kLegacyDefaultThreadType]!;
}

String normalizeThreadStatus(Object? raw) {
  final String key = _normalizeKey(raw);
  if (key.isEmpty) {
    return 'open';
  }
  if (kThreadStatuses.contains(key)) {
    return key;
  }
  return _legacyStatusAliases[key] ?? 'open';
}

String threadStatusLabel(Object? status) {
  final String normalized = normalizeThreadStatus(status);
  return kThreadStatusLabels[normalized] ?? 'Open';
}

String normalizeMomentumState(Object? raw) {
  final String key = _normalizeKey(raw);
  if (kMomentumStates.contains(key)) {
    return key;
  }
  return 'new';
}

String momentumLabel(Object? state) {
  final String normalized = normalizeMomentumState(state);
  return kMomentumLabels[normalized] ?? 'New';
}

String? normalizeReactionType(Object? raw) {
  final String key = _normalizeKey(raw);
  if (kReactionTypes.contains(key)) {
    return key;
  }
  if (key == 'like' || key == 'heart') {
    return 'helpful';
  }
  if (key == 'dislike') {
    return null;
  }
  return null;
}

String normalizeCategoryId(Object? raw) {
  final String key = _normalizeKey(raw);
  if (kCanonicalCategoryIds.contains(key)) {
    return key;
  }
  return _legacyCategoryAliases[key] ??
      (key.isEmpty ? 'creator_life' : key);
}

String categoryLabel(Object? categoryId) {
  final String normalized = normalizeCategoryId(categoryId);
  return kCategoryLabels[normalized] ?? normalized;
}

String normalizeFeedFilter(Object? raw) {
  final String key = _normalizeKey(raw);
  if (kFeedFilters.contains(key)) {
    return key;
  }
  return 'for_you';
}

String normalizeFeedModule(Object? raw) {
  final String key = _normalizeKey(raw);
  if (kFeedModules.contains(key)) {
    return key;
  }
  return 'featured';
}

List<String> allowedReactionsForType(Object? threadType) {
  final String type = normalizeThreadType(threadType);
  return List<String>.from(
    kReactionsByThreadType[type] ?? kReactionsByThreadType['question']!,
  );
}

TippyStarterPreset? tippyStarterById(String id) {
  for (final TippyStarterPreset preset in kTippyStarterPresets) {
    if (preset.id == id) {
      return preset;
    }
  }
  return null;
}

/// Contract-aligned momentum from activity counters (adapter/server only).
String computeMomentumState({
  required DateTime createdAt,
  required DateTime lastActivityAt,
  required int replyCountInWindow,
  required int uniqueParticipantsInWindow,
  required int savesInWindow,
  required String status,
  DateTime? now,
}) {
  final String normalizedStatus = normalizeThreadStatus(status);
  if (normalizedStatus == 'resolved' || normalizedStatus == 'deleted') {
    return 'resolved';
  }
  final DateTime clock = now ?? DateTime.now().toUtc();
  final Duration sinceActivity = clock.difference(lastActivityAt.toUtc());
  final Duration sinceCreated = clock.difference(createdAt.toUtc());
  if (replyCountInWindow >= ThreadsMomentumThresholds.activeNowMinReplies &&
      uniqueParticipantsInWindow >=
          ThreadsMomentumThresholds.activeNowMinParticipants &&
      sinceActivity.inMinutes <=
          ThreadsMomentumThresholds.activeNowWindowMinutes) {
    return 'active_now';
  }
  if (replyCountInWindow >= ThreadsMomentumThresholds.trendingMinReplies &&
      uniqueParticipantsInWindow >=
          ThreadsMomentumThresholds.trendingMinParticipants &&
      savesInWindow >= ThreadsMomentumThresholds.trendingMinSaves &&
      sinceActivity.inHours <=
          ThreadsMomentumThresholds.trendingWindowHours) {
    return 'trending';
  }
  if (replyCountInWindow >= ThreadsMomentumThresholds.pickingUpMinReplies &&
      uniqueParticipantsInWindow >=
          ThreadsMomentumThresholds.pickingUpMinParticipants &&
      sinceActivity.inHours <=
          ThreadsMomentumThresholds.pickingUpWindowHours) {
    return 'picking_up';
  }
  if (sinceCreated.inHours <= ThreadsMomentumThresholds.newMaxAgeHours) {
    return 'new';
  }
  return 'new';
}
