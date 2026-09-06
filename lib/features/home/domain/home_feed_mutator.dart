import '../../../models/feed_tab.dart';
import '../../../models/home_video.dart';
import '../../../utils/home_video_playback.dart';
import 'home_feed_pagination.dart';
import 'home_feed_processing.dart';
import '../models/home_feed_state.dart';

/// Result of turning a For You snapshot into Home videos.
class HomeRealtimeFeedBuildResult {
  const HomeRealtimeFeedBuildResult({
    required this.videos,
    this.removedVideoIds = const <String>{},
  });

  final List<HomeVideo> videos;

  /// Snapshot docs that must leave painted Home, including deleted owners.
  final Set<String> removedVideoIds;
}

/// Merges [incoming] into [existing] without dropping items or reordering
/// the current feed. New ids from [incoming] are prepended.
///
/// Never downgrade an owner local-pending (instant publish) card to an empty
/// processing stub from a partial realtime snapshot.
List<HomeVideo> mergeHomeFeedPreserveOrder({
  required List<HomeVideo> existing,
  required List<HomeVideo> incoming,
}) {
  final List<HomeVideo> safeExisting = dedupeHomeVideosById(existing);
  final List<HomeVideo> safeIncoming = dedupeHomeVideosById(incoming);
  if (safeIncoming.isEmpty) {
    return safeExisting;
  }
  if (safeExisting.isEmpty) {
    return safeIncoming;
  }
  final Map<String, HomeVideo> incomingById = <String, HomeVideo>{
    for (final HomeVideo video in safeIncoming) video.id: video,
  };
  final Set<String> existingIds =
      safeExisting.map((HomeVideo video) => video.id).toSet();
  final List<HomeVideo> newLeading = safeIncoming
      .where((HomeVideo video) => !existingIds.contains(video.id))
      .toList(growable: false);
  final List<HomeVideo> updatedExisting = safeExisting.map((HomeVideo video) {
    final HomeVideo? incomingVideo = incomingById[video.id];
    if (incomingVideo == null) {
      return video;
    }
    if (_shouldKeepExistingHomeVideo(video, incomingVideo)) {
      return video;
    }
    return incomingVideo;
  }).toList(growable: false);
  return dedupeHomeVideosById(<HomeVideo>[
    ...newLeading,
    ...updatedExisting,
  ]);
}

bool _shouldKeepExistingHomeVideo(HomeVideo existing, HomeVideo incoming) {
  if (isHomeVideoOwnerPendingLocal(existing) &&
      !isHomeVideoOwnerPendingLocal(incoming)) {
    return true;
  }
  if (isHomeVideoPlayable(existing) && !isHomeVideoPlayable(incoming)) {
    return true;
  }
  return false;
}

/// Drops remote cards whose Firestore docs are deleted / ineligible.
/// Keeps Instant Publish owner-local pending rows.
List<HomeVideo> dropHomeFeedVideosById({
  required List<HomeVideo> existing,
  required Set<String> removedIds,
}) {
  if (removedIds.isEmpty) {
    return existing;
  }
  return existing
      .where(
        (HomeVideo video) =>
            !removedIds.contains(video.id) ||
            isHomeVideoOwnerPendingLocal(video),
      )
      .toList(growable: false);
}

/// Live For You reconcile: update/prepend from [incoming], then drop
/// [removedIds] (deleted / feed-ineligible docs still present in the query).
List<HomeVideo> reconcileLiveHomeFeedSnapshot({
  required List<HomeVideo> existing,
  required List<HomeVideo> incoming,
  required Set<String> removedIds,
}) {
  final List<HomeVideo> withoutRemoved = dropHomeFeedVideosById(
    existing: existing,
    removedIds: removedIds,
  );
  return mergeHomeFeedPreserveOrder(
    existing: withoutRemoved,
    incoming: incoming,
  );
}

/// True when replacing the feed with [incoming] would likely be a bad partial
/// snapshot (e.g. realtime listener returning fewer docs than the visible feed).
bool shouldRejectShrinkingFeedReplacement({
  required List<HomeVideo> current,
  required List<HomeVideo> incoming,
  required String reason,
}) {
  if (reason == 'like_sync' || reason == 'liked_state_refresh') {
    return true;
  }
  if (current.isNotEmpty && incoming.isEmpty) {
    return true;
  }
  return false;
}

