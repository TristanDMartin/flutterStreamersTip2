import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../models/home_video.dart';
import '../../../models/optimistic_video.dart';
import '../../../services/optimistic_video_service.dart';
import '../../../utils/home_video_playback.dart';
import '../../../utils/video_document_rules.dart';
import 'home_feed_pending_upload_merge.dart';

/// Rank for owner-visible lifecycle. Higher = more advanced. Used so merges
/// never downgrade LOCAL_PENDING → removed → pending.
int ownerVideoLifecycleRank(HomeVideo video) {
  final String status = video.status.toLowerCase();
  if (status.contains('fail')) {
    return 10;
  }
  if (isHomeVideoOwnerPendingLocal(video)) {
    return 40;
  }
  if (status == 'uploading' || status == 'pending') {
    return 30;
  }
  if (status == 'processing') {
    return 50;
  }
  if (status == 'ready' ||
      status == 'published' ||
      status == 'active') {
    if (isHomeVideoPlayable(video) &&
        !isHomeVideoLocalFileUrl(video.videoURL)) {
      return 90;
    }
    return 70;
  }
  return 20;
}

bool isOwnerProtectedPendingVideo(HomeVideo video) {
  if (video.isDeleted) {
    return false;
  }
  if (isHomeVideoOwnerPendingLocal(video)) {
    return true;
  }
  final String status = video.status.toLowerCase();
  return status == 'uploading' ||
      status == 'processing' ||
      status == 'pending';
}

void logOwnerVideoMutation({
  required String videoId,
  required String action,
  required String source,
  String? previousState,
  String? nextState,
  String? reason,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    'OWNER_VIDEO_MUTATION videoId=$videoId action=$action '
    'source=$source previousState=${previousState ?? '-'} '
    'nextState=${nextState ?? '-'} reason=${reason ?? '-'}',
  );
}

/// Single owner Profile/Streamer list: canonical + durable pending, merge by id.
///
/// Public feed readiness (`isReadyForFeed`) never drops an owner card.
List<HomeVideo> mergeOwnerProfileVideos({
  required String profileUserId,
  required String viewerId,
  required List<HomeVideo> canonicalVideos,
  required OptimisticVideoService optimisticVideoService,
  String? currentUserDisplayName,
  String? currentUserPhotoUrl,
}) {
  final bool isOwner =
      viewerId.isNotEmpty && viewerId == profileUserId;
  final Map<String, HomeVideo> byId = <String, HomeVideo>{};
  for (final HomeVideo video in canonicalVideos) {
    if (!_belongsToOwner(video, profileUserId)) {
      continue;
    }
    if (!canShowHomeVideo(
      video: video,
      viewerId: viewerId,
      ownerId: profileUserId,
    )) {
      continue;
    }
    byId[video.id] = isOwner
        ? enrichOwnerPendingLocalHomeVideo(video)
        : video;
  }
  if (isOwner) {
    final List<OptimisticVideo> pending = optimisticVideoService
        .getOptimisticVideosForUser(profileUserId)
        .toList(growable: false);
    for (final OptimisticVideo item in pending) {
      final HomeVideo card = homeVideoFromOptimisticVideo(
        optimistic: item,
        currentUserDisplayName: currentUserDisplayName,
        currentUserPhotoUrl: currentUserPhotoUrl,
      );
      final HomeVideo? existing = byId[card.id];
      if (existing == null) {
        byId[card.id] = card;
        continue;
      }
      byId[card.id] = _pickMonotonicOwnerVideo(existing, card);
    }
  }
  final List<HomeVideo> merged = byId.values.toList(growable: false);
  merged.sort((HomeVideo a, HomeVideo b) {
    final int aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final int bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
    return bMs.compareTo(aMs);
  });
  return merged;
}

bool _belongsToOwner(HomeVideo video, String ownerId) {
  return ownerId.isNotEmpty && video.creator.id == ownerId;
}

HomeVideo _pickMonotonicOwnerVideo(HomeVideo existing, HomeVideo incoming) {
  final int existingRank = ownerVideoLifecycleRank(existing);
  final int incomingRank = ownerVideoLifecycleRank(incoming);
  if (incomingRank > existingRank) {
    return incoming;
  }
  if (incomingRank < existingRank) {
    return existing;
  }
  if (isHomeVideoOwnerPendingLocal(existing) &&
      !isHomeVideoOwnerPendingLocal(incoming)) {
    return existing;
  }
  if (isHomeVideoPlayable(existing) && !isHomeVideoPlayable(incoming)) {
    return existing;
  }
  return incoming;
}

/// Whether a Firestore snapshot means the owner card must be removed.
bool shouldRemoveOwnerVideoFromSnapshot({
  required bool docExists,
  required Map<String, dynamic>? data,
  required bool isOwnerViewing,
  required bool hasDurablePending,
}) {
  if (!docExists) {
    // Instant Publish: Worker may not have created videos/{id} yet.
    if (isOwnerViewing && hasDurablePending) {
      return false;
    }
    return true;
  }
  if (data == null) {
    return isOwnerViewing ? false : true;
  }
  if (isVideoDeletedFromFirestore(data)) {
    return true;
  }
  if (isOwnerViewing) {
    // Owner may see uploading/processing — never treat as deletion.
    final String status =
        (data['status'] as String? ?? 'processing').toLowerCase();
    return !kOwnerProfileVideoStatuses.contains(status);
  }
  return !isVideoVisibleInFeed(data);
}

/// Preserve owner pending/processing rows across public feed refreshes.
List<HomeVideo> preserveOwnerVideosAcrossPublicFeedRefresh({
  required List<HomeVideo> incomingPublicFeed,
  required List<HomeVideo> existingState,
  required String viewerId,
}) {
  final List<HomeVideo> next = List<HomeVideo>.of(incomingPublicFeed);
  final Set<String> nextIds = next.map((HomeVideo v) => v.id).toSet();
  for (final HomeVideo existing in existingState) {
    if (nextIds.contains(existing.id)) {
      continue;
    }
    final String ownerId = existing.creator.id;
    if (ownerId.isEmpty) {
      continue;
    }
    final bool isOwnPending = viewerId.isNotEmpty &&
        ownerId == viewerId &&
        isOwnerProtectedPendingVideo(existing);
    if (isOwnPending ||
        canShowHomeVideo(
          video: existing,
          viewerId: viewerId,
          ownerId: ownerId,
        )) {
      next.add(existing);
      nextIds.add(existing.id);
    }
  }
  return next;
}

Timestamp? createdAtOrNow(HomeVideo video) {
  return video.createdAt ?? Timestamp.now();
}
