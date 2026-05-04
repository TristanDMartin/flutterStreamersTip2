import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/video_url_resolver.dart';

void main() {
  group('getOwnerId', () {
    test('reads videoOwnerId', () {
      final String? actual = getOwnerId(<String, dynamic>{
        'videoOwnerId': 'owner123',
        'userId': '',
      });
      expect(actual, 'owner123');
    });
    test('reads meta.creator_id', () {
      final String? actual = getOwnerId(<String, dynamic>{
        'meta': <String, dynamic>{'creator_id': 'metaUid'},
      });
      expect(actual, 'metaUid');
    });
  });
  group('inferOwnerIdFromVideoDocumentId', () {
    test('returns uid prefix when pattern matches', () {
      const String uid = 'abcdefghijklmnopqrst';
      final String? actual =
          inferOwnerIdFromVideoDocumentId('${uid}_clip001');
      expect(actual, uid);
    });
    test('returns null when no underscore', () {
      expect(inferOwnerIdFromVideoDocumentId('nounderscoreid'), isNull);
    });
  });
}
