import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/account_navigation.dart';

void main() {
  group('status-only navigation', () {
    test('routes only from activationState + tippyStageHint', () {
      expect(
        navigationFromAccountStatus(
          activationState: 'ACTIVATED',
          tippyStageHint: 'verify_email',
          allowApp: true,
        ).route,
        'app',
      );
      expect(
        navigationFromAccountStatus(
          activationState: 'EMAIL_VERIFICATION_REQUIRED',
          tippyStageHint: 'verify_email',
        ).route,
        'verify-email',
      );
      final AccountNavigation actual = navigationFromAccountStatus(
        activationState: 'CREATOR_IDENTITY',
        tippyStageHint: 'username',
      );
      expect(actual.route, 'onboarding');
      expect(actual.tippyStageHint, 'username');
    });

    test('does not rewind CREATOR_IDENTITY to Meet Tippy', () {
      final AccountNavigation actual = navigationFromAccountStatus(
        activationState: 'CREATOR_IDENTITY',
        activationReason: 'new_account_starts_tippy',
        tippyStageHint: 'welcome',
      );
      expect(actual.route, 'onboarding');
      expect(actual.tippyStageHint, 'account_secured');
    });

    test('never overlays Tippy for app-routed logged-in users', () {
      expect(shouldShowTippyOnboardingOverlay('app'), isFalse);
      expect(shouldShowTippyOnboardingOverlay(null), isFalse);
      expect(shouldShowTippyOnboardingOverlay('onboarding'), isTrue);
      expect(shouldShowTippyOnboardingOverlay('verify-email'), isTrue);
    });

    test('does not boot MainTabView until ACTIVATED/status app', () {
      expect(
        shouldBootAuthenticatedAppShell(
          activationCommitted: false,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: 'onboarding',
          localOnboardingComplete: false,
        ),
        isFalse,
      );
      expect(
        shouldBootAuthenticatedAppShell(
          activationCommitted: false,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: null,
          localOnboardingComplete: true,
        ),
        isFalse,
      );
      expect(
        shouldShowAuthenticatedOnboardingShell(
          activationCommitted: false,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: 'onboarding',
          localOnboardingComplete: false,
        ),
        isTrue,
      );
      expect(
        shouldBootAuthenticatedAppShell(
          activationCommitted: false,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: 'verify-email',
          localOnboardingComplete: false,
        ),
        isFalse,
      );
      expect(
        shouldBootAuthenticatedAppShell(
          activationCommitted: false,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: null,
          localOnboardingComplete: false,
        ),
        isFalse,
      );
      expect(
        shouldShowAuthenticatedOnboardingShell(
          activationCommitted: false,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: null,
          localOnboardingComplete: false,
        ),
        isTrue,
      );
      expect(
        shouldBootAuthenticatedAppShell(
          activationCommitted: true,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: 'onboarding',
          localOnboardingComplete: false,
        ),
        isTrue,
      );
      expect(
        shouldShowAuthenticatedOnboardingShell(
          activationCommitted: true,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: 'onboarding',
          localOnboardingComplete: false,
        ),
        isFalse,
      );
      expect(
        shouldBootAuthenticatedAppShell(
          activationCommitted: false,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: 'app',
          localOnboardingComplete: false,
        ),
        isTrue,
      );
    });

    test('keeps unverified password signup on verify-email', () {
      expect(
        effectiveOnboardingStatusRoute(
          statusRoute: 'app',
          passwordNeedsVerify: true,
        ),
        'verify-email',
      );
      expect(
        effectiveOnboardingStatusRoute(
          statusRoute: null,
          passwordNeedsVerify: true,
        ),
        'verify-email',
      );
      expect(
        effectiveOnboardingStatusRoute(
          statusRoute: null,
          hasSignupClosedFloor: true,
        ),
        'verify-email',
      );
      expect(
        effectiveOnboardingStatusRoute(
          statusRoute: 'app',
          hasSignupClosedFloor: true,
        ),
        'app',
      );
      expect(
        shouldShowAuthenticatedOnboardingShell(
          activationCommitted: false,
          isTesterSession: false,
          testerSessionDismissed: false,
          statusRoute: effectiveOnboardingStatusRoute(
            statusRoute: null,
            passwordNeedsVerify: true,
          ),
          localOnboardingComplete: true,
        ),
        isTrue,
      );
    });
  });
}
