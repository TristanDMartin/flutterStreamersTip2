import 'package:video_player/video_player.dart';

import '../constants/playback_owners.dart';
import 'playback_controller_pool.dart';
import 'playback_feed_index_tracker.dart';
import 'playback_pool_policy.dart';
import 'playback_warm_window_policy.dart';

/// Hard-enforces the global controller pool cap when soft eviction stalls.
class PlaybackPoolCapCoordinator {
  const PlaybackPoolCapCoordinator();

  static bool ownerConflictsWithVisibleSurface(
    String controllerOwner,
    String visibleOwner,
  ) {
    if (visibleOwner == PlaybackOwners.home ||
        visibleOwner.startsWith('${PlaybackOwners.home}/')) {
      return controllerOwner == PlaybackOwners.discover ||
          controllerOwner == PlaybackOwners.discoverPlayer ||
          controllerOwner.startsWith('${PlaybackOwners.discover}/');
    }
    if (visibleOwner == PlaybackOwners.discover ||
        visibleOwner == PlaybackOwners.discoverPlayer ||
        visibleOwner.startsWith(PlaybackOwners.discover)) {
      return controllerOwner == PlaybackOwners.home ||
          controllerOwner.startsWith('${PlaybackOwners.home}/');
    }
    if (visibleOwner == PlaybackOwners.profile ||
        visibleOwner == PlaybackOwners.network) {
      return controllerOwner == PlaybackOwners.home ||
          controllerOwner.startsWith('${PlaybackOwners.home}/') ||
          controllerOwner == PlaybackOwners.discover ||
          controllerOwner == PlaybackOwners.discoverPlayer ||
          controllerOwner.startsWith(PlaybackOwners.discover);
    }
    return false;
  }

  /// Drops pooled controllers owned by a surface that is no longer visible.
  int stripConflictingSurfaceControllers({
    required String visibleOwner,
    required PlaybackControllerPool pool,
    required Map<String, String> controllerOwners,
    required void Function(String videoId) onUnregister,
    required void Function(String action, String videoId, {String? reason})
        onPoolAudit,
  }) {
    final List<String> toRemove = <String>[];
    for (final MapEntry<String, String> entry in controllerOwners.entries) {
      if (ownerConflictsWithVisibleSurface(entry.value, visibleOwner)) {
        toRemove.add(entry.key);
      }
    }
    for (final String videoId in toRemove) {
      onPoolAudit(
        'evicted',
        videoId,
        reason: 'surface_handoff_$visibleOwner',
      );
      onUnregister(videoId);
    }
    return toRemove.length;
  }

  /// Evicts farthest / outside-warm-window controllers until [pool.length] ≤ [maxSize].
  int enforcePoolCap({
    required PlaybackControllerPool pool,
    required PlaybackFeedIndexTracker feedIndex,
    required String? activeVideoId,
    required bool Function(String videoId) isActiveVideo,
    required void Function(String videoId) onUnregister,
    required void Function(String action, String videoId, {String? reason})
        onPoolAudit,
    Set<String> protectedVideoIds = const <String>{},
    int maxSize = PlaybackPoolPolicy.maxControllerPoolSize,
    String reason = 'cap',
  }) {
    int evicted = 0;
    while (pool.length > maxSize) {
      final String? victim = _pickEvictionCandidate(
        pool: pool,
        feedIndex: feedIndex,
        activeVideoId: activeVideoId,
        isActiveVideo: isActiveVideo,
        protectedVideoIds: protectedVideoIds,
        onPoolAudit: onPoolAudit,
        maxSize: maxSize,
      );
      if (victim == null) {
        break;
      }
      onPoolAudit('evicted', victim, reason: '${reason}_pool_cap');
      onUnregister(victim);
      evicted++;
    }
    return evicted;
  }

