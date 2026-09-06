import '../../../models/home_video.dart';
import '../../../services/optimistic_video_service.dart';
import '../../../utils/home_video_playback.dart';
import '../../../utils/video_document_rules.dart';
import 'home_feed_pending_upload_merge.dart';

/// Removes duplicate videos by id (first occurrence wins).
List<HomeVideo> dedupeHomeVideosById(List<HomeVideo> videos) {
  final Map<String, HomeVideo> byId = <String, HomeVideo>{};
  final List<HomeVideo> deduped = <HomeVideo>[];
  for (final HomeVideo video in videos) {
    final String id = video.id.trim();
    if (id.isEmpty || byId.containsKey(id)) {
      continue;
    }
    byId[id] = video;
    deduped.add(video);
  }
  return deduped;
}

/// Playable items first, then newest by [HomeVideo.createdAt].
List<HomeVideo> rankHomeVideosForFeed(List<HomeVideo> videos) {
  final List<HomeVideo> ordered = List<HomeVideo>.from(videos);
  ordered.sort((HomeVideo a, HomeVideo b) {
    final bool aPlayable = isHomeVideoPlayable(a);
    final bool bPlayable = isHomeVideoPlayable(b);
    if (aPlayable != bPlayable) {
      return aPlayable ? -1 : 1;
    }
    final int aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final int bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
    return bMs.compareTo(aMs);
  });
  return ordered;
}

/// Drops cached/painted cards whose owner is no longer renderable.
List<HomeVideo> keepHomeVideosWithRenderableOwners({
  required List<HomeVideo> videos,
  required Set<String> renderableOwnerIds,
}) {
  if (videos.isEmpty) {
    return videos;
  }
  return videos
      .where(
        (HomeVideo video) => renderableOwnerIds.contains(video.creator.id),
      )
      .toList(growable: false);
}

/// Keeps only items that can play in the home feed.
List<HomeVideo> filterPlayableHomeVideos(List<HomeVideo> feed) {
  return feed
      .where(isHomeVideoVisibleInFeed)
      .where(isHomeVideoDisplayPlayable)
      .toList(growable: false);
}

/// Rank, merge pending uploads, and dedupe for For You display.
///
/// Owner pending local items are kept even though they are not
/// globally feed-visible (`isReadyForFeed` / ready status), but only when the
/// durable local file still exists — never leave a blank cell at index 0.
/// Owner uploading/processing stubs from VideoService (cold-start Firestore
/// merge) are also prepended so kill/reopen does not hide the owner's post.
List<HomeVideo> prepareForYouFeedDisplayList({
  required List<HomeVideo> sourceVideos,
  required String? currentUserId,
  required OptimisticVideoService optimisticVideoService,
  String? currentUserDisplayName,
  String? currentUserPhotoUrl,
}) {
  final List<HomeVideo> canonical = sourceVideos
      .where((HomeVideo video) => !isHomeVideoOwnerPendingLocal(video))
      .where((HomeVideo video) => !isHomeVideoProcessing(video))
      .where(isHomeVideoVisibleInFeed)
      .where(isHomeVideoDisplayPlayable)
      .toList(growable: false);
  final List<HomeVideo> ownerProcessing = sourceVideos
      .where((HomeVideo video) {
        if (currentUserId == null || currentUserId.isEmpty) {
          return false;
        }
        if (video.creator.id != currentUserId) {
          return false;
        }
        return isHomeVideoProcessing(video) ||
            isHomeVideoOwnerPendingLocal(video);
      })
      .toList(growable: false);
  final List<HomeVideo> merged = dedupeHomeVideosById(
    mergePendingUploadsIntoFeed(
      readyVideos: rankHomeVideosForFeed(<HomeVideo>[
        ...ownerProcessing,
        ...canonical,
      ]),
      currentUserId: currentUserId,
      optimisticVideoService: optimisticVideoService,
      currentUserDisplayName: currentUserDisplayName,
      currentUserPhotoUrl: currentUserPhotoUrl,
    ),
  );
  return merged
      .where(
        (HomeVideo video) =>
            isHomeVideoDisplayPlayable(video) || isHomeVideoProcessing(video),
      )
      .toList(growable: false);
}

/// Keep a painted warm feed when network returns empty (avoid blanking Home).
bool shouldKeepWarmFeedOverEmptyNetwork({
  required List<HomeVideo> currentVideos,
  required List<HomeVideo> networkVideos,
}) {
  return currentVideos.isNotEmpty && networkVideos.isEmpty;
}

/// Whether a mid-swipe feed sync must jump immediately (invalid index).
bool shouldForceFeedIndexSyncDuringScroll({
  required int currentIndex,
  required int nextVideoCount,
}) {
  if (nextVideoCount <= 0) {
    return true;
  }
  return currentIndex >= nextVideoCount;
}
