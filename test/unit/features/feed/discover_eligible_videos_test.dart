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

    test('rejects owner local pending instant-play overlays', () {
      expect(
        isDiscoverEligibleHomeVideo(
          _video(
            id: 'local',
            status: 'uploading',
            videoURL: 'file:///tmp/cap.mp4',
          ),
        ),
        isFalse,
      );
      expect(
        rejectDiscoverEligibleHomeVideo(
          _video(
            id: 'local',
            status: 'processing',
            videoURL: 'file:///data/cap.mp4',
          ),
        ),
        'owner_local_pending',
      );
    });

    test('rejects failed and processing statuses', () {
      expect(
        isDiscoverEligibleHomeVideo(
          _video(id: 'f', status: 'failed'),
        ),
        isFalse,
      );
      expect(
        isDiscoverEligibleHomeVideo(
          _video(id: 'p', status: 'processing'),
        ),
        isFalse,
      );
    });

    test('rejects cached deleted video even with playable url', () {
      expect(
        isDiscoverEligibleHomeVideo(
          _video(id: 'deleted').copyWith(isDeleted: true),
        ),
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

    test('missing category matches all and general', () {
      final HomeVideo uncategorized = _video(id: 'b', categoryId: '');
      expect(
        homeVideoMatchesDiscoverCategory(uncategorized, 'all'),
        isTrue,
      );
      expect(
        homeVideoMatchesDiscoverCategory(uncategorized, 'general'),
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