  String? _pickEvictionCandidate({
    required PlaybackControllerPool pool,
    required PlaybackFeedIndexTracker feedIndex,
    required String? activeVideoId,
    required bool Function(String videoId) isActiveVideo,
    required Set<String> protectedVideoIds,
    required void Function(String action, String videoId, {String? reason})
        onPoolAudit,
    required int maxSize,
  }) {
    final int? currentIndex = feedIndex.currentFeedIndex;
    final int direction = feedIndex.lastScrollDirection;
    final List<String> candidates = <String>[];
    for (final String videoId in pool.keys) {
      final String? protection = _protectionReason(
        videoId: videoId,
        pool: pool,
        feedIndex: feedIndex,
        activeVideoId: activeVideoId,
        isActiveVideo: isActiveVideo,
        protectedVideoIds: protectedVideoIds,
        maxSize: maxSize,
      );
      if (protection != null) {
        if (protection == 'pending_or_requested_focus') {
          onPoolAudit(
            'EVICTION_BLOCKED_PENDING_FOCUS',
            videoId,
            reason: protection,
          );
        } else if (protection == 'current_or_active') {
          onPoolAudit(
            'EVICTION_BLOCKED_CURRENT',
            videoId,
            reason: protection,
          );
        }
        continue;
      }
      onPoolAudit('EVICTION_CANDIDATE', videoId, reason: 'pool_cap');
      candidates.add(videoId);
    }
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((String a, String b) {
      final int? indexA = feedIndex.videoIdToIndex[a];
      final int? indexB = feedIndex.videoIdToIndex[b];
      final bool outsideA = indexA == null ||
          currentIndex == null ||
          PlaybackWarmWindowPolicy.isOutsideWarmWindow(
            videoIndex: indexA,
            currentIndex: currentIndex,
            direction: direction,
          );
      final bool outsideB = indexB == null ||
          currentIndex == null ||
          PlaybackWarmWindowPolicy.isOutsideWarmWindow(
            videoIndex: indexB,
            currentIndex: currentIndex,
            direction: direction,
          );
      if (outsideA != outsideB) {
        return outsideA ? -1 : 1;
      }
      if (indexA == null && indexB != null) {
        return -1;
      }
      if (indexB == null && indexA != null) {
        return 1;
      }
      if (currentIndex == null || indexA == null || indexB == null) {
        return 0;
      }
      final int distA = (indexA - currentIndex).abs();
      final int distB = (indexB - currentIndex).abs();
      return distB.compareTo(distA);
    });
    return candidates.first;
  }

  String? _protectionReason({
    required String videoId,
    required PlaybackControllerPool pool,
    required PlaybackFeedIndexTracker feedIndex,
    required String? activeVideoId,
    required bool Function(String videoId) isActiveVideo,
    required Set<String> protectedVideoIds,
    required int maxSize,
  }) {
    if (protectedVideoIds.contains(videoId)) {
      return 'pending_or_requested_focus';
    }
    if (videoId == activeVideoId || isActiveVideo(videoId)) {
      return 'current_or_active';
    }
    if (pool.initializing.contains(videoId)) {
      return 'initializing';
    }
    final VideoPlayerController? pooled = pool[videoId];
    if (pooled != null && pool.isAttachedTo(videoId, pooled)) {
      final int? videoIndex = feedIndex.videoIdToIndex[videoId];
      final int? currentIndex = feedIndex.currentFeedIndex;
      if (videoIndex != null &&
          currentIndex != null &&
          !PlaybackWarmWindowPolicy.isOutsideWarmWindow(
            videoIndex: videoIndex,
            currentIndex: currentIndex,
            direction: feedIndex.lastScrollDirection,
          )) {
        return 'attached_visible';
      }
      pool.markDetached(videoId);
    }
    if (pool.pinnedVideoIds.contains(videoId)) {
      final int? videoIndex = feedIndex.videoIdToIndex[videoId];
      final int? currentIndex = feedIndex.currentFeedIndex;
      if (videoIndex != null &&
          currentIndex != null &&
          !PlaybackWarmWindowPolicy.isOutsideWarmWindow(
            videoIndex: videoIndex,
            currentIndex: currentIndex,
            direction: feedIndex.lastScrollDirection,
          )) {
        return 'warm_window_pin';
      }
    }
    final String? owner = pool.ownerOf(videoId);
    if (owner == PlaybackOwners.player) {
      return 'full_screen_player';
    }
    return null;
  }
}
