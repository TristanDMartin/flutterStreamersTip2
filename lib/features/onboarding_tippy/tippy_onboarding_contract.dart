/// Tippy Onboarding Contract v3 — keep in sync with
/// `contracts/tippy-onboarding.v3.json` and
/// `streamerstipReact/lib/onboarding/tippyOnboardingContract.ts`.
///
/// Canonical journey: Meet Tippy → Creator DNA → DNA Reveal → Account →
/// Identity → Notifications → Creator Space → First Mission.
library;

const String kTippyOnboardingContractVersion = '3.0.0';
const int kTippyOnboardingSessionSchemaVersion = 3;
const String kTippyOnboardingSessionStorageKey = 'tippy_onboarding_v3';

/// @deprecated Prefer [kTippyOnboardingSessionStorageKey].
const String kTippyOnboardingV1SessionStorageKey = 'tippy_onboarding_v1';
const int kTippyOnboardingTotalQuestions = 7;
const int kTippyOnboardingXpReward = 50;

/// Incomplete Tippy funnels always resume — never wipe progress on idle.
@Deprecated('Idle restart removed; progress persists until onboarding completes.')
const Duration kTippyOnboardingInactivityRestart = Duration(days: 36500);

abstract final class TippyOnboardingCopy {
  static const String welcomeHi = "Hey! I'm Tippy";
  static const String welcomeBeat1 =
      "I'm your creator copilot inside StreamersTip.";
  static const String welcomeBeat2 =
      'Tell me a little about what you create and where you want to go. '
      "I'll personalize StreamersTip around you.";
  static const String welcomeSupport =
      'Takes about 2 minutes. You can change anything later.';
  static const String welcomeCta = "LET'S GET STARTED";

  /// @deprecated use [welcomeBeat2]
  static const String questionsIntro = welcomeBeat2;

  /// Kept for older view paths that still reference a single welcome string.
  static const String welcome = welcomeHi;
  static const String gettingToKnowYou = 'Getting to know you';
  static const String dnaRevealIntro =
      "Okay… I'm starting to understand your creator world.";
  static const String dnaRevealBody =
      "I'll use this to personalize your recommendations, Creator Academy, "
      'content planning, missions, and the advice I give you.';
  static const String dnaRevealCta = 'BUILD MY STREAMERSTIP';
  static const String preSignup = "Let's save what we just built.";
  static const String signupBody =
      'Create your free StreamersTip account so I can save your creator '
      'profile, personalize your recommendations, and keep your missions '
      'and progress with you.';
  static const String notificationsExplain =
      'I can let you know when someone connects with you, your content needs '
      'attention, a creator milestone happens, a mission is ready, your team '
      'needs you, or Tippy spots something worth knowing.';
  static const String notificationsDeclined =
      'No problem. You can turn them on anytime.';
  static const String notificationsCta = 'YES, KEEP ME UPDATED';
  static const String notificationsSkip = 'NOT NOW';
  static const String welcomeBack =
      "Welcome back. Let's finish setting up your creator space.";
  static const String welcomeBackCta = 'CONTINUE';

  /// Trial is post-onboarding only in v3 — kept for legacy sessions.
  static const String trialIntro =
      "Based on what you've shared, Creator Pro can unlock more planning "
      "and AI help when you're ready.";
  static const String verifyEmail = 'One quick security check.';
  static const String verifyEmailTitle = 'Check your email';
  static const String verifyEmailBody = 'I sent a verification link to:';
  static const String accountSecured = 'Perfect. Your account is secure.';
  static const String accountSecuredNext =
      "Now let's create the identity other creators will see.";
  static const String avatarPrompt =
      "First, let's put a face—or a brand—to the name.";
  static const String displayNamePrompt = 'What should creators call you?';
  static const String usernamePrompt =
      'Now claim your StreamersTip username.';
  static const String bioPrompt = 'Want me to help introduce you?';
  static const String platformsPrompt = 'Want people to find you elsewhere?';
  static const String platformsPromptLegacy = 'Where do you create content?';
  static const String categoriesPrompt =
      'Which content areas best describe you?';
  static const String profileReviewPrompt =
      "Looking good. Here's your Creator Card.";
  static const String findFriends =
      'Want to see creators you already know? I can check your contacts '
      'and recommend people to follow.';
  static const String creatorSpaceTitle = 'Your creator space is ready.';
  static const String creatorSpaceWelcome = 'Welcome to StreamersTip';
  static const String creatorSpaceXpLabel = 'Setup bonus';
  static const String creatorSpaceCta = 'ENTER STREAMERSTIP';
  static const String firstMissionTitle =
      "I've got your first mission ready.";
  static const String firstMissionName = 'Follow 3 matching creators';
  static const String firstMissionBody =
      'Jump into Discover and follow creators who match your niche. You can skip and explore on your own.';
  static const String firstMissionCta = 'FIND CREATORS';
  static const String firstMissionSkip = 'Explore on my own';

