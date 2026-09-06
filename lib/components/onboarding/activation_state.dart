/// Canonical activation state machine — mirrors
/// streamerstipReact/lib/onboarding/activationState.ts
///
/// activationState = lifecycle authority
/// tippyStageHint = presentation/resume location
///
/// Guest dna_reveal remains GUEST_PERSONALIZATION. TTFR is recorded there.
/// Signed-in analysis begins at FIRST_GROWTH_PLAN.
library;

import 'resolve_onboarding_destination.dart';

const List<String> kActivationStates = <String>[
  'NEW',
  'GUEST_PERSONALIZATION',
  'ACCOUNT_REQUIRED',
  'EMAIL_VERIFICATION_REQUIRED',
  'CREATOR_IDENTITY',
  'FIRST_GROWTH_PLAN',
  'FIRST_MISSION',
  'ACTIVATED',
];

const String kGuestDnaRevealActivationState = 'GUEST_PERSONALIZATION';
const String kSignedInAnalysisBeginsAt = 'FIRST_GROWTH_PLAN';

/// @deprecated Prefer FIRST_GROWTH_PLAN. Alias during web/Flutter rollout.
const String kLegacyTippyInitialAnalysis = 'TIPPY_INITIAL_ANALYSIS';

const Set<String> _identityStages = <String>{
  'account_secured',
  'avatar',
  'username',
  'bio',
  'platform_handles',
  'profile_review',
  'twitch_connect',
  'notifications',
};

class ActivationDecision {
  const ActivationDecision({
    required this.state,
    required this.tippyStageHint,
    required this.allowApp,
    required this.reason,
  });

  final String state;
  final String? tippyStageHint;
  final bool allowApp;
  final String reason;
}

ActivationDecision resolveActivationState({
  required bool isAuthenticated,
  OnboardingDestination? destination,
  String? guestStage,
  bool hasGuestSession = false,
  bool hasFirstGrowthPlan = false,
  String? firstMissionChoice,
}) {
  if (destination?.lifecycle == 'COMPLETE') {
    return ActivationDecision(
      state: 'ACTIVATED',
      tippyStageHint: null,
      allowApp: true,
      reason: destination!.reason,
    );
  }
  if (destination?.lifecycle == 'VERIFY') {
    return ActivationDecision(
      state: 'EMAIL_VERIFICATION_REQUIRED',
      tippyStageHint: destination?.tippyStageHint ?? 'verify_email',
      allowApp: false,
      reason: destination!.reason,
    );
  }
  if (!isAuthenticated) {
    final String stage = (guestStage ?? '').trim();
    if (!hasGuestSession && stage.isEmpty) {
      return const ActivationDecision(
        state: 'NEW',
        tippyStageHint: 'welcome',
        allowApp: false,
        reason: 'no_session',
      );
    }
    if (stage == 'signup') {
      return const ActivationDecision(
        state: 'ACCOUNT_REQUIRED',
        tippyStageHint: 'signup',
        allowApp: false,
        reason: 'guest_needs_account',
      );
    }
    return ActivationDecision(
      state: 'GUEST_PERSONALIZATION',
      tippyStageHint: stage.isEmpty ? 'welcome' : stage,
      allowApp: false,
      reason: stage == 'dna_reveal' ? 'guest_dna_reveal' : 'guest_personalization',
    );
  }
  final String stage = (destination?.tippyStageHint ?? guestStage ?? 'welcome')
      .trim();
  if (destination?.reason == 'identity_recycled_restart') {
    final bool restartingGuest = stage.isEmpty ||
        stage == 'welcome' ||
        stage == 'questions' ||
        stage == 'dna_reveal' ||
        stage == 'signup';
    if (restartingGuest) {
      return ActivationDecision(
        state: 'GUEST_PERSONALIZATION',
        tippyStageHint: stage.isEmpty ? 'welcome' : stage,
        allowApp: false,
        reason: destination!.reason,
      );
    }
  }
  // firstMissionChoice alone never ACTIVATES. Require lifecycle COMPLETE.
  if (stage == 'verify_email') {
    return ActivationDecision(
      state: 'EMAIL_VERIFICATION_REQUIRED',
      tippyStageHint: 'verify_email',
      allowApp: false,
      reason: destination?.reason ?? 'needs_verify',
    );
  }
  if (_identityStages.contains(stage)) {
    return ActivationDecision(
      state: 'CREATOR_IDENTITY',
      tippyStageHint: stage,
      allowApp: false,
      reason: destination?.reason ?? 'creator_identity',
    );
  }
  if (stage == 'creator_space_ready') {
    return ActivationDecision(
      state: 'FIRST_GROWTH_PLAN',
      tippyStageHint: 'creator_space_ready',
      allowApp: false,
      reason: hasFirstGrowthPlan
          ? 'awaiting_first_growth_plan'
          : 'signed_in_analysis',
    );
  }
  if (stage == 'first_mission') {
    return const ActivationDecision(
      state: 'FIRST_MISSION',
      tippyStageHint: 'first_mission',
      allowApp: false,
      reason: 'awaiting_first_mission',
    );
  }
  return ActivationDecision(
    state: 'CREATOR_IDENTITY',
    tippyStageHint: _identityStages.contains(stage) ? stage : 'account_secured',
    allowApp: false,
    reason: destination?.reason ?? 'authenticated_identity',
  );
}

const Map<String, int> kActivationStateRank = <String, int>{
  'NEW': 0,
  'GUEST_PERSONALIZATION': 10,
  'ACCOUNT_REQUIRED': 20,
  'EMAIL_VERIFICATION_REQUIRED': 30,
  'CREATOR_IDENTITY': 40,
  'FIRST_GROWTH_PLAN': 50,
  'TIPPY_INITIAL_ANALYSIS': 50,
  'FIRST_MISSION': 60,
  'ACTIVATED': 70,
};

bool isActivated(String? state) => state == 'ACTIVATED';

bool isFirstMissionResolvedChoice(String? choice) =>
    choice == 'accept' || choice == 'skip';

/// First-mission accept/skip does NOT grant ACTIVATED by itself.
/// Only status.lifecycle COMPLETE / activationState ACTIVATED does.
bool canCommitFirstMissionActivation({
  required bool attachActivated,
  required bool statusAllowApp,
  String? statusActivationState,
  String? statusReason,
  String? firstMissionChoice,
}) {
  if (attachActivated ||
      statusAllowApp ||
      isActivated(statusActivationState)) {
    return true;
  }
  return false;
}

bool shouldContinueActivation(String? state) => !isActivated(state);

bool canActivationMove(String from, String to, {String? reason}) {
  if (reason == 'identity_recycled_restart') {
    return true;
  }
  final String fromKey =
      from == 'TIPPY_INITIAL_ANALYSIS' ? 'FIRST_GROWTH_PLAN' : from;
  final String toKey =
      to == 'TIPPY_INITIAL_ANALYSIS' ? 'FIRST_GROWTH_PLAN' : to;
  final int fromRank = kActivationStateRank[fromKey] ?? 0;
  final int toRank = kActivationStateRank[toKey] ?? 0;
  return toRank >= fromRank;
}
