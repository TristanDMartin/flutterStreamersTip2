import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/threads/creator_threads_shell.dart';
import 'package:streamers_tip/features/threads/threads_contract.dart';
import 'package:streamers_tip/features/threads/threads_models.dart';
import 'package:streamers_tip/features/threads/threads_repository.dart';
import 'package:streamers_tip/features/threads/thread_workspace_header.dart';

class _FakeThreadsRepository implements ThreadsRepository {
  @override
  Future<String> createReply(CreateReplyRequest request) async => 'r1';

  @override
  Future<String> createThread(CreateThreadRequest request) async => 't1';

  @override
  Future<void> deleteReply({
    required String threadId,
    required String replyId,
    required String userId,
  }) async {}

  @override
  Future<void> followThread({
    required String threadId,
    required String userId,
    bool follow = true,
  }) async {}

  @override
  Future<ThreadDto?> getThread(String threadId) async => null;

  @override
  List<TippyStarterPreset> getTippyStarters() => const <TippyStarterPreset>[];

  @override
  Future<List<ThreadDto>> listFeed({
    required String filter,
    String? categoryId,
    String? searchQuery,
    String? viewerId,
    int pageSize = 20,
  }) async =>
      const <ThreadDto>[];

  @override
  Future<List<ThreadFeedModuleDto>> listModules({
    required String viewerId,
  }) async =>
      const <ThreadFeedModuleDto>[];

  @override
  Future<List<ThreadReactionDto>> listReactions({
    required String threadId,
  }) async =>
      const <ThreadReactionDto>[];

  @override
  Future<List<ThreadReplyDto>> listReplies({
    required String threadId,
    int pageSize = 100,
  }) async =>
      const <ThreadReplyDto>[];

  @override
  Future<void> markViewed({
    required String threadId,
    required String userId,
  }) async {}

  @override
  Future<void> react({
    required String threadId,
    required String userId,
    required String reactionType,
    String targetType = 'thread',
    String? targetId,
  }) async {}

  @override
  Future<void> resolveThread({
    required String threadId,
    required String resolvedBy,
    required List<String> selectedReplyIds,
    String? resolutionNote,
  }) async {}

  @override
  Future<void> saveThread({
    required String threadId,
    required String userId,
    bool save = true,
  }) async {}
}

void main() {
  testWidgets('CreatorThreadsShell shows product chrome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreatorThreadsShell(
            repository: _FakeThreadsRepository(),
            embeddedInHome: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Creator Threads'), findsOneWidget);
    expect(
      find.textContaining('Tippy: What are you working through today?'),
      findsOneWidget,
    );
  });

  testWidgets('ThreadWorkspaceHeader shows type and title', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 2);
    final ThreadDto thread = ThreadDto(
      id: 't1',
      schemaVersion: 2,
      authorId: '',
      type: 'question',
      title: 'OBS audio delay?',
      body: 'Need help',
      categoryId: 'streaming',
      status: 'open',
      momentumState: 'new',
      visibility: 'public',
      replyCount: 0,
      participantCount: 1,
      helpfulCount: 0,
      saveCount: 0,
      followCount: 0,
      lastActivityAt: now,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThreadWorkspaceHeader(thread: thread),
        ),
      ),
    );
    expect(find.text('OBS audio delay?'), findsOneWidget);
    expect(find.text('Ask a question'), findsOneWidget);
    expect(find.text('Streaming'), findsOneWidget);
  });
}
