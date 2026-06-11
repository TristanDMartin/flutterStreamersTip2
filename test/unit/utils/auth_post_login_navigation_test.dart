import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/auth_post_login_navigation.dart';

void main() {
  group('authProvidersNeedEmailVerification', () {
    test('requires verification for an unverified password account', () {
      expect(
        authProvidersNeedEmailVerification(
          emailVerified: false,
          providerIds: const <String>['password'],
        ),
        isTrue,
      );
    });

    test('does not block an Apple account', () {
      expect(
        authProvidersNeedEmailVerification(
          emailVerified: false,
          providerIds: const <String>['apple.com'],
        ),
        isFalse,
      );
    });

    test('does not block a Google account', () {
      expect(
        authProvidersNeedEmailVerification(
          emailVerified: false,
          providerIds: const <String>['google.com'],
        ),
        isFalse,
      );
    });

    test('does not block an already verified account', () {
      expect(
        authProvidersNeedEmailVerification(
          emailVerified: true,
          providerIds: const <String>['password'],
        ),
        isFalse,
      );
    });
  });
}
