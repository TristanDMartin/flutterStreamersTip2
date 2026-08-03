import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/threads/threads_models.dart';
import 'package:streamers_tip/features/threads/threads_repository.dart';

void main() {
  group('ThreadsFeatureFlags', () {
    test('fromEnvironment exposes ui/reads/writes defaults', () {
      final ThreadsFeatureFlags actual = ThreadsFeatureFlags.fromEnvironment();
      expect(actual.uiEnabled, isTrue);
      expect(actual.readsEnabled, isTrue);
      expect(actual.writesEnabled, isTrue);
      expect(actual.cutover, isFalse);
    });

    test('defaults keep flags off when constructed empty', () {
      const ThreadsFeatureFlags actual = ThreadsFeatureFlags.defaults;
      expect(actual.readsEnabled, isFalse);
      expect(actual.writesEnabled, isFalse);
      expect(actual.uiEnabled, isFalse);
      expect(actual.cutover, isFalse);
    });
  });

  group('ThreadReplyDto', () {
    test('holds reply fields for detail UI', () {
      final DateTime now = DateTime.utc(2026, 8, 2);
      final ThreadReplyDto actual = ThreadReplyDto(
        id: 'r1',
        threadId: 't1',
        authorId: 'u1',
        body: 'Try lowering bitrate',
        createdAt: now,
        updatedAt: now,
        helpfulCount: 2,
      );
      expect(actual.id, 'r1');
      expect(actual.body, 'Try lowering bitrate');
      expect(actual.helpfulCount, 2);
    });
  });

  group('CreateReplyRequest', () {
    test('requires thread and author', () {
      const CreateReplyRequest input = CreateReplyRequest(
        threadId: 't1',
        authorId: 'u1',
        body: 'Helpful tip',
      );
      expect(input.threadId, 't1');
      expect(input.authorId, 'u1');
      expect(input.body, 'Helpful tip');
    });
  });
}
