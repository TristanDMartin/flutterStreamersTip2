import '../../../models/feed_tab.dart';
import '../../../models/home_video.dart';

const Object homeFeedStateUnset = Object();
const Object feedSliceUnset = Object();

class HomeState {
  final List<HomeVideo> forYouVideos;
  final List<HomeVideo> followingVideos;
  final bool hasNotification;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreContent;
  final bool hasLoaded;
  final dynamic lastForYouDoc;
  final dynamic lastFollowingDoc;
  final Map<String, dynamic>? lastFollowingCursor;
  final FeedTab? activeFeed;
  final FeedSlice? forYouSlice;
  final FeedSlice? followingSlice;
  final bool shouldPauseAllVideos;
  final bool shouldResumeCurrentVideo;
  final String? error;

  const HomeState({
    this.forYouVideos = const [],
    this.followingVideos = const [],
    this.hasNotification = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
    this.hasLoaded = false,
    this.lastForYouDoc,
    this.lastFollowingDoc,
    this.lastFollowingCursor,
    this.activeFeed,
    this.forYouSlice,
    this.followingSlice,
    this.shouldPauseAllVideos = false,
    this.shouldResumeCurrentVideo = false,
    this.error,
  });

  HomeState copyWith({
    List<HomeVideo>? forYouVideos,
    List<HomeVideo>? followingVideos,
    bool? hasNotification,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreContent,
    bool? hasLoaded,
    Object? lastForYouDoc = homeFeedStateUnset,
    Object? lastFollowingDoc = homeFeedStateUnset,
    Object? lastFollowingCursor = homeFeedStateUnset,
    Object? activeFeed = homeFeedStateUnset,
    Object? forYouSlice = homeFeedStateUnset,
    Object? followingSlice = homeFeedStateUnset,
    bool? shouldPauseAllVideos,
    bool? shouldResumeCurrentVideo,
    String? error,
    bool clearError = false,
  }) {
    return HomeState(
      forYouVideos: forYouVideos ?? this.forYouVideos,
      followingVideos: followingVideos ?? this.followingVideos,
      hasNotification: hasNotification ?? this.hasNotification,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      lastForYouDoc: identical(lastForYouDoc, homeFeedStateUnset)
          ? this.lastForYouDoc
          : lastForYouDoc,
      lastFollowingDoc: identical(lastFollowingDoc, homeFeedStateUnset)
          ? this.lastFollowingDoc
          : lastFollowingDoc,
      lastFollowingCursor: identical(lastFollowingCursor, homeFeedStateUnset)
          ? this.lastFollowingCursor
          : lastFollowingCursor as Map<String, dynamic>?,
      activeFeed: identical(activeFeed, homeFeedStateUnset)
          ? this.activeFeed
          : activeFeed as FeedTab?,
      forYouSlice: identical(forYouSlice, homeFeedStateUnset)
          ? this.forYouSlice
          : forYouSlice as FeedSlice?,
      followingSlice: identical(followingSlice, homeFeedStateUnset)
          ? this.followingSlice
          : followingSlice as FeedSlice?,
      shouldPauseAllVideos: shouldPauseAllVideos ?? this.shouldPauseAllVideos,
      shouldResumeCurrentVideo:
          shouldResumeCurrentVideo ?? this.shouldResumeCurrentVideo,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static const HomeState initial = HomeState();
}

class HomeFeedViewData {
  const HomeFeedViewData({
    required this.feed,
    required this.videos,
    required this.isLoading,
    required this.error,
  });

  final FeedTab feed;
  final List<HomeVideo> videos;
  final bool isLoading;
  final String? error;

  bool get supportsVideoFeed => feed.supportsVideoFeed;
  bool get supportsRefresh => feed.supportsRefresh;
  bool get hasError => error != null && error!.isNotEmpty;
}

extension HomeStateFeedAccess on HomeState {
  HomeFeedViewData feedData(FeedTab feed) {
    switch (feed) {
      case FeedTab.forYou:
        return HomeFeedViewData(
          feed: feed,
          videos: forYouVideos,
          isLoading: isLoading,
          error: error,
        );
      case FeedTab.following:
        return HomeFeedViewData(
          feed: feed,
          videos: followingVideos,
          isLoading: followingSlice?.isLoading ?? false,
          error: followingSlice?.error,
        );
      case FeedTab.threads:
        return const HomeFeedViewData(
          feed: FeedTab.threads,
          videos: <HomeVideo>[],
          isLoading: false,
          error: null,
        );
    }
  }
}

class FeedSlice {
  final List<HomeVideo> items;
  final Map<String, dynamic>? nextCursor;
  final bool isLoading;
  final String? error;
  final String? emptyMessage;
  final String? requestId;

  const FeedSlice({
    required this.items,
    required this.nextCursor,
    required this.isLoading,
    this.error,
    this.emptyMessage,
    this.requestId,
  });

  FeedSlice copyWith({
    List<HomeVideo>? items,
    Object? nextCursor = feedSliceUnset,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? emptyMessage,
    bool clearEmptyMessage = false,
    Object? requestId = feedSliceUnset,
  }) {
    return FeedSlice(
      items: items ?? this.items,
      nextCursor: identical(nextCursor, feedSliceUnset)
          ? this.nextCursor
          : nextCursor as Map<String, dynamic>?,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      emptyMessage:
          clearEmptyMessage ? null : (emptyMessage ?? this.emptyMessage),
      requestId: identical(requestId, feedSliceUnset)
          ? this.requestId
          : requestId as String?,
    );
  }
}
