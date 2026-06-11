import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/home_video.dart';
import 'video_url_resolver.dart';

/// Feed-visible statuses (legacy `active`; target is `ready`).
const Set<String> kVideoVisibleInFeedStatuses = {
  'ready',
  'published',
  'active',
};

/// True when the doc has fields [FollowsService]/legacy resolution might use.
bool hasLegacyOwnerResolutionHints(Map<String, dynamic> data) {
  const hintKeys = <String>[
    'creatorUsername',
    'username',
    'creator',
    'handle',
    'creatorName',
    'displayName',
  ];
  for (final String key in hintKeys) {
    final Object? value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return true;
    }
  }
  final String? videoId = (data['id'] as String?)?.trim();
  if (videoId != null && videoId.contains('_')) {
    final String prefix = videoId.substring(0, videoId.indexOf('_'));
    if (prefix.length >= 20 && prefix.length <= 40) {
      return true;
    }
  }
  return false;
}

bool isPublicFeedVisibility(Map<String, dynamic> data) {
  final String? visibility = data['visibility'] as String?;
  final String? privacy = data['privacy'] as String?;
  return visibility == 'public' ||
      privacy == 'Everyone' ||
      privacy == 'Public' ||
      (visibility == null && privacy == null);
}

/// Fast reject before expensive hydration. Returns a machine-readable reason.
String? rejectFeedCandidateBeforeHydration(
  Map<String, dynamic> data, {
  String? Function(Map<String, dynamic> data)? readOwnerId,
}) {
  if (data['isDeleted'] == true || data['deleted'] == true) {
    return 'deleted_flag';
  }
  if (data['deletedAt'] != null) {
    return 'deletedAt';
  }
  final String status = (data['status'] as String? ?? '').toLowerCase();
  if (status == 'deleted' || status == 'removed') {
    return 'status:$status';
  }
  if (!kVideoVisibleInFeedStatuses.contains(status)) {
    return 'status:$status';
  }
  if (data['visible'] == false) {
    return 'visible:false';
  }
  if (data['isReadyForFeed'] != true) {
    return 'isReadyForFeed:not_true';
  }
  if (!isPublicFeedVisibility(data)) {
    return 'visibility';
  }
  final String? ownerId = readOwnerId?.call(data);
  if ((ownerId == null || ownerId.isEmpty) &&
      !hasLegacyOwnerResolutionHints(data)) {
    return 'missing_owner';
  }
  return null;
}

/// Mirror of web `isVideoVisibleInFeed` — use for every Firestore/API list.
bool isVideoVisibleInFeed(Map<String, dynamic>? data) {
  if (data == null) {
    return false;
  }
  if (data['isDeleted'] == true) {
    return false;
  }
  if (data['status'] == 'deleted') {
    return false;
  }
  if (data['deletedAt'] != null) {
    return false;
  }
  final String status = (data['status'] as String? ?? '').toLowerCase();
  return kVideoVisibleInFeedStatuses.contains(status);
}

/// [HomeVideo] rows built in-memory (no `deletedAt` on model; `status` is set).
bool isHomeVideoVisibleInFeed(HomeVideo video) {
  return isVideoVisibleInFeed(<String, dynamic>{'status': video.status});
}

bool isVideoDeletedFromFirestore(Map<String, dynamic> data) {
  if (data['isDeleted'] == true || data['deleted'] == true) {
    return true;
  }
  final String? status = (data['status'] as String?)?.toLowerCase();
  if (status == 'deleted' || status == 'removed') {
    return true;
  }
  final Object? deletedAt = data['deletedAt'];
  if (deletedAt is Timestamp || deletedAt is DateTime) {
    return true;
  }
  return false;
}

/// Home/discover public feed: visible status + not deleted + feed-ready flags.
bool isVideoEligibleForPublicFeed(Map<String, dynamic> data) {
  if (!isVideoVisibleInFeed(data)) {
    return false;
  }
  if (data['visible'] == false || data['isReadyForFeed'] != true) {
    return false;
  }
  return true;
}

/// Canonical reject reason for Home + Discover lists (owner + visibility + status).
String? rejectDiscoverVideoCandidate(Map<String, dynamic> data) {
  return rejectFeedCandidateBeforeHydration(
    data,
    readOwnerId: getOwnerId,
  );
}

/// Discover/Home shared eligibility: public feed rules + playable URL.
bool isDiscoverEligibleFromFirestore(
  Map<String, dynamic> data, {
  bool logSkip = false,
  String? videoId,
}) {
  final String id = videoId ?? (data['id'] as String?) ?? '';
  final String? reason = rejectDiscoverVideoCandidate(data);
  if (reason != null) {
    if (logSkip && kDebugMode) {
      logDiscoverVideoSkip(
        videoId: id,
        reason: reason,
        data: data,
      );
    }
    return false;
  }
  if (!hasReadyPlaybackSource(data)) {
    if (logSkip && kDebugMode) {
      logDiscoverVideoSkip(
        videoId: id,
        reason: 'no_playable_url',
        data: data,
      );
    }
    return false;
  }
  return true;
}

void logDiscoverVideoSkip({
  required String videoId,
  required String reason,
  required Map<String, dynamic> data,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    'DISCOVER_SKIP video=$videoId reason=$reason '
    'category=${data['category']} categoryId=${data['categoryId']} '
    'category_id=${data['category_id']} categories=${data['categories']} '
    'status=${data['status']} visibility=${data['visibility']} '
    'privacy=${data['privacy']}',
  );
}

void logDiscoverCategoryDiagnostic({
  required String selectedCategory,
  required int total,
  required int eligible,
  required int matching,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    'DISCOVER_DIAGNOSTIC selected=$selectedCategory total=$total '
    'eligible=$eligible matching=$matching',
  );
}
