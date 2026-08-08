import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../core/feature_flags.dart';
import '../../models/forum_author.dart';
import '../../models/forum_comment.dart';
import '../../services/forum_service.dart';
import '../../services/thread_invite_service.dart';
import '../gamification/emit_gamification_event.dart';
import 'thread_visibility.dart';
import 'threads_contract.dart';
import 'threads_gamification.dart';
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

  /// Compile-time flags from `--dart-define` / [FeatureFlags].
  static ThreadsFeatureFlags fromEnvironment() {
    return const ThreadsFeatureFlags(
      readsEnabled: FeatureFlags.threadsV2Reads,
      writesEnabled: FeatureFlags.threadsV2Writes,
      uiEnabled: FeatureFlags.threadsV2Ui,
      cutover: FeatureFlags.threadsV2Cutover,
    );
  }
}

/// Shared repository port — website implements the same method names.
abstract class ThreadsRepository {
  Future<List<ThreadDto>> listFeed({
    required String filter,
    String? categoryId,
    String? searchQuery,
    String? viewerId,
    int pageSize = 20,
  });

  Future<List<ThreadFeedModuleDto>> listModules({
    required String viewerId,
  });

  Future<ThreadDto?> getThread(String threadId);

  Future<String> createThread(CreateThreadRequest request);

  Future<List<ThreadReplyDto>> listReplies({
    required String threadId,
    int pageSize = 100,
  });

  Future<String> createReply(CreateReplyRequest request);

  Future<void> deleteReply({
    required String threadId,
    required String replyId,
    required String userId,
  });

  Future<void> markViewed({
    required String threadId,
    required String userId,
  });

