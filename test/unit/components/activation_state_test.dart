import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/components/onboarding/activation_state.dart';
import 'package:streamers_tip/components/onboarding/resolve_onboarding_destination.dart';

OnboardingDestination destination({
  required String lifecycle,
  required String reason,
  String? tippyStageHint,
  bool allowApp = false,
}) {
  return OnboardingDestination(
    lifecycle: lifecycle,
    tippyStageHint: tippyStageHint,
    allowApp: allowApp,
    reason: reason,
    photoStatus: 'unknown',
    isLegacyComplete: false,
  );
}

void main() {
  group('resolveActivationState', () {
    test('starts NEW guests at welcome', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: false,
      );
      expect(actual.state, 'NEW');
      expect(actual.tippyStageHint, 'welcome');
      expect(actual.allowApp, isFalse);
    });

    test('keeps guest DNA including dna_reveal in GUEST_PERSONALIZATION', () {
      final ActivationDecision questions = resolveActivationState(
        isAuthenticated: false,
        hasGuestSession: true,
        guestStage: 'questions',
      );
      expect(questions.state, 'GUEST_PERSONALIZATION');
      final ActivationDecision reveal = resolveActivationState(
        isAuthenticated: false,
        hasGuestSession: true,
        guestStage: 'dna_reveal',
      );
      expect(reveal.state, 'GUEST_PERSONALIZATION');
      expect(reveal.state, kGuestDnaRevealActivationState);
      expect(reveal.tippyStageHint, 'dna_reveal');
    });

    test('requires an account after DNA', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: false,
        hasGuestSession: true,
        guestStage: 'signup',
      );
      expect(actual.state, 'ACCOUNT_REQUIRED');
    });

    test('blocks unverified email', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'VERIFY',
          reason: 'needs_verify',
          tippyStageHint: 'verify_email',
        ),
      );
      expect(actual.state, 'EMAIL_VERIFICATION_REQUIRED');
      expect(actual.allowApp, isFalse);
    });

    test('maps identity stages to CREATOR_IDENTITY', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'TIPPY',
          reason: 'tippy_in_progress',
          tippyStageHint: 'username',
        ),
      );
      expect(actual.state, 'CREATOR_IDENTITY');
    });

    test('does not skip TIPPY_INITIAL_ANALYSIS before the first plan exists', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'TIPPY',
          reason: 'tippy_in_progress',
          tippyStageHint: 'creator_space_ready',
        ),
        hasFirstGrowthPlan: false,
      );
      expect(actual.state, 'TIPPY_INITIAL_ANALYSIS');
      expect(actual.state, kSignedInAnalysisBeginsAt);
    });

    test('moves to FIRST_GROWTH_PLAN once the canonical plan exists', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'TIPPY',
          reason: 'tippy_in_progress',
          tippyStageHint: 'creator_space_ready',
        ),
        hasFirstGrowthPlan: true,
      );
      expect(actual.state, 'FIRST_GROWTH_PLAN');
    });

    test('completed accounts stay ACTIVATED even with a guest session', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'COMPLETE',
          reason: 'sticky_complete',
          allowApp: true,
        ),
        hasGuestSession: true,
        guestStage: 'welcome',
      );
      expect(actual.state, 'ACTIVATED');
      expect(actual.allowApp, isTrue);
    });

    test('deleted identities restart from welcome', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'TIPPY',
          reason: 'identity_recycled_restart',
          tippyStageHint: 'welcome',
        ),
      );
      expect(actual.state, 'GUEST_PERSONALIZATION');
      expect(actual.tippyStageHint, 'welcome');
      expect(actual.allowApp, isFalse);
    });

    test('verified recycled identities continue creator identity', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'TIPPY',
          reason: 'identity_recycled_restart',
          tippyStageHint: 'account_secured',
        ),
      );
      expect(actual.state, 'CREATOR_IDENTITY');
      expect(actual.tippyStageHint, 'account_secured');
      expect(actual.allowApp, isFalse);
    });

    test('first mission accept is ACTIVATED even with a leftover first_mission hint', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'TIPPY',
          reason: 'tippy_in_progress',
          tippyStageHint: 'first_mission',
        ),
        firstMissionChoice: 'accept',
      );
      expect(actual.state, 'ACTIVATED');
      expect(actual.allowApp, isTrue);
    });

    test('leftover first mission choice does not activate a recycled identity', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'TIPPY',
          reason: 'identity_recycled_restart',
          tippyStageHint: 'welcome',
        ),
        firstMissionChoice: 'accept',
      );
      expect(actual.state, 'GUEST_PERSONALIZATION');
      expect(actual.allowApp, isFalse);
    });

    test('first mission persist can enter the app when attach omitted activation', () {
      expect(
        canCommitFirstMissionActivation(
          attachActivated: false,
          statusAllowApp: false,
          statusActivationState: 'CREATOR_IDENTITY',
          statusReason: 'new_account_starts_tippy',
          firstMissionChoice: 'accept',
        ),
        isTrue,
      );
      expect(
        canCommitFirstMissionActivation(
          attachActivated: false,
          statusAllowApp: false,
          statusActivationState: 'CREATOR_IDENTITY',
          statusReason: 'identity_recycled_restart',
          firstMissionChoice: 'accept',
        ),
        isFalse,
      );
    });

    test('never maps a verified account to Meet Tippy from a stale welcome hint', () {
      final ActivationDecision actual = resolveActivationState(
        isAuthenticated: true,
        destination: destination(
          lifecycle: 'TIPPY',
          reason: 'new_account_starts_tippy',
          tippyStageHint: 'welcome',
        ),
      );
      expect(actual.state, 'CREATOR_IDENTITY');
      expect(actual.tippyStageHint, 'account_secured');
    });
  });
}
