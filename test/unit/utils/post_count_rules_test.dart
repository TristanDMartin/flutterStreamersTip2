import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/utils/post_count_rules.dart';

void main() {
  group('videoCountsAsUserPost', () {
    test('counts ready public posts with Everyone privacy', () {
      expect(
        videoCountsAsUserPost(<String, dynamic>{
          'status': 'ready',
          'privacy': 'Everyone',
          'visible': true,
        }),
        isTrue,
      );
    });

    test('excludes processing and draft posts', () {
      expect(
        videoCountsAsUserPost(<String, dynamic>{
          'status': 'processing',
          'privacy': 'Everyone',
        }),
        isFalse,
      );
      expect(
        videoCountsAsUserPost(<String, dynamic>{
          'status': 'draft',
          'privacy': 'Everyone',
        }),
        isFalse,
      );
    });

    test('excludes deleted and hidden posts', () {
      expect(
        videoCountsAsUserPost(<String, dynamic>{
          'status': 'ready',
          'privacy': 'Everyone',
          'isDeleted': true,
        }),
        isFalse,
      );
      expect(
        videoCountsAsUserPost(<String, dynamic>{
          'status': 'ready',
          'privacy': 'Everyone',
          'visible': false,
        }),
        isFalse,
      );
    });

    test('excludes private privacy levels', () {
      expect(
        videoCountsAsUserPost(<String, dynamic>{
          'status': 'published',
          'privacy': 'private',
        }),
        isFalse,
      );
    });
  });

  group('homeVideoCountsAsUserPost', () {
    test('maps public visibility to countable posts', () {
      const HomeVideo video = HomeVideo(
        id: 'v1',
        creator: User(
          id: 'u1',
          username: 'creator',
          displayName: 'Creator',
        ),
        videoURL: 'https://example.com/v.mp4',
        status: 'ready',
        visibility: 'public',
      );
      expect(homeVideoCountsAsUserPost(video), isTrue);
    });

    test('excludes drafts and processing profile rows', () {
      const HomeVideo draft = HomeVideo(
        id: 'v2',
        creator: User(
          id: 'u1',
          username: 'creator',
          displayName: 'Creator',
        ),
        videoURL: 'https://example.com/v.mp4',
        status: 'ready',
        visibility: 'public',
        isDraft: true,
      );
      const HomeVideo processing = HomeVideo(
        id: 'v3',
        creator: User(
          id: 'u1',
          username: 'creator',
          displayName: 'Creator',
        ),
        videoURL: 'https://example.com/v.mp4',
        status: 'processing',
        visibility: 'public',
      );
      expect(homeVideoCountsAsUserPost(draft), isFalse);
      expect(homeVideoCountsAsUserPost(processing), isFalse);
    });
  });
}
