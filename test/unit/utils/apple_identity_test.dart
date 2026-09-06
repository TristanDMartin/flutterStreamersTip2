import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/apple_identity.dart';

void main() {
  group('apple identity', () {
    test('detects Hide My Email relay addresses', () {
      expect(
        isApplePrivateRelayEmail('abc123@privaterelay.appleid.com'),
        isTrue,
      );
      expect(isApplePrivateRelayEmail('creator@gmail.com'), isFalse);
    });

    test('persists name and email only when existing profile is empty', () {
      final AppleFirstAuthPersist first = shouldPersistAppleFirstAuthFields(
        existingDisplayName: null,
        incomingDisplayName: 'Avery Lee',
        existingEmail: null,
        incomingEmail: 'abc@privaterelay.appleid.com',
      );
      expect(first.persistDisplayName, 'Avery Lee');
      expect(first.persistEmail, 'abc@privaterelay.appleid.com');

      final AppleFirstAuthPersist returning = shouldPersistAppleFirstAuthFields(
        existingDisplayName: 'Creator',
        incomingDisplayName: 'Avery Lee',
        existingEmail: 'old@example.com',
        incomingEmail: 'abc@privaterelay.appleid.com',
      );
      expect(returning.persistDisplayName, isNull);
      expect(returning.persistEmail, isNull);
    });
  });
}
