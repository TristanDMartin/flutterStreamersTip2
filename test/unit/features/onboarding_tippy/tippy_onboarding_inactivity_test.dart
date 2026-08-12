import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_attach_pending.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_contract.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_session.dart';

void main() {
  group('TippyOnboardingGuestSession progress persistence', () {
    TippyOnboardingGuestSession sessionAt({
      required DateTime updatedAt,
      String stage = TippyOnboardingStages.questions,
      String? landingChoice,
      int questionIndex = 2,
      Map<String, dynamic>? answers,
    }) {
      return TippyOnboardingGuestSession(
        schemaVersion: kTippyOnboardingSessionSchemaVersion,
        sessionId: 'tos_test',
        stage: stage,
        questionIndex: questionIndex,
        answers: answers ?? <String, dynamic>{'q1': 'a'},
        trialIntent: false,
        notificationsChoice: null,
        landingChoice: landingChoice,
        updatedAt: updatedAt,
        completedQuestionsAt: null,
        hasSeenTippyIntro: true,
      );
    }

    test('isInactiveExpired never clears incomplete progress', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      final TippyOnboardingGuestSession stale = sessionAt(
        updatedAt: now.subtract(const Duration(days: 30)),
      );
      expect(stale.isInactiveExpired(now: now), isFalse);
    });

    test('mid-quiz sessions still need resume after a day', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      final TippyOnboardingGuestSession mid = sessionAt(
        updatedAt: now.subtract(const Duration(days: 1)),
      );
      expect(tippySessionNeedsResume(mid, now: now), isTrue);
      expect(mid.hasMeaningfulProgress, isTrue);
    });

    test('completed landing sessions do not need resume', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      final TippyOnboardingGuestSession done = sessionAt(
        updatedAt: now.subtract(const Duration(days: 2)),
        landingChoice: 'explore',
        stage: TippyOnboardingStages.landingChoice,
      );
      expect(tippySessionNeedsResume(done, now: now), isFalse);
    });

    test('empty welcome session does not count as resume', () {
      final TippyOnboardingGuestSession empty =
          TippyOnboardingGuestSession.empty();
      expect(empty.hasMeaningfulProgress, isFalse);
      expect(tippySessionNeedsResume(empty), isFalse);
    });
  });
}
