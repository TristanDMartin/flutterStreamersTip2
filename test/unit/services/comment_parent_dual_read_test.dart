import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/firestore_map_readers.dart';

void main() {
  group('comment parent dual-read', () {
    test('reads parentCommentId when only Flutter field is set', () {
      expect(
        readCommentParentId(<String, dynamic>{'parentCommentId': 'c1'}),
        'c1',
      );
    });

    test('reads parentId when only web field is set', () {
      expect(
        readCommentParentId(<String, dynamic>{'parentId': 'c2'}),
        'c2',
      );
    });

    test('prefers parentCommentId when both are set', () {
      expect(
        readCommentParentId(<String, dynamic>{
          'parentCommentId': 'flutter',
          'parentId': 'web',
        }),
        'flutter',
      );
    });

    test('treats empty strings as top-level', () {
      expect(
        isTopLevelComment(<String, dynamic>{
          'parentId': '',
          'parentCommentId': '  ',
        }),
        isTrue,
      );
    });

    test('rail count excludes replies and deleted', () {
      final List<Map<String, dynamic>> docs = <Map<String, dynamic>>[
        <String, dynamic>{'text': 'root'},
        <String, dynamic>{'text': 'reply', 'parentId': 'root'},
        <String, dynamic>{
          'text': 'flutter-reply',
          'parentCommentId': 'root',
        },
        <String, dynamic>{'text': 'gone', 'deleted': true},
      ];
      int actual = 0;
      for (final Map<String, dynamic> data in docs) {
        final bool deleted = data['deleted'] as bool? ?? false;
        if (!deleted && isTopLevelComment(data)) {
          actual++;
        }
      }
      expect(actual, 1);
    });
  });
}
