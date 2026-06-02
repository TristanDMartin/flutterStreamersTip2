import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_video.dart';
import '../providers/discover_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/home_provider.dart' as hp;
import 'video_service.dart';

final videoDeletionServiceProvider = Provider<VideoDeletionService>((ref) {
  return VideoDeletionService(ref: ref);
});

/// Global soft-delete via `deleteVideo` / `deleteVideos` (us-central1).
/// Optimistic list removal only — never hard-delete `videos/{id}` on the client.
/// Filter feeds with [isVideoVisibleInFeed] / [isHomeVideoVisibleInFeed].
class VideoDeletionService {
  VideoDeletionService({
    FirebaseFunctions? functions,
    Ref? ref,
  })  : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _ref = ref;

  final FirebaseFunctions _functions;
  final Ref? _ref;

  Future<void> deleteVideo(
    String videoId, {
    String source = 'app',
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('deleteVideo');
    await callable.call(<String, dynamic>{
      'videoId': videoId,
      'source': source,
    });
  }

  Future<void> deleteVideos(
    List<String> videoIds, {
    String source = 'app',
  }) async {
    if (videoIds.isEmpty) {
      return;
    }
    final HttpsCallable callable = _functions.httpsCallable('deleteVideos');
    await callable.call(<String, dynamic>{
      'videoIds': videoIds,
      'source': source,
    });
  }

  void applyOptimisticRemoval(
    List<String> videoIds, {
    String? profileUserId,
  }) {
    final Ref? ref = _ref;
    if (ref == null) {
      return;
    }
    final VideoService videoService =
        ref.read(videoServiceStateProvider.notifier);
    for (final String id in videoIds) {
      videoService.removeVideo(id);
    }
    ref.invalidate(hp.homeProvider);
    ref.invalidate(discoverProvider);
    ref.invalidate(favoritesProvider);
    if (profileUserId != null && profileUserId.isNotEmpty) {
      ref.invalidate(userVideosProvider(profileUserId));
    }
  }

  void rollbackOptimisticRemoval(List<HomeVideo> videos) {
    final Ref? ref = _ref;
    if (ref == null) {
      return;
    }
    final VideoService videoService =
        ref.read(videoServiceStateProvider.notifier);
    for (final HomeVideo video in videos) {
      videoService.addVideo(video);
    }
    ref.invalidate(hp.homeProvider);
    ref.invalidate(discoverProvider);
    ref.invalidate(favoritesProvider);
  }

  Future<void> deleteVideoWithOptimisticUi({
    required String videoId,
    required List<HomeVideo> rollbackVideos,
    String? profileUserId,
    String source = 'app',
  }) async {
    applyOptimisticRemoval(<String>[videoId], profileUserId: profileUserId);
    try {
      await deleteVideo(videoId, source: source);
      await _refreshFeeds();
    } catch (e) {
      debugPrint('❌ VideoDeletionService: delete failed, rolling back: $e');
      rollbackOptimisticRemoval(rollbackVideos);
      rethrow;
    }
  }

  Future<void> deleteVideosWithOptimisticUi({
    required List<String> videoIds,
    required List<HomeVideo> rollbackVideos,
    String? profileUserId,
    String source = 'app',
  }) async {
    applyOptimisticRemoval(videoIds, profileUserId: profileUserId);
    try {
      await deleteVideos(videoIds, source: source);
      await _refreshFeeds();
    } catch (e) {
      debugPrint('❌ VideoDeletionService: bulk delete failed: $e');
      rollbackOptimisticRemoval(rollbackVideos);
      rethrow;
    }
  }

  Future<void> _refreshFeeds() async {
    final Ref? ref = _ref;
    if (ref == null) {
      return;
    }
    try {
      await ref.read(hp.homeProvider.notifier).refreshFeed();
      await ref.read(videoServiceStateProvider.notifier).refresh();
    } catch (e, st) {
      debugPrint(
          '⚠️ VideoDeletionService: refresh after delete failed: $e $st');
    }
  }
}
