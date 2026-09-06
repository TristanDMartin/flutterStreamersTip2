/// Tippy Onboarding Contract v3 — keep in sync with
/// `contracts/tippy-onboarding.v3.json` and
/// `streamerstipReact/lib/onboarding/tippyOnboardingContract.ts`.
///
/// Canonical journey: Meet Tippy → Creator DNA → DNA Reveal → Account →
/// Identity → optional Tippy Twitch connect → Notifications →
/// Creator Space → First Mission.
library;

const String kTippyOnboardingContractVersion = '3.0.0';
const int kTippyOnboardingSessionSchemaVersion = 3;
const String kTippyOnboardingSessionStorageKey = 'tippy_onboarding_v3';

/// @deprecated Prefer [kTippyOnboardingSessionStorageKey].
const String kTippyOnboardingV1SessionStorageKey = 'tippy_onboarding_v1';

/// Set after account deletion so the next Get Started cannot resume old Tippy.
const String kTippyForceFreshAfterAccountDeletionKey =
    'tippy_force_fresh_after_account_deletion';

/// Sticky until Tippy attach succeeds with startedFromWelcome after a delete.
const String kTippyStartedFromWelcomeAfterDeletionKey =
    'tippy_started_from_welcome_after_deletion';

const String kTippySignupClosedFloorKey = 'tippy_signup_closed_floor';

/// Survives verify-floor release and unexpected Auth sign-out.
const String kTippyReservedSignupUsernameKey =
    'tippy_reserved_signup_username';

