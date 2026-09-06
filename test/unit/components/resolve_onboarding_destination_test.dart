import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/components/onboarding/resolve_onboarding_destination.dart';

void main() {
  group('resolveOnboardingDestination identity recycle', () {
    test('recycled account that finished Tippy on this UID stays COMPLETE', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'identityRecycled': true,
          'username': 'samehandle',
          'displayName': 'Same Person',
          'onboarding': <String, dynamic>{
            'lifecycle': 'COMPLETE',
            'status': 'completed',
            'completed': true,
            'tippyFunnelCompleted': true,
            'essentialProfileComplete': true,
          },
        },
        emailVerified: true,
        isPasswordProvider: false,
      );
      expect(actual.lifecycle, 'COMPLETE');
      expect(actual.reason, 'sticky_complete');
    });

    test('recycled leftover firstMissionChoice does not sticky-complete', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'identityRecycled': true,
          'username': 'samehandle',
          'onboarding': <String, dynamic>{
            'lifecycle': 'NOT_STARTED',
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': false,
            'creatorCardCompleted': true,
            'firstMissionChoice': 'accept',
            'landingChoice': 'recommended',
            'ignoreLocalResume': true,
            'forceWelcome': true,
          },
        },
        emailVerified: false,
        isPasswordProvider: true,
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.reason, 'identity_recycled_restart');
      expect(actual.allowApp, isFalse);
    });

    test('recycled account without Tippy complete ignores legacy bypass', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'identityRecycled': true,
          'username': 'samehandle',
          'displayName': 'Same Person',
          'hasCompletedOnboarding': true,
          'createdAt': '2025-01-01T00:00:00.000Z',
          'onboarding': <String, dynamic>{
            'status': 'completed',
            'completed': true,
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': false,
          },
        },
        emailVerified: true,
        isPasswordProvider: false,
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'welcome');
      expect(actual.reason, 'identity_recycled_restart');
      expect(actual.allowApp, isFalse);
    });

    test('recycled account with established username alone starts Tippy', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'identityRecycled': true,
          'username': 'recycled_user',
          'displayName': 'Recycled',
          'onboarding': <String, dynamic>{
            'status': 'not_started',
            'completed': false,
          },
        },
        emailVerified: true,
        isPasswordProvider: false,
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'welcome');
      expect(actual.reason, 'identity_recycled_restart');
    });

    test('recycled mid-Tippy on new UID resumes exact stage', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'identityRecycled': true,
          'onboarding': <String, dynamic>{
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': false,
            'ignoreLocalResume': false,
            'forceWelcome': false,
          },
        },
        emailVerified: true,
        isPasswordProvider: false,
        localTippyStage: 'username',
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.reason, 'tippy_in_progress');
      expect(actual.tippyStageHint, 'username');
    });

    test('ignoreLocalResume forces Welcome after account deletion', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'identityRecycled': true,
          'onboarding': <String, dynamic>{
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': false,
            'ignoreLocalResume': true,
            'forceWelcome': true,
            'currentStep': 'WELCOME',
            'completedSteps': <String>[],
          },
        },
        emailVerified: true,
        isPasswordProvider: false,
        localTippyStage: 'username',
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'welcome');
      expect(actual.reason, 'identity_recycled_restart');
      expect(actual.allowApp, isFalse);
    });

    test('verified password recycle does not rewind to Meet Tippy', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'identityRecycled': true,
          'onboarding': <String, dynamic>{
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': false,
            'ignoreLocalResume': true,
            'forceWelcome': true,
          },
        },
        emailVerified: true,
        isPasswordProvider: true,
        localTippyStage: 'verify_email',
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'account_secured');
      expect(actual.reason, 'tippy_in_progress');
    });

    test('verified password new account continues at account_secured', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'username': 'newcreator',
          'onboarding': <String, dynamic>{
            'version': 1,
            'completed': false,
          },
        },
        emailVerified: true,
        isPasswordProvider: true,
        localTippyStage: 'verify_email',
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'account_secured');
      expect(actual.reason, 'new_account_starts_tippy');
    });

    test('verified password without user doc continues at account_secured', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: null,
        emailVerified: true,
        isPasswordProvider: true,
        localTippyStage: 'verify_email',
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'account_secured');
      expect(actual.reason, 'no_user_doc_verified');
    });

    test('verified Google without user doc continues at account_secured', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: null,
        emailVerified: true,
        isPasswordProvider: false,
        localTippyStage: 'welcome',
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'account_secured');
      expect(actual.reason, 'no_user_doc_verified');
    });

    test('does not resume to notifications after the Creator Card exists', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'onboarding': <String, dynamic>{
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': true,
          },
        },
        emailVerified: true,
        isPasswordProvider: false,
        localTippyStage: 'notifications',
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'creator_space_ready');
    });

    test('skips twitch_connect resume when status is SKIPPED', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'onboarding': <String, dynamic>{
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': true,
            'selectedPlatforms': <String>['twitch'],
            'twitchConnectionStatus': 'SKIPPED',
          },
        },
        emailVerified: true,
        isPasswordProvider: false,
      );
      expect(actual.lifecycle, 'TIPPY');
      expect(actual.tippyStageHint, 'creator_space_ready');
    });

    test('first mission accept is COMPLETE even without tippyFunnelCompleted', () {
      final OnboardingDestination actual = resolveOnboardingDestination(
        userData: <String, dynamic>{
          'username': 'doneuser',
          'onboarding': <String, dynamic>{
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': true,
            'firstMissionChoice': 'accept',
          },
        },
        emailVerified: true,
        isPasswordProvider: true,
        localTippyStage: 'first_mission',
      );
      expect(actual.lifecycle, 'COMPLETE');
      expect(actual.allowApp, isTrue);
      expect(actual.tippyStageHint, isNull);
    });
  });
}