FeedSlice currentForYouSlice(HomeState state) {
  return state.forYouSlice ??
      const FeedSlice(
        items: <HomeVideo>[],
        nextCursor: null,
        isLoading: false,
      );
}

FeedSlice currentFollowingSlice(HomeState state) {
  return state.followingSlice ??
      const FeedSlice(
        items: <HomeVideo>[],
        nextCursor: null,
        isLoading: false,
      );
}

List<HomeVideo> videosForFeed(HomeState state, FeedTab feed) {
  switch (feed) {
    case FeedTab.forYou:
      return state.forYouVideos;
    case FeedTab.following:
      return state.followingVideos;
    case FeedTab.threads:
      return const <HomeVideo>[];
  }
}

HomeState applyForYouFeedUpdate({
  required HomeState state,
  required List<HomeVideo> mergedVideos,
  required bool isLoading,
  Map<String, dynamic>? nextCursor,
  Object? lastDocument = homeFeedStateUnset,
  String? error,
  bool clearError = false,
}) {
  final FeedSlice slice = currentForYouSlice(state);
  final Map<String, dynamic>? effectiveCursor =
      HomeFeedPagination.cursorForFeedUpdate(
    videoCount: mergedVideos.length,
    nextCursor: nextCursor,
  );
  return state.copyWith(
    forYouVideos: mergedVideos,
    isLoading: isLoading,
    hasMoreContent: HomeFeedPagination.inferHasMoreContent(
      videoCount: mergedVideos.length,
      nextCursor: effectiveCursor,
    ),
    lastForYouDoc: lastDocument,
    forYouSlice: slice.copyWith(
      items: mergedVideos,
      nextCursor: effectiveCursor,
      isLoading: isLoading,
      error: error,
      clearError: clearError,
    ),
    error: error,
    clearError: clearError,
  );
}

HomeState applyFollowingFeedUpdate({
  required HomeState state,
  required List<HomeVideo> videos,
  required bool isLoading,
  Map<String, dynamic>? nextCursor,
  Object? lastDocument = homeFeedStateUnset,
  String? error,
  bool clearError = false,
}) {
  final FeedSlice slice = currentFollowingSlice(state);
  return state.copyWith(
    followingVideos: videos,
    lastFollowingDoc: lastDocument,
    followingSlice: slice.copyWith(
      items: videos,
      nextCursor: nextCursor,
      isLoading: isLoading,
      error: error,
      clearError: clearError,
    ),
  );
}

List<HomeVideo> mapHomeVideos(
  List<HomeVideo> videos,
  HomeVideo Function(HomeVideo) update,
) {
  return videos.map(update).toList(growable: false);
}

HomeState replaceVideosInFeeds(
  HomeState state,
  HomeVideo Function(HomeVideo) update,
) {
  return state.copyWith(
    forYouVideos: mapHomeVideos(state.forYouVideos, update),
    followingVideos: mapHomeVideos(state.followingVideos, update),
  );
}

List<HomeVideo> updateVideoInList(
  List<HomeVideo> videos,
  String videoId,
  HomeVideo Function(HomeVideo) update,
) {
  final int index = videos.indexWhere((HomeVideo v) => v.id == videoId);
  if (index == -1) {
    return videos;
  }
  final List<HomeVideo> updated = List<HomeVideo>.from(videos);
  updated[index] = update(updated[index]);
  return updated;
}

HomeState updateVideoAcrossFeeds(
  HomeState state,
  String videoId,
  HomeVideo Function(HomeVideo) update,
) {
  return state.copyWith(
    forYouVideos: updateVideoInList(state.forYouVideos, videoId, update),
    followingVideos: updateVideoInList(state.followingVideos, videoId, update),
  );
}

HomeState setVideosForFeed(
  HomeState state,
  FeedTab feed,
  List<HomeVideo> videos,
) {
  switch (feed) {
    case FeedTab.forYou:
      return state.copyWith(forYouVideos: videos);
    case FeedTab.following:
      return state.copyWith(followingVideos: videos);
    case FeedTab.threads:
      return state;
  }
}
