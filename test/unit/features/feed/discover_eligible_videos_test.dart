import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/feed/domain/discover_eligible_videos.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/utils/category_schema.dart';

HomeVideo _video({
  required String id,
  String categoryId = 'gaming',
  String status = 'ready',
  String visibility = 'public',
  String videoURL = 'https://example.com/v.m3u8',
}) {
  return HomeVideo(
    id: id,
    creator: const User(
      id: 'u1',
      username: 'creator',
      displayName: 'Creator',
    ),
    videoURL: videoURL,
    categoryId: categoryId,
    status: status,
    visibility: visibility,
  );
}

void main() {
  group('isDiscoverEligibleHomeVideo', () {
    test('accepts playable public ready video', () {
      expect(isDiscoverEligibleHomeVideo(_video(id: 'a')), isTrue);
    });

    test('rejects empty playback url', () {
      expect(
        isDiscoverEligibleHomeVideo(_video(id: 'a', videoURL: '')),
        isFalse,
      );
    });

  });

  group('homeVideoMatchesDiscoverCategory', () {
    test('all matches every eligible category', () {
      expect(
        homeVideoMatchesDiscoverCategory(_video(id: 'a'), 'All'),
        isTrue,
      );
    });

    test('gaming matches gaming slug', () {
      expect(
        homeVideoMatchesDiscoverCategory(
          _video(id: 'a', categoryId: 'Gaming'),
          'gaming',
        ),
        isTrue,
      );
    });

    test('FPS matches fps slug', () {
      expect(
        homeVideoMatchesDiscoverCategory(
          _video(id: 'a', categoryId: 'FPS'),
          'fps',
        ),
        isTrue,
      );
    });

    test('missing category only matches all', () {
      final HomeVideo uncategorized = _video(id: 'b', categoryId: '');
      expect(
        homeVideoMatchesDiscoverCategory(uncategorized, 'all'),
        isTrue,
      );
      expect(
        homeVideoMatchesDiscoverCategory(uncategorized, 'gaming'),
        isFalse,
      );
      expect(normalizeVideoCategorySlug(uncategorized), kDefaultCategoryId);
    });
  });
}
