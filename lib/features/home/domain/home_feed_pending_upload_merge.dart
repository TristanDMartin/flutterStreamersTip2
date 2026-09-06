import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../models/home_video.dart';
import '../../../models/optimistic_video.dart';
import '../../../models/user.dart' as st_user;
import '../../../models/video_thumbnails.dart';
import '../../../services/optimistic_video_service.dart';
import '../../../utils/home_video_playback.dart';
import '../../../utils/video_caption_resolver.dart';
import '../../../utils/video_document_rules.dart';
import '../../../utils/video_url_resolver.dart';

String localPlaybackUrlFromPath(String? path) {
  final String trimmed = (path ?? '').trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('file://')) {
    return trimmed;
  }
  return 'file://$trimmed';
}

String _filesystemPathFromLocalUrl(String pathOrUrl) {
  final String trimmed = pathOrUrl.trim();
  if (trimmed.startsWith('file://')) {
    try {
      return Uri.parse(trimmed).toFilePath();
    } catch (_) {
      return trimmed.replaceFirst('file://', '');
    }
  }
  return trimmed;
}

bool optimisticLocalFileExists(OptimisticVideo item) {
  final String path = (item.localVideoPath ?? '').trim();
  if (path.isEmpty) {
    return false;
  }
  return File(_filesystemPathFromLocalUrl(path)).existsSync();
}

bool homeVideoLocalFileExists(HomeVideo video) {
  if (!isHomeVideoLocalFileUrl(video.videoURL)) {
    return false;
  }
  return File(_filesystemPathFromLocalUrl(video.videoURL)).existsSync();
}

bool _optimisticHasLocalPlayback(OptimisticVideo item) {
  return optimisticLocalFileExists(item);
}

bool _shouldOverlayOptimisticOnHome(OptimisticVideo item) {
  // Instant Publish: Home card only when durable local MP4 exists on disk.
  return _optimisticHasLocalPlayback(item);
}

/// Owner Profile/Streamer Instant Publish overlay.
///
/// Keep local-backed optimistic rows visible until the grid already has the
/// same id (enriched stub or remote-ready). Includes [VideoStatus.uploadSucceeded]
/// so Profile does not drop the tile when Mux flips ready before merge catches up.
bool shouldOverlayOptimisticOnOwnerProfile({
  required OptimisticVideo item,
  required List<HomeVideo> profileVideos,
}) {
  if (item.status.hasFailed) {
    return !profileVideos.any(
      (HomeVideo video) => video.id == item.videoId,
    );
  }
  if (!_optimisticHasLocalPlayback(item)) {
    return false;
  }
  return !profileVideos.any(
    (HomeVideo video) => video.id == item.videoId,
  );
}

bool isHomeVideoDisplayPlayable(HomeVideo video) {
  if (isHomeVideoOwnerPendingLocal(video)) {
    return homeVideoLocalFileExists(video);
  }
  if (!isHomeVideoPlayable(video)) {
    return false;
  }
  if (isHomeVideoLocalFileUrl(video.videoURL)) {
    return homeVideoLocalFileExists(video);
  }
  return resolveReadyPlaybackUrl(<String, dynamic>{
        'status': video.status,
        'isReadyForFeed': true,
        'canonicalPlaybackUrl': video.videoURL,
        'hlsUrl': video.videoURL,
        'videoUrl': video.videoURL,
      }) !=
      null;
}


bool _hasRemotePlayableCanonical(List<HomeVideo> canonical, String videoId) {
  for (final HomeVideo video in canonical) {
    if (video.id != videoId) {
      continue;
    }
    if (isHomeVideoOwnerPendingLocal(video)) {
      return false;
    }
    if (!isHomeVideoPlayable(video)) {
      return false;
    }
    if (isHomeVideoLocalFileUrl(video.videoURL)) {
      return false;
    }
    return true;
  }
  return false;
}

