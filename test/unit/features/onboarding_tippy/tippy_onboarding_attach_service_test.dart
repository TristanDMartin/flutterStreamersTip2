import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_attach_service.dart';

void main() {
  group('parseTippyOnboardingAttachPayload', () {
    test('reads top-level activation fields', () {
      final TippyOnboardingAttachResult actual =
          parseTippyOnboardingAttachPayload(<String, dynamic>{
        'success': true,
        'attached': true,
        'activationState': 'ACTIVATED',
        'allowApp': true,
        'firstGrowthPlanId': 'plan_1',
      });
      expect(actual.ok, isTrue);
      expect(actual.isActivated, isTrue);
      expect(actual.firstGrowthPlanId, 'plan_1');
    });

    test('unwraps nested Cloud Function payloads', () {
      final TippyOnboardingAttachResult actual =
          parseTippyOnboardingAttachPayload(<String, dynamic>{
        'result': <String, dynamic>{
          'success': true,
          'activationState': 'ACTIVATED',
          'allowApp': true,
        },
      });
      expect(actual.isActivated, isTrue);
    });

    test('treats empty 200 bodies as not activated', () {
      final TippyOnboardingAttachResult actual =
          parseTippyOnboardingAttachPayload(<String, dynamic>{});
      expect(actual.ok, isFalse);
      expect(actual.isActivated, isFalse);
    });
  });

  group('stale attach retry', () {
    test('retries 409 when startedFromWelcome was not sent', () {
      expect(
        shouldRetryStaleOnboardingAttach(
          statusCode: 409,
          startedFromWelcomeAlreadySent: false,
        ),
        isTrue,
      );
    });

    test('does not retry 409 after startedFromWelcome was sent', () {
      expect(
        shouldRetryStaleOnboardingAttach(
          statusCode: 409,
          startedFromWelcomeAlreadySent: true,
        ),
        isFalse,
      );
    });

    test('detects stale from 409 and error text', () {
      expect(
        isStaleOnboardingAttach(
          statusCode: 409,
          message: 'STALE_ONBOARDING_SESSION: start Tippy from Welcome',
        ),
        isTrue,
      );
      expect(
        isStaleOnboardingAttach(statusCode: 200, message: 'ok'),
        isFalse,
      );
    });
  });
}
