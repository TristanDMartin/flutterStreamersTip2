import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/core/backend/firebase_https_function_url.dart';

void main() {
  group('resolveFirebaseHttpsFunctionUrl', () {
    test('prefers explicit override', () {
      final String actual = resolveFirebaseHttpsFunctionUrl(
        explicitOverride: 'https://custom.example/tippyApi',
        envDefineValue: 'https://env.example/tippyApi',
        functionName: 'tippyApi',
      );
      expect(actual, 'https://custom.example/tippyApi');
    });

    test('uses env when explicit is empty', () {
      final String actual = resolveFirebaseHttpsFunctionUrl(
        explicitOverride: null,
        envDefineValue: 'https://env.example/meEntitlements',
        functionName: 'meEntitlements',
      );
      expect(actual, 'https://env.example/meEntitlements');
    });

    test('trims whitespace on configured values', () {
      final String actual = resolveFirebaseHttpsFunctionUrl(
        explicitOverride: '  https://trimmed.example  ',
        envDefineValue: '',
        functionName: 'fn',
      );
      expect(actual, 'https://trimmed.example');
    });
  });

  group('buildFirebaseHttpsFunctionUrlFromProject', () {
    test('returns empty when Firebase is not initialized', () {
      final String actual = buildFirebaseHttpsFunctionUrlFromProject(
        functionName: 'meEntitlements',
      );
      expect(actual, '');
    });
  });
}
