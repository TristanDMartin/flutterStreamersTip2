import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/discover_category_rules.dart';

void main() {
  group('matchesDiscoverCategory', () {
    test('All matches videos without category', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'status': 'ready',
      };
      expect(matchesDiscoverCategory(data, 'All'), isTrue);
    });

    test('gaming matches canonical categoryId', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'categoryId': 'gaming',
        'categoryName': 'Gaming',
      };
      expect(matchesDiscoverCategory(data, 'gaming'), isTrue);
    });

    test('gaming rejects video with no category fields', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'hlsUrl': 'https://example.com/a.m3u8',
      };
      expect(matchesDiscoverCategory(data, 'gaming'), isFalse);
    });

    test('legacy category field still matches gaming', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'category': 'game',
      };
      expect(matchesDiscoverCategory(data, 'gaming'), isTrue);
    });
  });
}
