import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_mutator.dart';
import 'package:streamers_tip/features/home/models/home_feed_state.dart';
import 'package:streamers_tip/models/feed_tab.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';

void main() {
  HomeVideo video({
    required String id,
    bool isLiked = false,
    int likes = 0,
  }) {
    return HomeVideo(
      id: id,
      creator: const User(
        id: 'u1',
        username: 'u',
        displayName: 'U',
        bio: '',
        hashtags: <String>[],
      ),
      videoURL: 'https://cdn.example/$id.mp4',
      isLiked: isLiked,
      likes: likes,
    );
  }

  group('applyForYouFeedUpdate', () {
    test('updates slice and top-level forYou list', () {
      const HomeState initial = HomeState(isLoading: true);
      final HomeState actual = applyForYouFeedUpdate(
        state: initial,
        mergedVideos: <HomeVideo>[video(id: 'v1')],
        isLoading: false,
        nextCursor: null,
        clearError: true,
      );
      expect(actual.forYouVideos.single.id, 'v1');
      expect(actual.isLoading, isFalse);
      expect(actual.forYouSlice?.items.single.id, 'v1');
    });
  });

  group('updateVideoAcrossFeeds', () {
    test('updates matching video in both feeds', () {
      final HomeState initial = HomeState(
        forYouVideos: <HomeVideo>[video(id: 'v1', isLiked: false)],
        followingVideos: <HomeVideo>[video(id: 'v1', isLiked: false)],
      );
      final HomeState actual = updateVideoAcrossFeeds(
        initial,
        'v1',
        (HomeVideo item) => item.copyWith(isLiked: true, likes: 1),
      );
      expect(actual.forYouVideos.single.isLiked, isTrue);
      expect(actual.followingVideos.single.isLiked, isTrue);
    });
  });

  group('replaceVideosInFeeds', () {
    test('maps both feeds', () {
      final HomeState initial = HomeState(
        forYouVideos: <HomeVideo>[video(id: 'a')],
        followingVideos: <HomeVideo>[video(id: 'b')],
      );
      final HomeState actual = replaceVideosInFeeds(
        initial,
        (HomeVideo item) => item.copyWith(likes: 9),
      );
      expect(actual.forYouVideos.single.likes, 9);
      expect(actual.followingVideos.single.likes, 9);
    });
  });

  group('videosForFeed', () {
    test('returns feed-specific lists', () {
      final HomeState state = HomeState(
        forYouVideos: <HomeVideo>[video(id: 'f')],
        followingVideos: <HomeVideo>[video(id: 'g')],
      );
      expect(videosForFeed(state, FeedTab.forYou).single.id, 'f');
      expect(videosForFeed(state, FeedTab.following).single.id, 'g');
      expect(videosForFeed(state, FeedTab.threads), isEmpty);
    });
  });
}
