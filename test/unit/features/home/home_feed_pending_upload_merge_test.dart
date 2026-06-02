import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_pending_upload_merge.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/optimistic_video.dart';

void main() {
  group('homeVideoFromOptimisticVideo', () {
    test('maps processing upload to home card', () {
      final OptimisticVideo optimistic = OptimisticVideo(
        videoId: 'vid-1',
        ownerId: 'uid-1',
        caption: 'Hello',
        thumbnailUrl: 'https://cdn.example/t.jpg',
        createdAt: DateTime(2026, 1, 1),
        status: VideoStatus.processing,
        categories: const <String>['gaming'],
        isOptimistic: true,
      );
      final HomeVideo actual = homeVideoFromOptimisticVideo(
        optimistic: optimistic,
        currentUserDisplayName: 'Creator',
        currentUserPhotoUrl: 'https://cdn.example/a.jpg',
      );
      expect(actual.id, 'vid-1');
      expect(actual.status, 'processing');
      expect(actual.caption, 'Hello');
      expect(actual.creator.displayName, 'Creator');
    });
  });
}
