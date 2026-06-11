import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/category_schema.dart';

void main() {
  group('buildCanonicalCategoryFields', () {
    test('defaults empty to general with categoryName', () {
      final Map<String, dynamic> fields =
          buildCanonicalCategoryFields('');
      expect(fields['categoryId'], 'general');
      expect(fields['categoryName'], 'General');
    });

    test('normalizes gaming selection', () {
      final Map<String, dynamic> fields =
          buildCanonicalCategoryFields('Gaming');
      expect(fields['categoryId'], 'gaming');
      expect(fields['categoryName'], 'Gaming');
    });
  });

  group('readCanonicalCategoryFromVideo', () {
    test('reads canonical fields when present', () {
      final CanonicalCategory actual = readCanonicalCategoryFromVideo(
        <String, dynamic>{
          'categoryId': 'gaming',
          'categoryName': 'Gaming',
        },
      );
      expect(actual.categoryId, 'gaming');
      expect(actual.categoryName, 'Gaming');
    });

    test('returns empty when no category data', () {
      final CanonicalCategory actual = readCanonicalCategoryFromVideo(
        <String, dynamic>{'status': 'ready'},
      );
      expect(actual.isPopulated, isFalse);
    });
  });
}
