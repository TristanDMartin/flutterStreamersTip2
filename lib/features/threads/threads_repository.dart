import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/forum_service.dart';
import 'threads_contract.dart';
import 'threads_legacy_adapter.dart';
import 'threads_models.dart';

/// Feature flags for Threads v2 rollout (local defaults; wire remote later).
class ThreadsFeatureFlags {
  const ThreadsFeatureFlags({
    this.readsEnabled = false,
    this.writesEnabled = false,
    this.uiEnabled = false,
    this.cutover = false,
  });

  final bool readsEnabled;
  final bool writesEnabled;
  final bool uiEnabled;
  final bool cutover;

  static const ThreadsFeatureFlags defaults = ThreadsFeatureFlags();
}

/// Shared repository port — website implements the same method names.
abstract class ThreadsRepository {
  Future<List<ThreadDto>> listFeed({
    required String filter,
    String? categoryId,
    String? searchQuery,
    int pageSize = 20,
  });

  Future<List<ThreadFeedModuleDto>> listModules({
    required String viewerId,
  });

  Future<ThreadDto?> getThread(String threadId);

  Future<String> createThread(CreateThreadRequest request);

  Future<void> markViewed({
    required String threadId,
    required String userId,
  });

  Future<void> react({
    required String threadId,
    required String userId,
    required String reactionType,
    String targetType = 'thread',
    String? targetId,
  });

  Future<void> resolveThread({
    required String threadId,
    required String resolvedBy,
    required List<String> selectedReplyIds,
    String? resolutionNote,
  });

  List<TippyStarterPreset> getTippyStarters();
}

