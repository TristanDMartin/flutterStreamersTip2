import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/threads/related_video.dart';
import 'package:streamers_tip/features/threads/thread_invite.dart';
import 'package:streamers_tip/features/threads/thread_visibility.dart';

void main() {
  group('related_video helpers', () {
    test('strips Related Video markdown including localhost urls', () {
      const String input = '''
Discussion body

---

**Related Video:** [Watch Video](http://localhost:3000/video/video_123)
''';
      expect(stripRelatedVideoMarkdown(input), 'Discussion body');
    });

    test('cleans legacy video-comment body for card display', () {
      const String input =
          '**Original Comment from @TechnQs:** "lmao" --- **Related Video:** [Watch Video](http://localhost:3000/video/video_1780286682796_gRoRo0FL)';
      expect(displayThreadBody(input), 'lmao');
      expect(displayThreadBody(input), isNot(contains('localhost')));
      expect(displayThreadBody(input), isNot(contains('Watch Video')));
    });

    test('prefers canonical field ids over markdown', () {
      expect(
        resolveRelatedVideoId(
          sourceVideoId: 'video_from_field',
          content:
              '**Related Video:** [Watch Video](http://localhost:3000/video/video_from_md)',
        ),
        'video_from_field',
      );
    });
  });

  group('thread invite permissions', () {
    test('owner can invite on inviteOnly threads', () {
      expect(
        canInviteToThread(
          currentUserId: 'owner',
          ownerId: 'owner',
          visibility: kThreadVisibilityInviteOnly,
        ),
        isTrue,
      );
    });

    test('non-owner cannot invite by default', () {
      expect(
        canInviteToThread(
          currentUserId: 'viewer',
          ownerId: 'owner',
          visibility: kThreadVisibilityInviteOnly,
        ),
        isFalse,
      );
    });

    test('inviteOnly access requires invite flag', () {
      expect(
        canViewerAccessThread(
          visibility: kThreadVisibilityInviteOnly,
          authorId: 'owner',
          viewerId: 'viewer',
          viewerHasInviteAccess: true,
        ),
        isTrue,
      );
      expect(
        canViewerAccessThread(
          visibility: kThreadVisibilityInviteOnly,
          authorId: 'owner',
          viewerId: 'viewer',
        ),
        isFalse,
      );
    });
  });
}
