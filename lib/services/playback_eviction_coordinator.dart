import 'package:flutter/material.dart';

import '../constants/playback_owners.dart';
import '../models/home_video.dart';
import '../utils/safe_video_controller.dart';
import '../utils/secure_log.dart';
import 'playback_controller_pool.dart';
import 'playback_feed_index_tracker.dart';
import 'playback_pool_policy.dart';
import 'playback_preload_order.dart';
import 'playback_warm_window_policy.dart';

/// Preload window warming and two-stage controller eviction.
class PlaybackEvictionCoordinator {
  const PlaybackEvictionCoordinator();

  static const int poolRadius = 1;
  static const int maxControllerPoolSize =
      PlaybackPoolPolicy.maxControllerPoolSize;

  void preloadAround({
    required int index,
    required List<HomeVideo> videos,
    required PlaybackControllerPool pool,
    required PlaybackFeedIndexTracker feedIndex,
    required PlaybackPreloadBurstGuard burstGuard,
    required void Function(int index, String videoId) onSyncFeedIndexMapping,
    required void Function(int currentIndex,
            {int backwardRadius, int forwardRadius})
        onUpdatePinSet,
    required Future<void> Function(int index, HomeVideo video,
            {String controllerOwner})
        onEnsureControllerReady,
    required void Function(int index) onDisposeFarControllers,
    int direction = 0,
    String controllerOwner = PlaybackOwners.home,
    void Function(String message)? log,
  }) {
    // 🔒 SAFETY: Validate inputs
    if (videos.isEmpty) {
      secureLog('⚠️ PlaybackManager: Videos list is empty, skipping preload');
      return;
    }
    if (index < 0) {
      secureLog('⚠️ PlaybackManager: Invalid index $index for preloadAround');
      return;
    }
    if (index >= videos.length) {
      secureLog(
          '⚠️ PlaybackManager: Index $index out of bounds (videos.length: ${videos.length})');
      return;
    }

    final centerVideoId = videos[index].id;
    if (burstGuard.shouldSkipDuplicateBurst(
      index: index,
      centerVideoId: centerVideoId,
    )) {
      return;
    }
    burstGuard.recordRequest(
      index: index,
      centerVideoId: centerVideoId,
    );

    feedIndex.lastScrollDirection = direction;
    final ({int backward, int forward}) radii =
        PlaybackWarmWindowPolicy.radiiForDirection(direction);
    final int backwardRadius = radii.backward;
    final int forwardRadius = radii.forward;

    // 🔥 FIX: Wrap in try-catch to prevent crashes during rapid swiping
    try {
      // Bias warming toward the user's swipe direction so the next likely
      // landing video is ready without over-churning the controller pool.
      final List<int> preloadIndices = computePlaybackPreloadIndices(
        index: index,
        videoCount: videos.length,
        direction: direction,
        backwardRadius: backwardRadius,
        forwardRadius: forwardRadius,
      );

      for (final n in preloadIndices) {
        final video = videos[n];
        if (video.id.isNotEmpty) {
          onSyncFeedIndexMapping(n, video.id);
        }
      }

      onUpdatePinSet(
        index,
        backwardRadius: backwardRadius,
        forwardRadius: forwardRadius,
      );

      for (final n in preloadIndices) {
        // 🔒 SAFETY: Double-check bounds before accessing
        if (n >= 0 && n < videos.length) {
          try {
            final video = videos[n];

            // 🔒 SAFETY: Validate video object before preloading
            if (video.id.isEmpty || video.videoURL.isEmpty) {
              secureLog(
                  '⚠️ PlaybackManager: Invalid video at index $n, skipping preload');
              continue;
            }

            final videoId = video.id;
            onSyncFeedIndexMapping(n, videoId);

            if (!pool.controllers.containsKey(videoId)) {
              final int distanceFromCurrent = (n - index).abs();
              if (pool.controllers.length >
                  PlaybackWarmWindowPolicy.maxControllerPoolSize) {
                onDisposeFarControllers(index);
              }
              if (distanceFromCurrent > 2 &&
                  pool.controllers.length >=
                      PlaybackWarmWindowPolicy.maxControllerPoolSize) {
                secureLog(
                  '⏭️ PlaybackManager: Skipping distant preload at index $n '
                  '(pool=${pool.controllers.length}, cap='
                  '${PlaybackWarmWindowPolicy.maxControllerPoolSize})',
                );
                continue;
              }
              // Next videos - preload in background (fire-and-forget)
              secureLog(
                  '🔄 PlaybackManager: Preloading next video controller for index $n (video: $videoId)');
              onEnsureControllerReady(
                n,
                video,
                controllerOwner: controllerOwner,
              ).catchError((e, stackTrace) {
                secureLog(
                    '⚠️ PlaybackManager: Error preloading next video index $n: $e');
                secureLog('Stack trace: $stackTrace');
              });
            } else {
              // Check if existing controller is initialized
              final existingController = pool.controllers[videoId];
              if (existingController != null &&
                  pool.isControllerSafe(videoId, existingController)) {
                try {
                  if (!existingController.value.isInitialized) {
                    // Controller exists but not initialized - ensure it's ready
                    secureLog(
                        '🔄 PlaybackManager: Re-initializing controller for index $n (video: $videoId)');
                    onEnsureControllerReady(
                      n,
                      video,
                      controllerOwner: controllerOwner,
                    ).catchError((e, stackTrace) {
                      secureLog(
                          '⚠️ PlaybackManager: Error re-initializing index $n: $e');
                    });
                  } else {
                    secureLog(
                        '✅ PlaybackManager: Controller already ready for index $n');
                  }
                } catch (e) {
                  secureLog(
                    '🔄 PlaybackManager: Controller unsafe ($e), '
                    're-initializing for index $n',
                  );
                  onEnsureControllerReady(
                    n,
                    video,
                    controllerOwner: controllerOwner,
                  ).catchError((e, stackTrace) {
                    secureLog(
                        '⚠️ PlaybackManager: Error re-initializing index $n: $e');
                  });
                }
              } else {
                secureLog(
                    '✅ PlaybackManager: Controller already exists for index $n, skipping preload');
              }
            }
          } catch (e, stackTrace) {
            secureLog(
                '❌ PlaybackManager: Error processing preload index $n: $e');
            secureLog('Stack trace: $stackTrace');
            // Continue with next index
          }
        }
      }
    } catch (e, stackTrace) {
      secureLog('❌ PlaybackManager: Critical error in preloadAround: $e');
      secureLog('Stack trace: $stackTrace');
      // Don't crash - just log
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (pool.controllers.length >
                PlaybackWarmWindowPolicy.maxControllerPoolSize ||
            pool.controllers.keys.any((videoId) {
              final videoIndex = feedIndex.videoIdToIndex[videoId];
              if (videoIndex == null) return true;
              return PlaybackWarmWindowPolicy.isOutsideWarmWindow(
                videoIndex: videoIndex,
                currentIndex: index,
                direction: feedIndex.lastScrollDirection,
              );
            })) {
          secureLog(
              '⚠️ PlaybackManager: Cleaning up outside warm window (pool=${pool.controllers.length})');
          onDisposeFarControllers(index);
        }
      } catch (e) {
        secureLog(
            '❌ PlaybackManager: Error disposing far controllers (deferred): $e');
      }
    });
  }

  /// 🔥 PHASE 1 FIX: Two-stage eviction (cooldown then disposal)
  /// Dispose controllers far from current index with cooldown protection
  /// 🔒 SAFETY: Only disposes controllers that are definitely not in use
  /// 🔥 CRITICAL MEMORY FIX: Also enforces maximum pool size
  void disposeFarControllers({
    required int index,
    required PlaybackControllerPool pool,
    required PlaybackFeedIndexTracker feedIndex,
    required Map<String, bool> muteStates,
    required String? activeVideoId,
    required bool Function(String videoId) isActiveVideo,
    required void Function(int currentIndex,
            {int backwardRadius, int forwardRadius})
        onUpdatePinSet,
    required void Function(String event, String videoId, {String? reason})
        onLogControllerEvent,
    void Function(String message)? log,
  }) {
    final ({int backward, int forward}) radii =
        PlaybackWarmWindowPolicy.radiiForDirection(
      feedIndex.lastScrollDirection,
    );
    onUpdatePinSet(
      index,
      backwardRadius: radii.backward,
      forwardRadius: radii.forward,
    );

    // 🔥 FIX: Wrap entire method in try-catch to prevent crashes
    try {
      final now = DateTime.now();
      final toDispose = <String>[];

      // 🔥 STEP 1: Clean up stale/disposed controllers first
      final staleControllers = <String>[];
      try {
        for (final entry in pool.controllers.entries) {
          try {
            final videoId = entry.key;
            final controller = entry.value;
            if (!pool.isControllerSafe(videoId, controller)) {
              staleControllers.add(videoId);
            }
          } catch (e) {
            secureLog(
                '⚠️ PlaybackManager: Error checking controller safety: $e');
            // Continue with next entry
          }
        }
      } catch (e, stackTrace) {
        secureLog('❌ PlaybackManager: Error cleaning stale controllers: $e');
        secureLog('Stack trace: $stackTrace');
        // Continue anyway
      }

      // Clean up stale controllers
      for (final videoId in staleControllers) {
        if (pool.initializing.contains(videoId) ||
            videoId == activeVideoId ||
            isActiveVideo(videoId) ||
            pool.ownerOf(videoId) == PlaybackOwners.player ||
            pool.ownerOf(videoId) == PlaybackOwners.discoverPlayer ||
            pool.pinnedVideoIds.contains(videoId)) {
          onLogControllerEvent(
            'CLEANUP_SKIPPED_ACTIVE_VIDEO',
            videoId,
            reason: 'stale_protected',
          );
          continue;
        }
        try {
          onLogControllerEvent('DISPOSE_REQUESTED', videoId,
              reason: 'stale_controller');
          pool.controllers.remove(videoId);
          pool.owners.remove(videoId);
          muteStates.remove(videoId);
          pool.disposed[videoId] = true;
          pool.pinnedVideoIds.remove(videoId);
          pool.cooldownUntil.remove(videoId);
          pool.attached.remove(videoId);
          pool.createdAt.remove(videoId);
          final videoIndex = feedIndex.videoIdToIndex[videoId];
          if (videoIndex != null) {
            feedIndex.videoIdToIndex.remove(videoId);
            feedIndex.indexToVideoId.remove(videoIndex);
            feedIndex.lastKnownPositions.remove(videoIndex);
          }
          onLogControllerEvent('DISPOSED', videoId, reason: 'stale');
        } catch (e) {
          secureLog(
              '⚠️ PlaybackManager: Error cleaning stale controller $videoId: $e');
        }
      }

      // 🔥 PHASE 1 FIX: STEP 2: Two-stage eviction - Stage A: Mark for cooldown
      try {
        for (final entry in pool.controllers.entries) {
          try {
            final videoId = entry.key;
            final videoIndex = feedIndex.videoIdToIndex[videoId];

            // 🔥 GUARD: Never dispose pinned, active, or initializing controllers
            if (pool.pinnedVideoIds.contains(videoId) ||
                videoId == activeVideoId ||
                isActiveVideo(videoId) ||
                pool.initializing.contains(videoId) ||
                pool.ownerOf(videoId) == PlaybackOwners.player ||
                pool.ownerOf(videoId) == PlaybackOwners.discoverPlayer) {
              if (videoId == activeVideoId || isActiveVideo(videoId)) {
                onLogControllerEvent(
                  'CLEANUP_SKIPPED_ACTIVE_VIDEO',
                  videoId,
                  reason: 'cooldown_protected',
                );
              }
              // Cancel cooldown if video came back into protected zone
              if (pool.cooldownUntil.containsKey(videoId)) {
                pool.cooldownUntil.remove(videoId);
                onLogControllerEvent('COOLDOWN_CANCELLED', videoId,
                    reason: 'protected_zone');
              }
              continue;
            }
            // 🔥 PHASE 2.3: Protect attached controllers only inside warm window
            final attachedId = pool.attached[videoId];
            if (attachedId != null && attachedId == entry.value.hashCode) {
              final bool attachedInWarmWindow = videoIndex != null &&
                  !PlaybackWarmWindowPolicy.isOutsideWarmWindow(
                    videoIndex: videoIndex,
                    currentIndex: index,
                    direction: feedIndex.lastScrollDirection,
                  );
              if (attachedInWarmWindow) {
                if (pool.cooldownUntil.containsKey(videoId)) {
                  pool.cooldownUntil.remove(videoId);
                  onLogControllerEvent('COOLDOWN_CANCELLED', videoId,
                      reason: 'attached');
                }
                continue;
              }
              pool.markDetached(videoId);
            }
            // 🔥 PHASE 2.3: Don't dispose within TTL of registration (reduces surface churn on scroll-back)
            final createdAt = pool.createdAt[videoId];
            if (createdAt != null &&
                now.difference(createdAt) <
                    Duration(
                        seconds:
                            PlaybackPoolPolicy.disposalEligibilityTtlSeconds)) {
              if (!pool.cooldownUntil.containsKey(videoId)) {
                pool.cooldownUntil[videoId] = createdAt.add(Duration(
                    seconds: PlaybackPoolPolicy.disposalEligibilityTtlSeconds));
                onLogControllerEvent('START_COOLDOWN', videoId,
                    reason: 'within_ttl');
              }
              continue;
            }

            // Check if outside warm window
            if (videoIndex != null &&
                PlaybackWarmWindowPolicy.isOutsideWarmWindow(
                  videoIndex: videoIndex,
                  currentIndex: index,
                  direction: feedIndex.lastScrollDirection,
                )) {
              final controller = entry.value;
              if (!pool.isControllerSafe(videoId, controller)) continue;

              try {
                // Only mark for cooldown if controller is initialized and ready
                if (controller.value.isInitialized &&
                    !controller.value.hasError) {
                  // Check if already in cooldown
                  if (pool.cooldownUntil.containsKey(videoId)) {
                    // Check if cooldown expired
                    final cooldownExpiry = pool.cooldownUntil[videoId]!;
                    if (now.isAfter(cooldownExpiry)) {
                      // Cooldown expired - mark for disposal
                      toDispose.add(videoId);
                    }
                  } else {
                    // Start cooldown (soft eviction)
                    pool.cooldownUntil[videoId] = now.add(
                        Duration(seconds: PlaybackPoolPolicy.cooldownSeconds));
                    onLogControllerEvent('START_COOLDOWN', videoId,
                        reason:
                            'outside_radius index=$videoIndex current=$index');
                  }
                }
              } catch (e, st) {
                logPlaybackSwallowed('evictPool.radiusCheck', e, st);
              }
            } else if (videoIndex == null) {
              // No index mapping - start cooldown if initialized
              final controller = entry.value;
              if (pool.attached[videoId] == controller.hashCode) {
                continue;
              }
              final createdAt = pool.createdAt[videoId];
              if (createdAt != null &&
                  now.difference(createdAt) <
                      Duration(
                          seconds: PlaybackPoolPolicy
                              .disposalEligibilityTtlSeconds)) {
                if (!pool.cooldownUntil.containsKey(videoId)) {
                  pool.cooldownUntil[videoId] = createdAt.add(Duration(
                      seconds:
                          PlaybackPoolPolicy.disposalEligibilityTtlSeconds));
                  onLogControllerEvent('START_COOLDOWN', videoId,
                      reason: 'no_index_within_ttl');
                }
                continue;
              }
              if (pool.isControllerSafe(videoId, controller)) {
                try {
                  if (controller.value.isInitialized &&
                      !controller.value.hasError) {
                    if (!pool.cooldownUntil.containsKey(videoId)) {
                      pool.cooldownUntil[videoId] = now.add(Duration(
                          seconds: PlaybackPoolPolicy.cooldownSeconds));
                      onLogControllerEvent('START_COOLDOWN', videoId,
                          reason: 'no_index_mapping');
                    } else {
                      final cooldownExpiry = pool.cooldownUntil[videoId]!;
                      if (now.isAfter(cooldownExpiry)) {
                        toDispose.add(videoId);
                      }
                    }
                  }
                } catch (e, st) {
                  logPlaybackSwallowed('evictPool.noIndexCheck', e, st);
                }
              }
            }
          } catch (e) {
            secureLog(
                '⚠️ PlaybackManager: Error processing controller entry: $e');
            // Continue with next entry
          }
        }

        // 🔥 PHASE 1 FIX: STEP 3: Stage B - Hard eviction (rate limited: max 1 per cycle)
        if (toDispose.isNotEmpty &&
            pool.controllers.length >
                PlaybackEvictionCoordinator.maxControllerPoolSize) {
          // Sort by distance (furthest first)
          toDispose.sort((a, b) {
            final indexA = feedIndex.videoIdToIndex[a];
            final indexB = feedIndex.videoIdToIndex[b];
            if (indexA == null) return 1;
            if (indexB == null) return -1;
            final distA = (indexA - index).abs();
            final distB = (indexB - index).abs();
            return distB.compareTo(distA); // Furthest first
          });

          // Dispose only the furthest one (rate limit to prevent spikes)
          final videoIdToDispose = toDispose.first;
          final controller = pool.controllers.remove(videoIdToDispose);
          if (controller != null) {
            final bool isAttached =
                pool.attached[videoIdToDispose] == controller.hashCode;
            final createdAt = pool.createdAt[videoIdToDispose];
            final bool withinTtl = createdAt != null &&
                now.difference(createdAt) <
                    Duration(
                        seconds:
                            PlaybackPoolPolicy.disposalEligibilityTtlSeconds);
            if (isAttached || withinTtl) {
              pool.controllers[videoIdToDispose] = controller;
            } else {
              onLogControllerEvent('DISPOSE_REQUESTED', videoIdToDispose,
                  reason: 'cooldown_expired_furthest');
              try {
                pool.owners.remove(videoIdToDispose);
                muteStates.remove(videoIdToDispose);
                pool.disposed[videoIdToDispose] = true;
                pool.pinnedVideoIds.remove(videoIdToDispose);
                pool.cooldownUntil.remove(videoIdToDispose);
                pool.attached.remove(videoIdToDispose);
                pool.createdAt.remove(videoIdToDispose);
                final videoIndex = feedIndex.videoIdToIndex[videoIdToDispose];
                if (videoIndex != null) {
                  feedIndex.videoIdToIndex.remove(videoIdToDispose);
                  feedIndex.indexToVideoId.remove(videoIndex);
                  feedIndex.lastKnownPositions.remove(videoIndex);
                }
                if (pool.isControllerSafe(videoIdToDispose, controller)) {
                  controller.dispose();
                }
                onLogControllerEvent('DISPOSED', videoIdToDispose,
                    reason: 'cooldown_expired');
              } catch (e) {
                secureLog(
                    '❌ PlaybackManager: Error disposing controller $videoIdToDispose: $e');
              }
            }
          }
        }

        // 🔥 PHASE 1 FIX: STEP 4: If pool still too large, mark more for cooldown
        if (pool.controllers.length >
            PlaybackEvictionCoordinator.maxControllerPoolSize) {
          final readyEntries = pool.controllers.entries.where((e) {
            if (pool.pinnedVideoIds.contains(e.key) ||
                e.key == activeVideoId ||
                isActiveVideo(e.key) ||
                pool.initializing.contains(e.key)) {
              if (e.key == activeVideoId || isActiveVideo(e.key)) {
                onLogControllerEvent(
                  'CLEANUP_SKIPPED_ACTIVE_VIDEO',
                  e.key,
                  reason: 'pool_size_protected',
                );
              }
              return false;
            }
            try {
              return pool.isControllerSafe(e.key, e.value) &&
                  e.value.value.isInitialized &&
                  !e.value.value.hasError;
            } catch (e, st) {
              logPlaybackSwallowed('evictPool.poolFilter', e, st);
              return false;
            }
          }).toList();

          readyEntries.sort((a, b) {
            final indexA = feedIndex.videoIdToIndex[a.key];
            final indexB = feedIndex.videoIdToIndex[b.key];
            if (indexA == null) return 1;
            if (indexB == null) return -1;
            final distA = (indexA - index).abs();
            final distB = (indexB - index).abs();
            return distB.compareTo(distA); // Furthest first
          });

          // Mark furthest ready entries for cooldown
          final excessCount = pool.controllers.length -
              PlaybackEvictionCoordinator.maxControllerPoolSize;
          for (final entry in readyEntries.take(excessCount)) {
            if (!pool.cooldownUntil.containsKey(entry.key)) {
              pool.cooldownUntil[entry.key] = now
                  .add(Duration(seconds: PlaybackPoolPolicy.cooldownSeconds));
              onLogControllerEvent('START_COOLDOWN', entry.key,
                  reason:
                      'pool_size_limit distance=${feedIndex.videoIdToIndex[entry.key] != null ? (feedIndex.videoIdToIndex[entry.key]! - index).abs() : "unknown"}');
            }
          }
        }

        if (pool.controllers.length >
            PlaybackEvictionCoordinator.maxControllerPoolSize) {
          final overflowEntries = pool.controllers.entries.where((entry) {
            final videoId = entry.key;
            final videoIndex = feedIndex.videoIdToIndex[videoId];
            final bool outsideWarmWindow = videoIndex == null ||
                PlaybackWarmWindowPolicy.isOutsideWarmWindow(
                  videoIndex: videoIndex,
                  currentIndex: index,
                  direction: feedIndex.lastScrollDirection,
                );
            if (!outsideWarmWindow) return false;
            if (pool.pinnedVideoIds.contains(videoId) ||
                videoId == activeVideoId ||
                isActiveVideo(videoId) ||
                pool.initializing.contains(videoId) ||
                pool.ownerOf(videoId) == PlaybackOwners.player ||
                pool.ownerOf(videoId) == PlaybackOwners.discoverPlayer) {
              if (videoId == activeVideoId || isActiveVideo(videoId)) {
                onLogControllerEvent(
                  'CLEANUP_SKIPPED_ACTIVE_VIDEO',
                  videoId,
                  reason: 'hard_cap_protected',
                );
              }
              return false;
            }
            return pool.attached[videoId] != entry.value.hashCode;
          }).toList()
            ..sort((a, b) {
              final indexA = feedIndex.videoIdToIndex[a.key];
              final indexB = feedIndex.videoIdToIndex[b.key];
              if (indexA == null) return -1;
              if (indexB == null) return 1;
              return (indexB - index).abs().compareTo((indexA - index).abs());
            });

          for (final entry in overflowEntries) {
            if (pool.controllers.length <=
                PlaybackEvictionCoordinator.maxControllerPoolSize) {
              break;
            }
            final videoId = entry.key;
            final controller = pool.controllers.remove(videoId);
            if (controller == null) continue;
            if (pool.isAttachedTo(videoId, controller)) {
              pool.controllers[videoId] = controller;
              continue;
            }
            onLogControllerEvent('DISPOSE_REQUESTED', videoId,
                reason: 'hard_pool_cap');
            try {
              pool.owners.remove(videoId);
              muteStates.remove(videoId);
              pool.disposed[videoId] = true;
              pool.pinnedVideoIds.remove(videoId);
              pool.cooldownUntil.remove(videoId);
              pool.attached.remove(videoId);
              pool.createdAt.remove(videoId);
              final videoIndex = feedIndex.videoIdToIndex[videoId];
              if (videoIndex != null) {
                feedIndex.videoIdToIndex.remove(videoId);
                feedIndex.indexToVideoId.remove(videoIndex);
                feedIndex.lastKnownPositions.remove(videoIndex);
              }
              if (pool.isControllerSafe(videoId, controller)) {
                controller.dispose();
              }
              onLogControllerEvent('DISPOSED', videoId,
                  reason: 'hard_pool_cap');
            } catch (e) {
              secureLog(
                  '❌ PlaybackManager: Error hard-disposing controller $videoId: $e');
            }
          }
        }
      } catch (e, stackTrace) {
        secureLog('❌ PlaybackManager: Error in two-stage eviction: $e');
        secureLog('Stack trace: $stackTrace');
      }
    } catch (e, stackTrace) {
      secureLog(
          '❌ PlaybackManager: Critical error in disposeFarControllers: $e');
      secureLog('Stack trace: $stackTrace');
      // Don't crash - just log
    }
  }
}