/// Set when the user backs out of verify-email to pick another signup method.
const String kTippyVerifyFloorReleasedKey = 'tippy_verify_floor_released';

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
  static const String checkupBroughtOver =
      "Perfect. I brought over what I learned. I already have a picture of what you're creating. Now I want to understand where you want to take it.";
  static const String checkupBroughtOverBody =
      "I can see what you're making. What I can't see is where you want to go.";
  static const String checkupLooksRight = 'LOOKS RIGHT';
  static const String checkupEdit = 'EDIT';

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
  static const String preSignup =
      "Great — I know enough about you now. Let's save this so I can "
      'build your plan.';
  static const String signupBody =
      'Create your free StreamersTip account so I can save your creator '
      'profile, personalize your recommendations, and keep your missions '
      'and progress with you.';
  static const String notificationsTitle = 'Stay in the loop';
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
  static const String accountSecured = 'Perfect. I saved everything.';
  static const String accountSecuredNext =
      "Now let's create the identity other creators will see.";
  static const String avatarPrompt =
      "First, let's put a face—or a brand—to the name.";
  static const String displayNamePrompt = 'What should creators call you?';
  static const String usernamePrompt =
      'Now claim your StreamersTip username.';
  static const String usernameLockedTitle = 'Your creator username';
  static const String usernameLockedBody =
      'This is the username you created when you signed up.';
  static const String usernameChange = 'Change username';
  static const String bioPrompt = 'Want me to help introduce you?';
  static const String platformsPrompt = 'Want people to find you elsewhere?';
  static const String platformsPromptLegacy = 'Where do you create content?';
  static const String categoriesPrompt =
      'Which content areas best describe you?';
  static const String profileReviewPrompt =
      "Looking good. Here's your Creator Card.";
  static const String twitchConnectTitle = 'Your Twitch setup';
  static const String twitchConnectIntro =
      'Tippy can join you while you\'re live.';
  static const String twitchConnectBody =
      'Connect your Twitch account and Tippy will be ready to help when '
      'you go live — chat, commands, community interactions, and creator '
      'insights.';
  static const String twitchConnectCta = 'CONNECT TWITCH';
  static const String twitchConnectSkip = 'NOT NOW';
  static const String twitchConnectSuccessTitle = 'Twitch connected';
  static const String twitchConnectSuccessBody =
      "I'm ready for your next stream. When you're live, I can help with "
      'your chat, commands, community interactions, and creator insights.';
  static const String twitchConnectSuccessCta = 'CONTINUE';
  static const String findFriends =
      'Want to see creators you already know? I can check your contacts '
      'and recommend people to follow.';
  static const String creatorSpaceTitle =
      "Here's what I think you should focus on first.";
  static const String creatorSpaceWelcome =
      'Your starting growth plan is ready.';
  static const String creatorSpaceXpLabel = 'Setup bonus';
  static const String creatorSpaceCta = 'ENTER STREAMERSTIP';
  static const String firstMissionTitle =
      "Based on what you told me, I'd start here.";
  static const String firstMissionName = 'Start My First Mission';
  static const String firstMissionBody =
      'Open the starter growth plan Tippy built from your Creator DNA and '
      'ship the first piece.';
  static const String firstMissionCta = 'START MY FIRST MISSION';
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
  /// Skippable Tippy↔Twitch OAuth — only when Creator DNA selected Twitch.
  static const String twitchConnect = 'twitch_connect';
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
    username,
    bio,
    platformHandles,
    profileReview,
    twitchConnect,
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
    displayName: username,
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

  /// Visible Back only. Never rewinds server lifecycle or identity.
  static String? reviewPrevious({
    required String stage,
    bool isAuthenticated = false,
    bool emailVerified = false,
    Map<String, dynamic> answers = const <String, dynamic>{},
    List<String>? selectedPlatforms,
  }) {
    final String current = normalize(stage);
    String? previousStage = previous(current);
    if (previousStage == null) {
      return null;
    }
    if (current == notifications &&
        previousStage == twitchConnect &&
        !hasSelectedTwitchInDna(answers, selectedPlatforms: selectedPlatforms)) {
      previousStage = profileReview;
    }
    final bool identityLocked = isAtOrAfter(current, twitchConnect);
    if (identityLocked && !isAtOrAfter(previousStage, twitchConnect)) {
      final bool skippedTwitchBranch = current == notifications &&
          previousStage == profileReview &&
          !hasSelectedTwitchInDna(answers, selectedPlatforms: selectedPlatforms);
      if (!skippedTwitchBranch) {
        return null;
      }
    }
    final bool verifiedFloor =
        emailVerified || isAtOrAfter(current, accountSecured);
    if (verifiedFloor && !isAtOrAfter(previousStage, accountSecured)) {
      return null;
    }
    if (isAuthenticated &&
        (previousStage == welcome ||
            previousStage == questions ||
            previousStage == dnaReveal ||
            previousStage == signup)) {
      return null;
    }
    return previousStage;
  }

  /// Never rewind a live Tippy session. After verify/signup, a stale
  /// `welcome` hint continues at [accountSecured] instead of Meet Tippy.
  static String resumeStage({
    required String currentStage,
    String? proposedStage,
  }) {
    final String current = normalize(currentStage);
    final String proposedRaw = proposedStage?.trim() ?? '';
    if (proposedRaw.isEmpty) {
      return current == verifyEmail || current == signup
          ? accountSecured
          : current;
    }
    final String proposed = normalize(proposedRaw);
    final int currentIndex = all.indexOf(current);
    final int proposedIndex = all.indexOf(proposed);
    if (proposedIndex < currentIndex) {
      return current == verifyEmail || current == signup
          ? accountSecured
          : current;
    }
    return proposed;
  }

  static bool isAtOrAfter(String stage, String minimum) {
    final int currentIndex = all.indexOf(normalize(stage));
    final int minimumIndex = all.indexOf(normalize(minimum));
    return currentIndex >= 0 && minimumIndex >= 0 && currentIndex >= minimumIndex;
  }

  /// Visible Tippy stage during/after password signup.
  /// createUser success sets a verify_email floor. Status may move
  /// the user forward, never back to the account-creation CTA.
  static String resolveVisibleStage({
    required String storedStage,
    String? signupClosedFloor,
    String? statusHint,
    String? statusRoute,
    bool emailVerified = false,
  }) {
    final String stored = normalize(storedStage);
    final String floorRaw = signupClosedFloor?.trim() ?? '';
    final bool hasFloor = floorRaw.isNotEmpty;
    final String? floor = hasFloor ? normalize(floorRaw) : null;
    String visible = stored;
    if (floor != null && !isAtOrAfter(visible, floor)) {
      visible = floor;
    }
    final bool inAuthFunnel =
        hasFloor || stored == signup || stored == verifyEmail;
    if (emailVerified &&
        inAuthFunnel &&
        !isAtOrAfter(visible, accountSecured)) {
      visible = accountSecured;
    }
    if (hasFloor &&
        !emailVerified &&
        !isAtOrAfter(visible, verifyEmail)) {
      visible = verifyEmail;
    }
    String? proposed;
    if (statusRoute == 'verify-email') {
      proposed = verifyEmail;
    } else if (statusRoute == 'onboarding') {
      final String hint = statusHint?.trim() ?? '';
      if (hint.isNotEmpty) {
        proposed = normalize(hint);
      }
    }
    if (proposed != null && isAtOrAfter(proposed, visible)) {
      visible = proposed;
    }
    if (hasFloor &&
        !emailVerified &&
        !isAtOrAfter(visible, verifyEmail)) {
      visible = verifyEmail;
    }
    if (emailVerified &&
        inAuthFunnel &&
        !isAtOrAfter(visible, accountSecured)) {
      visible = accountSecured;
    }
    return visible;
  }

  static String clampVisibleStage({
    required String storedStage,
    String? floor,
  }) {
    return resolveVisibleStage(
      storedStage: storedStage,
      signupClosedFloor: floor,
    );
  }

  /// Meet Tippy rewind is only for a signed-out leftover identity screen.
  /// Never rewind a live signup, verification, or cached-auth resume.
  static bool shouldForceMeetTippyIntroForGuest({
    required String stage,
    required bool isAuthenticated,
    bool hasCachedAuth = false,
    bool isAuthResume = false,
    bool hasLiveVerificationIntent = false,
  }) {
    if (isAuthenticated ||
        hasCachedAuth ||
        isAuthResume ||
        hasLiveVerificationIntent) {
      return false;
    }
    return isAtOrAfter(stage, verifyEmail);
  }

  static bool hasSessionProgress({
    required String stage,
    int questionIndex = 0,
    Map<String, dynamic>? answers,
    bool hasSeenTippyIntro = false,
  }) {
    if (hasSeenTippyIntro) {
      return true;
    }
    if (questionIndex > 0) {
      return true;
    }
    if (answers != null && answers.isNotEmpty) {
      return true;
    }
    return isAtOrAfter(stage, questions);
  }

  /// After account deletion, reset Tippy once for a fresh guest Get Started.
  /// Never reset a live quiz, signup, or authenticated create-account remount.
  static bool shouldResetSessionAfterAccountDeletion({
    required bool hasDeleteFlag,
    required bool isAuthenticated,
    required String stage,
    int questionIndex = 0,
    Map<String, dynamic>? answers,
    bool hasSeenTippyIntro = false,
  }) {
    if (!hasDeleteFlag || isAuthenticated) {
      return false;
    }
    return !hasSessionProgress(
      stage: stage,
      questionIndex: questionIndex,
      answers: answers,
      hasSeenTippyIntro: hasSeenTippyIntro,
    );
  }

  static const List<String> guidedProfileStages = <String>[
    accountSecured,
    avatar,
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
    twitchConnect,
    notifications,
    creatorSpaceReady,
    firstMission,
  ];

  static bool isPostQuizStage(String stage) {
    return postQuizStages.contains(normalize(stage));
  }

  /// Creator DNA "Where do you create?" includes Twitch.
  static List<String> normalizeDnaPlatformIds(Object? raw) {
    if (raw is List) {
      return raw
          .map((Object? e) => e.toString().trim().toLowerCase())
          .where((String id) => id.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return <String>[raw.trim().toLowerCase()];
    }
    return const <String>[];
  }

  static bool hasSelectedTwitchInDna(
    Map<String, dynamic> answers, {
    List<String>? selectedPlatforms,
  }) {
    if (normalizeDnaPlatformIds(answers['platforms']).contains('twitch')) {
      return true;
    }
    if (selectedPlatforms == null) {
      return false;
    }
    return selectedPlatforms
        .map((String id) => id.trim().toLowerCase())
        .contains('twitch');
  }

  static List<String> mergeOnboardingSelectedPlatforms({
    List<String>? dnaPlatformIds,
    List<String>? existingSelected,
    List<String>? profilePlatformIds,
  }) {
    final Set<String> merged = <String>{};
    for (final List<String>? list
        in <List<String>?>[dnaPlatformIds, existingSelected, profilePlatformIds]) {
      if (list == null) {
        continue;
      }
      for (final String id in list) {
        final String normalized = id.trim().toLowerCase();
        if (normalized.isNotEmpty) {
          merged.add(normalized);
        }
      }
    }
    return merged.toList(growable: false);
  }

  /// After Creator Card: Twitch OAuth only when DNA selected Twitch and
  /// connection is still unresolved.
  static String stageAfterCreatorCard({
    Map<String, dynamic> answers = const <String, dynamic>{},
    List<String>? selectedPlatforms,
    String? twitchConnectionStatus,
  }) {
    final String status = (twitchConnectionStatus ?? '').trim().toUpperCase();
    if (hasSelectedTwitchInDna(answers, selectedPlatforms: selectedPlatforms) &&
        status != TippyTwitchConnectionStatus.skipped &&
        status != TippyTwitchConnectionStatus.connected) {
      return twitchConnect;
    }
    return notifications;
  }

  /// Client authority when local DNA still requires Twitch OAuth.
  static String resolvePostCreatorCardStage({
    required String localStage,
    String? serverStage,
  }) {
    if (localStage == twitchConnect && serverStage != twitchConnect) {
      return twitchConnect;
    }
    final String trimmed = (serverStage ?? '').trim();
    if (trimmed.isNotEmpty) {
      return normalize(trimmed);
    }
    return localStage;
  }
}

