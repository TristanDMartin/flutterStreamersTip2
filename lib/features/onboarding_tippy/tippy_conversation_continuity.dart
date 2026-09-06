/// Tippy conversation continuity — extend tippy_onboarding_v3.
/// Keep meanings identical to website `lib/onboarding/tippyConversationContinuity.ts`.
library;

import 'tippy_onboarding_contract.dart';
import 'tippy_onboarding_session.dart';

const List<String> kTippyConversationActs = <String>[
  'INTRODUCED',
  'DISCOVERY',
  'ASSESSMENT',
  'PREVIEW',
  'ACCOUNT_GATE',
  'ACCOUNT_CLAIMED',
  'PROFILE_BUILD',
  'PLAN_BUILD',
  'COMPLETE',
];

abstract final class TippyContinuityCopy {
  static const String accountClaimedLead = 'Perfect — I saved everything.';
  static const String accountClaimedNext =
      "Now let's turn what you told me into your creator profile and growth plan.";
}

class TippyConversationCommit {
  const TippyConversationCommit({
    required this.stepId,
    required this.turn,
    required this.message,
    this.secondaryDelivered = false,
  });

  final String stepId;
  final int turn;
  final String message;
  final bool secondaryDelivered;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stepId': stepId,
        'turn': turn,
        'message': message,
        'secondaryDelivered': secondaryDelivered,
      };

  factory TippyConversationCommit.fromJson(Map<String, dynamic> json) {
    return TippyConversationCommit(
      stepId: (json['stepId'] as String? ?? '').trim(),
      turn: (json['turn'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
      secondaryDelivered: json['secondaryDelivered'] == true,
    );
  }
}

class TippyInitialGrowthPlan {
  const TippyInitialGrowthPlan({
    required this.title,
    required this.focus,
    required this.why,
    required this.firstSteps,
    required this.format,
  });

  final String title;
  final String focus;
  final String why;
  final List<String> firstSteps;
  final String format;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'focus': focus,
        'why': why,
        'firstSteps': firstSteps,
        'format': format,
      };

  factory TippyInitialGrowthPlan.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TippyInitialGrowthPlan(
        title: '',
        focus: '',
        why: '',
        firstSteps: <String>[],
        format: 'short_form',
      );
    }
    return TippyInitialGrowthPlan(
      title: json['title'] as String? ?? '',
      focus: json['focus'] as String? ?? '',
      why: json['why'] as String? ?? '',
      firstSteps: (json['firstSteps'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      format: json['format'] as String? ?? 'short_form',
    );
  }
}

class TippyGeneratedPreview {
  const TippyGeneratedPreview({
    required this.observations,
    required this.growthOpportunity,
    required this.growthFocus,
    required this.plan,
  });

