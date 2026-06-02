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
    await controller.seekTo(pending.trimStart);
  }

  void _onPositionChanged() {
    if (!controller.value.isInitialized) {
      return;
    }
    final Duration position = controller.value.position;
    if (position >= pending.trimEnd) {
      controller.seekTo(pending.trimStart);
      if (!controller.value.isPlaying) {
        onTick();
      }
      return;
    }
    if (position < pending.trimStart) {
      controller.seekTo(pending.trimStart);
    }
    onTick();
  }
}