/// Dual-read repository: prefer `threads/`, else project `forumPosts`.
class FirestoreThreadsRepository implements ThreadsRepository {
  FirestoreThreadsRepository({
    FirebaseFirestore? firestore,
    ForumService? forumService,
    ThreadsLegacyAdapter? adapter,
    ThreadsFeatureFlags flags = ThreadsFeatureFlags.defaults,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _forumService = forumService ?? ForumService(),
        _adapter = adapter ?? const ThreadsLegacyAdapter(),
        _flags = flags;

  final FirebaseFirestore _firestore;
  final ForumService _forumService;
  final ThreadsLegacyAdapter _adapter;
  final ThreadsFeatureFlags _flags;

  @override
  Future<List<ThreadDto>> listFeed({
    required String filter,
    String? categoryId,
    String? searchQuery,
    int pageSize = 20,
  }) async {
    final String normalizedFilter = normalizeFeedFilter(filter);
    if (_flags.readsEnabled) {
      final List<ThreadDto> fromV2 = await _listFromThreadsCollection(
        categoryId: categoryId,
        searchQuery: searchQuery,
        pageSize: pageSize,
      );
      if (fromV2.isNotEmpty) {
        return _applyFilterHeuristic(fromV2, normalizedFilter);
      }
    }
    final legacy = await _forumService.getPosts(
      categoryId: categoryId,
      searchQuery: searchQuery,
      sortBy: _sortForFilter(normalizedFilter),
      pageSize: pageSize,
    );
    final List<ThreadDto> projected =
        legacy.map(_adapter.fromForumPost).toList(growable: false);
    return _applyFilterHeuristic(projected, normalizedFilter);
  }

  @override
  Future<List<ThreadFeedModuleDto>> listModules({
    required String viewerId,
  }) async {
    final List<ThreadDto> feed = await listFeed(filter: 'for_you');
    if (feed.isEmpty) {
      return const <ThreadFeedModuleDto>[];
    }
    final List<ThreadFeedModuleDto> modules = <ThreadFeedModuleDto>[];
    final List<ThreadDto> unanswered = feed
        .where(
          (ThreadDto t) =>
              t.type == 'question' &&
              t.replyCount == 0 &&
              t.status == 'open',
        )
        .toList(growable: false);
    final List<ThreadDto> wins = feed
        .where((ThreadDto t) => t.type == 'creator_win')
        .toList(growable: false);
    final List<ThreadDto> trending = feed
        .where(
          (ThreadDto t) =>
              t.momentumState == 'trending' ||
              t.momentumState == 'picking_up' ||
              t.momentumState == 'active_now',
        )
        .toList(growable: false);
    if (feed.isNotEmpty) {
      modules.add(
        ThreadFeedModuleDto(
          moduleId: 'featured',
          title: kFeedModuleLabels['featured']!,
          threads: <ThreadDto>[feed.first],
        ),
      );
    }
    if (unanswered.isNotEmpty) {
      modules.add(
        ThreadFeedModuleDto(
          moduleId: 'need_your_input',
          title: kFeedModuleLabels['need_your_input']!,
          subtitle: 'Questions waiting for a useful response',
          threads: unanswered.take(5).toList(growable: false),
        ),
      );
    }
    if (trending.isNotEmpty) {
      modules.add(
        ThreadFeedModuleDto(
          moduleId: 'trending_in_space',
          title: kFeedModuleLabels['trending_in_space']!,
          threads: trending.take(5).toList(growable: false),
        ),
      );
    }
    if (wins.isNotEmpty) {
      modules.add(
        ThreadFeedModuleDto(
          moduleId: 'creator_wins',
          title: kFeedModuleLabels['creator_wins']!,
          threads: wins.take(5).toList(growable: false),
        ),
      );
    }
    return modules;
  }

  @override
  Future<ThreadDto?> getThread(String threadId) async {
    if (_flags.readsEnabled) {
      final DocumentSnapshot<Map<String, dynamic>> v2 =
          await _firestore.collection('threads').doc(threadId).get();
      if (v2.exists && v2.data() != null) {
        return _fromV2Map(threadId, v2.data()!);
      }
    }
    final legacy = await _forumService.getPost(threadId);
    if (legacy == null) {
      return null;
    }
    return _adapter.fromForumPost(legacy);
  }

  @override
  Future<String> createThread(CreateThreadRequest request) async {
    final String type = normalizeThreadType(request.type);
    final String categoryId = normalizeCategoryId(request.categoryId);
    final String status = 'open';
    final DateTime now = DateTime.now().toUtc();
    if (_flags.writesEnabled) {
      final DocumentReference<Map<String, dynamic>> ref =
          _firestore.collection('threads').doc();
      await ref.set(<String, dynamic>{
        'schemaVersion': kThreadsSchemaVersion,
        'authorId': request.authorId,
        'type': type,
        'title': request.title.trim(),
        'body': request.body.trim(),
        'categoryId': categoryId,
        'status': status,
        'momentumState': 'new',
        'visibility': request.visibility,
        'platformTags': request.platformTags,
        'topicTags': request.topicTags,
        'payload': request.payload,
        'sourceVideoId': request.sourceVideoId,
        'sourceCommentId': request.sourceCommentId,
        'sourceComment': request.sourceComment,
        'replyCount': 0,
        'participantCount': 1,
        'helpfulCount': 0,
        'saveCount': 0,
        'followCount': 0,
        'lastActivityAt': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'deleted': false,
        'tippyStarterId': request.tippyStarterId,
      });
      await _firestore
          .collection('threads')
          .doc(ref.id)
          .collection('participants')
          .doc(request.authorId)
          .set(<String, dynamic>{
        'role': 'author',
        'joinedAt': Timestamp.fromDate(now),
        'lastViewedAt': Timestamp.fromDate(now),
        'notificationPreference': 'all',
      });
      return ref.id;
    }
    // Legacy write path until threads_v2_writes is enabled.
    return _forumService.createPost(
      title: request.title,
      content: request.body,
      categoryId: categoryId,
      tags: <String>[
        ...request.topicTags,
        'type:$type',
        if (request.tippyStarterId != null)
          'tippy:${request.tippyStarterId}',
      ],
      author: await _forumService.getUserProfile(request.authorId),
      linkedVideoId: request.sourceVideoId,
    );
  }

  @override
  Future<void> markViewed({
    required String threadId,
    required String userId,
  }) async {
    if (!_flags.writesEnabled) {
      return;
    }
    final DateTime now = DateTime.now().toUtc();
    await _firestore
        .collection('threads')
        .doc(threadId)
        .collection('participants')
        .doc(userId)
        .set(
      <String, dynamic>{
        'lastViewedAt': Timestamp.fromDate(now),
        'joinedAt': Timestamp.fromDate(now),
        'role': 'participant',
        'notificationPreference': 'all',
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> react({
    required String threadId,
    required String userId,
    required String reactionType,
    String targetType = 'thread',
    String? targetId,
  }) async {
    final String? normalized = normalizeReactionType(reactionType);
    if (normalized == null) {
      return;
    }
    if (!_flags.writesEnabled) {
      if (normalized == 'helpful') {
        await _forumService.togglePostLike(
          threadId,
          userId,
          await _forumService.getUserProfile(userId),
        );
      }
      return;
    }
    final String reactionId =
        '${targetType}_${targetId ?? threadId}_${userId}_$normalized';
    await _firestore
        .collection('threads')
        .doc(threadId)
        .collection('reactions')
        .doc(reactionId)
        .set(<String, dynamic>{
      'targetType': targetType,
      'targetId': targetId ?? threadId,
      'userId': userId,
      'reactionType': normalized,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (normalized == 'helpful') {
      await _firestore.collection('threads').doc(threadId).update(
        <String, dynamic>{
          'helpfulCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
  }

  @override
  Future<void> resolveThread({
    required String threadId,
    required String resolvedBy,
    required List<String> selectedReplyIds,
    String? resolutionNote,
  }) async {
    if (!_flags.writesEnabled) {
      return;
    }
    final DateTime now = DateTime.now().toUtc();
    final WriteBatch batch = _firestore.batch();
    final DocumentReference<Map<String, dynamic>> threadRef =
        _firestore.collection('threads').doc(threadId);
    batch.set(
      threadRef.collection('resolution').doc('current'),
      <String, dynamic>{
        'selectedReplyIds': selectedReplyIds,
        'resolutionNote': resolutionNote,
        'resolvedAt': Timestamp.fromDate(now),
        'resolvedBy': resolvedBy,
      },
    );
    batch.update(threadRef, <String, dynamic>{
      'status': 'resolved',
      'momentumState': 'resolved',
      'updatedAt': Timestamp.fromDate(now),
    });
    await batch.commit();
  }

  @override
  List<TippyStarterPreset> getTippyStarters() => kTippyStarterPresets;

  Future<List<ThreadDto>> _listFromThreadsCollection({
    String? categoryId,
    String? searchQuery,
    int pageSize = 20,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('threads')
        .where('deleted', isEqualTo: false)
        .orderBy('lastActivityAt', descending: true)
        .limit(pageSize);
    if (categoryId != null && categoryId.isNotEmpty) {
      query = _firestore
          .collection('threads')
          .where('deleted', isEqualTo: false)
          .where('categoryId', isEqualTo: normalizeCategoryId(categoryId))
          .orderBy('lastActivityAt', descending: true)
          .limit(pageSize);
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await query.get();
      List<ThreadDto> threads = snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                _fromV2Map(doc.id, doc.data()),
          )
          .toList(growable: false);
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final String q = searchQuery.trim().toLowerCase();
        threads = threads
            .where(
              (ThreadDto t) =>
                  t.title.toLowerCase().contains(q) ||
                  t.body.toLowerCase().contains(q),
            )
            .toList(growable: false);
      }
      return threads;
    } catch (_) {
      return const <ThreadDto>[];
    }
  }

  ThreadDto _fromV2Map(String id, Map<String, dynamic> data) {
    DateTime readTs(Object? value, DateTime fallback) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    final DateTime now = DateTime.now();
    final DateTime createdAt = readTs(data['createdAt'], now);
    final DateTime updatedAt = readTs(data['updatedAt'], createdAt);
    final DateTime lastActivity =
        readTs(data['lastActivityAt'], updatedAt);
    return ThreadDto(
      id: id,
      schemaVersion:
          (data['schemaVersion'] as num?)?.toInt() ?? kThreadsSchemaVersion,
      authorId: (data['authorId'] as String?) ?? '',
      type: normalizeThreadType(data['type']),
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      categoryId: normalizeCategoryId(data['categoryId']),
      status: normalizeThreadStatus(data['status']),
      momentumState: normalizeMomentumState(data['momentumState']),
      visibility: (data['visibility'] as String?) ?? 'public',
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      participantCount: (data['participantCount'] as num?)?.toInt() ?? 1,
      helpfulCount: (data['helpfulCount'] as num?)?.toInt() ?? 0,
      saveCount: (data['saveCount'] as num?)?.toInt() ?? 0,
      followCount: (data['followCount'] as num?)?.toInt() ?? 0,
      lastActivityAt: lastActivity,
      createdAt: createdAt,
      updatedAt: updatedAt,
      platformTags:
          List<String>.from(data['platformTags'] as List? ?? const <dynamic>[]),
      topicTags:
          List<String>.from(data['topicTags'] as List? ?? const <dynamic>[]),
      payload: Map<String, dynamic>.from(
        data['payload'] as Map? ?? const <String, dynamic>{},
      ),
      sourceVideoId: data['sourceVideoId'] as String?,
      sourceCommentId: data['sourceCommentId'] as String?,
      deleted: data['deleted'] == true,
      deletedReason: data['deletedReason'] as String?,
      migratedFrom: data['migratedFrom'] as String?,
    );
  }

  ThreadSortBy _sortForFilter(String filter) {
    switch (filter) {
      case 'trending':
        return ThreadSortBy.trending;
      case 'live':
        return ThreadSortBy.activeNow;
      case 'following':
        return ThreadSortBy.popular;
      default:
        return ThreadSortBy.recent;
    }
  }

  List<ThreadDto> _applyFilterHeuristic(
    List<ThreadDto> input,
    String filter,
  ) {
    switch (filter) {
      case 'unanswered':
        return input
            .where(
              (ThreadDto t) => t.replyCount == 0 && t.status == 'open',
            )
            .toList(growable: false);
      case 'live':
        return input
            .where((ThreadDto t) => t.momentumState == 'active_now')
            .toList(growable: false);
      case 'trending':
        return input
            .where(
              (ThreadDto t) =>
                  t.momentumState == 'trending' ||
                  t.momentumState == 'picking_up',
            )
            .toList(growable: false);
      default:
        return input;
    }
  }
}