/// Persisted on session + `users.onboarding.twitchConnectionStatus`.
/// Separate from platform handle strings (@username).
abstract final class TippyTwitchConnectionStatus {
  static const String skipped = 'SKIPPED';
  static const String connected = 'CONNECTED';
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

int? nextUnansweredOnboardingIndex(
  Map<String, dynamic> answers, [
  int from = 0,
]) {
  for (int i = from; i < kTippyOnboardingQuestions.length; i++) {
    final TippyOnboardingQuestion question = kTippyOnboardingQuestions[i];
    if (!isValidTippyOnboardingAnswer(question, answers[question.id])) {
      return i;
    }
  }
  return null;
}

const List<String> kTippyOnboardingInvariants = <String>[
  'creator_dna_never_creates_identity',
  'email_prefix_never_becomes_username',
  'never_derive_username_from_email_after_signup',
  'canonical_username_beats_local_draft',
  'owned_username_is_never_taken',
  'tippy_stages_never_override_activation_state',
  'local_storage_never_determines_identity',
  'verification_never_rewinds_onboarding',
  'signup_success_never_reopens_signup',
  'signup_visible_stage_is_monotonic',
  'notifications_never_block_activation',
  'twitch_handle_is_not_oauth',
  'twitch_oauth_does_not_gate_creator_card',
  'kill_resume_resolves_from_account_status',
  'activated_never_reenters_onboarding',
  'back_never_rewinds_lifecycle',
  'back_preserves_entered_values',
];

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

const Map<String, String> kTippyGoalBioPhrases = <String, String>{
  'build_audience': 'growing an audience',
  'consistent_content': 'becoming more consistent',
  'better_content': 'creating better content',
  'multi_platform': 'growing across platforms',
  'network_creators': 'connecting with other creators',
  'build_community': 'building community',
  'monetize': 'earning from content',
  'work_with_brands': 'working with brands',
};

const Map<String, String> kTippyCreatorTypeBioRoles = <String, String>{
  'streamer': 'live streamer',
  'video_creator': 'video creator',
  'clipper': 'clipper',
  'hybrid': 'stream and video creator',
  'exploring': 'creator still exploring',
};

bool hasTippyDnaAnswers(Map<String, dynamic> answers) {
  final Object? creatorType = answers['creator_type'];
  if (creatorType is String && creatorType.trim().isNotEmpty) {
    return true;
  }
  final Object? nicheDesc = answers['niche_description'];
  if (nicheDesc is String && nicheDesc.trim().isNotEmpty) {
    return true;
  }
  if (answers['niche'] is List && (answers['niche'] as List).isNotEmpty) {
    return true;
  }
  if (answers['goals'] is List && (answers['goals'] as List).isNotEmpty) {
    return true;
  }
  return false;
}

String? tippyOnboardingOptionLabel(String questionId, String optionId) {
  for (final TippyOnboardingQuestion question in kTippyOnboardingQuestions) {
    if (question.id != questionId) {
      continue;
    }
    for (final TippyOnboardingOption option in question.options) {
      if (option.id == optionId) {
        return option.label;
      }
    }
  }
  return null;
}

List<String> buildCreatorDnaSummary(Map<String, dynamic> answers) {
  final List<String> lines = <String>[];

  final Object? creatorType = answers['creator_type'];
  if (creatorType is String) {
    final String? label = tippyOnboardingOptionLabel(
      'creator_type',
      creatorType,
    );
    if (label != null) {
      lines.add(label);
    }
  }

  final Object? platforms = answers['platforms'];
  if (platforms is List && platforms.isNotEmpty) {
    final List<String> labels = platforms
        .whereType<String>()
        .map(
          (String id) => tippyOnboardingOptionLabel('platforms', id) ?? id,
        )
        .where((String label) => label.trim().isNotEmpty)
        .toList();
    if (labels.isNotEmpty) {
      lines.add(labels.join(' + '));
    }
  }

  final Object? niche = answers['niche'];
  if (niche is List && niche.isNotEmpty) {
    final List<String> labels = niche
        .whereType<String>()
        .map((String id) {
          for (final ({String id, String label}) category
              in kTippyGuidedCategories) {
            if (category.id == id) {
              return category.label;
            }
          }
          return id;
        })
        .where((String label) => label.trim().isNotEmpty)
        .take(3)
        .toList();
    if (labels.isNotEmpty) {
      lines.add(labels.join(' · '));
    }
  } else if (niche is String && niche.trim().isNotEmpty) {
    lines.add(niche.trim());
  }

  final Object? nicheDescription = answers['niche_description'];
  if (nicheDescription is String && nicheDescription.trim().isNotEmpty) {
    lines.add('"${nicheDescription.trim()}"');
  }

  final Object? experience = answers['experience'];
  if (experience is String) {
    final String? label = tippyOnboardingOptionLabel('experience', experience);
    if (label != null) {
      lines.add(label);
    }
  }

  final Object? goals = answers['goals'];
  if (goals is List && goals.isNotEmpty && goals.first is String) {
    final String? label = tippyOnboardingOptionLabel(
      'goals',
      goals.first as String,
    );
    if (label != null) {
      lines.add(label);
    }
  }

  final Object? schedule = answers['schedule'];
  if (schedule is String) {
    final String id = schedule == 'rarely' ? 'whenever' : schedule;
    final String? label = tippyOnboardingOptionLabel('schedule', id);
    if (label != null) {
      lines.add('Creates ${label.toLowerCase()}');
    }
  }

  return lines;
}

String suggestBioFromAnswers(Map<String, dynamic> answers) {
  return tippyBioRemixVariants(answers).first;
}

const int kTippyBioMaxLength = 160;
const int kTippyBioMaxRemixes = 3;

String truncateTippyBio(String value) {
  final String trimmed = value.trim();
  if (trimmed.length <= kTippyBioMaxLength) {
    return trimmed;
  }
  return trimmed.substring(0, kTippyBioMaxLength).trim();
}

({
  String niche,
  String role,
  String goal,
  String platformFocus,
}) _tippyBioDnaParts(Map<String, dynamic> answers) {
  final Object? rawNicheDesc = answers['niche_description'];
  final String nicheDesc =
      rawNicheDesc is String ? rawNicheDesc.trim() : '';
  final String nicheCats = _nicheCategoryLabels(answers['niche']);
  final Object? rawCreatorType = answers['creator_type'];
  final String creatorTypeId =
      rawCreatorType is String ? rawCreatorType : '';
  final String role =
      kTippyCreatorTypeBioRoles[creatorTypeId] ?? 'creator';
  final String primaryGoalId = _firstAnswerId(answers['goals']);
  final String goal =
      kTippyGoalBioPhrases[primaryGoalId] ?? 'growing with the audience';
  final Object? rawPlatforms = answers['platforms'];
  String platformFocus = 'every platform that fits';
  if (rawPlatforms is List) {
    final List<String> labels = rawPlatforms
        .whereType<String>()
        .map((String id) {
          for (final ({String id, String label}) platform
              in kTippyGuidedPlatforms) {
            if (platform.id == id) {
              return platform.label;
            }
          }
          return '';
        })
        .where((String label) => label.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (labels.isNotEmpty) {
      platformFocus = labels.join(' + ');
    }
  }
  final String niche = nicheDesc.isNotEmpty
      ? _capitalizeFirst(nicheDesc)
      : (nicheCats.isNotEmpty ? nicheCats : 'Creator');
  return (
    niche: niche,
    role: role,
    goal: goal,
    platformFocus: platformFocus,
  );
}

double tippyBioSimilarity(String a, String b) {
  Set<String> tokenize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((String t) => t.length > 2)
        .toSet();
  }

  final Set<String> left = tokenize(a);
  final Set<String> right = tokenize(b);
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }
  int overlap = 0;
  for (final String token in left) {
    if (right.contains(token)) {
      overlap += 1;
    }
  }
  return overlap / (left.length + right.length - overlap);
}

