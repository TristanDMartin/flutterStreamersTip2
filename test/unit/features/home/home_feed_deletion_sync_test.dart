import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/application/home_feed_deletion_sync.dart';

void main() {
  group('HomeFeedDeletionSync removal', () {
    test('tombstone when isDeleted', () {
      expect(
        HomeFeedDeletionSync.removalReasonForTest(
          docExists: true,
          data: <String, dynamic>{
            'status': 'ready',
            'isDeleted': true,
            'isReadyForFeed': true,
          },
        ),
        'tombstone',
      );
    });

    test('missing doc', () {
      expect(
        HomeFeedDeletionSync.removalReasonForTest(
          docExists: false,
          data: null,
        ),
        'missing_doc',
      );
    });

    test('owner tombstone', () {
      expect(
        HomeFeedDeletionSync.removalReasonForTest(
          docExists: true,
          data: <String, dynamic>{
            'status': 'ready',
            'isDeleted': false,
            'isReadyForFeed': true,
            'ownerActive': false,
            'hlsUrl': 'https://stream.mux.com/x.m3u8',
          },
        ),
        'owner_tombstone',
      );
    });

    test('keeps ready public playable', () {
      expect(
        HomeFeedDeletionSync.removalReasonForTest(
          docExists: true,
          data: <String, dynamic>{
            'status': 'ready',
            'isDeleted': false,
            'isReadyForFeed': true,
            'visible': true,
            'hlsUrl': 'https://stream.mux.com/x.m3u8',
          },
        ),
        isNull,
      );
    });
  });
}