  /// @deprecated v3 uses [creatorSpaceTitle]
  static const String success =
      "Your creator space is ready! I've personalized StreamersTip "
      'around your goals.';

  /// @deprecated v3 uses first mission instead of landing choice
  static const String landingChoice =
      'Great! Where would you like to start?';
}

abstract final class TippyOnboardingStages {
  static const String welcome = 'welcome';
  static const String questions = 'questions';
  static const String dnaReveal = 'dna_reveal';
  static const String signup = 'signup';
  static const String verifyEmail = 'verify_email';
  static const String accountSecured = 'account_secured';
  static const String avatar = 'avatar';
  static const String displayName = 'display_name';
  static const String username = 'username';
  static const String bio = 'bio';
  static const String platformHandles = 'platform_handles';
  static const String profileReview = 'profile_review';
  static const String notifications = 'notifications';
  static const String creatorSpaceReady = 'creator_space_ready';
  static const String firstMission = 'first_mission';

  /// Legacy aliases — same string as the v3 stage they map to (compile safety).
  static const String trial = signup;
  static const String platforms = platformHandles;
  static const String categories = profileReview;
  static const String findFriends = creatorSpaceReady;
  static const String success = creatorSpaceReady;
  static const String landingChoice = firstMission;

  /// Legacy alias — maps to [accountSecured] for older sessions.
  static const String creatorProfile = 'creator_profile';

  static const List<String> all = <String>[
    welcome,
    questions,
    dnaReveal,
    signup,
    verifyEmail,
    accountSecured,
    avatar,
    displayName,
    username,
    bio,
    platformHandles,
    profileReview,
    notifications,
    creatorSpaceReady,
    firstMission,
  ];

  /// Maps v1 / mid-funnel stage ids onto the v3 canonical path.
  static const Map<String, String> legacyAliases = <String, String>{
    creatorProfile: accountSecured,
    'trial': signup,
    'platforms': platformHandles,
    'categories': profileReview,
    'find_friends': creatorSpaceReady,
    'success': creatorSpaceReady,
    'landing_choice': firstMission,
  };

  static bool isValid(String? stage) =>
      stage != null &&
      (all.contains(stage) || legacyAliases.containsKey(stage));

  static String normalize(String? stage) {
    if (stage != null && legacyAliases.containsKey(stage)) {
      return legacyAliases[stage]!;
    }
    if (stage != null && all.contains(stage)) {
      return stage;
    }
    return welcome;
  }

  static String? next(String stage) {
    final String normalized = normalize(stage);
    final int index = all.indexOf(normalized);
    if (index < 0 || index >= all.length - 1) {
      return null;
    }
    return all[index + 1];
  }

  static String? previous(String stage) {
    final String normalized = normalize(stage);
    final int index = all.indexOf(normalized);
    if (index <= 0) {
      return null;
    }
    return all[index - 1];
  }

  static const List<String> guidedProfileStages = <String>[
    accountSecured,
    avatar,
    displayName,
    username,
    bio,
    platformHandles,
    profileReview,
  ];

  static bool isGuidedProfileStage(String stage) {
    return guidedProfileStages.contains(normalize(stage));
  }

  static const List<String> postQuizStages = <String>[
    dnaReveal,
    signup,
    verifyEmail,
    ...guidedProfileStages,
    notifications,
    creatorSpaceReady,
    firstMission,
  ];

  static bool isPostQuizStage(String stage) {
    return postQuizStages.contains(normalize(stage));
  }
}

enum TippyOnboardingInputType {
  singleSelect,
  multiSelect,
  text,
}

class TippyOnboardingOption {
  const TippyOnboardingOption({
    required this.id,
    required this.label,
    this.icon,
  });

  final String id;
  final String label;
  final String? icon;
}

