import '../../../models/feed_tab.dart';
import '../../../models/home_video.dart';
import '../models/home_feed_state.dart';

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
  return state.copyWith(
    forYouVideos: mergedVideos,
    isLoading: isLoading,
    hasMoreContent: nextCursor != null,
    lastForYouDoc: lastDocument,
    forYouSlice: slice.copyWith(
      items: mergedVideos,
      nextCursor: nextCursor,
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
