import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/threads/thread_visibility.dart';

void main() {
  group('threadVisibility contract', () {
    test('normalizes invite aliases to inviteOnly', () {
      expect(normalizeThreadVisibility('invite_only'), kThreadVisibilityInviteOnly);
      expect(normalizeThreadVisibility('inviteOnly'), kThreadVisibilityInviteOnly);
    });

    test('allows anyone for public threads', () {
      expect(
        canViewerAccessThread(
          visibility: kThreadVisibilityPublic,
          authorId: 'author',
          viewerId: null,
        ),
        isTrue,
      );
    });

    test('requires follow for followers visibility', () {
      expect(
        canViewerAccessThread(
          visibility: kThreadVisibilityFollowers,
          authorId: 'author',
          viewerId: 'viewer',
          viewerFollowsAuthor: false,
        ),
        isFalse,
      );
      expect(
        canViewerAccessThread(
          visibility: kThreadVisibilityFollowers,
          authorId: 'author',
          viewerId: 'viewer',
          viewerFollowsAuthor: true,
        ),
        isTrue,
      );
    });

    test('limits inviteOnly to author or invitees', () {
      expect(
        canViewerAccessThread(
          visibility: kThreadVisibilityInviteOnly,
          authorId: 'author',
          viewerId: 'author',
        ),
        isTrue,
      );
      expect(
        canViewerAccessThread(
          visibility: kThreadVisibilityInviteOnly,
          authorId: 'author',
          viewerId: 'viewer',
          viewerFollowsAuthor: true,
        ),
        isFalse,
      );
      expect(
        canViewerAccessThread(
          visibility: kThreadVisibilityInviteOnly,
          authorId: 'author',
          viewerId: 'viewer',
          viewerHasInviteAccess: true,
        ),
        isTrue,
      );
    });
  });
}
