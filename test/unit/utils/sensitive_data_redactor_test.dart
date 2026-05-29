import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/sensitive_data_redactor.dart';

void main() {
  group('SensitiveDataRedactor', () {
    test('redacts 28-char Firebase UID', () {
      const String uid = 'abcdefghijklmnopqrstuvwxyz12';
      final String result = SensitiveDataRedactor.redact('user $uid done');
      expect(result, isNot(contains(uid)));
      expect(result, contains('[redacted]'));
    });

    test('redacts labeled userId', () {
      const String input = 'userId: abcdefghijklmnopqrstuvwxyz12';
      final String result = SensitiveDataRedactor.redact(input);
      expect(result, 'userId: [redacted]');
    });

    test('redacts email addresses', () {
      const String input = 'Contact support@example.com today';
      final String result = SensitiveDataRedactor.redact(input);
      expect(result, isNot(contains('support@example.com')));
      expect(result, contains('[redacted]'));
    });

    test('maskId shows partial id', () {
      expect(
        SensitiveDataRedactor.maskId('abcdefghijklmnopqrstuvwxyz12'),
        'abcd…yz12',
      );
    });

    test('looksLikeFirebaseUid detects standard uid', () {
      expect(
        SensitiveDataRedactor.looksLikeFirebaseUid(
          'abcdefghijklmnopqrstuvwxyz12',
        ),
        isTrue,
      );
      expect(SensitiveDataRedactor.looksLikeFirebaseUid('short'), isFalse);
    });
  });
}