/// Merges in-flight optimistic uploads into a ready feed list.
///
/// Canonical feed stays untouched for other users; pending overlays are
/// owner-only and prepended at index 0 (newest first).
List<HomeVideo> mergePendingUploadsIntoFeed({
  required List<HomeVideo> readyVideos,
  required String? currentUserId,
  required OptimisticVideoService optimisticVideoService,
  String? currentUserDisplayName,
  String? currentUserPhotoUrl,
}) {
  final List<HomeVideo> ownerProcessing = readyVideos
      .where((HomeVideo video) {
        if (currentUserId == null || currentUserId.isEmpty) {
          return false;
        }
        if (video.creator.id != currentUserId) {
          return false;
        }
        return isHomeVideoProcessing(video);
      })
      .toList(growable: false);
  final List<HomeVideo> canonical = readyVideos
      .where((HomeVideo video) => !isHomeVideoOwnerPendingLocal(video))
      .where((HomeVideo video) => !isHomeVideoProcessing(video))
      .where(isHomeVideoVisibleInFeed)
      .toList(growable: false);
  if (currentUserId == null || currentUserId.isEmpty) {
    debugPrint(
      'HOME_CANONICAL_COUNT=${canonical.length} PENDING_OVERLAY_COUNT=0 '
      'HOME_MERGED_COUNT=${canonical.length}',
    );
    return enrichHomeVideosWithOptimisticCaptions(
      videos: canonical,
      optimisticVideoService: optimisticVideoService,
    );
  }
  final List<OptimisticVideo> pendingUploads = optimisticVideoService
      .getOptimisticVideosForUser(currentUserId)
      .where(_shouldOverlayOptimisticOnHome)
      .where(
        (OptimisticVideo item) => !_hasRemotePlayableCanonical(
          canonical,
          item.videoId,
        ),
      )
      .toList()
    ..sort(
      (OptimisticVideo a, OptimisticVideo b) =>
          b.createdAt.compareTo(a.createdAt),
    );
  debugPrint(
    'HOME_CANONICAL_COUNT=${canonical.length} '
    'PENDING_OVERLAY_COUNT=${pendingUploads.length} '
    'OWNER_PROCESSING_COUNT=${ownerProcessing.length}',
  );
  if (pendingUploads.isEmpty && ownerProcessing.isEmpty) {
    debugPrint('HOME_MERGED_COUNT=${canonical.length}');
    return enrichHomeVideosWithOptimisticCaptions(
      videos: canonical,
      optimisticVideoService: optimisticVideoService,
    );
  }
  final List<HomeVideo> pendingCards = <HomeVideo>[];
  for (int i = 0; i < pendingUploads.length; i++) {
    final OptimisticVideo optimistic = pendingUploads[i];
    if (!_optimisticHasLocalPlayback(optimistic)) {
      debugPrint(
        'HOME_PENDING_SKIPPED videoId=${optimistic.videoId} reason=no_local_mp4',
      );
      continue;
    }
    final HomeVideo card = homeVideoFromOptimisticVideo(
      optimistic: optimistic,
      currentUserDisplayName: currentUserDisplayName,
      currentUserPhotoUrl: currentUserPhotoUrl,
    );
    if (!isHomeVideoPlayable(card) || !isHomeVideoDisplayPlayable(card)) {
      debugPrint(
        'HOME_PENDING_SKIPPED videoId=${card.id} reason=not_display_playable',
      );
      continue;
    }
    pendingCards.add(card);
    debugPrint(
      'HOME_PENDING_INSERTED videoId=${card.id} index=$i '
      'localPlayback=${isHomeVideoOwnerPendingLocal(card)}',
    );
  }
  final Set<String> pendingIds =
      pendingCards.map((HomeVideo video) => video.id).toSet();
  final List<HomeVideo> processingWithoutLocal = ownerProcessing
      .where((HomeVideo video) => !pendingIds.contains(video.id))
      .toList(growable: false);
  final List<HomeVideo> merged = <HomeVideo>[
    ...pendingCards,
    ...processingWithoutLocal,
    ...canonical,
  ];
  debugPrint('HOME_MERGED_COUNT=${merged.length}');
  return enrichHomeVideosWithOptimisticCaptions(
    videos: merged,
    optimisticVideoService: optimisticVideoService,
  );
}

