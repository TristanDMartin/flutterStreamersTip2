import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/owner_video_resolver.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';

void main() {
  group('shouldRemoveOwnerVideoFromSnapshot', () {
    test('owner pending survives missing Firestore doc', () {
      final bool actual = shouldRemoveOwnerVideoFromSnapshot(
        docExists: false,
        data: null,
        isOwnerViewing: true,
        hasDurablePending: true,
      );
      expect(actual, isFalse);
    });

    test('owner uploading is not treated as deletion', () {
      final bool actual = shouldRemoveOwnerVideoFromSnapshot(
        docExists: true,
        data: <String, dynamic>{
          'status': 'uploading',
          'isDeleted': false,
        },
        isOwnerViewing: true,
        hasDurablePending: true,
      );
      expect(actual, isFalse);
    });

    test('owner processing is not treated as deletion', () {
      final bool actual = shouldRemoveOwnerVideoFromSnapshot(
        docExists: true,
        data: <String, dynamic>{
          'status': 'processing',
          'isReadyForFeed': false,
        },
        isOwnerViewing: true,
        hasDurablePending: false,
      );
      expect(actual, isFalse);
    });

    test('tombstone still removes owner video', () {
      final bool actual = shouldRemoveOwnerVideoFromSnapshot(
        docExists: true,
        data: <String, dynamic>{
          'status': 'deleted',
          'isDeleted': true,
        },
        isOwnerViewing: true,
        hasDurablePending: true,
      );
      expect(actual, isTrue);
    });

    test('public viewer still drops non-ready', () {
      final bool actual = shouldRemoveOwnerVideoFromSnapshot(
        docExists: true,
        data: <String, dynamic>{
          'status': 'processing',
          'isReadyForFeed': false,
        },
        isOwnerViewing: false,
        hasDurablePending: false,
      );
      expect(actual, isTrue);
    });
  });

  group('preserveOwnerVideosAcrossPublicFeedRefresh', () {
    test('keeps owner uploading rows outside public ready feed', () {
      final List<HomeVideo> incoming = <HomeVideo>[
        HomeVideo(
          id: 'ready-1',
          creator: const User(
            id: 'other',
            username: 'other',
            displayName: 'Other',
          ),
          videoURL: 'https://stream.mux.com/a.m3u8',
          status: 'ready',
        ),
      ];
      final List<HomeVideo> existing = <HomeVideo>[
        ...incoming,
        HomeVideo(
          id: 'pending-1',
          creator: const User(
            id: 'owner',
            username: 'you',
            displayName: 'You',
          ),
          videoURL: 'file:///tmp/local.mp4',
          status: 'uploading',
        ),
      ];
      final List<HomeVideo> actual = preserveOwnerVideosAcrossPublicFeedRefresh(
        incomingPublicFeed: incoming,
        existingState: existing,
        viewerId: 'owner',
      );
      expect(actual.map((HomeVideo v) => v.id).toList(), contains('pending-1'));
      expect(actual.map((HomeVideo v) => v.id).toList(), contains('ready-1'));
    });
  });

  group('ownerVideoLifecycleRank', () {
    test('ready remote outranks uploading', () {
      final HomeVideo uploading = HomeVideo(
        id: 'a',
        creator: const User(id: 'o', username: 'o', displayName: 'O'),
        videoURL: '',
        status: 'uploading',
      );
      final HomeVideo ready = HomeVideo(
        id: 'a',
        creator: const User(id: 'o', username: 'o', displayName: 'O'),
        videoURL: 'https://stream.mux.com/x.m3u8',
        status: 'ready',
      );
      expect(
        ownerVideoLifecycleRank(ready),
        greaterThan(ownerVideoLifecycleRank(uploading)),
      );
    });
  });
}
