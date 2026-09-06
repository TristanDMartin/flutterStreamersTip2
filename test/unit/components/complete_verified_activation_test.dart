import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/account_navigation.dart';
import 'package:streamers_tip/components/onboarding/account_status_client.dart';
import 'package:streamers_tip/components/onboarding/complete_verified_activation.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_contract.dart';

void main() {
  group('verified activation experience', () {
    test('retries one 5xx then 400ms', () {
      expect(kVerifiedActivationRetryDelaysMs, <int>[0, 400]);
    });

    test('is not ready until activationState can route', () {
      expect(
        isVerifiedActivationReady(
          activationState: 'EMAIL_VERIFICATION_REQUIRED',
          tippyStageHint: 'verify_email',
        ),
        isFalse,
      );
      expect(
        isVerifiedActivationReady(
          activationState: 'CREATOR_IDENTITY',
          tippyStageHint: 'account_secured',
        ),
        isFalse,
      );
      expect(
        isVerifiedActivationReady(
          activationState: 'CREATOR_IDENTITY',
          tippyStageHint: 'account_secured',
          provisioned: true,
        ),
        isTrue,
      );
    });

    test('never routes successful verification to Meet Tippy', () {
      final AccountNavigation nav = navigationFromAccountStatus(
        activationState: 'CREATOR_IDENTITY',
        tippyStageHint: 'welcome',
      );
      expect(nav.route, 'onboarding');
      expect(nav.tippyStageHint, 'account_secured');
      expect(
        TippyOnboardingStages.resumeStage(
          currentStage: TippyOnboardingStages.verifyEmail,
          proposedStage: nav.tippyStageHint,
        ),
        TippyOnboardingStages.accountSecured,
      );
    });

    test('retries temporary delay then returns identity status', () async {
      final List<int> waits = <int>[];
      int attempts = 0;
      int refreshes = 0;
      final AccountStatusSnapshot status =
          await runVerifiedActivationReconciliation(
        intendedUid: 'uid-1',
        reloadAndRefresh: ({bool forceRefresh = false}) async {
          refreshes += 1;
          return const VerifiedActivationSession(
            uid: 'uid-1',
            emailVerified: true,
          );
        },
        provision: (String uid) async {
          expect(uid, 'uid-1');
          attempts += 1;
          if (attempts == 1) {
            throw const VerifiedActivationException(
              code: 'PROVISION_FAILED',
              status: 500,
            );
          }
        },
        getStatus: () async {
          return const AccountStatusSnapshot(
            activationState: 'CREATOR_IDENTITY',
            tippyStageHint: 'account_secured',
            allowApp: false,
            lifecycle: 'ONBOARDING',
            username: 'keptname',
            preferredUsername: 'keptname',
            provisioned: true,
          );
        },
        wait: (int ms) async => waits.add(ms),
      );
      expect(refreshes, 3);
      expect(attempts, 2);
      expect(status.activationState, 'CREATOR_IDENTITY');
      expect(status.username, 'keptname');
      expect(waits, <int>[400]);
    });

    test('treats already-provisioned as success', () async {
      final AccountStatusSnapshot status =
          await runVerifiedActivationReconciliation(
        reloadAndRefresh: ({bool forceRefresh = false}) async =>
            const VerifiedActivationSession(
          uid: 'uid-1',
          emailVerified: true,
        ),
        provision: (_) async {},
        getStatus: () async => const AccountStatusSnapshot(
          activationState: 'CREATOR_IDENTITY',
          tippyStageHint: 'username',
          allowApp: false,
          lifecycle: 'ONBOARDING',
          username: 'keptname',
          provisioned: true,
        ),
        wait: (_) async {},
      );
      expect(
        isVerifiedActivationReady(
          activationState: status.activationState,
          tippyStageHint: status.tippyStageHint,
          provisioned: status.provisioned,
        ),
        isTrue,
      );
    });

    test('does not retry identity mismatch', () async {
      await expectLater(
        runVerifiedActivationReconciliation(
          reloadAndRefresh: ({bool forceRefresh = false}) async =>
              const VerifiedActivationSession(
            uid: 'uid-1',
            emailVerified: true,
          ),
          provision: (_) async {
            throw const VerifiedActivationException(
              code: 'IDENTITY_MISMATCH',
              status: 403,
            );
          },
          getStatus: () async {
            fail('should not status');
          },
          wait: (_) async {},
        ),
        throwsA(
          isA<VerifiedActivationException>().having(
            (VerifiedActivationException e) => e.code,
            'code',
            'IDENTITY_MISMATCH',
          ),
        ),
      );
    });

    test('does not retry signup block or 429', () {
      expect(
        isRetryableVerifiedActivationFailure(
          code: 'SIGNUP_BLOCKED',
          status: 403,
        ),
        isFalse,
      );
      expect(
        isRetryableVerifiedActivationFailure(
          code: 'EMAIL_VERIFICATION_REQUIRED',
          status: 403,
        ),
        isFalse,
      );
      expect(
        isRetryableVerifiedActivationFailure(
          code: 'rate_limited',
          status: 429,
        ),
        isFalse,
      );
    });

    test('force-refreshes once for EMAIL_VERIFICATION_REQUIRED then stops',
        () async {
      final List<bool> refreshes = <bool>[];
      await expectLater(
        runVerifiedActivationReconciliation(
          reloadAndRefresh: ({bool forceRefresh = false}) async {
            refreshes.add(forceRefresh);
            return const VerifiedActivationSession(
              uid: 'uid-1',
              emailVerified: true,
            );
          },
          provision: (_) async {
            throw const VerifiedActivationException(
              code: 'EMAIL_VERIFICATION_REQUIRED',
              status: 403,
            );
          },
          getStatus: () async {
            fail('should not status');
          },
          wait: (_) async {},
        ),
        throwsA(
          isA<VerifiedActivationException>().having(
            (VerifiedActivationException e) => e.code,
            'code',
            'EMAIL_VERIFICATION_REQUIRED',
          ),
        ),
      );
      expect(refreshes, <bool>[false, true]);
    });

    test('persistent failure is a real error, not still-finishing copy', () {
      expect(kVerifiedActivationPersistentError.toLowerCase(),
          isNot(contains('still finishing')));
      expect(kVerifiedActivationPersistentError.toLowerCase(),
          isNot(contains('tap')));
      expect(
        isRetryableVerifiedActivationFailure(
          code: 'PROVISION_FAILED',
          status: 500,
        ),
        isTrue,
      );
    });
  });
}
