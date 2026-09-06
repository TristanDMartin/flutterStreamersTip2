import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'pending_post.dart';

/// Keeps [controller] playback within [pending] trim bounds.
class PreviewTrimPlayback {
  PreviewTrimPlayback({
    required this.controller,
    required this.pending,
    required this.onTick,
  }) {
    controller.addListener(_onPositionChanged);
  }

  final VideoPlayerController controller;
  PendingPost pending;
  final VoidCallback onTick;

  /// When false, seeks past trim ends are allowed (e.g. while Trim sheet is open).
  bool isEnabled = true;

  /// Prevents seek→listener→seek loops when clamping.
  bool _isSeeking = false;

  void dispose() {
    controller.removeListener(_onPositionChanged);
  }

  void applyPending(PendingPost next) {
    pending = next;
    seekToTrimStart();
  }

  Future<void> seekToTrimStart() async {
    if (!controller.value.isInitialized) {
      return;
    }
    _isSeeking = true;
    try {
      await controller.seekTo(pending.trimStart);
    } finally {
      _isSeeking = false;
    }
  }

  Future<void> _loopToStart({required bool resume}) async {
    _isSeeking = true;
    try {
      await controller.seekTo(pending.trimStart);
      if (resume && !controller.value.isPlaying) {
        await controller.play();
      }
    } finally {
      _isSeeking = false;
      onTick();
    }
  }

  void _onPositionChanged() {
    if (!controller.value.isInitialized || _isSeeking) {
      return;
    }
    if (!isEnabled) {
      onTick();
      return;
    }
    final Duration position = controller.value.position;
    if (position >= pending.trimEnd) {
      final bool resume = controller.value.isPlaying;
      // ignore: unawaited_futures
      _loopToStart(resume: resume);
      return;
    }
    if (position < pending.trimStart) {
      // ignore: unawaited_futures
      _loopToStart(resume: controller.value.isPlaying);
      return;
    }
    onTick();
  }
}
