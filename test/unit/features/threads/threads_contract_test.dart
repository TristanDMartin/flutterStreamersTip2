import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/threads/threads_contract.dart';
import 'package:streamers_tip/features/threads/threads_legacy_adapter.dart';
import 'package:streamers_tip/models/forum_author.dart';
import 'package:streamers_tip/models/forum_post.dart';

void main() {
  group('threads_contract', () {
    test('normalizes legacy status published to open', () {
      expect(normalizeThreadStatus('published'), 'open');
      expect(normalizeThreadStatus('closed'), 'resolved');
    });

    test('maps legacy like reaction to helpful', () {
      expect(normalizeReactionType('like'), 'helpful');
      expect(normalizeReactionType('dislike'), isNull);
    });

    test('normalizes legacy category aliases', () {
      expect(normalizeCategoryId('streaming_tips'), 'streaming');
      expect(normalizeCategoryId('lfg'), 'collaboration');
    });

    test('computeMomentumState returns active_now for rapid replies', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      final String actual = computeMomentumState(
        createdAt: now.subtract(const Duration(hours: 2)),
        lastActivityAt: now.subtract(const Duration(minutes: 5)),
        replyCountInWindow: 4,
        uniqueParticipantsInWindow: 3,
        savesInWindow: 0,
        status: 'open',
        now: now,
      );
      expect(actual, 'active_now');
    });

    test('resolved status forces resolved momentum', () {
      final DateTime now = DateTime.utc(2026, 8, 2);
      final String actual = computeMomentumState(
        createdAt: now,
        lastActivityAt: now,
        replyCountInWindow: 100,
        uniqueParticipantsInWindow: 50,
        savesInWindow: 20,
        status: 'resolved',
        now: now,
      );
      expect(actual, 'resolved');
    });
  });

  group('ThreadsLegacyAdapter', () {
    test('projects forum post into ThreadDto', () {
      final ForumPost input = ForumPost(
        id: 'post_1',
        title: 'Need OBS feedback',
        content: 'My audio is delayed',
        category: 'streaming_tips',
        categoryDisplayName: 'Streaming Tips',
        tags: const <String>['feedback'],
        author: ForumAuthor(
          uid: 'u1',
          username: 'creator',
          displayName: 'Creator',
        ),
        visibility: 'public',
        likes: 3,
        commentCount: 0,
        likedBy: const <String>['a', 'b', 'c'],
        bookmarkedBy: const <String>['a'],
        followedBy: const <String>[],
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
        deleted: false,
      );
      final actual = const ThreadsLegacyAdapter().fromForumPost(input);
      expect(actual.id, 'post_1');
      expect(actual.type, 'feedback_request');
      expect(actual.categoryId, 'streaming');
      expect(actual.body, 'My audio is delayed');
      expect(actual.replyCount, 0);
      expect(actual.saveCount, 1);
      expect(actual.legacyLikeCount, 3);
      expect(actual.migratedFrom, 'forumPosts');
      expect(actual.schemaVersion, kThreadsSchemaVersion);
    });
  });
}
