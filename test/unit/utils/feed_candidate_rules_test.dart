import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/utils/video_document_rules.dart';
import 'package:streamers_tip/utils/video_url_resolver.dart';

void main() {
  group('rejectFeedCandidateBeforeHydration', () {
    test('rejects deleted and non-ready statuses with explicit reason', () {
      expect(
        rejectFeedCandidateBeforeHydration(
          {'status': 'processing'},
          readOwnerId: getOwnerId,
        ),
        'status:processing',
      );
      expect(
        rejectFeedCandidateBeforeHydration(
          {'status': 'ready', 'deletedAt': '2026-01-01'},
          readOwnerId: getOwnerId,
        ),
        'deletedAt',
      );
    });

    test('rejects orphaned videos without owner hints', () {
      expect(
        rejectFeedCandidateBeforeHydration(
          {
            'status': 'ready',
            'isReadyForFeed': true,
            'visibility': 'public',
            'id': '1777510738834_1003',
          },
          readOwnerId: getOwnerId,
        ),
        'missing_owner',
      );
    });

    test('allows ready public video with canonical owner', () {
      expect(
        rejectFeedCandidateBeforeHydration(
          {
            'status': 'ready',
            'isReadyForFeed': true,
            'visibility': 'public',
            'ownerId': 'abc123owner0000000000000001',
          },
          readOwnerId: getOwnerId,
        ),
        isNull,
      );
    });

    test('rejects deleted HomeVideo rows even when status remains ready', () {
      expect(
        isHomeVideoVisibleInFeed(HomeVideo(
          id: 'deleted-ready',
          creator: const User(
            id: 'abc123owner0000000000000001',
            username: 'creator',
            displayName: 'Creator',
          ),
          videoURL: 'https://stream.mux.com/abc.m3u8',
          status: 'ready',
          isDeleted: true,
        )),
        isFalse,
      );
    });

    test('requires isReadyForFeed to be explicitly true', () {
      expect(
        rejectFeedCandidateBeforeHydration(
          {
            'status': 'ready',
            'visibility': 'public',
            'ownerId': 'abc123owner0000000000000001',
          },
          readOwnerId: getOwnerId,
        ),
        'isReadyForFeed:not_true',
      );
    });
  });

  group('rejectProfileListCandidate', () {
    const String owner = 'abc123owner0000000000000001';

    test('allows processing uploads for owner profile', () {
      expect(
        rejectProfileListCandidate(
          <String, dynamic>{
            'status': 'processing',
            'visibility': 'public',
            'userId': owner,
          },
          owner,
          viewerUserId: owner,
        ),
        isNull,
      );
    });

    test('rejects processing when viewer is not owner and video is private',
        () {
      expect(
        rejectProfileListCandidate(
          <String, dynamic>{
            'status': 'processing',
            'visibility': 'private',
            'userId': owner,
          },
          owner,
          viewerUserId: 'other_viewer_00000000000001',
        ),
        'visibility',
      );
    });

    test('rejects deleted docs', () {
      expect(
        rejectProfileListCandidate(
          <String, dynamic>{
            'status': 'ready',
            'isDeleted': true,
            'userId': owner,
          },
          owner,
          viewerUserId: owner,
        ),
        'deleted',
      );
    });
  });
}
