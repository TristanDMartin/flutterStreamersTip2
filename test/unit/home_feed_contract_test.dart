import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/feed_tab.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/providers/home_provider.dart';
import 'package:streamers_tip/widgets/home_view_components/video_page_view_widget.dart';

void main() {
  group('FeedTab contract', () {
    test('exposes stable feed capabilities', () {
      expect(FeedTab.forYou.supportsVideoFeed, isTrue);
      expect(FeedTab.forYou.supportsRefresh, isTrue);

      expect(FeedTab.following.displayName, 'Progression');
      expect(FeedTab.following.supportsVideoFeed, isFalse);
      expect(FeedTab.following.supportsRefresh, isFalse);

      expect(FeedTab.threads.supportsVideoFeed, isFalse);
      expect(FeedTab.threads.supportsRefresh, isFalse);
    });

    test('maps display names back to tabs', () {
      expect(
        FeedTabExtension.fromDisplayName(FeedTab.forYou.displayName),
        FeedTab.forYou,
      );
      expect(
        FeedTabExtension.fromDisplayName(FeedTab.following.displayName),
        FeedTab.following,
      );
      expect(
        FeedTabExtension.fromDisplayName(FeedTab.threads.displayName),
        FeedTab.threads,
      );
      expect(
        FeedTabExtension.fromDisplayName('Unexpected tab'),
        FeedTab.forYou,
      );
    });
  });

  group('HomeState feedData', () {
    test('returns feed-specific view data from one place', () {
      final HomeVideo sampleVideo = HomeVideo(
        id: 'video-1',
        creator: const User(
          id: 'user-1',
          username: 'creator',
          displayName: 'Creator',
        ),
        videoURL: 'https://example.com/video.mp4',
      );

      final HomeState state = HomeState(
        forYouVideos: <HomeVideo>[sampleVideo],
        followingVideos: <HomeVideo>[sampleVideo.copyWith(id: 'video-2')],
        isLoading: true,
        error: 'for you error',
        followingSlice: const FeedSlice(
          items: <HomeVideo>[],
          nextCursor: null,
          isLoading: true,
          error: 'following error',
        ),
      );

      final HomeFeedViewData forYouData = state.feedData(FeedTab.forYou);
      expect(forYouData.videos, hasLength(1));
      expect(forYouData.isLoading, isTrue);
      expect(forYouData.error, 'for you error');

      final HomeFeedViewData followingData = state.feedData(FeedTab.following);
      expect(followingData.videos, hasLength(1));
      expect(followingData.isLoading, isTrue);
      expect(followingData.error, 'following error');

      final HomeFeedViewData threadsData = state.feedData(FeedTab.threads);
      expect(threadsData.videos, isEmpty);
      expect(threadsData.isLoading, isFalse);
      expect(threadsData.error, isNull);
    });

    test('copyWith can explicitly clear nullable pagination fields', () {
      final HomeState state = HomeState(
        lastForYouDoc: 'cursor-a',
        lastFollowingDoc: 'cursor-b',
        forYouSlice: const FeedSlice(
          items: <HomeVideo>[],
          nextCursor: <String, dynamic>{'lastDoc': 'cursor-a'},
          isLoading: false,
          requestId: 'req-1',
        ),
      );

      final HomeState cleared = state.copyWith(
        lastForYouDoc: null,
        lastFollowingDoc: null,
        forYouSlice: null,
      );

      expect(cleared.lastForYouDoc, isNull);
      expect(cleared.lastFollowingDoc, isNull);
      expect(cleared.forYouSlice, isNull);
    });
  });

  group('FeedSlice copyWith', () {
    test('can explicitly clear nullable fields', () {
      const FeedSlice slice = FeedSlice(
        items: <HomeVideo>[],
        nextCursor: <String, dynamic>{'lastDoc': 'cursor-a'},
        isLoading: true,
        requestId: 'req-1',
      );

      final FeedSlice cleared = slice.copyWith(
        nextCursor: null,
        isLoading: false,
        requestId: null,
      );

      expect(cleared.nextCursor, isNull);
      expect(cleared.isLoading, isFalse);
      expect(cleared.requestId, isNull);
    });
  });

  group('VideoPageView index safety', () {
    test('clamps stale feed indexes into the available video range', () {
      expect(clampHomeVideoIndex(-3, 4), 0);
      expect(clampHomeVideoIndex(0, 4), 0);
      expect(clampHomeVideoIndex(2, 4), 2);
      expect(clampHomeVideoIndex(99, 4), 3);
    });

    test('returns zero when there are no videos', () {
      expect(clampHomeVideoIndex(5, 0), 0);
      expect(clampHomeVideoIndex(5, -1), 0);
    });
  });
}
