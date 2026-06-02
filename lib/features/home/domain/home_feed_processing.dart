import '../../../models/home_video.dart';
import '../../../services/optimistic_video_service.dart';
import '../../../utils/home_video_playback.dart';
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

/// Keeps only items that can play in the home feed.
List<HomeVideo> filterPlayableHomeVideos(List<HomeVideo> feed) {
  return feed.where(isHomeVideoPlayable).toList(growable: false);
}

/// Rank, merge pending uploads, and dedupe for For You display.
List<HomeVideo> prepareForYouFeedDisplayList({
  required List<HomeVideo> sourceVideos,
  required String? currentUserId,
  required OptimisticVideoService optimisticVideoService,
  String? currentUserDisplayName,
  String? currentUserPhotoUrl,
}) {
  return dedupeHomeVideosById(
    mergePendingUploadsIntoFeed(
      readyVideos: rankHomeVideosForFeed(sourceVideos),
      currentUserId: currentUserId,
      optimisticVideoService: optimisticVideoService,
      currentUserDisplayName: currentUserDisplayName,
      currentUserPhotoUrl: currentUserPhotoUrl,
    ),
  );
}
