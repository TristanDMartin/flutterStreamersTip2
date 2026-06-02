import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/home_video.dart';
import '../../../models/optimistic_video.dart';
import '../../../models/user.dart' as st_user;
import '../../../services/optimistic_video_service.dart';
import '../../../utils/video_caption_resolver.dart';

/// Merges in-flight optimistic uploads into a ready feed list.
List<HomeVideo> mergePendingUploadsIntoFeed({
  required List<HomeVideo> readyVideos,
  required String? currentUserId,
  required OptimisticVideoService optimisticVideoService,
  String? currentUserDisplayName,
  String? currentUserPhotoUrl,
}) {
  if (currentUserId == null) {
    return enrichHomeVideosWithOptimisticCaptions(
      videos: readyVideos,
      optimisticVideoService: optimisticVideoService,
    );
  }
  final List<OptimisticVideo> pendingUploads = optimisticVideoService
      .getOptimisticVideosForUser(currentUserId)
      .where(
        (OptimisticVideo item) =>
            item.status.isProcessing ||
            item.status.isPlaceholderPending ||
            item.status.hasFailed,
      )
      .where(
        (OptimisticVideo item) =>
            !readyVideos.any((HomeVideo video) => video.id == item.videoId),
      )
      .toList()
    ..sort(
      (OptimisticVideo a, OptimisticVideo b) =>
          b.createdAt.compareTo(a.createdAt),
    );
  if (pendingUploads.isEmpty) {
    return enrichHomeVideosWithOptimisticCaptions(
      videos: readyVideos,
      optimisticVideoService: optimisticVideoService,
    );
  }
  final List<HomeVideo> pendingCards = pendingUploads
      .map(
        (OptimisticVideo optimistic) => homeVideoFromOptimisticVideo(
          optimistic: optimistic,
          currentUserDisplayName: currentUserDisplayName,
          currentUserPhotoUrl: currentUserPhotoUrl,
        ),
      )
      .toList(growable: false);
  return enrichHomeVideosWithOptimisticCaptions(
    videos: <HomeVideo>[...pendingCards, ...readyVideos],
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
  return HomeVideo(
    id: optimistic.videoId,
    creator: creator,
    videoURL: '',
    thumbnailURL: optimistic.thumbnailUrl,
    caption: optimistic.caption,
    overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(
      optimistic.metadata ?? const <String, dynamic>{},
    ),
    status: optimistic.status.hasFailed ? 'failed' : 'processing',
    categoryId:
        optimistic.categories.isNotEmpty ? optimistic.categories.first : '',
    createdAt: Timestamp.fromDate(optimistic.createdAt),
  );
}