/// Fills missing captions from optimistic publish metadata.
List<HomeVideo> enrichHomeVideosWithOptimisticCaptions({
  required List<HomeVideo> videos,
  required OptimisticVideoService optimisticVideoService,
}) {
  return videos.map((HomeVideo video) {
    if (video.caption.trim().isNotEmpty &&
        video.overlayCaption.trim().isNotEmpty) {
      return video;
    }
    final OptimisticVideo? optimistic =
        optimisticVideoService.getOptimisticVideo(video.id);
    final String cachedCaption =
        optimisticVideoService.peekPublishedCaption(video.id) ?? '';
    final String optimisticCaption =
        optimistic?.caption.trim() ?? cachedCaption.trim();
    final String optimisticOverlay = resolveVideoOverlayCaptionFromFirestoreData(
      optimistic?.metadata ?? const <String, dynamic>{},
    );
    if (optimisticCaption.isEmpty && optimisticOverlay.isEmpty) {
      return video;
    }
    return video.copyWith(
      caption:
          video.caption.trim().isNotEmpty ? video.caption : optimisticCaption,
      overlayCaption: video.overlayCaption.trim().isNotEmpty
          ? video.overlayCaption
          : optimisticOverlay,
    );
  }).toList(growable: false);
}

HomeVideo homeVideoFromOptimisticVideo({
  required OptimisticVideo optimistic,
  String? currentUserDisplayName,
  String? currentUserPhotoUrl,
}) {
  final st_user.User creator = st_user.User(
    id: optimistic.ownerId,
    username: currentUserDisplayName ?? 'you',
    displayName: currentUserDisplayName ?? 'You',
    avatarURL: currentUserPhotoUrl,
    bio: '',
    hashtags: const <String>[],
  );
  final String localUrl = optimisticLocalFileExists(optimistic)
      ? localPlaybackUrlFromPath(optimistic.localVideoPath)
      : '';
  final String remoteUrl = (optimistic.hlsUrl ?? optimistic.videoUrl ?? '')
      .trim();
  final bool preferRemote = optimistic.status.isReady &&
      remoteUrl.isNotEmpty &&
      !isHomeVideoLocalFileUrl(remoteUrl);
  // Prefer durable local Instant Play until Mux remote is ready.
  final String playbackUrl = preferRemote
      ? remoteUrl
      : (localUrl.isNotEmpty ? localUrl : remoteUrl);
  final String status = optimistic.status.hasFailed
      ? 'failed'
      : (preferRemote
          ? 'ready'
          : (localUrl.isNotEmpty
              ? 'uploading'
              : (remoteUrl.isNotEmpty ? 'ready' : 'processing')));
  return HomeVideo(
    id: optimistic.videoId,
    creator: creator,
    videoURL: playbackUrl,
    thumbnailURL:
        optimistic.localThumbnailPath ?? optimistic.thumbnailUrl,
    thumbnails: _thumbnailsFromOptimisticCover(optimistic),
    caption: optimistic.caption,
    overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(
      optimistic.metadata ?? const <String, dynamic>{},
    ),
    status: status,
    visibility: 'public',
    categoryId:
        optimistic.categories.isNotEmpty ? optimistic.categories.first : '',
    createdAt: Timestamp.fromDate(optimistic.createdAt),
  );
}

