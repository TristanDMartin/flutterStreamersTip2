import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_attach_pending.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_contract.dart';

void main() {
  group('isReturningCompleteTippyUserFromData', () {
    test('does not treat recycled identity + username as complete', () {
      final bool actualX = isReturningCompleteTippyUserFromData(
        <String, dynamic>{
          'identityRecycled': true,
          'username': 'samehandle',
          'hasCompletedOnboarding': true,
          'onboarding': <String, dynamic>{
            'completed': true,
            'landingChoice': 'recommended',
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': false,
            'tippyOnboardingV1Attached': false,
            'slim7Completed': false,
          },
        },
      );
      expect(actualX, isFalse);
    });

    test('treats recycled identity complete only after Tippy on this uid', () {
      final bool actualX = isReturningCompleteTippyUserFromData(
        <String, dynamic>{
          'identityRecycled': true,
          'username': 'samehandle',
          'onboarding': <String, dynamic>{
            'tippyFunnelCompleted': true,
            'essentialProfileComplete': true,
          },
        },
      );
      expect(actualX, isTrue);
    });

    test('keeps established Google accounts complete', () {
      final bool actualX = isReturningCompleteTippyUserFromData(
        <String, dynamic>{
          'username': 'oldcreator',
          'onboarding': <String, dynamic>{
            'tippyFunnelCompleted': true,
            'essentialProfileComplete': true,
          },
        },
      );
      expect(actualX, isTrue);
    });
  });

  group('shouldSkipPendingTippyAttach', () {
    test('does not skip attach for recycled identity with username', () {
      final bool actualX = shouldSkipPendingTippyAttach(
        userData: <String, dynamic>{
          'identityRecycled': true,
          'username': 'samehandle',
          'onboarding': <String, dynamic>{
            'creatorCardCompleted': true,
            'essentialProfileComplete': true,
            'tippyFunnelCompleted': false,
          },
        },
        sessionStage: TippyOnboardingStages.questions,
      );
      expect(actualX, isFalse);
    });

    test('skips attach for established creator mid-quiz leftovers', () {
      final bool actualX = shouldSkipPendingTippyAttach(
        userData: <String, dynamic>{
          'username': 'oldcreator',
          'onboarding': <String, dynamic>{
            'creatorCardCompleted': true,
            'essentialProfileComplete': true,
            'tippyOnboardingV1Attached': false,
          },
        },
        sessionStage: TippyOnboardingStages.questions,
      );
      expect(actualX, isTrue);
    });
  });
}
