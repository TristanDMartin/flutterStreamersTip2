import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/core/backend/http_api_base_url.dart';

void main() {
  group('resolveHttpApiBaseUrl', () {
    test('prefers explicit override', () {
      final String actual = resolveHttpApiBaseUrl(
        explicitOverride: 'https://staging.example',
        envDefineValue: 'https://env.example',
      );
      expect(actual, 'https://staging.example');
    });

    test('uses env when explicit is empty', () {
      final String actual = resolveHttpApiBaseUrl(
        explicitOverride: null,
        envDefineValue: 'https://env.example',
      );
      expect(actual, 'https://env.example');
    });

    test('falls back to production default', () {
      final String actual = resolveHttpApiBaseUrl(
        explicitOverride: null,
        envDefineValue: '',
      );
      expect(actual, kStreamersTipProductionApiHost);
    });

    test('honors custom production default', () {
      final String actual = resolveHttpApiBaseUrl(
        explicitOverride: null,
        envDefineValue: '',
        productionDefault: 'https://custom.prod',
      );
      expect(actual, 'https://custom.prod');
    });
  });
}
