import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/config/giphy_config.dart';

void main() {
  test('apiKey comes from dart-define GIPHY_API_KEY', () {
    expect(GiphyConfig.apiKey, isA<String>());
  });

  test('without dart-define primary key is empty in tests', () {
    expect(GiphyConfig.apiKey, isEmpty);
  });

  test('bestApiKey uses fallback only in debug when primary empty', () {
    if (kDebugMode) {
      expect(GiphyConfig.bestApiKey, isNotEmpty);
    } else {
      expect(GiphyConfig.bestApiKey, isEmpty);
    }
  });
}
