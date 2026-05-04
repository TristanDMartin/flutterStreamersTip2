import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/gamification/gamification_providers.dart';
import '../features/gamification/models/subscription_plan.dart';
import '../features/gamification/models/user_progress_bundle.dart';
import '../features/tippy/tippy_access.dart';
import '../models/creator_command_snapshot.dart';
import 'current_user_provider.dart';

final Provider<FirebaseFirestore> creatorCommandFirestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

final StreamProvider<List<Map<String, dynamic>>> creatorCommandScheduledPostsProvider =
    StreamProvider<List<Map<String, dynamic>>>((Ref ref) {
  final AsyncValue<Map<String, dynamic>?> identity =
      ref.watch(currentUserStreamProvider);
  final String? userId = identity.valueOrNull?['id'] as String?;
  if (userId == null || userId.isEmpty) {
    return Stream<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]);
  }

  final FirebaseFirestore firestore = ref.watch(creatorCommandFirestoreProvider);
  return firestore
      .collection('scheduled_posts')
      .where('authorId', isEqualTo: userId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
        .toList(growable: false);
  });
});

final StreamProvider<int> creatorCommandDraftCountProvider =
    StreamProvider<int>((Ref ref) {
  final AsyncValue<Map<String, dynamic>?> identity =
      ref.watch(currentUserStreamProvider);
  final String? userId = identity.valueOrNull?['id'] as String?;
  if (userId == null || userId.isEmpty) {
    return Stream<int>.value(0);
  }

  final FirebaseFirestore firestore = ref.watch(creatorCommandFirestoreProvider);
  return firestore
      .collection('users')
      .doc(userId)
      .collection('drafts')
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs.length);
});

final StreamProvider<Map<String, dynamic>?> creatorCommandMetricsProvider =
    StreamProvider<Map<String, dynamic>?>((Ref ref) {
  final AsyncValue<Map<String, dynamic>?> identity =
      ref.watch(currentUserStreamProvider);
  final String? userId = identity.valueOrNull?['id'] as String?;
  if (userId == null || userId.isEmpty) {
    return Stream<Map<String, dynamic>?>.value(null);
  }

  final FirebaseFirestore firestore = ref.watch(creatorCommandFirestoreProvider);
  return firestore.collection('creator_metrics').doc(userId).snapshots().map(
    (DocumentSnapshot<Map<String, dynamic>> doc) => doc.data(),
  );
});

final StreamProvider<List<Map<String, dynamic>>> creatorCommandRecentVideosProvider =
    StreamProvider<List<Map<String, dynamic>>>((Ref ref) {
  final AsyncValue<Map<String, dynamic>?> identity =
      ref.watch(currentUserStreamProvider);
  final String? userId = identity.valueOrNull?['id'] as String?;
  if (userId == null || userId.isEmpty) {
    return Stream<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]);
  }

  final FirebaseFirestore firestore = ref.watch(creatorCommandFirestoreProvider);
  return firestore
      .collection('videos')
      .where('creatorId', isEqualTo: userId)
      .limit(100)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<Map<String, dynamic>> docs = snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data(),
        )
        .toList(growable: false);
    docs.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime? da = _readVideoCreatedAt(a);
      final DateTime? db = _readVideoCreatedAt(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return docs;
  });
});

