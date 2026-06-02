import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/bookmarks/models/video_bookmark_stream_event.dart';

void main() {
  group('VideoBookmarkStreamEvent', () {
    test('toggle carries video id and bookmark state', () {
      final VideoBookmarkStreamEvent event =
          VideoBookmarkStreamEvent.toggle('v1', true);
      expect(event.videoId, 'v1');
      expect(event.type, VideoBookmarkStreamEventType.toggle);
      expect(event.isBookmarked, isTrue);
    });

    test('error uses empty video id', () {
      final VideoBookmarkStreamEvent event =
          VideoBookmarkStreamEvent.error('failed');
      expect(event.videoId, isEmpty);
      expect(event.type, VideoBookmarkStreamEventType.error);
      expect(event.error, 'failed');
    });
  });
}