class TippyOnboardingQuestion {
  const TippyOnboardingQuestion({
    required this.id,
    required this.prompt,
    required this.tippySpeech,
    required this.why,
    required this.inputType,
    required this.fieldPath,
    required this.required,
    this.options = const <TippyOnboardingOption>[],
    this.minSelections,
    this.maxSelections,
    this.maxLength,
    this.placeholder,
    this.autoAdvance = false,
    this.companionAnswerKey,
    this.companionPlaceholder,
    this.companionMaxLength,
    this.reactions = const <String, String>{},
  });

  final String id;
  final String prompt;
  final String tippySpeech;
  final String why;
  final TippyOnboardingInputType inputType;
  final String fieldPath;
  final bool required;
  final List<TippyOnboardingOption> options;
  final int? minSelections;
  final int? maxSelections;
  final int? maxLength;
  final String? placeholder;
  final bool autoAdvance;
  final String? companionAnswerKey;
  final String? companionPlaceholder;
  final int? companionMaxLength;
  final Map<String, String> reactions;
}

const List<({String id, String label})> kTippyGuidedPlatforms =
    <({String id, String label})>[
  (id: 'youtube', label: 'YouTube'),
  (id: 'twitch', label: 'Twitch'),
  (id: 'tiktok', label: 'TikTok'),
  (id: 'instagram', label: 'Instagram'),
  (id: 'kick', label: 'Kick'),
  (id: 'facebook', label: 'Facebook'),
  (id: 'x', label: 'X'),
  (id: 'other', label: 'Other'),
];

const List<({String id, String label})> kTippyGuidedCategories =
    <({String id, String label})>[
  (id: 'gaming', label: 'Gaming'),
  (id: 'irl', label: 'IRL'),
  (id: 'commentary', label: 'Commentary'),
  (id: 'education', label: 'Education'),
  (id: 'lifestyle', label: 'Lifestyle'),
  (id: 'technology', label: 'Tech'),
  (id: 'music', label: 'Music'),
  (id: 'art', label: 'Art'),
  (id: 'fitness', label: 'Fitness'),
  (id: 'beauty', label: 'Beauty'),
  (id: 'comedy', label: 'Comedy'),
  (id: 'podcasts', label: 'Podcasting'),
  (id: 'other', label: 'Other'),
];

