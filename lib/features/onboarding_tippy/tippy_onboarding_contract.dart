/// Tippy Onboarding Contract v1 — keep in sync with
/// `contracts/tippy-onboarding.v1.json` and
/// `streamerstipReact/lib/onboarding/tippyOnboardingContract.ts`.
library;

const String kTippyOnboardingContractVersion = '1.0.0';
const int kTippyOnboardingSessionSchemaVersion = 1;
const String kTippyOnboardingSessionStorageKey = 'tippy_onboarding_v1';
const int kTippyOnboardingTotalQuestions = 7;

/// Incomplete Tippy funnels restart from Meet Tippy after this idle window.
const Duration kTippyOnboardingInactivityRestart = Duration(hours: 4);

abstract final class TippyOnboardingCopy {
  static const String welcomeHi = "Hi there! I'm Tippy!";
  static const String welcome =
      "Hi there! I'm Tippy. Welcome to StreamersTip!";
  static const String questionsIntro =
      'I have seven quick questions so I can personalize your '
      'creator workspace and help you grow.';
  static const String preSignup =
      "Perfect — I've started building your creator profile. "
      'Create your free account so I can save your answers and '
      'personalize StreamersTip for you.';
  static const String notificationsExplain =
      "I can remind you when it's time to create content, "
      'celebrate your milestones, and let you know when your '
      'posts perform well.';
  static const String notificationsDeclined =
      'No problem! You can always enable reminders later.';
  static const String trialIntro =
      "Based on what you've shared... I've already started "
      'building your creator workspace. '
      "I'd love to unlock everything for your first 7 days.";
  static const String verifyEmail =
      "One last step. Check your email so I know it's really you.";
  static const String accountSecured =
      'Great! Your account is secure. '
      "Now let's build the creator profile people will see on StreamersTip.";
  static const String avatarPrompt =
      "Let's add a profile picture so creators can recognize you.";
  static const String displayNamePrompt =
      'What should people call you?';
  static const String usernamePrompt =
      'Now choose your unique @username. '
      'People will use this to find and mention you.';
  static const String bioPrompt =
      "Tell creators what you make and what you're working toward.";
  static const String platformsPrompt =
      'Where do you create content?';
  static const String categoriesPrompt =
      'Which content areas best describe you?';
  static const String profileReviewPrompt =
      "Here's how your creator profile will appear. "
      'You can change any of this later.';
  static const String findFriends =
      'Want to see creators you already know? I can check your '
      'contacts and recommend people to follow.';
  static const String success =
      'Your creator profile is ready! '
      "I've also used your answers to personalize StreamersTip around your goals.";
  static const String landingChoice =
      'Great! Where would you like to start?';
}

abstract final class TippyOnboardingStages {
  static const String welcome = 'welcome';
  static const String questions = 'questions';
  static const String notifications = 'notifications';
  static const String trial = 'trial';
  static const String signup = 'signup';
  static const String verifyEmail = 'verify_email';
  static const String accountSecured = 'account_secured';
  static const String avatar = 'avatar';
  static const String displayName = 'display_name';
  static const String username = 'username';
  static const String bio = 'bio';
  static const String platforms = 'platforms';
  static const String categories = 'categories';
  static const String profileReview = 'profile_review';
  static const String findFriends = 'find_friends';
  static const String success = 'success';
  static const String landingChoice = 'landing_choice';

  /// Legacy alias — maps to [accountSecured] for older sessions.
  static const String creatorProfile = 'creator_profile';

  static const List<String> all = <String>[
    welcome,
    questions,
    notifications,
    trial,
    signup,
    verifyEmail,
    accountSecured,
    avatar,
    displayName,
    username,
    bio,
    platforms,
    categories,
    profileReview,
    findFriends,
    success,
    landingChoice,
  ];

  static bool isValid(String? stage) =>
      stage != null && (all.contains(stage) || stage == creatorProfile);

  static String normalize(String? stage) {
    if (stage == creatorProfile) {
      return accountSecured;
    }
    if (isValid(stage) && stage != creatorProfile) {
      return stage!;
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
    platforms,
    categories,
    profileReview,
  ];

  static bool isGuidedProfileStage(String stage) {
    return guidedProfileStages.contains(normalize(stage));
  }

  static bool isPostQuizStage(String stage) {
    final String normalized = normalize(stage);
    return normalized == notifications ||
        normalized == trial ||
        normalized == signup ||
        normalized == verifyEmail ||
        isGuidedProfileStage(normalized) ||
        normalized == findFriends ||
        normalized == success ||
        normalized == landingChoice;
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
  });

  final String id;
  final String label;
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
}

