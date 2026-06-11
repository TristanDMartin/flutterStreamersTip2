import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/onboarding_tester_config.dart';

void main() {
  group('OnboardingTesterConfig', () {
    test('matches username tester', () {
      expect(
        OnboardingTesterConfig.isTesterUser(
          userId: 'uid-123',
          username: 'tester',
        ),
        isTrue,
      );
    });

    test('matches configured tester email', () {
      expect(
        OnboardingTesterConfig.isTesterUser(
          userId: 'uid-123',
          email: 'tester@streamerstip.com',
        ),
        isTrue,
      );
    });

    test('matches contact tester email from default csv', () {
      expect(
        OnboardingTesterConfig.isTesterUser(
          userId: 'uid-123',
          email: 'contact@streamerstip.com',
        ),
        isTrue,
      );
    });

    test('matches tester display name', () {
      expect(
        OnboardingTesterConfig.isTesterUser(
          userId: 'uid-123',
          displayName: 'Tester',
        ),
        isTrue,
      );
    });

    test('matches streamerstiptester username from default csv', () {
      expect(
        OnboardingTesterConfig.isTesterUser(
          userId: 'uid-123',
          username: 'streamerstiptester',
        ),
        isTrue,
      );
    });

    test('does not match regular users', () {
      expect(
        OnboardingTesterConfig.isTesterUser(
          userId: 'uid-123',
          email: 'creator@example.com',
          username: 'mychannel',
        ),
        isFalse,
      );
    });
  });
}