  Future<List<ThreadReactionDto>> listReactions({
    required String threadId,
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

  Future<void> followThread({
    required String threadId,
    required String userId,
    bool follow = true,
  });

  Future<void> saveThread({
    required String threadId,
    required String userId,
    bool save = true,
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
  final Map<String, bool> _v2Presence = <String, bool>{};

  Future<bool> _isV2Thread(String threadId) async {
    final bool? cached = _v2Presence[threadId];
    if (cached != null) {
      return cached;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _firestore.collection('threads').doc(threadId).get();
    final bool exists = snap.exists;
    _v2Presence[threadId] = exists;
    return exists;
  }

  @override
  Future<List<ThreadDto>> listFeed({
    required String filter,
    String? categoryId,
    String? searchQuery,
    String? viewerId,
    int pageSize = 20,
  }) async {
    final String normalizedFilter = normalizeFeedFilter(filter);
    if (_flags.readsEnabled) {
      final List<ThreadDto> fromV2 = await _listFromThreadsCollection(
        categoryId: categoryId,
        searchQuery: searchQuery,
        pageSize: pageSize,
        viewerId: viewerId,
      );
      if (fromV2.isNotEmpty) {
        return _applyFilterHeuristic(
          fromV2,
          normalizedFilter,
          viewerId: viewerId,
        );
      }
    }
    final legacy = await _forumService.getPosts(
      categoryId: categoryId,
      searchQuery: searchQuery,
      sortBy: _sortForFilter(normalizedFilter),
      pageSize: pageSize,
      currentUserId: viewerId,
    );
    final List<ThreadDto> projected =
        legacy.map(_adapter.fromForumPost).toList(growable: false);
    return _applyFilterHeuristic(
      projected,
      normalizedFilter,
      viewerId: viewerId,
    );
  }

  @override
  Future<List<ThreadFeedModuleDto>> listModules({
    required String viewerId,
  }) async {
    final List<ThreadDto> feed = await listFeed(
      filter: 'for_you',
      viewerId: viewerId,
    );
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
        _v2Presence[threadId] = true;
        final ThreadDto dto = _fromV2Map(threadId, v2.data()!);
        final String? viewerId =
            firebase_auth.FirebaseAuth.instance.currentUser?.uid;
        final bool follows = await _viewerFollowsAuthor(
          viewerId,
          dto.authorId,
        );
        bool inviteAccess = false;
        final String vis = normalizeThreadVisibility(dto.visibility);
        if (vis == kThreadVisibilityInviteOnly &&
            viewerId != null &&
            viewerId.isNotEmpty &&
            viewerId != dto.authorId) {
          inviteAccess = await ThreadInviteService()
              .viewerHasThreadInviteAccess(threadId, viewerId);
        }
        if (!canViewerAccessThread(
          visibility: dto.visibility,
          authorId: dto.authorId,
          viewerId: viewerId,
          viewerFollowsAuthor: follows,
          viewerHasInviteAccess: inviteAccess,
        )) {
          return null;
        }
        return dto;
      }
      _v2Presence[threadId] = false;
    }
    final legacy = await _forumService.getPost(
      threadId,
      currentUserId: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
    );
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
        'visibility': normalizeThreadVisibility(request.visibility),
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
        'userId': request.authorId,
        'role': 'author',
        'joinedAt': Timestamp.fromDate(now),
        'lastViewedAt': Timestamp.fromDate(now),
        'notificationPreference': 'all',
      });
      scheduleGamificationEvent(
        ThreadsGamification.threadCreated,
        entityType: 'thread',
        entityId: ref.id,
      );
      return ref.id;
    }
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
  Future<List<ThreadReplyDto>> listReplies({
    required String threadId,
    int pageSize = 100,
  }) async {
    if (_flags.readsEnabled) {
      try {
        final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
            .collection('threads')
            .doc(threadId)
            .collection('replies')
            .where('deleted', isEqualTo: false)
            .orderBy('createdAt', descending: false)
            .limit(pageSize)
            .get();
        if (snap.docs.isNotEmpty) {
          return snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    _replyFromV2Map(threadId, doc.id, doc.data()),
              )
              .toList(growable: false);
        }
      } catch (_) {
        // Fall through to legacy comments.
      }
    }
    final QuerySnapshot<Map<String, dynamic>> legacy = await _firestore
        .collection('forumPosts')
        .doc(threadId)
        .collection('comments')
        .where('deleted', isEqualTo: false)
        .limit(pageSize)
        .get();
    final List<ForumComment> comments = legacy.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              ForumComment.fromFirestore(doc, threadId),
        )
        .toList(growable: false)
      ..sort(
        (ForumComment a, ForumComment b) =>
            a.createdAt.compareTo(b.createdAt),
      );
    return comments
        .map(_replyFromLegacyComment)
        .toList(growable: false);
  }

  @override
  Future<String> createReply(CreateReplyRequest request) async {
    final String body = request.body.trim();
    if (body.isEmpty) {
      throw ArgumentError('Reply body is required');
    }
    final DateTime now = DateTime.now().toUtc();
    final bool useV2 =
        _flags.writesEnabled && await _isV2Thread(request.threadId);
    if (useV2) {
      final DocumentReference<Map<String, dynamic>> ref = _firestore
          .collection('threads')
          .doc(request.threadId)
          .collection('replies')
          .doc();
      await ref.set(<String, dynamic>{
        'authorId': request.authorId,
        'body': body,
        'parentReplyId': request.parentReplyId,
        'authorDisplayName': request.authorDisplayName,
        'authorUsername': request.authorUsername,
        'authorAvatarUrl': request.authorAvatarUrl,
        'helpfulCount': 0,
        'deleted': false,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      await _firestore.collection('threads').doc(request.threadId).update(
        <String, dynamic>{
          'replyCount': FieldValue.increment(1),
          'lastActivityAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
      );
      await _firestore
          .collection('threads')
          .doc(request.threadId)
          .collection('participants')
          .doc(request.authorId)
          .set(
        <String, dynamic>{
          'userId': request.authorId,
          'role': 'participant',
          'joinedAt': Timestamp.fromDate(now),
          'lastViewedAt': Timestamp.fromDate(now),
          'notificationPreference': 'all',
        },
        SetOptions(merge: true),
      );
      scheduleGamificationEvent(
        ThreadsGamification.threadParticipated,
        entityType: 'thread',
        entityId: request.threadId,
      );
      return ref.id;
    }
    final ForumAuthor author = ForumAuthor(
      uid: request.authorId,
      username: request.authorUsername ?? 'user',
      displayName: request.authorDisplayName ?? 'User',
      avatarUrl: request.authorAvatarUrl,
    );
    return _forumService.addComment(
      request.threadId,
      body,
      author,
      parentCommentId: request.parentReplyId,
    );
  }

  @override
  Future<void> deleteReply({
    required String threadId,
    required String replyId,
    required String userId,
  }) async {
    final bool useV2 = _flags.writesEnabled && await _isV2Thread(threadId);
    if (useV2) {
      final DocumentReference<Map<String, dynamic>> replyRef = _firestore
          .collection('threads')
          .doc(threadId)
          .collection('replies')
          .doc(replyId);
      final DocumentSnapshot<Map<String, dynamic>> snap = await replyRef.get();
      if (!snap.exists || snap.data() == null) {
        throw StateError('Reply not found');
      }
      final Map<String, dynamic> data = snap.data()!;
      if (data['authorId']?.toString() != userId) {
        throw StateError('You can only delete your own replies.');
      }
      await replyRef.update(<String, dynamic>{
        'deleted': true,
        'body': '[deleted]',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('threads').doc(threadId).update(
        <String, dynamic>{
          'replyCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      return;
    }
    await _forumService.deleteComment(threadId, replyId);
  }

  @override
  Future<void> markViewed({
    required String threadId,
    required String userId,
  }) async {
    if (!_flags.writesEnabled) {
      return;
    }
    if (!await _isV2Thread(threadId)) {
      return;
    }
    try {
      final DateTime now = DateTime.now().toUtc();
      await _firestore
          .collection('threads')
          .doc(threadId)
          .collection('participants')
          .doc(userId)
          .set(
        <String, dynamic>{
          'userId': userId,
          'lastViewedAt': Timestamp.fromDate(now),
          'joinedAt': Timestamp.fromDate(now),
          'role': 'participant',
          'notificationPreference': 'all',
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-fatal — detail should still open if rules lag deploy.
    }
  }

  @override
  Future<List<ThreadReactionDto>> listReactions({
    required String threadId,
  }) async {
    final bool useV2 = _flags.readsEnabled && await _isV2Thread(threadId);
    final CollectionReference<Map<String, dynamic>> col = useV2
        ? _firestore.collection('threads').doc(threadId).collection('reactions')
        : _firestore
            .collection('forumPosts')
            .doc(threadId)
            .collection('reactions');
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await col.get();
      return snap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final Map<String, dynamic> data = d.data();
        return ThreadReactionDto(
          id: d.id,
          targetType: data['targetType']?.toString() ?? 'thread',
          targetId: data['targetId']?.toString() ?? threadId,
          userId: data['userId']?.toString() ?? '',
          reactionType: data['reactionType']?.toString() ?? '',
        );
      }).toList(growable: false);
    } catch (_) {
      return const <ThreadReactionDto>[];
    }
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
    final bool useV2 = _flags.writesEnabled && await _isV2Thread(threadId);
    if (!useV2) {
      final String reactionId =
          '${targetType}_${targetId ?? threadId}_${userId}_$normalized';
      final DocumentReference<Map<String, dynamic>> reactionRef = _firestore
          .collection('forumPosts')
          .doc(threadId)
          .collection('reactions')
          .doc(reactionId);
      final DocumentSnapshot<Map<String, dynamic>> existing =
          await reactionRef.get();
      if (existing.exists) {
        await reactionRef.delete();
        return;
      }
      await reactionRef.set(<String, dynamic>{
        'targetType': targetType,
        'targetId': targetId ?? threadId,
        'userId': userId,
        'reactionType': normalized,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    final String reactionId =
        '${targetType}_${targetId ?? threadId}_${userId}_$normalized';
    final DocumentReference<Map<String, dynamic>> reactionRef = _firestore
        .collection('threads')
        .doc(threadId)
        .collection('reactions')
        .doc(reactionId);
    final DocumentSnapshot<Map<String, dynamic>> existing =
        await reactionRef.get();
    if (existing.exists) {
      await reactionRef.delete();
      if (normalized == 'helpful') {
        await _bumpHelpfulCount(
          threadId: threadId,
          targetType: targetType,
          targetId: targetId,
          delta: -1,
        );
      }
      return;
    }
    await reactionRef.set(<String, dynamic>{
      'targetType': targetType,
      'targetId': targetId ?? threadId,
      'userId': userId,
      'reactionType': normalized,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (normalized == 'helpful') {
      await _bumpHelpfulCount(
        threadId: threadId,
        targetType: targetType,
        targetId: targetId,
        delta: 1,
      );
      scheduleGamificationEvent(
        ThreadsGamification.helpfulReactionReceived,
        entityType: targetType == 'reply' ? 'reply' : 'thread',
        entityId: targetId ?? threadId,
      );
    }
  }

  Future<void> _bumpHelpfulCount({
    required String threadId,
    required String targetType,
    required String? targetId,
    required int delta,
  }) async {
    if (targetType == 'reply' &&
        targetId != null &&
        targetId.isNotEmpty) {
      await _firestore
          .collection('threads')
          .doc(threadId)
          .collection('replies')
          .doc(targetId)
          .update(<String, dynamic>{
        'helpfulCount': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await _firestore.collection('threads').doc(threadId).update(
      <String, dynamic>{
        'helpfulCount': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
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
    if (!await _isV2Thread(threadId)) {
      throw StateError(
        'Resolve is only available after this thread is on Threads v2.',
      );
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
    scheduleGamificationEvent(
      ThreadsGamification.answerMarkedHelpful,
      entityType: 'thread',
      entityId: threadId,
    );
  }

  @override
  Future<void> followThread({
    required String threadId,
    required String userId,
    bool follow = true,
  }) async {
    final bool useV2 = _flags.writesEnabled && await _isV2Thread(threadId);
    if (!useV2) {
      await _firestore.collection('forumPosts').doc(threadId).update(
        <String, dynamic>{
          'followedBy': follow
              ? FieldValue.arrayUnion(<String>[userId])
              : FieldValue.arrayRemove(<String>[userId]),
        },
      );
      return;
    }
    final DateTime now = DateTime.now().toUtc();
    final DocumentReference<Map<String, dynamic>> participantRef = _firestore
        .collection('threads')
        .doc(threadId)
        .collection('participants')
        .doc(userId);
    if (follow) {
      await participantRef.set(
        <String, dynamic>{
          'userId': userId,
          'role': 'follower',
          'joinedAt': Timestamp.fromDate(now),
          'lastViewedAt': Timestamp.fromDate(now),
          'notificationPreference': 'all',
        },
        SetOptions(merge: true),
      );
      await _firestore.collection('threads').doc(threadId).update(
        <String, dynamic>{
          'followCount': FieldValue.increment(1),
          'updatedAt': Timestamp.fromDate(now),
        },
      );
    } else {
      await participantRef.set(
        <String, dynamic>{
          'role': 'participant',
          'notificationPreference': 'mute',
        },
        SetOptions(merge: true),
      );
      await _firestore.collection('threads').doc(threadId).update(
        <String, dynamic>{
          'followCount': FieldValue.increment(-1),
          'updatedAt': Timestamp.fromDate(now),
        },
      );
    }
  }

  @override
  Future<void> saveThread({
    required String threadId,
    required String userId,
    bool save = true,
  }) async {
    final bool useV2 = _flags.writesEnabled && await _isV2Thread(threadId);
    if (!useV2) {
      await _firestore.collection('forumPosts').doc(threadId).update(
        <String, dynamic>{
          'bookmarkedBy': save
              ? FieldValue.arrayUnion(<String>[userId])
              : FieldValue.arrayRemove(<String>[userId]),
        },
      );
      return;
    }
    final DocumentReference<Map<String, dynamic>> saveRef = _firestore
        .collection('threads')
        .doc(threadId)
        .collection('saves')
        .doc(userId);
    if (save) {
      await saveRef.set(<String, dynamic>{
        'userId': userId,
        'savedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('threads').doc(threadId).update(
        <String, dynamic>{
          'saveCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } else {
      await saveRef.delete();
      await _firestore.collection('threads').doc(threadId).update(
        <String, dynamic>{
          'saveCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
  }

  @override
  List<TippyStarterPreset> getTippyStarters() => kTippyStarterPresets;

  Future<List<ThreadDto>> _listFromThreadsCollection({
    String? categoryId,
    String? searchQuery,
    int pageSize = 20,
    String? viewerId,
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
      return _filterThreadsByAudience(threads, viewerId);
    } catch (_) {
      return const <ThreadDto>[];
    }
  }

  Future<List<ThreadDto>> _filterThreadsByAudience(
    List<ThreadDto> threads,
    String? viewerId,
  ) async {
    if (threads.isEmpty) {
      return threads;
    }
    final Map<String, bool> followCache = <String, bool>{};
    final Map<String, bool> inviteCache = <String, bool>{};
    final List<ThreadDto> visible = <ThreadDto>[];
    for (final ThreadDto thread in threads) {
      bool follows = false;
      bool inviteAccess = false;
      final String vis = normalizeThreadVisibility(thread.visibility);
      if (vis == kThreadVisibilityFollowers &&
          viewerId != null &&
          viewerId.isNotEmpty &&
          viewerId != thread.authorId) {
        follows = followCache[thread.authorId] ??=
            await _viewerFollowsAuthor(viewerId, thread.authorId);
      }
      if (vis == kThreadVisibilityInviteOnly &&
          viewerId != null &&
          viewerId.isNotEmpty &&
          viewerId != thread.authorId) {
        inviteAccess = inviteCache[thread.id] ??=
            await ThreadInviteService().viewerHasThreadInviteAccess(
          thread.id,
          viewerId,
        );
      }
      if (canViewerAccessThread(
        visibility: vis,
        authorId: thread.authorId,
        viewerId: viewerId,
        viewerFollowsAuthor: follows,
        viewerHasInviteAccess: inviteAccess,
      )) {
        visible.add(thread);
      }
    }
    return visible;
  }

  Future<bool> _viewerFollowsAuthor(String? viewerId, String authorId) async {
    if (viewerId == null || viewerId.isEmpty || authorId.isEmpty) {
      return false;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> edge = await _firestore
          .collection('follows')
          .doc('${viewerId}_$authorId')
          .get();
      if (edge.exists) {
        return true;
      }
      final DocumentSnapshot<Map<String, dynamic>> sub = await _firestore
          .collection('users')
          .doc(authorId)
          .collection('followers')
          .doc(viewerId)
          .get();
      return sub.exists;
    } catch (_) {
      return false;
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
      visibility: normalizeThreadVisibility(data['visibility']),
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

  ThreadReplyDto _replyFromV2Map(
    String threadId,
    String id,
    Map<String, dynamic> data,
  ) {
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
    return ThreadReplyDto(
      id: id,
      threadId: threadId,
      authorId: (data['authorId'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      parentReplyId: data['parentReplyId'] as String?,
      createdAt: createdAt,
      updatedAt: readTs(data['updatedAt'], createdAt),
      authorDisplayName: data['authorDisplayName'] as String?,
      authorUsername: data['authorUsername'] as String?,
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      helpfulCount: (data['helpfulCount'] as num?)?.toInt() ?? 0,
      deleted: data['deleted'] == true,
    );
  }

  ThreadReplyDto _replyFromLegacyComment(ForumComment comment) {
    return ThreadReplyDto(
      id: comment.id,
      threadId: comment.postId,
      authorId: comment.author.uid,
      body: comment.content,
      parentReplyId: comment.parentCommentId,
      createdAt: comment.createdAt,
      updatedAt: comment.updatedAt ?? comment.createdAt,
      authorDisplayName: comment.author.displayName,
      authorUsername: comment.author.username,
      authorAvatarUrl: comment.author.avatarUrl,
      helpfulCount: comment.likes,
      deleted: comment.deleted,
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
    String filter, {
    String? viewerId,
  }) {
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
      case 'following':
        if (viewerId == null || viewerId.isEmpty) {
          return input;
        }
        return input
            .where(
              (ThreadDto t) => t.legacyFollowedBy.contains(viewerId),
            )
            .toList(growable: false);
      default:
        return input;
    }
  }
}