VideoThumbnails? _thumbnailsFromOptimisticCover(OptimisticVideo optimistic) {
  final String? local = optimistic.localThumbnailPath?.trim();
  final String? remote = optimistic.thumbnailUrl?.trim();
  final String? url =
      (local != null && local.isNotEmpty) ? local : remote;
  if (url == null || url.isEmpty) {
    return null;
  }
  return VideoThumbnails(
    urls: <int, String>{
      360: url,
      540: url,
      720: url,
    },
    generatedAt: Timestamp.fromDate(optimistic.createdAt),
    aspectRatio: 0.5625,
  );
}

/// Upserts owner Instant Publish rows into [VideoService] so Profile/Streamer
/// share the same pending cards Home already overlays — no republish required.
void upsertOwnerPendingOptimisticVideos({
  required String ownerId,
  required OptimisticVideoService optimisticVideoService,
  required List<HomeVideo> existingVideos,
  required void Function(HomeVideo video) upsert,
  String? currentUserDisplayName,
  String? currentUserPhotoUrl,
}) {
  if (ownerId.isEmpty) {
    return;
  }
  final Map<String, HomeVideo> byId = <String, HomeVideo>{
    for (final HomeVideo video in existingVideos) video.id: video,
  };
  final List<OptimisticVideo> pending = optimisticVideoService
      .getOptimisticVideosForUser(ownerId)
      .where((OptimisticVideo item) {
        if (item.status.hasFailed) {
          return true;
        }
        if (item.status.isReady) {
          final String remote =
              (item.hlsUrl ?? item.videoUrl ?? '').trim();
          return remote.isNotEmpty || _optimisticHasLocalPlayback(item);
        }
        return _optimisticHasLocalPlayback(item);
      })
      .toList(growable: false);
  for (final OptimisticVideo item in pending) {
    final HomeVideo? existing = byId[item.videoId];
    if (existing != null &&
        !isHomeVideoOwnerPendingLocal(existing) &&
        isHomeVideoPlayable(existing) &&
        !isHomeVideoLocalFileUrl(existing.videoURL)) {
      continue;
    }
    final HomeVideo card = homeVideoFromOptimisticVideo(
      optimistic: item,
      currentUserDisplayName: currentUserDisplayName,
      currentUserPhotoUrl: currentUserPhotoUrl,
    );
    upsert(card);
    byId[card.id] = card;
  }
}

/// When Firestore already has a processing row, Profile/Streamer hide the
/// optimistic card by id — reattach the durable local MP4 so owners still
/// see/play the post instead of a permanent "Processing…" tile.
HomeVideo enrichOwnerPendingLocalHomeVideo(HomeVideo video) {
  if (video.id.isEmpty) {
    return video;
  }
  final OptimisticVideo? optimistic =
      OptimisticVideoService().getOptimisticVideo(video.id);
  if (optimistic == null) {
    return video;
  }
  final String localUrl = optimisticLocalFileExists(optimistic)
      ? localPlaybackUrlFromPath(optimistic.localVideoPath)
      : '';
  if (localUrl.isEmpty) {
    return video;
  }
  final bool hasRemotePlayable = video.videoURL.trim().isNotEmpty &&
      !isHomeVideoLocalFileUrl(video.videoURL) &&
      (video.status.toLowerCase() == 'ready' ||
          video.status.toLowerCase() == 'published' ||
          video.status.toLowerCase() == 'active');
  if (hasRemotePlayable) {
    return video;
  }
  // Keep owner-profile status vocabulary (`processing`/`failed`); local URL
  // makes isHomeVideoOwnerPendingLocal true so grids play instead of stall.
  return video.copyWith(
    videoURL: localUrl,
    status: optimistic.status.hasFailed ? 'failed' : 'processing',
    thumbnailURL: optimistic.localThumbnailPath ?? video.thumbnailURL,
    thumbnails: video.thumbnails ??
        _thumbnailsFromOptimisticCover(optimistic),
    caption: video.caption.trim().isNotEmpty
        ? video.caption
        : optimistic.caption,
  );
}
