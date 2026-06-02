import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/application/home_feed_warm_cache.dart';

void main() {
  group('HomeFeedWarmCache.sanitizeCursor', () {
    test('keeps primitive cursor fields', () {
      final Map<String, dynamic>? actual = HomeFeedWarmCache.sanitizeCursor(
        <String, dynamic>{
          'lastId': 'abc',
          'page': 2,
          'done': false,
        },
      );
      expect(actual, <String, dynamic>{
        'lastId': 'abc',
        'page': 2,
        'done': false,
      });
    });

    test('drops non-primitive values', () {
      final Map<String, dynamic>? actual = HomeFeedWarmCache.sanitizeCursor(
        <String, dynamic>{'doc': Object()},
      );
      expect(actual, isNull);
    });
  });
}
