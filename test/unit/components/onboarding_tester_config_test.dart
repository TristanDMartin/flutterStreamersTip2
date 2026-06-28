import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/onboarding_tester_config.dart';

void main() {
  group('OnboardingTesterConfig', () {
    test('isTesterUser is off by default in unit tests', () {
      expect(
        OnboardingTesterConfig.isTesterUser(
          userId: 'uid-123',
          email: 'tester@streamerstip.com',
        ),
        isFalse,
      );
    });

    test('matches username tester via visible matcher', () {
      expect(
        OnboardingTesterConfig.matchesTesterIdentity(
          userId: 'uid-123',
          username: 'tester',
        ),
        isTrue,
      );
    });

    test('matches configured tester email via visible matcher', () {
      expect(
        OnboardingTesterConfig.matchesTesterIdentity(
          userId: 'uid-123',
          email: 'tester@streamerstip.com',
        ),
        isTrue,
      );
    });

    test('matches contact tester email from default csv via visible matcher', () {
      expect(
        OnboardingTesterConfig.matchesTesterIdentity(
          userId: 'uid-123',
          email: 'contact@streamerstip.com',
        ),
        isTrue,
      );
    });

    test('matches tester display name via visible matcher', () {
      expect(
        OnboardingTesterConfig.matchesTesterIdentity(
          userId: 'uid-123',
          displayName: 'Tester',
        ),
        isTrue,
      );
    });

    test('does not match regular users via visible matcher', () {
      expect(
        OnboardingTesterConfig.matchesTesterIdentity(
          userId: 'uid-123',
          email: 'creator@example.com',
          username: 'mychannel',
        ),
        isFalse,
      );
    });

    test('promo data matches firestore eligibility flag', () {
      expect(
        OnboardingTesterConfig.isPromoDataTester(
          userId: 'uid-123',
          email: 'creator@example.com',
          username: 'mychannel',
          promoEligibleFromFirestore: true,
        ),
        isTrue,
      );
    });

    test('promo identity matching is off by default in unit tests', () {
      expect(
        OnboardingTesterConfig.isPromoDataTester(
          userId: 'uid-123',
          username: 'my_tester_account',
        ),
        isFalse,
      );
    });
  });
}
