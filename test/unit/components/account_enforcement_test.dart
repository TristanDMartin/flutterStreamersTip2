import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/account_enforcement.dart';

void main() {
  group('resolveAccountEnforcement', () {
    test('routes active and legacy-active to the app', () {
      expect(resolveAccountEnforcement('active').destination, 'app');
      expect(resolveAccountEnforcement('').legacyActive, isTrue);
      expect(resolveAccountEnforcement(null).canEnterApp, isTrue);
    });

    test('routes banned and legacy suspended to Account Suspended', () {
      expect(resolveAccountEnforcement('banned').destination, 'banned');
      expect(resolveAccountEnforcement('suspended').destination, 'banned');
      expect(resolveAccountEnforcement('disabled').canEnterApp, isFalse);
    });

    test('routes deactivated deleting and deleted separately', () {
      expect(
        resolveAccountEnforcement('deactivated').destination,
        'deactivated',
      );
      expect(resolveAccountEnforcement('deleting').destination, 'unavailable');
      expect(resolveAccountEnforcement('deleted').destination, 'deleted');
    });

    test('does not treat relationship blocked as accountStatus', () {
      expect(isRelationshipBlockLabel('blocked'), isTrue);
      final AccountEnforcementResult actual =
          resolveAccountEnforcement('blocked');
      expect(actual.destination, 'app');
      expect(actual.canEnterApp, isTrue);
      expect(actual.reason, kRelationshipBlockIsNotAccountStatus);
    });

    test('does not invent probation', () {
      expect(resolveAccountEnforcement('probation').destination, 'unavailable');
      expect(kCanonicalAccountStatuses.contains('probation'), isFalse);
    });
  });

  group('signup restriction reasons', () {
    test('maps disposable network device rate and risk', () {
      expect(
        mapSignupRestrictionReason(code: 'DISPOSABLE_EMAIL'),
        'disposable_email',
      );
      expect(
        mapSignupRestrictionReason(
          code: 'SIGNUP_BLOCKED',
          reasons: <String>['ip_velocity_high'],
        ),
        'network_temporarily_restricted',
      );
      expect(
        mapSignupRestrictionReason(
          code: 'SIGNUP_BLOCKED',
          reasons: <String>['device_velocity_high'],
          restrictionKind: 'device',
        ),
        'device_temporarily_restricted',
      );
      expect(
        mapSignupRestrictionReason(
          code: 'SIGNUP_CHALLENGE_REQUIRED',
          decision: 'CHALLENGE',
        ),
        'risk_review',
      );
    });

    test('uses honest restriction copy not banned', () {
      final ({String reason, String message}) actual =
          messageFromSignupRestriction(
        code: 'SIGNUP_BLOCKED',
        reasons: <String>['ip_restriction'],
      );
      expect(
        actual.message,
        'Account creation is temporarily restricted from this network. Please try again later.',
      );
      expect(actual.message.toLowerCase().contains('banned'), isFalse);
    });
  });

  test('banned screen copy is canonical', () {
    expect(kBannedAccountTitle, 'Account suspended');
    expect(
      kBannedAccountBody,
      'Your StreamersTip account has been suspended because it did not meet our Community Guidelines or Terms of Service.',
    );
  });
}
