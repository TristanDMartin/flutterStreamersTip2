import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/apple_sign_in_nonce.dart';

void main() {
  group('apple_sign_in_nonce', () {
    test('generateAppleSignInRawNonce returns requested length', () {
      final String nonce = generateAppleSignInRawNonce(24);
      expect(nonce.length, 24);
    });

    test('generateAppleSignInRawNonce produces unique values', () {
      final String first = generateAppleSignInRawNonce();
      final String second = generateAppleSignInRawNonce();
      expect(first, isNot(equals(second)));
    });

    test('sha256HashForAppleSignIn is stable hex digest', () {
      final String hash = sha256HashForAppleSignIn('test-nonce');
      expect(hash.length, 64);
      expect(hash, sha256HashForAppleSignIn('test-nonce'));
    });
  });
}