bool tippyBiosTooSimilar(String a, String b) {
  return tippyBioSimilarity(a, b) >= 0.55;
}

/// Full bios from Creator DNA only — never mutate a previous bio.
List<String> tippyBioRemixVariants(Map<String, dynamic> answers) {
  final ({
    String niche,
    String role,
    String goal,
    String platformFocus,
  }) parts = _tippyBioDnaParts(answers);
  final String nicheLower = parts.niche.toLowerCase();
  return <String>[
    '${parts.niche} ${parts.role} focused on ${parts.goal}. Building a '
        'community around consistent growth and good conversations.',
    'Streaming $nicheLower, competitive moments, and the clips worth saving. '
        'Growing on ${parts.platformFocus}.',
    'Creator mixing $nicheLower, commentary, and short-form content while '
        'aiming at ${parts.goal}.',
    'Building a community around $nicheLower, conversation, and consistent '
        'creator growth on ${parts.platformFocus}.',
  ].map(truncateTippyBio).toList(growable: false);
}

/// Remix generates a brand-new complete bio from DNA.
({String bio, int remixCount})? nextTippyRemixedBio({
  required Map<String, dynamic> answers,
  int remixCount = 0,
  List<String> previousBios = const <String>[],
}) {
  final int used = remixCount < 0 ? 0 : remixCount;
  if (used >= kTippyBioMaxRemixes) {
    return null;
  }
  final List<String> variants = tippyBioRemixVariants(answers);
  final List<String> avoid = previousBios
      .map(truncateTippyBio)
      .where((String b) => b.isNotEmpty)
      .toList(growable: false);
  final List<String> ordered = <String>[
    if (used + 1 < variants.length) variants[used + 1],
    for (int i = 0; i < variants.length; i++)
      if (i != used + 1 && i != 0) variants[i],
  ];
  for (final String candidate in ordered) {
    final bool tooClose =
        avoid.any((String prior) => tippyBiosTooSimilar(candidate, prior));
    if (!tooClose) {
      return (bio: candidate, remixCount: used + 1);
    }
  }
  if (ordered.isEmpty) {
    return null;
  }
  return (bio: ordered.first, remixCount: used + 1);
}

String _nicheCategoryLabels(Object? raw) {
  if (raw is String) {
    return raw;
  }
  if (raw is! List) {
    return '';
  }
  final List<String> labels = raw
      .whereType<String>()
      .map((String id) {
        for (final ({String id, String label}) category
            in kTippyGuidedCategories) {
          if (category.id == id) {
            return category.label;
          }
        }
        return '';
      })
      .where((String label) => label.isNotEmpty)
      .take(2)
      .toList();
  return labels.join(' and ');
}

String _firstAnswerId(Object? raw) {
  if (raw is String) {
    return raw;
  }
  if (raw is List && raw.isNotEmpty && raw.first is String) {
    return raw.first as String;
  }
  return '';
}

String _capitalizeFirst(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