const List<TippyOnboardingQuestion> kTippyOnboardingQuestions =
    <TippyOnboardingQuestion>[
  TippyOnboardingQuestion(
    id: 'creator_type',
    prompt: 'What kind of creator are you?',
    tippySpeech: 'First, what kind of creator are you?',
    why: "I'll use this to personalize your tools and recommendations.",
    inputType: TippyOnboardingInputType.singleSelect,
    fieldPath: 'identity.creatorType',
    required: true,
    autoAdvance: true,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(
        id: 'streamer',
        label: 'Live Streamer',
        icon: 'video',
      ),
      TippyOnboardingOption(
        id: 'video_creator',
        label: 'Video Creator',
        icon: 'play',
      ),
      TippyOnboardingOption(
        id: 'clipper',
        label: 'Clipper / Highlight Creator',
        icon: 'scissors',
      ),
      TippyOnboardingOption(
        id: 'hybrid',
        label: 'Stream + Video',
        icon: 'zap',
      ),
      TippyOnboardingOption(
        id: 'exploring',
        label: 'Still Exploring',
        icon: 'sprout',
      ),
    ],
    reactions: <String, String>{
      'exploring': "That's completely fine. We can figure this out together.",
      'streamer': 'Nice—live streaming gives us plenty to work with.',
      'hybrid': 'Hybrid creators get a lot out of StreamersTip.',
    },
  ),
  TippyOnboardingQuestion(
    id: 'platforms',
    prompt: 'Where are you creating right now?',
    tippySpeech: 'Where are you creating right now?',
    why: 'No account connections yet. Just tell me where you create.',
    inputType: TippyOnboardingInputType.multiSelect,
    fieldPath: 'platforms.primary',
    required: true,
    minSelections: 1,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'youtube', label: 'YouTube'),
      TippyOnboardingOption(id: 'twitch', label: 'Twitch'),
      TippyOnboardingOption(id: 'tiktok', label: 'TikTok'),
      TippyOnboardingOption(id: 'instagram', label: 'Instagram'),
      TippyOnboardingOption(id: 'kick', label: 'Kick'),
      TippyOnboardingOption(id: 'facebook', label: 'Facebook'),
      TippyOnboardingOption(id: 'x', label: 'X'),
      TippyOnboardingOption(id: 'other', label: 'Other'),
    ],
    reactions: <String, String>{
      'twitch': 'Nice—Twitch gives us plenty to work with.',
    },
  ),
  TippyOnboardingQuestion(
    id: 'niche',
    prompt: 'What kind of content feels most like you?',
    tippySpeech: 'What kind of content feels most like you?',
    why: 'Pick up to 5. Optionally describe your niche below.',
    inputType: TippyOnboardingInputType.multiSelect,
    fieldPath: 'identity.categories',
    required: true,
    minSelections: 1,
    maxSelections: 5,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'gaming', label: 'Gaming'),
      TippyOnboardingOption(id: 'irl', label: 'IRL'),
      TippyOnboardingOption(id: 'commentary', label: 'Commentary'),
      TippyOnboardingOption(id: 'education', label: 'Education'),
      TippyOnboardingOption(id: 'lifestyle', label: 'Lifestyle'),
      TippyOnboardingOption(id: 'technology', label: 'Tech'),
      TippyOnboardingOption(id: 'music', label: 'Music'),
      TippyOnboardingOption(id: 'art', label: 'Art'),
      TippyOnboardingOption(id: 'fitness', label: 'Fitness'),
      TippyOnboardingOption(id: 'beauty', label: 'Beauty'),
      TippyOnboardingOption(id: 'comedy', label: 'Comedy'),
      TippyOnboardingOption(id: 'podcasts', label: 'Podcasting'),
      TippyOnboardingOption(id: 'other', label: 'Other'),
    ],
    companionAnswerKey: 'niche_description',
    companionPlaceholder: 'Competitive FPS with chill vibes',
    companionMaxLength: 80,
  ),
  TippyOnboardingQuestion(
    id: 'experience',
    prompt: 'Where would you say you are in your creator journey?',
    tippySpeech: 'Where would you say you are in your creator journey?',
    why: "I'll adjust how much guidance I give you.",
    inputType: TippyOnboardingInputType.singleSelect,
    fieldPath: 'identity.experienceLevel',
    required: true,
    autoAdvance: true,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(
        id: 'beginner',
        label: 'Just Getting Started',
        icon: 'sprout',
      ),
      TippyOnboardingOption(
        id: 'intermediate',
        label: 'Building Momentum',
        icon: 'rocket',
      ),
      TippyOnboardingOption(
        id: 'advanced',
        label: 'Experienced Creator',
        icon: 'flame',
      ),
      TippyOnboardingOption(
        id: 'pro',
        label: 'Full-Time / Professional',
        icon: 'trophy',
      ),
    ],
  ),
  TippyOnboardingQuestion(
    id: 'goals',
    prompt: 'What would make the biggest difference for you right now?',
    tippySpeech: 'What would make the biggest difference for you right now?',
    why: "Choose up to three. I'll prioritize StreamersTip around these.",
    inputType: TippyOnboardingInputType.multiSelect,
    fieldPath: 'goals.goalIds',
    required: true,
    minSelections: 1,
    maxSelections: 3,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'build_audience', label: 'Grow my audience'),
      TippyOnboardingOption(
        id: 'consistent_content',
        label: 'Become more consistent',
      ),
      TippyOnboardingOption(
        id: 'better_content',
        label: 'Create better content',
      ),
      TippyOnboardingOption(
        id: 'multi_platform',
        label: 'Grow across platforms',
      ),
      TippyOnboardingOption(
        id: 'network_creators',
        label: 'Connect with creators',
      ),
      TippyOnboardingOption(
        id: 'build_community',
        label: 'Build my community',
      ),
      TippyOnboardingOption(
        id: 'monetize',
        label: 'Start earning from content',
      ),
      TippyOnboardingOption(
        id: 'work_with_brands',
        label: 'Work with brands',
      ),
    ],
    reactions: <String, String>{
      'consistent_content':
          'Consistency is something I can help you build into a system.',
      'build_audience': "Audience growth — I'll keep that front and center.",
    },
  ),
  TippyOnboardingQuestion(
    id: 'schedule',
    prompt: 'What does your content rhythm look like right now?',
    tippySpeech: 'What does your content rhythm look like right now?',
    why: "No judgment. I'll build plans around your actual schedule.",
    inputType: TippyOnboardingInputType.singleSelect,
    fieldPath: 'behavior.postingFrequency',
    required: true,
    autoAdvance: true,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'daily', label: 'Every day'),
      TippyOnboardingOption(id: 'few_week', label: 'A few times a week'),
      TippyOnboardingOption(id: 'weekly', label: 'About once a week'),
      TippyOnboardingOption(id: 'few_month', label: 'A few times a month'),
      TippyOnboardingOption(id: 'whenever', label: 'Whenever I can'),
      TippyOnboardingOption(id: 'not_started', label: "I haven't started yet"),
    ],
    reactions: <String, String>{
      'whenever':
          "Got it. We'll start with something realistic instead of "
              'trying to overhaul everything at once.',
      'not_started':
          "Got it. We'll start with something realistic instead of "
              'trying to overhaul everything at once.',
      'rarely':
          "Got it. We'll start with something realistic instead of "
              'trying to overhaul everything at once.',
    },
  ),
  TippyOnboardingQuestion(
    id: 'content_formats',
    prompt: 'What do you usually create?',
    tippySpeech: 'What do you usually create?',
    why: 'So templates and ideas match how you publish.',
    inputType: TippyOnboardingInputType.multiSelect,
    fieldPath: 'content.contentFormats',
    required: true,
    minSelections: 1,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'livestreams', label: 'Livestreams'),
      TippyOnboardingOption(id: 'shorts', label: 'Shorts / Reels'),
      TippyOnboardingOption(id: 'clips', label: 'Clips / Highlights'),
      TippyOnboardingOption(id: 'longform', label: 'Long-form Videos'),
      TippyOnboardingOption(id: 'posts', label: 'Posts / Threads'),
      TippyOnboardingOption(id: 'podcasts', label: 'Podcasts'),
    ],
  ),
];