const List<TippyOnboardingQuestion> kTippyOnboardingQuestions =
    <TippyOnboardingQuestion>[
  TippyOnboardingQuestion(
    id: 'creator_type',
    prompt: 'What kind of creator are you?',
    tippySpeech: 'First — how do you usually show up as a creator?',
    why: 'So I can tailor coaching and templates to your creator style.',
    inputType: TippyOnboardingInputType.singleSelect,
    fieldPath: 'identity.creatorType',
    required: true,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'streamer', label: 'Live streamer'),
      TippyOnboardingOption(id: 'video_creator', label: 'Video creator'),
      TippyOnboardingOption(id: 'clipper', label: 'Clipper / highlighter'),
      TippyOnboardingOption(id: 'hybrid', label: 'Hybrid (stream + video)'),
      TippyOnboardingOption(id: 'exploring', label: 'Still exploring'),
    ],
  ),
  TippyOnboardingQuestion(
    id: 'platforms',
    prompt: 'Which platforms do you focus on most?',
    tippySpeech:
        'Where do you publish most right now? (No need to connect accounts yet.)',
    why: 'So recommendations and planners match your platforms.',
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
    ],
  ),
  TippyOnboardingQuestion(
    id: 'niche',
    prompt: 'How would you describe your niche?',
    tippySpeech: "In one short line — what's your niche?",
    why: 'So Tippy can suggest ideas that fit your world.',
    inputType: TippyOnboardingInputType.text,
    fieldPath: 'identity.niche',
    required: true,
    maxLength: 60,
    placeholder: 'e.g. Competitive FPS with chill vibes',
  ),
  TippyOnboardingQuestion(
    id: 'experience',
    prompt: 'How experienced are you as a creator?',
    tippySpeech: 'How experienced do you feel as a creator today?',
    why: 'So coaching depth matches where you are now.',
    inputType: TippyOnboardingInputType.singleSelect,
    fieldPath: 'identity.experienceLevel',
    required: true,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'beginner', label: 'Just starting'),
      TippyOnboardingOption(id: 'intermediate', label: 'Some experience'),
      TippyOnboardingOption(id: 'advanced', label: 'Experienced'),
      TippyOnboardingOption(id: 'pro', label: 'Full-time / pro'),
    ],
  ),
  TippyOnboardingQuestion(
    id: 'goals',
    prompt: 'What are your main creator goals right now?',
    tippySpeech: 'What do you want help with most?',
    why: 'So your dashboard and Tippy focus on the right outcomes.',
    inputType: TippyOnboardingInputType.multiSelect,
    fieldPath: 'goals.goalIds',
    required: true,
    minSelections: 1,
    maxSelections: 5,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'build_audience', label: 'Build an audience'),
      TippyOnboardingOption(
        id: 'multi_platform',
        label: 'Grow on multiple platforms',
      ),
      TippyOnboardingOption(
        id: 'consistent_content',
        label: 'Create consistent content',
      ),
      TippyOnboardingOption(
        id: 'network_creators',
        label: 'Connect with other creators',
      ),
      TippyOnboardingOption(id: 'monetize', label: 'Monetize my content'),
    ],
  ),
  TippyOnboardingQuestion(
    id: 'schedule',
    prompt: 'How often do you usually post?',
    tippySpeech: 'How often are you posting or streaming right now?',
    why: 'So reminders and plans match your real rhythm.',
    inputType: TippyOnboardingInputType.singleSelect,
    fieldPath: 'behavior.postingFrequency',
    required: true,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'daily', label: 'Daily'),
      TippyOnboardingOption(id: 'few_week', label: 'A few times a week'),
      TippyOnboardingOption(id: 'weekly', label: 'Weekly'),
      TippyOnboardingOption(id: 'rarely', label: 'Rarely / inconsistently'),
    ],
  ),
  TippyOnboardingQuestion(
    id: 'content_formats',
    prompt: 'Which content formats do you create most?',
    tippySpeech: 'What formats do you create most?',
    why: 'So templates and ideas match how you publish.',
    inputType: TippyOnboardingInputType.multiSelect,
    fieldPath: 'content.contentFormats',
    required: true,
    minSelections: 1,
    options: <TippyOnboardingOption>[
      TippyOnboardingOption(id: 'livestreams', label: 'Livestreams'),
      TippyOnboardingOption(id: 'shorts', label: 'Shorts / Reels'),
      TippyOnboardingOption(id: 'clips', label: 'Clips highlights'),
      TippyOnboardingOption(id: 'longform', label: 'Long-form video'),
      TippyOnboardingOption(id: 'posts', label: 'Posts / threads'),
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
      return question.options.any(
        (TippyOnboardingOption option) => option.id == raw,
      );
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
  static const String notificationsChoice =
      'tippy_onboarding_notifications_choice';
  static const String trialIntent = 'tippy_onboarding_trial_intent';
  static const String signupStarted = 'tippy_onboarding_signup_started';
  static const String signupAttached = 'tippy_onboarding_signup_attached';
  static const String completed = 'tippy_onboarding_completed';
  static const String landingChoice = 'tippy_onboarding_landing_choice';
}
