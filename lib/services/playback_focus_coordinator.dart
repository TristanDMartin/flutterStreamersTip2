import 'dart:async';

/// Focus, blocking, and active-owner state for [GlobalPlaybackManager].
///
/// Owns active video/owner tracking, nestable playback blocks, visible-owner
/// gating, pending focus queue, and related broadcast streams.
class PlaybackFocusCoordinator {
  String? activeVideoId;
  String? activeOwner;
  String? visibleOwner;
  int blockLevel = 0;
  String? blockReason;
  final Map<String, String> pendingFocusRequests = <String, String>{};

  final StreamController<String?> _activeVideoController =
      StreamController<String?>.broadcast();
  final StreamController<String?> _activeOwnerController =
      StreamController<String?>.broadcast();
  final StreamController<bool> _playbackBlockedController =
      StreamController<bool>.broadcast();

  Stream<String?> get activeVideoStream => _activeVideoController.stream;
  Stream<String?> get activeOwnerStream => _activeOwnerController.stream;
  Stream<bool> get playbackBlockedStream => _playbackBlockedController.stream;

  bool get isPlaybackBlocked => blockLevel > 0;

  bool isActive(String videoId) => activeVideoId == videoId;

  bool ownerMatchesVisibleOwner(String owner) {
    final String? visible = visibleOwner;
    if (visible == null) {
      return true;
    }
    return owner == visible || owner.startsWith('$visible/');
  }

  bool controllerBelongsToOwner(String controllerOwner, String owner) {
    return controllerOwner == owner || controllerOwner.startsWith('$owner/');
  }

  bool isDisposingActiveOwner(String owner) {
    if (activeOwner == null) {
      return false;
    }
    return activeOwner == owner || owner.startsWith('$activeOwner/');
  }

  void setVisibleOwner(String owner) {
    visibleOwner = owner;
  }

  void publishActiveVideo(String? videoId) {
    activeVideoId = videoId;
    _activeVideoController.add(videoId);
  }

  void publishActiveOwner(String? owner) {
    activeOwner = owner;
    _activeOwnerController.add(owner);
  }

  void publishActiveSession({
    required String videoId,
    String? owner,
  }) {
    publishActiveVideo(videoId);
    if (owner != null && activeOwner != owner) {
      publishActiveOwner(owner);
    }
  }

  void incrementBlock({String? reason}) {
    blockLevel++;
    blockReason = reason ?? 'manual_block';
    _playbackBlockedController.add(true);
  }

  /// Returns true when playback becomes fully unblocked.
  bool decrementBlock() {
    if (blockLevel <= 0) {
      return false;
    }
    blockLevel--;
    if (blockLevel == 0) {
      blockReason = null;
      _playbackBlockedController.add(false);
      return true;
    }
    return false;
  }

  bool forceUnblock() {
    if (blockLevel <= 0) {
      return false;
    }
    blockLevel = 0;
    blockReason = null;
    _playbackBlockedController.add(false);
    return true;
  }

  /// Clears a stale global block when explicitly switching owners.
  bool clearBlockOnOwnerSwitch() {
    if (blockLevel <= 0) {
      return false;
    }
    blockLevel = 0;
    blockReason = null;
    _playbackBlockedController.add(false);
    return true;
  }

  void queuePendingFocus(String videoId, String owner) {
    pendingFocusRequests[videoId] = owner;
  }

  String? takePendingOwner(String videoId) {
    return pendingFocusRequests.remove(videoId);
  }

  String? pendingOwnerFor(String videoId) {
    return pendingFocusRequests[videoId];
  }

  void clearPendingFocus(String videoId) {
    pendingFocusRequests.remove(videoId);
  }

  int clearPendingFocusForOwner(String owner, {String? exceptVideoId}) {
    final List<String> toRemove = pendingFocusRequests.entries
        .where(
          (MapEntry<String, String> entry) =>
              entry.value == owner && entry.key != exceptVideoId,
        )
        .map((MapEntry<String, String> entry) => entry.key)
        .toList(growable: false);
    for (final String videoId in toRemove) {
      pendingFocusRequests.remove(videoId);
    }
    return toRemove.length;
  }

  int clearAllPendingFocus() {
    final int count = pendingFocusRequests.length;
    pendingFocusRequests.clear();
    return count;
  }

  void resetFocusState() {
    activeVideoId = null;
    activeOwner = null;
    pendingFocusRequests.clear();
    publishActiveVideo(null);
    publishActiveOwner(null);
  }

  Map<String, Object?> debugSnapshot() {
    return <String, Object?>{
      'activeVideoId': activeVideoId,
      'activeOwner': activeOwner,
      'visibleOwner': visibleOwner,
      'blockLevel': blockLevel,
      'blockReason': blockReason,
      'pendingFocusCount': pendingFocusRequests.length,
    };
  }

  void dispose() {
    _activeVideoController.close();
    _activeOwnerController.close();
    _playbackBlockedController.close();
  }
}
