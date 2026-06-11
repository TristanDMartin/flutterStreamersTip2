import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_pagination.dart';

void main() {
  group('HomeFeedPagination', () {
    test('inferHasMoreContent stays true for bootstrap cursor', () {
      expect(
        HomeFeedPagination.inferHasMoreContent(
          videoCount: 8,
          nextCursor: HomeFeedPagination.bootstrapCursor,
        ),
        isTrue,
      );
    });

    test('inferHasMoreContent is false when exhausted', () {
      expect(
        HomeFeedPagination.inferHasMoreContent(
          videoCount: 20,
          nextCursor: HomeFeedPagination.exhaustedCursor,
        ),
        isFalse,
      );
    });

    test('cursorForFeedUpdate assigns bootstrap when cursor missing', () {
      expect(
        HomeFeedPagination.cursorForFeedUpdate(
          videoCount: 8,
          nextCursor: null,
        ),
        HomeFeedPagination.bootstrapCursor,
      );
    });
  });
}