final Provider<AsyncValue<CreatorCommandSnapshot?>> creatorCommandSnapshotProvider =
    Provider<AsyncValue<CreatorCommandSnapshot?>>((Ref ref) {
  final AsyncValue<Map<String, dynamic>?> identity =
      ref.watch(currentUserStreamProvider);
  final AsyncValue<UserProgressBundle> progress =
      ref.watch(userProgressBundleProvider);
  final AsyncValue<List<Map<String, dynamic>>> scheduledPosts =
      ref.watch(creatorCommandScheduledPostsProvider);
  final AsyncValue<int> draftCount = ref.watch(creatorCommandDraftCountProvider);
  final AsyncValue<Map<String, dynamic>?> metrics =
      ref.watch(creatorCommandMetricsProvider);
  final AsyncValue<List<Map<String, dynamic>>> recentVideos =
      ref.watch(creatorCommandRecentVideosProvider);

  if (identity.isLoading) {
    return const AsyncValue<CreatorCommandSnapshot?>.loading();
  }

  if (identity.hasError) {
    return AsyncValue<CreatorCommandSnapshot?>.error(
      identity.error!,
      identity.stackTrace ?? StackTrace.current,
    );
  }

  final Map<String, dynamic>? userData = identity.valueOrNull;
  if (userData == null) {
    return const AsyncValue<CreatorCommandSnapshot?>.data(null);
  }

  final UserProgressBundle bundle =
      progress.valueOrNull ?? UserProgressBundle.fallback();
  final List<Map<String, dynamic>> scheduledList =
      scheduledPosts.valueOrNull ?? const <Map<String, dynamic>>[];
  final int safeDraftCount = draftCount.valueOrNull ?? 0;
  final Map<String, dynamic>? metricsMap = metrics.valueOrNull;
  final List<Map<String, dynamic>> videoList =
      recentVideos.valueOrNull ?? const <Map<String, dynamic>>[];

  return AsyncValue<CreatorCommandSnapshot?>.data(
    buildCreatorCommandSnapshot(
      userData: userData,
      bundle: bundle,
      scheduledPosts: scheduledList,
      draftCount: safeDraftCount,
      metrics: metricsMap,
      recentVideos: videoList,
    ),
  );
});

CreatorCommandSnapshot buildCreatorCommandSnapshot({
  required Map<String, dynamic> userData,
  required UserProgressBundle bundle,
  required List<Map<String, dynamic>> scheduledPosts,
  required int draftCount,
  required Map<String, dynamic>? metrics,
  required List<Map<String, dynamic>> recentVideos,
}) {
  final List<Map<String, dynamic>> creatorPosts = scheduledPosts
      .where((Map<String, dynamic> post) => (post['authorId'] as String?) == userData['id'])
      .toList(growable: false);
  creatorPosts.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime? aTime = _readScheduledAt(a);
    final DateTime? bTime = _readScheduledAt(b);
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return aTime.compareTo(bTime);
  });

  final DateTime now = DateTime.now();
  final List<Map<String, dynamic>> plannerPosts = creatorPosts
      .where((Map<String, dynamic> post) {
    final String status = (post['status'] as String? ?? '').toLowerCase();
    return status == 'scheduled' ||
        status == 'publishing' ||
        status == 'draft';
  }).toList(growable: false);
  final List<Map<String, dynamic>> queuePosts = creatorPosts
      .where((Map<String, dynamic> post) {
    final String status = (post['status'] as String? ?? '').toLowerCase();
    return status == 'scheduled' || status == 'publishing';
  }).toList(growable: false);
  final int scheduledQueueCount = queuePosts.length;
  final List<Map<String, dynamic>> duePosts = queuePosts
      .where((Map<String, dynamic> post) => _readScheduledAt(post) != null)
      .toList(growable: false);
  duePosts.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime aTime = _readScheduledAt(a)!;
    final DateTime bTime = _readScheduledAt(b)!;
    return aTime.compareTo(bTime);
  });
  final Map<String, dynamic>? nextPost =
      duePosts.isEmpty ? null : duePosts.first;
  final DateTime? nextPostDueAt =
      nextPost == null ? null : _readScheduledAt(nextPost);
  final bool nextPostOverdue =
      nextPostDueAt != null && nextPostDueAt.isBefore(now);
  final int alertCount = plannerPosts.where((Map<String, dynamic> post) {
    final bool requiresAttention =
        post['metadata']?['requiresCreatorAttention'] as bool? ??
            post['requiresCreatorAttention'] as bool? ??
            false;
    final DateTime? dueAt = _readScheduledAt(post);
    final bool overdue = dueAt != null && dueAt.isBefore(now);
    return requiresAttention || overdue;
  }).length;

  final double? uploadConsistency = _readDouble(
        metrics,
        const <String>['uploadConsistency'],
      ) ??
      _calculateUploadConsistency(recentVideos);
  final int consistencyScorePercent =
      ((uploadConsistency ?? 0).clamp(0.0, 1.0) * 100).round();
  final double? growthVelocity = _readDouble(
    metrics,
    const <String>['growthVelocity'],
  );

  return CreatorCommandSnapshot(
    userId: userData['id'] as String? ?? '',
    username: userData['username'] as String? ?? '',
    displayName: userData['displayName'] as String? ?? '',
    level: bundle.progress.level,
    streakDays: bundle.progress.streakDays,
    subscriptionPlan: bundle.subscription?.plan ?? SubscriptionPlan.unknown,
    tippyAiEnabled: resolveTippyEnabled(bundle),
    draftCount: draftCount,
    consistencyScorePercent: consistencyScorePercent,
    alertCount: alertCount,
    requiresAttentionCount: alertCount,
    pendingWorkCount: draftCount,
    scheduledQueueCount: scheduledQueueCount,
    growthPercent: growthVelocity == null ? null : growthVelocity * 100,
    nextPostDueAt: nextPostDueAt,
    nextPostOverdue: nextPostOverdue,
  );
}

