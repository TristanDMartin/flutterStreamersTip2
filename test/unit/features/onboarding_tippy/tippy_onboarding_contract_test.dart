import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_contract.dart';

void main() {
  group('TippyOnboardingContract v1', () {
    test('has exactly seven questions with stable ids', () {
      expect(kTippyOnboardingQuestions.length, kTippyOnboardingTotalQuestions);
      expect(
        kTippyOnboardingQuestions.map((TippyOnboardingQuestion q) => q.id),
        <String>[
          'creator_type',
          'platforms',
          'niche',
          'experience',
          'goals',
          'schedule',
          'content_formats',
        ],
      );
    });

    test('validates single and multi answers', () {
      final TippyOnboardingQuestion creatorType =
          kTippyOnboardingQuestions.first;
      expect(isValidTippyOnboardingAnswer(creatorType, 'streamer'), isTrue);
      expect(isValidTippyOnboardingAnswer(creatorType, 'nope'), isFalse);
      final TippyOnboardingQuestion platforms =
          tippyOnboardingQuestionById('platforms')!;
      expect(
        isValidTippyOnboardingAnswer(platforms, <String>['twitch', 'youtube']),
        isTrue,
      );
      expect(
        isValidTippyOnboardingAnswer(platforms, <String>[]),
        isFalse,
      );
    });

    test('stage next advances through funnel', () {
      expect(
        TippyOnboardingStages.next(TippyOnboardingStages.welcome),
        TippyOnboardingStages.questions,
      );
      expect(
        TippyOnboardingStages.next(TippyOnboardingStages.landingChoice),
        isNull,
      );
    });
  });
}
