import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/application/home_for_you_feed_loader.dart';
import 'package:streamers_tip/features/home/domain/home_following_feed_merge.dart';
import 'package:streamers_tip/models/home_video.dart';

void main() {
  group('nextCursorFromLastDocument', () {
    test('wraps last document for slice cursor', () {
      expect(
        nextCursorFromLastDocument('doc-1'),
        <String, dynamic>{'lastDoc': 'doc-1'},
      );
    });

    test('returns null when last document missing', () {
      expect(nextCursorFromLastDocument(null), isNull);
    });
  });

  group('HomeForYouFeedPage', () {
    test('defaults clearError to false', () {
      const HomeForYouFeedPage page = HomeForYouFeedPage(
        videos: <HomeVideo>[],
      );
      expect(page.clearError, isFalse);
    });
  });
}
