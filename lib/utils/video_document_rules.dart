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

/// Owner profile grid/status visibility.
const Set<String> kOwnerProfileVideoStatuses = {
  'processing',
  'ready',
  'failed',
};

/// Public profile/card video visibility for non-owner viewers.
const Set<String> kPublicProfileVideoStatuses = {
  'processing',
  'ready',
};

/// Profile grid / owner list — kept for existing callers.
const Set<String> kVideoProfileListStatuses = kOwnerProfileVideoStatuses;

bool isVideoProfileListStatus(String? rawStatus) {
  final String status = (rawStatus ?? 'processing').toLowerCase();
  return kVideoProfileListStatuses.contains(status);
}

bool canShowVideo({
  required Map<String, dynamic> video,
  required String viewerId,
  required String ownerId,
}) {
  if (isVideoDeletedFromFirestore(video)) {
    return false;
  }

  final String status =
      (video['status'] as String? ?? 'processing').toLowerCase();
  final bool isOwner = viewerId.isNotEmpty && viewerId == ownerId;
  if (isOwner) {
    return kOwnerProfileVideoStatuses.contains(status);
  }

  final String visibility =
      (video['visibility'] as String? ?? '').trim().toLowerCase();
  return visibility == 'public' && kPublicProfileVideoStatuses.contains(status);
}

bool canShowHomeVideo({
  required HomeVideo video,
  required String viewerId,
  required String ownerId,
}) {
  return canShowVideo(
    video: <String, dynamic>{
      'status': video.status,
      'visibility': video.visibility,
      'isDeleted': video.isDeleted,
      'deletedAt': video.deletedAt,
    },
    viewerId: viewerId,
    ownerId: ownerId,
  );
}

void logProfileVideoCheck({
  required String viewName,
  required String viewerId,
  required String profileUserId,
  required String videoId,
  required String ownerId,
  required String status,
  required String visibility,
  required bool isDeleted,
  required bool canShow,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    'PROFILE_VIDEO_CHECK '
    'view=$viewName '
    'viewerId=$viewerId '
    'profileUserId=$profileUserId '
    'videoId=$videoId '
    'ownerId=$ownerId '
    'status=$status '
    'visibility=$visibility '
    'isDeleted=$isDeleted '
    'canShow=$canShow',
  );
}

/// Autoplay / controller init — ready docs with a playback URL only.
bool isVideoEligibleForAutoplay(Map<String, dynamic> data) {
  final String status = (data['status'] as String? ?? '').toLowerCase();
  if (!kVideoVisibleInFeedStatuses.contains(status)) {
    return false;
  }
  return hasReadyPlaybackSource(data);
}

bool isHomeVideoEligibleForProfileList(HomeVideo video) {
  if (video.isDraft == true) {
    return false;
  }
  return isVideoProfileListStatus(video.status);
}

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

bool isHomeVideoVisibleInFeed(HomeVideo video) {
  return isVideoVisibleInFeed(<String, dynamic>{
    'status': video.status,
    'isDeleted': video.isDeleted,
    'deletedAt': video.deletedAt,
  });
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

/// Profile grid display — aligned with website (show processing + ready).
String? rejectProfileListCandidate(
  Map<String, dynamic> data,
  String profileUserId, {
  String? viewerUserId,
  String viewName = 'ProfileView',
}) {
  if (isVideoDeletedFromFirestore(data)) {
    return 'deleted';
  }
  final String? owner = (data['ownerId'] as String?)?.trim();
  if (owner == null || owner.isEmpty || owner != profileUserId) {
    return 'owner_mismatch';
  }
  if (data['isDraft'] == true) {
    return 'isDraft';
  }
  final String viewerId = viewerUserId ?? '';
  final bool show = canShowVideo(
    video: data,
    viewerId: viewerId,
    ownerId: profileUserId,
  );
  logProfileVideoCheck(
    viewName: viewName,
    viewerId: viewerId,
    profileUserId: profileUserId,
    videoId: (data['id'] ?? data['videoId'] ?? '').toString(),
    ownerId: owner,
    status: (data['status'] as String? ?? 'processing').toLowerCase(),
    visibility: (data['visibility'] ?? data['privacy'] ?? '').toString(),
    isDeleted: data['isDeleted'] == true ||
        data['deleted'] == true ||
        data['deletedAt'] != null,
    canShow: show,
  );
  if (!show) {
    final String status =
        (data['status'] as String? ?? 'processing').toLowerCase();
    final bool isOwnerViewing = viewerId == profileUserId;
    if (isOwnerViewing && !kOwnerProfileVideoStatuses.contains(status)) {
      return 'status:$status';
    }
    if (!isOwnerViewing && !kPublicProfileVideoStatuses.contains(status)) {
      return 'status:$status';
    }
    final String visibility =
        (data['visibility'] as String? ?? '').trim().toLowerCase();
    if (visibility != 'public' && viewerId != profileUserId) {
      return 'visibility';
    }
    return 'status:$status';
  }
  return null;
}

/// Post-count / stats — strict feed-ready gate (unchanged).
String? rejectProfileGridCandidate(
  Map<String, dynamic> data,
  String profileUserId,
) {
  final String? owner = getOwnerId(data);
  if (owner == null || owner != profileUserId) {
    return 'owner_mismatch';
  }
  if (!isVideoVisibleInFeed(data)) {
    return 'status:${data['status']}';
  }
  if (data['visible'] == false) {
    return 'visible:false';
  }
  if (data['isDraft'] == true) {
    return 'isDraft';
  }
  if (data['isReadyForFeed'] != true) {
    return 'isReadyForFeed:not_true';
  }
  if (!isPublicFeedVisibility(data)) {
    return 'visibility';
  }
  return null;
}

void logVideoEligibility({
  required String videoId,
  required Map<String, dynamic> data,
  String? excludedReason,
  String context = 'profile',
}) {
  if (!kDebugMode) {
    return;
  }
  final String? ownerId = getOwnerId(data);
  final String? playbackUrl = resolveReadyPlaybackUrl(data);
  final String? thumbnailUrl =
      (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;
  debugPrint(
    'VIDEO_ELIGIBILITY context=$context id=$videoId '
    'ownerId=$ownerId '
    'status=${data['status']} '
    'visibility=${data['visibility']} '
    'isDeleted=${data['isDeleted']} '
    'hasPlayback=${playbackUrl != null} '
    'hasThumbnail=${thumbnailUrl != null && thumbnailUrl.isNotEmpty} '
    'excludedReason=${excludedReason ?? 'none'}',
  );
}

/// Debug log for app vs website feed parity (profile + home hydration).
void logFeedVideoCandidate({
  required String context,
  required String videoId,
  required Map<String, dynamic> data,
  String? rejectReason,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    'FEED_VIDEO context=$context id=$videoId '
    'reject=${rejectReason ?? 'none'} '
    'status=${data['status']} visibility=${data['visibility']} '
    'privacy=${data['privacy']} isReadyForFeed=${data['isReadyForFeed']} '
    'playbackUrl=${data['playbackUrl']} muxPlaybackId=${data['muxPlaybackId']} '
    'createdAt=${data['createdAt']}',
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
