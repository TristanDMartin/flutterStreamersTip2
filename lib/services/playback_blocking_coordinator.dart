import 'playback_focus_coordinator.dart';

/// Nestable playback blocking (camera, modals, tab switches).
class PlaybackBlockingCoordinator {
  const PlaybackBlockingCoordinator();

  void block({
    required PlaybackFocusCoordinator focus,
    required void Function() pauseAll,
    required void Function(String event, {String? reason}) onTelemetry,
    String? reason,
    void Function(String message)? log,
  }) {
    focus.incrementBlock(reason: reason);
    log?.call(
      '🚫 PlaybackManager: BLOCKED (level: ${focus.blockLevel}) - '
      'reason: ${focus.blockReason}',
    );
    onTelemetry('block', reason: focus.blockReason);
    pauseAll();
  }

  void unblock({
    required PlaybackFocusCoordinator focus,
    required void Function(String event, {String? reason}) onTelemetry,
    void Function(String message)? log,
  }) {
    if (focus.blockLevel > 0) {
      final bool fullyUnblocked = focus.decrementBlock();
      log?.call('✅ PlaybackManager: UNBLOCKED (level: ${focus.blockLevel})');
      onTelemetry('unblock');
      if (fullyUnblocked) {
        log?.call('🎯 PlaybackManager: FULLY UNBLOCKED - ready for playback');
      }
    } else {
      log?.call(
        '⚠️ PlaybackManager: unblock() called but blockLevel is already 0',
      );
    }
  }
}
