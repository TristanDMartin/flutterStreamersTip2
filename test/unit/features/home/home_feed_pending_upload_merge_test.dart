import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_pending_upload_merge.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/optimistic_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/utils/home_video_playback.dart';

Future<File> _createTempLocalMp4(String name) async {
  final Directory tempDir = await Directory.systemTemp.createTemp(
    'st_pending_merge_',
  );
  final File localMp4 = File('${tempDir.path}/$name');
  await localMp4.writeAsBytes(const <int>[0, 0, 0, 0]);
  return localMp4;
}

void main() {
  group('homeVideoFromOptimisticVideo', () {
    test('maps local durable path to file playback url', () async {
      final File localMp4 = await _createTempLocalMp4('cap_1.mp4');
      addTearDown(() async {
        final Directory parent = localMp4.parent;
        if (await parent.exists()) {
          await parent.delete(recursive: true);
        }
      });
      final OptimisticVideo optimistic = OptimisticVideo(
        videoId: 'vid-1',
        ownerId: 'uid-1',
        caption: 'Hello',
        thumbnailUrl: 'https://cdn.example/t.jpg',
        localVideoPath: localMp4.path,
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
      expect(actual.status, 'uploading');
      expect(actual.videoURL, 'file://${localMp4.path}');
      expect(isHomeVideoOwnerPendingLocal(actual), isTrue);
      expect(isHomeVideoPlayable(actual), isTrue);
    });

    test('missing local file does not keep deleted draft path', () {
      final OptimisticVideo optimistic = OptimisticVideo(
        videoId: 'vid-missing',
        ownerId: 'uid-1',
        caption: 'Hello',
        localVideoPath: '/tmp/does-not-exist-streamerstip.mp4',
        createdAt: DateTime(2026, 1, 1),
        status: VideoStatus.processing,
        categories: const <String>['gaming'],
        isOptimistic: true,
      );
      final HomeVideo actual = homeVideoFromOptimisticVideo(
        optimistic: optimistic,
      );
      expect(actual.videoURL.startsWith('file://'), isFalse);
      expect(isHomeVideoOwnerPendingLocal(actual), isFalse);
    });
  });

  group('owner pending + canonical composition', () {
    test('22 canonical + 1 pending local = 23 with pending at index 0',
        () async {
      final File localMp4 = await _createTempLocalMp4('cap.mp4');
      addTearDown(() async {
        final Directory parent = localMp4.parent;
        if (await parent.exists()) {
          await parent.delete(recursive: true);
        }
      });
      final List<HomeVideo> canonical = List<HomeVideo>.generate(
        22,
        (int i) => HomeVideo(
          id: 'ready-$i',
          creator: const User(
            id: 'other',
            username: 'other',
            displayName: 'Other',
          ),
          videoURL: 'https://stream.mux.com/abc$i.m3u8',
          status: 'ready',
        ),
      );
      final HomeVideo pending = homeVideoFromOptimisticVideo(
        optimistic: OptimisticVideo(
          videoId: 'pending-new',
          ownerId: 'uid-owner',
          caption: 'just posted',
          localVideoPath: localMp4.path,
          createdAt: DateTime.now(),
          status: VideoStatus.processing,
          categories: const <String>['gaming'],
          isOptimistic: true,
        ),
      );
      final List<HomeVideo> display = <HomeVideo>[pending, ...canonical];
      expect(display.length, 23);
      expect(display.first.id, 'pending-new');
      expect(isHomeVideoPlayable(display.first), isTrue);
      expect(isHomeVideoOwnerPendingLocal(display.first), isTrue);
    });

    test('display playable requires existing local file for pending', () {
      final HomeVideo missingLocal = HomeVideo(
        id: 'missing-file',
        creator: const User(
          id: 'uid-owner',
          username: 'you',
          displayName: 'You',
        ),
        videoURL: 'file:///tmp/does-not-exist-streamerstip.mp4',
        status: 'uploading',
      );
      expect(isHomeVideoOwnerPendingLocal(missingLocal), isTrue);
      expect(isHomeVideoPlayable(missingLocal), isTrue);
      expect(isHomeVideoDisplayPlayable(missingLocal), isFalse);
    });

    test('keeps local overlay mapping when optimistic is ready', () {
      final OptimisticVideo readyLocal = OptimisticVideo(
        videoId: 'pending-ready',
        ownerId: 'uid-owner',
        caption: 'just posted',
        localVideoPath: '/data/user/0/app/CameraCaptures/cap.mp4',
        createdAt: DateTime.now(),
        status: VideoStatus.uploadSucceeded,
        categories: const <String>['gaming'],
        isOptimistic: true,
        videoUrl: 'https://stream.mux.com/abc.m3u8',
      );
      final HomeVideo card = homeVideoFromOptimisticVideo(
        optimistic: readyLocal,
      );
      expect(card.status, 'ready');
      expect(isHomeVideoPlayable(card), isTrue);
      expect(card.videoURL, 'https://stream.mux.com/abc.m3u8');
    });

    test('ready without remote still uses local Instant Play', () async {
      final File localMp4 = await _createTempLocalMp4('cap_ready.mp4');
      addTearDown(() async {
        final Directory parent = localMp4.parent;
        if (await parent.exists()) {
          await parent.delete(recursive: true);
        }
      });
      final OptimisticVideo readyLocalOnly = OptimisticVideo(
        videoId: 'pending-ready-local',
        ownerId: 'uid-owner',
        caption: 'just posted',
        localVideoPath: localMp4.path,
        createdAt: DateTime.now(),
        status: VideoStatus.uploadSucceeded,
        categories: const <String>['gaming'],
        isOptimistic: true,
      );
      final HomeVideo card = homeVideoFromOptimisticVideo(
        optimistic: readyLocalOnly,
      );
      expect(isHomeVideoOwnerPendingLocal(card), isTrue);
      expect(isHomeVideoPlayable(card), isTrue);
      expect(card.videoURL.startsWith('file://'), isTrue);
    });

    test('profile overlay keeps ready local until grid already has id',
        () async {
      final File localMp4 = await _createTempLocalMp4('cap_profile.mp4');
      addTearDown(() async {
        final Directory parent = localMp4.parent;
        if (await parent.exists()) {
          await parent.delete(recursive: true);
        }
      });
      final OptimisticVideo readyLocal = OptimisticVideo(
        videoId: 'pending-ready',
        ownerId: 'uid-owner',
        caption: 'just posted',
        localVideoPath: localMp4.path,
        createdAt: DateTime.now(),
        status: VideoStatus.uploadSucceeded,
        categories: const <String>['gaming'],
        isOptimistic: true,
      );
      expect(
        shouldOverlayOptimisticOnOwnerProfile(
          item: readyLocal,
          profileVideos: const <HomeVideo>[],
        ),
        isTrue,
      );
      expect(
        shouldOverlayOptimisticOnOwnerProfile(
          item: readyLocal,
          profileVideos: <HomeVideo>[
            HomeVideo(
              id: 'pending-ready',
              creator: const User(
                id: 'uid-owner',
                username: 'you',
                displayName: 'You',
              ),
              videoURL: 'https://stream.mux.com/abc.m3u8',
              status: 'ready',
            ),
          ],
        ),
        isFalse,
      );
    });
  });
}
