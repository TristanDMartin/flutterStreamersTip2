import 'package:video_player/video_player.dart';

import 'package:streamers_tip/utils/secure_log.dart';

import 'playback_pool_policy.dart';

/// In-memory pool of [VideoPlayerController] instances and eviction metadata.
///
/// Owns controller maps, attachment pins, cooldown windows, and safety checks.
/// Playback focus and audio routing remain in [GlobalPlaybackManager].
class PlaybackControllerPool {
  static const int disposalEligibilityTtlSeconds =
      PlaybackPoolPolicy.disposalEligibilityTtlSeconds;

  final Map<String, VideoPlayerController> controllers =
      <String, VideoPlayerController>{};
  final Map<String, String> owners = <String, String>{};
  final Map<String, bool> disposed = <String, bool>{};
  final Set<String> initializing = <String>{};
  final Map<String, DateTime> cooldownUntil = <String, DateTime>{};
  final Set<String> pinnedVideoIds = <String>{};
  final Map<String, int> attached = <String, int>{};
  final Map<String, DateTime> createdAt = <String, DateTime>{};

  int get length => controllers.length;

  bool containsKey(String videoId) => controllers.containsKey(videoId);

  VideoPlayerController? operator [](String videoId) => controllers[videoId];

  Iterable<MapEntry<String, VideoPlayerController>> get entries =>
      controllers.entries;

  Iterable<String> get keys => controllers.keys;

  String? ownerOf(String videoId) => owners[videoId];

  void setOwner(String videoId, String owner) {
    owners[videoId] = owner;
  }

  void markInitializing(String videoId) {
    initializing.add(videoId);
  }

  void clearInitializing(String videoId) {
    initializing.remove(videoId);
  }

  void markAttached(String videoId, int controllerId) {
    attached[videoId] = controllerId;
  }

  void markDetached(String videoId) {
    attached.remove(videoId);
  }

  bool isAttachedTo(String videoId, VideoPlayerController controller) {
    return attached[videoId] == controller.hashCode;
  }

  void prepareForRegister(String videoId) {
    initializing.remove(videoId);
    cooldownUntil.remove(videoId);
    disposed.remove(videoId);
  }

  void recordRegister(String videoId, VideoPlayerController controller) {
    controllers[videoId] = controller;
    createdAt[videoId] = DateTime.now();
  }

  void removePoolEntry(String videoId) {
    controllers.remove(videoId);
    owners.remove(videoId);
    attached.remove(videoId);
    createdAt.remove(videoId);
  }

  void markDisposed(String videoId) {
    disposed[videoId] = true;
  }

  /// Whether [controller] is initialized, error-free, and not marked disposed.
  bool isControllerSafe(String videoId, VideoPlayerController controller) {
    if (disposed[videoId] == true) {
      return false;
    }
    try {
      final VideoPlayerValue value = controller.value;
      return value.isInitialized && !value.hasError;
    } catch (e) {
      secureLog(
        '⚠️ PlaybackControllerPool: Controller for video $videoId is disposed: $e',
      );
      disposed[videoId] = true;
      return false;
    }
  }

  /// Whether [id] may be evicted from the pool (not active, attached, or init).
  bool canEvict({
    required String id,
    required VideoPlayerController controller,
    required DateTime now,
    required String? activeVideoId,
  }) {
    if (id == activeVideoId) {
      return false;
    }
    if (attached[id] == controller.hashCode) {
      return false;
    }
    if (initializing.contains(id)) {
      return false;
    }
    final DateTime? registeredAt = createdAt[id];
    if (registeredAt != null &&
        now.difference(registeredAt) <
            Duration(seconds: disposalEligibilityTtlSeconds)) {
      return false;
    }
    return true;
  }

  /// Protects previous/current/next indices from hard disposal.
  void updatePinSet({
    required int currentIndex,
    required Map<int, String> indexToVideoId,
    int backwardRadius = 1,
    int forwardRadius = 1,
  }) {
    pinnedVideoIds.clear();
    for (int offset = -backwardRadius; offset <= forwardRadius; offset++) {
      final int index = currentIndex + offset;
      final String? videoId = indexToVideoId[index];
      if (videoId != null && controllers.containsKey(videoId)) {
        pinnedVideoIds.add(videoId);
      }
    }
  }

  /// Compact snapshot token for debug logging (`P`=pinned, `I`=init, `C`=cooldown).
  String snapshotTokenFor(String videoId) {
    final String pin = pinnedVideoIds.contains(videoId) ? 'P' : '-';
    final String init = initializing.contains(videoId) ? 'I' : '-';
    final String cooldown = cooldownUntil.containsKey(videoId) ? 'C' : '-';
    return '$videoId[$pin$init$cooldown]';
  }

  void clearAll() {
    controllers.clear();
    owners.clear();
    disposed.clear();
    attached.clear();
    createdAt.clear();
    cooldownUntil.clear();
    pinnedVideoIds.clear();
    initializing.clear();
  }
}