DateTime? _readVideoCreatedAt(Map<String, dynamic> video) {
  final Object? createdAt = video['createdAt'];
  if (createdAt is Timestamp) return createdAt.toDate();
  if (createdAt is DateTime) return createdAt;
  if (createdAt is String) return DateTime.tryParse(createdAt);
  return null;
}

DateTime? _coerceToDateTime(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

DateTime? _readScheduledAt(Map<String, dynamic>? post) {
  if (post == null) return null;
  final List<DateTime> candidates = <DateTime>[];
  final Object? schedule = post['schedule'];
  if (schedule is Map<String, dynamic>) {
    final DateTime? root = _coerceToDateTime(schedule['scheduledAtUtc']);
    if (root != null) candidates.add(root);
    final Object? perRaw = schedule['perPlatform'];
    if (perRaw is Map<String, dynamic>) {
      for (final Object? value in perRaw.values) {
        if (value is Map<String, dynamic>) {
          final DateTime? t = _coerceToDateTime(value['scheduledAtUtc']);
          if (t != null) candidates.add(t);
        }
      }
    }
  }
  final DateTime? docRoot = _coerceToDateTime(post['scheduledAtUtc']);
  if (docRoot != null) candidates.add(docRoot);
  final List<dynamic>? platforms = post['platforms'] as List<dynamic>?;
  if (platforms != null) {
    for (final Object? rawPlatform in platforms) {
      if (rawPlatform is! Map<String, dynamic>) continue;
      final bool enabled = rawPlatform['enabled'] as bool? ?? true;
      if (!enabled) continue;
      final DateTime? t = _coerceToDateTime(rawPlatform['scheduledAtUtc']);
      if (t != null) candidates.add(t);
    }
  }
  if (candidates.isEmpty) return null;
  candidates.sort((DateTime a, DateTime b) => a.compareTo(b));
  return candidates.first;
}

double? _readDouble(Map<String, dynamic>? source, List<String> keys) {
  if (source == null) return null;
  for (final String key in keys) {
    final Object? value = source[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
  }
  return null;
}

double? _calculateUploadConsistency(List<Map<String, dynamic>> videos) {
  if (videos.length < 2) return 0.0;
  final DateTime now = DateTime.now();
  int weeksWithUploads = 0;
  for (int week = 0; week < 10; week++) {
    final DateTime weekStart = now.subtract(Duration(days: 7 * (week + 1)));
    final DateTime weekEnd = now.subtract(Duration(days: 7 * week));
    final bool hasUploadThisWeek = videos.any((Map<String, dynamic> video) {
      final Object? createdAt = video['createdAt'];
      DateTime? date;
      if (createdAt is Timestamp) {
        date = createdAt.toDate();
      } else if (createdAt is DateTime) {
        date = createdAt;
      } else if (createdAt is String) {
        date = DateTime.tryParse(createdAt);
      }
      return date != null &&
          date.isAfter(weekStart) &&
          date.isBefore(weekEnd);
    });
    if (hasUploadThisWeek) {
      weeksWithUploads++;
    }
  }
  return weeksWithUploads / 10.0;
}
