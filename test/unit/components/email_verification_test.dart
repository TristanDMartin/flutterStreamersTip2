import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/email_verification.dart';
import 'package:streamers_tip/components/onboarding/email_verification_sender.dart';

void main() {
  group('email verification origin', () {
    test('allows localhost and production hosts', () {
      expect(isAllowedVerificationOrigin('http://localhost:3000'), isTrue);
      expect(isAllowedVerificationOrigin('https://streamerstip.com'), isTrue);
      expect(
        isAllowedVerificationOrigin('https://www.streamerstip.com'),
        isTrue,
      );
    });

    test('rejects untrusted continue origins', () {
      expect(isAllowedVerificationOrigin('https://evil.example'), isFalse);
      expect(
        () => resolveVerificationContinueOrigin('https://evil.example'),
        throwsA(isA<StateError>()),
      );
    });

    test('release builds ignore localhost continue origin', () {
      expect(
        resolveAppEmailVerificationOrigin(
          configuredOrigin: 'http://localhost:3000',
          isDebug: false,
          isWeb: false,
          siteApiBase: 'https://streamerstip.com',
        ),
        'https://streamerstip.com',
      );
    });

    test('debug builds default to localhost, never production', () {
      expect(
        resolveAppEmailVerificationOrigin(
          configuredOrigin: '',
          isDebug: true,
          isWeb: false,
          siteApiBase: 'https://streamerstip.com',
        ),
        'http://localhost:3000',
      );
      expect(
        resolveAppEmailVerificationOrigin(
          configuredOrigin: 'https://streamerstip.com',
          isDebug: true,
          isWeb: false,
        ),
        'https://streamerstip.com',
      );
    });

    test('builds localhost continue URL with intent uid', () {
      expect(
        buildEmailVerificationContinueUrl(
          origin: 'http://localhost:3000',
          intentUid: 'uid-a',
        ),
        'http://localhost:3000/verify-email?intent=uid-a&return=%2Fonboarding',
      );
    });

    test('keeps resume path on the signup origin', () {
      expect(
        buildEmailVerificationContinueUrl(
          origin: 'http://localhost:3000',
          intentUid: 'uid-a',
          resumePath: '/onboarding',
        ),
        'http://localhost:3000/verify-email?intent=uid-a&return=%2Fonboarding',
      );
      expect(sanitizeVerificationResumePath('https://evil.example'), isEmpty);
      expect(sanitizeVerificationResumePath('//evil.example'), isEmpty);
    });
  });

  group('evaluateVerificationIdentity', () {
    test('is ready only for the signup uid', () {
      expect(
        evaluateVerificationIdentity(
          intendedUid: 'uid-a',
          intendedEmail: 'a@example.com',
          currentUid: 'uid-a',
          currentEmail: 'A@example.com',
          emailVerified: true,
        ).status,
        VerificationIdentityStatus.ready,
      );
    });

    test('blocks a different signed-in account', () {
      final VerificationIdentityResult actual = evaluateVerificationIdentity(
        intendedUid: 'uid-a',
        intendedEmail: 'a@example.com',
        currentUid: 'uid-b',
        currentEmail: 'b@example.com',
        emailVerified: true,
      );
      expect(actual.status, VerificationIdentityStatus.mismatch);
      expect(actual.reason, 'uid');
    });

    test('does not adopt the active session as the intended owner', () {
      final ({String uid, String email}) intended =
          resolveVerificationIntentOwner(
        queryIntentUid: 'uid-a',
        actionEmail: 'a@example.com',
      );
      expect(intended.uid, 'uid-a');
      expect(
        evaluateVerificationIdentity(
          intendedUid: intended.uid,
          intendedEmail: intended.email,
          currentUid: 'uid-b',
          currentEmail: 'b@example.com',
          emailVerified: true,
        ).status,
        VerificationIdentityStatus.mismatch,
      );
    });

    test('stays notVerified until reload reports verified', () {
      expect(
        evaluateVerificationIdentity(
          intendedUid: 'uid-a',
          intendedEmail: 'a@example.com',
          currentUid: 'uid-a',
          currentEmail: 'a@example.com',
          emailVerified: false,
        ).status,
        VerificationIdentityStatus.notVerified,
      );
    });
  });

  group('recycled verification identity', () {
    test('adopts the live uid when the same email was recreated', () {
      expect(
        shouldAdoptCurrentUserForRecycledIntent(
          intendedUid: 'uid-old',
          intendedEmail: 'beacon1606@gmail.com',
          currentUid: 'uid-new',
          currentEmail: 'beacon1606@gmail.com',
          currentEmailVerified: false,
        ),
        isTrue,
      );
    });

    test('does not adopt a different verified account', () {
      expect(
        shouldAdoptCurrentUserForRecycledIntent(
          intendedUid: 'verification-target-uid',
          intendedEmail: 'verification-target@example.com',
          currentUid: 'existing-primary-uid',
          currentEmail: 'existing-primary@example.com',
          currentEmailVerified: true,
        ),
        isFalse,
      );
    });

    test('prefers the live signup over a stale continue-url uid', () {
      final ({String uid, String email}) actual = selectVerificationIntentOwner(
        queryIntentUid: 'uid-old',
        storedUid: 'uid-new',
        storedEmail: 'beacon1606@gmail.com',
        currentUid: 'uid-new',
        currentEmail: 'beacon1606@gmail.com',
      );
      expect(actual.uid, 'uid-new');
      expect(actual.email, 'beacon1606@gmail.com');
    });

    test('prefers server pending intent over a stale query uid', () {
      final ({String uid, String email}) actual = selectVerificationIntentOwner(
        queryIntentUid: 'deleted-uid',
        storedUid: 'deleted-uid',
        storedEmail: 'beacon1606@gmail.com',
        currentUid: 'uid-new',
        currentEmail: 'beacon1606@gmail.com',
        serverIntentUid: 'uid-new',
        serverIntentEmail: 'beacon1606@gmail.com',
      );
      expect(actual.uid, 'uid-new');
      expect(actual.email, 'beacon1606@gmail.com');
    });
  });

  group('mismatch verification session', () {
    test('signed-in account A does not own account B verification link', () {
      final ({String uid, String email}) actual = selectVerificationIntentOwner(
        queryIntentUid: 'verification-target-uid',
        storedUid: 'verification-target-uid',
        storedEmail: 'verification-target@example.com',
        actionEmail: 'verification-target@example.com',
        currentUid: 'existing-primary-uid',
        currentEmail: 'existing-primary@example.com',
        currentEmailVerified: true,
      );
      expect(actual.uid, 'verification-target-uid');
      expect(actual.email, 'verification-target@example.com');
    });
  });

  group('isIntendedVerificationUser', () {
    test('matches uid and email only', () {
      expect(
        isIntendedVerificationUser(
          intendedUid: 'uid-a',
          intendedEmail: 'a@example.com',
          currentUid: 'uid-a',
          currentEmail: 'A@example.com',
        ),
        isTrue,
      );
      expect(
        isIntendedVerificationUser(
          intendedUid: 'uid-a',
          intendedEmail: 'a@example.com',
          currentUid: 'uid-b',
          currentEmail: 'a@example.com',
        ),
        isFalse,
      );
    });
  });

  group('resolveLiveVerificationOwner', () {
    test('adopts the live unverified signup when stored intent is missing', () {
      final ({String uid, String email}) actual = resolveLiveVerificationOwner(
        currentUid: 'uid-new',
        currentEmail: 'beacon1606@gmail.com',
      );
      expect(actual.uid, 'uid-new');
      expect(actual.email, 'beacon1606@gmail.com');
    });

    test('does not adopt a different verified account when stored is empty', () {
      final ({String uid, String email}) actual = resolveLiveVerificationOwner(
        currentUid: 'existing-primary-uid',
        currentEmail: 'existing-primary@example.com',
        currentEmailVerified: true,
      );
      expect(actual.uid, isEmpty);
    });

    test('keeps the stored signup owner when it matches the live user', () {
      final ({String uid, String email}) actual = resolveLiveVerificationOwner(
        storedUid: 'uid-new',
        storedEmail: 'beacon1606@gmail.com',
        currentUid: 'uid-new',
        currentEmail: 'beacon1606@gmail.com',
      );
      expect(actual.uid, 'uid-new');
      expect(actual.email, 'beacon1606@gmail.com');
    });
  });
}
