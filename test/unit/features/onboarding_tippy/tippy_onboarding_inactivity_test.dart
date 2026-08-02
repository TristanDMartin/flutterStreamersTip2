import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_attach_pending.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_contract.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_session.dart';

void main() {
  group('TippyOnboardingGuestSession inactivity restart', () {
    TippyOnboardingGuestSession sessionAt({
      required DateTime updatedAt,
      String stage = TippyOnboardingStages.questions,
      String? landingChoice,
    }) {
      return TippyOnboardingGuestSession(
        schemaVersion: kTippyOnboardingSessionSchemaVersion,
        sessionId: 'tos_test',
        stage: stage,
        questionIndex: 2,
        answers: <String, dynamic>{'q1': 'a'},
        trialIntent: false,
        notificationsChoice: null,
        landingChoice: landingChoice,
        updatedAt: updatedAt,
        completedQuestionsAt: null,
        hasSeenTippyIntro: true,
      );
    }

    test('isInactiveExpired after idle timeout when incomplete', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      final TippyOnboardingGuestSession stale = sessionAt(
        updatedAt: now.subtract(kTippyOnboardingInactivityRestart),
      );
      expect(stale.isInactiveExpired(now: now), isTrue);
    });

    test('isInactiveExpired false within idle window', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      final TippyOnboardingGuestSession fresh = sessionAt(
        updatedAt: now.subtract(const Duration(hours: 1)),
      );
      expect(fresh.isInactiveExpired(now: now), isFalse);
    });

    test('completed landing sessions are never stale', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      final TippyOnboardingGuestSession done = sessionAt(
        updatedAt: now.subtract(const Duration(days: 2)),
        landingChoice: 'explore',
        stage: TippyOnboardingStages.landingChoice,
      );
      expect(done.isInactiveExpired(now: now), isFalse);
    });

    test('tippySessionNeedsResume false when inactive expired', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      final TippyOnboardingGuestSession stale = TippyOnboardingGuestSession(
        schemaVersion: kTippyOnboardingSessionSchemaVersion,
        sessionId: 'tos_test',
        stage: TippyOnboardingStages.findFriends,
        questionIndex: 0,
        answers: <String, dynamic>{'q1': 'a'},
        trialIntent: false,
        notificationsChoice: 'enabled',
        landingChoice: null,
        updatedAt: now.subtract(kTippyOnboardingInactivityRestart),
        completedQuestionsAt: now.subtract(const Duration(hours: 5)),
        hasSeenTippyIntro: true,
      );
      expect(tippySessionNeedsResume(stale, now: now), isFalse);
    });
  });
}