TippyOnboardingQuestion? tippyOnboardingQuestionById(String id) {
  for (final TippyOnboardingQuestion question in kTippyOnboardingQuestions) {
    if (question.id == id) {
      return question;
    }
  }
  return null;
}

bool isValidTippyOnboardingAnswer(
  TippyOnboardingQuestion question,
  Object? raw,
) {
  switch (question.inputType) {
    case TippyOnboardingInputType.singleSelect:
      if (raw is! String || raw.trim().isEmpty) {
        return false;
      }
      if (question.options.any(
        (TippyOnboardingOption option) => option.id == raw,
      )) {
        return true;
      }
      // Accept legacy schedule id.
      return question.id == 'schedule' && raw == 'rarely';
    case TippyOnboardingInputType.multiSelect:
      if (raw is! List || raw.isEmpty) {
        return false;
      }
      final Set<String> ids = question.options
          .map((TippyOnboardingOption option) => option.id)
          .toSet();
      final List<String> selected = raw
          .whereType<String>()
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList();
      if (selected.isEmpty) {
        return false;
      }
      if (question.minSelections != null &&
          selected.length < question.minSelections!) {
        return false;
      }
      if (question.maxSelections != null &&
          selected.length > question.maxSelections!) {
        return false;
      }
      return selected.every(ids.contains);
    case TippyOnboardingInputType.text:
      if (raw is! String) {
        return false;
      }
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return false;
      }
      final int maxLength = question.maxLength ?? 60;
      return trimmed.length <= maxLength;
  }
}

abstract final class TippyOnboardingAnalytics {
  static const String started = 'tippy_onboarding_started';
  static const String stepCompleted = 'tippy_onboarding_step_completed';
  static const String questionsCompleted =
      'tippy_onboarding_questions_completed';
  static const String dnaReveal = 'tippy_onboarding_dna_reveal';
  static const String notificationsChoice =
      'tippy_onboarding_notifications_choice';
  static const String trialIntent = 'tippy_onboarding_trial_intent';
  static const String signupStarted = 'tippy_onboarding_signup_started';
  static const String signupAttached = 'tippy_onboarding_signup_attached';
  static const String completed = 'tippy_onboarding_completed';
  static const String creatorSpaceReady =
      'tippy_onboarding_creator_space_ready';
  static const String firstMission = 'tippy_onboarding_first_mission';
  static const String landingChoice = 'tippy_onboarding_landing_choice';
}
