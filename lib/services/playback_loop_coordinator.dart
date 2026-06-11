import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../constants/playback_owners.dart';
import '../utils/playback_teardown.dart';

typedef ShouldLoopVideo = bool Function(String videoId);
typedef CanPlayOwner = bool Function(String owner);
typedef ResolveOwner = String? Function(String videoId);

class _LoopBinding {
  _LoopBinding({
    required this.controller,
    required this.listener,
  });

  final VideoPlayerController controller;
  final VoidCallback listener;
}

/// Enables TikTok-style looping on the active feed controller at the manager
/// layer (native [VideoPlayerController.setLooping] plus a near-end safety seek).
class PlaybackLoopCoordinator {
  PlaybackLoopCoordinator();

  static const Duration nearEndRestartThreshold = Duration(milliseconds: 500);
  static const Duration loopSeekThreshold = Duration(milliseconds: 150);
  static const Duration nativeLoopGracePeriod = Duration(milliseconds: 700);
  static const Duration manualLoopDebounce = Duration(milliseconds: 500);

  final Map<String, _LoopBinding> _bindings = <String, _LoopBinding>{};
  final Set<String> _loopRestartInProgress = <String>{};
  final Map<String, DateTime> _loopEndedDetectedAt = <String, DateTime>{};
  final Map<String, DateTime> _lastManualRestartAt = <String, DateTime>{};

  static Duration clampResumePosition(
    Duration position,
    Duration duration,
  ) {
    if (duration <= Duration.zero) {
      return position;
    }
    if (position >= duration - nearEndRestartThreshold) {
      return Duration.zero;
    }
    return position;
  }

  static bool isNearEndPosition(Duration position, Duration duration) {
    if (duration <= Duration.zero) {
      return false;
    }
    return position >= duration - nearEndRestartThreshold;
  }

  static bool isFeedLoopOwner(String? owner) {
    if (owner == null || owner.isEmpty) {
      return false;
    }
    return owner == PlaybackOwners.home ||
        owner.startsWith('${PlaybackOwners.home}/');
  }

  Future<void> configureForVideo({
    required String videoId,
    required VideoPlayerController controller,
    required ShouldLoopVideo shouldLoop,
    required CanPlayOwner canPlay,
    required ResolveOwner resolveOwner,
    void Function(String message)? log,
  }) async {
    if (!_isControllerReady(controller)) {
      return;
    }
    try {
      await controller.setLooping(true);
      log?.call('LOOP_ENABLED videoId=$videoId');
      log?.call('LOOP_NATIVE_ENABLED videoId=$videoId');
    } catch (e, st) {
      ignorePlaybackTeardownError('playback_loop', e, st);
    }
    attachSafetyListener(
      videoId: videoId,
      controller: controller,
      shouldLoop: shouldLoop,
      canPlay: canPlay,
      resolveOwner: resolveOwner,
      log: log,
    );
  }

  void attachSafetyListener({
    required String videoId,
    required VideoPlayerController controller,
    required ShouldLoopVideo shouldLoop,
    required CanPlayOwner canPlay,
    required ResolveOwner resolveOwner,
    void Function(String message)? log,
  }) {
    detachForVideo(videoId);
    void listener() {
      _onControllerTick(
        videoId: videoId,
        controller: controller,
        shouldLoop: shouldLoop,
        canPlay: canPlay,
        resolveOwner: resolveOwner,
        log: log,
      );
    }

    controller.addListener(listener);
    _bindings[videoId] = _LoopBinding(
      controller: controller,
      listener: listener,
    );
  }

  void detachForVideo(String videoId) {
    final _LoopBinding? binding = _bindings.remove(videoId);
    _loopRestartInProgress.remove(videoId);
    _loopEndedDetectedAt.remove(videoId);
    _lastManualRestartAt.remove(videoId);
    if (binding == null) {
      return;
    }
    try {
      binding.controller.removeListener(binding.listener);
    } catch (e, st) {
      ignorePlaybackTeardownError('playback_loop', e, st);
    }
  }

  void detachAll() {
    for (final String videoId in _bindings.keys.toList()) {
      detachForVideo(videoId);
    }
  }

  void _onControllerTick({
    required String videoId,
    required VideoPlayerController controller,
    required ShouldLoopVideo shouldLoop,
    required CanPlayOwner canPlay,
    required ResolveOwner resolveOwner,
    void Function(String message)? log,
  }) {
    if (_loopRestartInProgress.contains(videoId)) {
      return;
    }
    if (!shouldLoop(videoId)) {
      return;
    }
    if (!_isControllerReady(controller)) {
      return;
    }
    final VideoPlayerValue value = controller.value;
    final Duration position = value.position;
    final Duration duration = value.duration;
    if (duration == Duration.zero) {
      return;
    }
    final bool endedAndStopped = !value.isPlaying && position >= duration;
    final bool stuckPastEnd =
        value.isPlaying && position > duration + nativeLoopGracePeriod;
    if (!endedAndStopped && !stuckPastEnd) {
      _loopEndedDetectedAt.remove(videoId);
      return;
    }
    // Native loop may report isPlaying while stuck past duration; still restart.
    if (value.isPlaying && !stuckPastEnd) {
      log?.call('LOOP_MANUAL_SKIPPED_NATIVE_ACTIVE videoId=$videoId');
      return;
    }
    final bool wasPlaying = value.isPlaying;
    log?.call(
      'LOOP_ENDED_DETECTED videoId=$videoId '
      'position=${position.inMilliseconds} duration=${duration.inMilliseconds}',
    );
    final DateTime now = DateTime.now();
    final DateTime? lastRestartAt = _lastManualRestartAt[videoId];
    if (lastRestartAt != null &&
        now.difference(lastRestartAt) < manualLoopDebounce) {
      log?.call('LOOP_MANUAL_SKIPPED_NATIVE_ACTIVE videoId=$videoId');
      return;
    }
    if (endedAndStopped && !stuckPastEnd) {
      final DateTime firstDetected =
          _loopEndedDetectedAt.putIfAbsent(videoId, () => now);
      if (now.difference(firstDetected) < nativeLoopGracePeriod) {
        log?.call('LOOP_MANUAL_SKIPPED_NATIVE_ACTIVE videoId=$videoId');
        return;
      }
    }
    _loopRestartInProgress.add(videoId);
    unawaited(() async {
      try {
        if (!shouldLoop(videoId) || !_isControllerReady(controller)) {
          return;
        }
        await controller.seekTo(Duration.zero);
        final String? owner = resolveOwner(videoId);
        if (owner != null && canPlay(owner) && isFeedLoopOwner(owner)) {
          await controller.play();
        }
        _lastManualRestartAt[videoId] = DateTime.now();
        log?.call(
          'LOOP_MANUAL_RESTART videoId=$videoId wasPlaying=$wasPlaying '
          'owner=${owner ?? 'unknown'}',
        );
      } catch (e, st) {
        log?.call('LOOP_STOPPED_UNEXPECTEDLY videoId=$videoId reason=$e');
        ignorePlaybackTeardownError('playback_loop', e, st);
      } finally {
        _loopRestartInProgress.remove(videoId);
        _loopEndedDetectedAt.remove(videoId);
      }
    }());
  }

  bool _isControllerReady(VideoPlayerController controller) {
    try {
      return controller.value.isInitialized && !controller.value.hasError;
    } catch (e, st) {
      ignorePlaybackTeardownError('playback_loop', e, st);
      return false;
    }
  }
}