  final List<String> observations;
  final String growthOpportunity;
  final String growthFocus;
  final TippyInitialGrowthPlan plan;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'observations': observations,
        'growthOpportunity': growthOpportunity,
        'growthFocus': growthFocus,
        'plan': plan.toJson(),
      };

  factory TippyGeneratedPreview.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TippyGeneratedPreview(
        observations: const <String>[],
        growthOpportunity: '',
        growthFocus: '',
        plan: TippyInitialGrowthPlan.fromJson(null),
      );
    }
    return TippyGeneratedPreview(
      observations: (json['observations'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      growthOpportunity: json['growthOpportunity'] as String? ?? '',
      growthFocus: json['growthFocus'] as String? ?? '',
      plan: TippyInitialGrowthPlan.fromJson(
        (json['plan'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

class TippyPreviewContext {
  const TippyPreviewContext({
    required this.platforms,
    this.cadence,
    this.goal,
    this.bottleneck,
    this.creatorType,
    this.formats = const <String>[],
  });

  final List<String> platforms;
  final String? cadence;
  final String? goal;
  final String? bottleneck;
  final String? creatorType;
  final List<String> formats;
}

const Set<String> _streamingPlatforms = <String>{'twitch', 'kick'};
const Set<String> _shortFormPlatforms = <String>{
  'tiktok',
  'instagram',
  'youtube',
};
const Set<String> _streamingFormats = <String>{'livestreams'};
const Set<String> _shortFormats = <String>{'shorts', 'clips'};

bool hasStartedPublishing(String? cadence) {
  final String id = (cadence ?? '').trim();
  return id.isNotEmpty && id != 'not_started';
}

List<String> namedPreviewPlatforms(List<String> platforms) {
  return platforms
      .map((String id) => id.trim().toLowerCase())
      .where((String id) => id.isNotEmpty && id != 'other')
      .toList(growable: false);
}

String previewPlatformLabel(String id) {
  switch (id) {
    case 'youtube':
      return 'YouTube';
    case 'twitch':
      return 'Twitch';
    case 'tiktok':
      return 'TikTok';
    case 'instagram':
      return 'Instagram';
    case 'kick':
      return 'Kick';
    case 'facebook':
      return 'Facebook';
    case 'x':
      return 'X';
    default:
      return id;
  }
}

String resolveTippyPlanFormat(TippyPreviewContext ctx) {
  final List<String> platforms = namedPreviewPlatforms(ctx.platforms);
  final List<String> formats =
      ctx.formats.map((String id) => id.trim().toLowerCase()).toList();
  final String creatorType = (ctx.creatorType ?? '').trim().toLowerCase();
  final bool hasStreamingPlatform =
      platforms.any(_streamingPlatforms.contains);
  final bool hasShortPlatform = platforms.any(_shortFormPlatforms.contains);
  final bool hasLivestreams = formats.any(_streamingFormats.contains);
  final bool hasShorts = formats.any(_shortFormats.contains);
  final bool isStreamer =
      creatorType == 'streamer' || creatorType == 'hybrid';
  if (hasLivestreams && (hasShorts || hasShortPlatform)) {
    return 'hybrid';
  }
  if (hasStreamingPlatform && hasShortPlatform) {
    return 'hybrid';
  }
  if (hasLivestreams ||
      isStreamer ||
      (hasStreamingPlatform && !hasShortPlatform && !hasShorts)) {
    return 'streaming';
  }
  return 'short_form';
}

bool isStreamingFirst(TippyPreviewContext ctx) {
  final String format = resolveTippyPlanFormat(ctx);
  return format == 'streaming' || format == 'hybrid';
}

String streamingHomeLabel(TippyPreviewContext ctx) {
  final List<String> platforms = namedPreviewPlatforms(ctx.platforms);
  if (platforms.contains('twitch')) {
    return 'Twitch';
  }
  if (platforms.contains('kick')) {
    return 'Kick';
  }
  return 'your stream';
}

String publishHomeLabel(TippyPreviewContext ctx) {
  final List<String> platforms = namedPreviewPlatforms(ctx.platforms);
  if (platforms.isEmpty) {
    return 'your main channel';
  }
  return previewPlatformLabel(platforms.first);
}

String buildHonestCadenceObservation(TippyPreviewContext ctx) {
  if (!hasStartedPublishing(ctx.cadence)) {
    return "You haven't started publishing consistently yet.";
  }
  if (ctx.cadence == 'whenever') {
    return 'Your rhythm is improvised — you post whenever you can.';
  }
  if (ctx.cadence == 'few_month') {
    return isStreamingFirst(ctx)
        ? 'You go live a few times a month.'
        : 'You post a few times a month.';
  }
  if (ctx.cadence == 'weekly') {
    return isStreamingFirst(ctx)
        ? "You're already aiming at a weekly stream."
        : 'You already have a weekly posting slot.';
  }
  if (ctx.cadence == 'daily') {
    return "You're already showing up every day.";
  }
  return isStreamingFirst(ctx)
      ? 'You stream a few times a week.'
      : 'You post a few times a week.';
}

String buildHonestPlatformObservation(TippyPreviewContext ctx) {
  final List<String> named = namedPreviewPlatforms(ctx.platforms);
  final List<String> labels = named.map(previewPlatformLabel).toList();
  if (named.isEmpty) {
    return "You're creating off the usual platform map.";
  }
  if (named.length == 1) {
    return "${labels.first} is the platform you're starting with.";
  }
  if (named.length == 2) {
    return "You're starting on ${labels[0]} and ${labels[1]}.";
  }
  return "You're starting on ${labels[0]}, ${labels[1]}, and more.";
}

String buildHonestGrowthObservation(TippyPreviewContext ctx) {
  if (!hasStartedPublishing(ctx.cadence) || ctx.bottleneck == 'starting') {
    return "You haven't started publishing consistently yet.";
  }
  if (ctx.bottleneck == 'growth') {
    if (ctx.cadence == 'daily' || ctx.cadence == 'few_week') {
      return "You're already publishing, and you said growth is the wall right now.";
    }
    return 'You named growth as the wall, and there is not yet a weekly rhythm to learn from.';
  }
  return buildHonestCadenceObservation(ctx);
}

bool containsDishonestEffortClaim(String text) {
  return RegExp('effort is not converting', caseSensitive: false)
      .hasMatch(text);
}

TippyInitialGrowthPlan buildFormatAwareFirstPlan(TippyPreviewContext ctx) {
  final String format = resolveTippyPlanFormat(ctx);
  final String streamHome = streamingHomeLabel(ctx);
  final String publishHome = publishHomeLabel(ctx);
  if (format == 'streaming' || format == 'hybrid') {
    return TippyInitialGrowthPlan(
      title: 'Establish your $streamHome rhythm',
      focus: 'Build your first consistent week on $streamHome',
      why: hasStartedPublishing(ctx.cadence)
          ? '$streamHome is the platform you\'re starting with. The first plan is a stream rhythm you can keep — not an upload calendar.'
          : 'You\'re starting with $streamHome. The first plan is three streams you can actually complete — not a full content machine.',
      firstSteps: const <String>[
        'Choose three streams you can realistically complete this week.',
        'Give each stream a clear idea/title before you go live.',
        'Complete your first stream and use what happens during it to identify your first clip or cross-platform post.',
      ],
      format: format,
    );
  }
  return TippyInitialGrowthPlan(
    title: hasStartedPublishing(ctx.cadence)
        ? 'Start with a repeatable week on $publishHome'
        : 'Ship your first week on $publishHome',
    focus: hasStartedPublishing(ctx.cadence)
        ? 'a cadence you can keep on $publishHome'
        : 'first-week activation on $publishHome',
    why: hasStartedPublishing(ctx.cadence)
        ? 'You\'re starting on $publishHome. The first plan is a publish rhythm you can keep.'
        : 'You haven\'t started publishing consistently yet. The first plan is three posts on $publishHome — not a full system.',
    firstSteps: <String>[
      'Pick one format you\'ll actually publish on $publishHome',
      'Write three titles before you open an editor',
      'Publish the first one this week, even if it feels small',
    ],
    format: format,
  );
}

TippyGeneratedPreview buildDurablePreview(TippyPreviewContext ctx) {
  final TippyInitialGrowthPlan plan = buildFormatAwareFirstPlan(ctx);
  return TippyGeneratedPreview(
    observations: <String>[
      buildHonestCadenceObservation(ctx),
      buildHonestPlatformObservation(ctx),
      ctx.bottleneck == 'growth'
          ? buildHonestGrowthObservation(ctx)
          : plan.why,
    ],
    growthOpportunity: !hasStartedPublishing(ctx.cadence)
        ? 'Your first opportunity is building a repeatable publishing habit.'
        : plan.focus,
    growthFocus: plan.focus,
    plan: plan,
  );
}

TippyPreviewContext previewContextFromDnaAnswers(Map<String, dynamic> answers) {
  final Object? platformsRaw = answers['platforms'];
  final Object? formatsRaw = answers['content_formats'];
  final Object? goalsRaw = answers['goals'];
  return TippyPreviewContext(
    platforms: platformsRaw is List
        ? platformsRaw.map((Object? e) => e.toString()).toList()
        : const <String>[],
    cadence: answers['schedule'] is String ? answers['schedule'] as String : null,
    goal: goalsRaw is List && goalsRaw.isNotEmpty
        ? goalsRaw.first.toString()
        : null,
    bottleneck:
        answers['bottleneck'] is String ? answers['bottleneck'] as String : null,
    creatorType: answers['creator_type'] is String
        ? answers['creator_type'] as String
        : null,
    formats: formatsRaw is List
        ? formatsRaw.map((Object? e) => e.toString()).toList()
        : const <String>[],
  );
}

bool shouldSkipTippyIntro(TippyOnboardingGuestSession session) {
  if (session.hasSeenTippyIntro) {
    return true;
  }
  if (session.startedFromCheckup) {
    return true;
  }
  if (TippyOnboardingStages.isAtOrAfter(
    session.stage,
    TippyOnboardingStages.questions,
  )) {
    return true;
  }
  return false;
}

bool shouldRegeneratePreview(
  TippyOnboardingGuestSession session, {
  bool explicitAsk = false,
}) {
  if (explicitAsk) {
    return true;
  }
  if (session.generatedPreview != null) {
    return false;
  }
  if (session.creatorScorePreview != null) {
    return false;
  }
  if (session.initialGrowthPlan != null) {
    return false;
  }
  return true;
}

TippyOnboardingGuestSession ensureDurablePreview(
  TippyOnboardingGuestSession session, {
  bool explicitAsk = false,
}) {
  if (!shouldRegeneratePreview(session, explicitAsk: explicitAsk)) {
    return session;
  }
  if (session.answers.isEmpty) {
    return session;
  }
  final TippyGeneratedPreview preview =
      buildDurablePreview(previewContextFromDnaAnswers(session.answers));
  return session.copyWith(
    generatedPreview: preview,
    growthOpportunity: preview.growthOpportunity,
    growthFocus: preview.growthFocus,
    initialGrowthPlan: preview.plan,
    conversationAct: session.conversationAct ?? 'PREVIEW',
  );
}

TippyOnboardingGuestSession commitConversationTurn(
  TippyOnboardingGuestSession session,
  TippyConversationCommit commit,
) {
  final List<TippyConversationCommit> timeline =
      List<TippyConversationCommit>.from(session.conversationTimeline);
  final int index =
      timeline.indexWhere((TippyConversationCommit row) => row.stepId == commit.stepId);
  if (index >= 0) {
    timeline[index] = commit;
  } else {
    timeline.add(commit);
  }
  final List<String> completed = List<String>.from(session.completedSteps);
  if (!completed.contains(commit.stepId)) {
    completed.add(commit.stepId);
  }
  return session.copyWith(
    conversationTurn: commit.turn,
    lastTippyMessage: commit.message,
    secondarySpeechDelivered: commit.secondaryDelivered,
    conversationTimeline: timeline,
    completedSteps: completed,
  );
}

TippyConversationCommit? restoreCommittedTurn(
  TippyOnboardingGuestSession session,
  String stepId,
) {
  for (final TippyConversationCommit row in session.conversationTimeline) {
    if (row.stepId == stepId) {
      return row;
    }
  }
  if (session.lastTippyMessage != null) {
    return TippyConversationCommit(
      stepId: stepId,
      turn: session.conversationTurn,
      message: session.lastTippyMessage!,
      secondaryDelivered: session.secondarySpeechDelivered,
    );
  }
  return null;
}

TippyOnboardingGuestSession claimGuestOnboardingSession(
  TippyOnboardingGuestSession session, {
  required String uid,
  bool emailVerified = false,
}) {
  final String trimmed = uid.trim();
  if (session.accountCreated &&
      (session.claimedUid == null || session.claimedUid == trimmed)) {
    return session.copyWith(
      hasSeenTippyIntro: true,
      conversationAct: 'ACCOUNT_CLAIMED',
      claimedUid: trimmed.isEmpty ? session.claimedUid : trimmed,
      emailVerified: emailVerified || session.emailVerified,
    );
  }
  return commitConversationTurn(
    session.copyWith(
      hasSeenTippyIntro: true,
      accountCreated: true,
      claimedUid: trimmed,
      emailVerified: emailVerified || session.emailVerified,
      conversationAct: 'ACCOUNT_CLAIMED',
    ),
    const TippyConversationCommit(
      stepId: 'account_claimed',
      turn: 0,
      message: TippyContinuityCopy.accountClaimedLead,
    ),
  );
}

bool didCreateSecondOnboardingSession(
  TippyOnboardingGuestSession before,
  TippyOnboardingGuestSession after,
) {
  return before.sessionId.trim() != after.sessionId.trim();
}

int resolveWelcomeTurn(TippyOnboardingGuestSession session) {
  final TippyConversationCommit? committed =
      restoreCommittedTurn(session, 'welcome');
  final int turn = committed?.turn ?? session.conversationTurn;
  if (turn <= 0) {
    return 0;
  }
  if (turn == 1) {
    return 1;
  }
  return 2;
}
