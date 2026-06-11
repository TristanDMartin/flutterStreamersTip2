import 'package:video_player/video_player.dart';

import 'playback_controller_pool.dart';
import 'playback_focus_coordinator.dart';

/// Lightweight playback telemetry and pool lifecycle logs.
class PlaybackTelemetryCoordinator {
  const PlaybackTelemetryCoordinator();

  void logTelemetry({
    required PlaybackFocusCoordinator focus,
    required String event,
    String? videoId,
    String? owner,
    String? reason,
    double? volume,
    void Function(String message)? log,
  }) {
    log?.call(
      '🎧 PlaybackTelemetry: event=$event video=$videoId owner=$owner '
      'blocked=${focus.blockLevel} reason=${reason ?? focus.blockReason} '
      'volume=$volume',
    );
  }

  void logControllerEvent({
    required String event,
    required String videoId,
    required PlaybackControllerPool pool,
    required Set<String> pinnedVideoIds,
    required Set<String> initializingControllers,
    required Map<String, DateTime> cooldownUntil,
    int? controllerId,
    String? reason,
    required void Function({String? reason}) onPoolSnapshot,
    void Function(String message)? log,
  }) {
    final VideoPlayerController? controller = pool[videoId];
    final String controllerIdStr = controllerId?.toString() ??
        controller?.hashCode.toString() ??
        'unknown';
    final String isPinned =
        pinnedVideoIds.contains(videoId) ? 'pinned' : 'unpinned';
    final String isInitializing =
        initializingControllers.contains(videoId) ? 'initializing' : 'ready';
    final String inCooldown =
        cooldownUntil.containsKey(videoId) ? 'cooldown' : 'active';
    log?.call(
      '🎬 CONTROLLER_LIFECYCLE: event=$event videoId=$videoId '
      'controllerId=$controllerIdStr $isPinned $isInitializing $inCooldown '
      'reason=${reason ?? "N/A"}',
    );
    _emitPoolAuditIfNeeded(
      event: event,
      videoId: videoId,
      reason: reason,
      log: log,
    );
    if (event.contains('CREATE') ||
        event.contains('DISPOSE') ||
        event.contains('ACQUIRE') ||
        event.contains('RELEASE') ||
        event.contains('COOLDOWN') ||
        event.contains('REGISTER') ||
        event.contains('EVICT')) {
      onPoolSnapshot(reason: event);
    }
  }

  void logPoolAudit({
    required String action,
    required String videoId,
    required int poolSize,
    String? reason,
    void Function(String message)? log,
  }) {
    log?.call(
      'POOL_AUDIT action=$action videoId=$videoId poolSize=$poolSize '
      'reason=${reason ?? 'n/a'}',
    );
  }

  void _emitPoolAuditIfNeeded({
    required String event,
    required String videoId,
    String? reason,
    void Function(String message)? log,
  }) {
    String? action;
    if (event.contains('REGISTER') || event.contains('CREATE')) {
      action = 'created';
    } else if (event.contains('DISPOSED') || event.contains('DISPOSE')) {
      action = 'disposed';
    } else if (event.contains('START_COOLDOWN')) {
      action = 'cooldownStarted';
    } else if (event.contains('COOLDOWN_CANCELLED')) {
      action = 'cooldownCancelled';
    }
    if (action == null) {
      return;
    }
    log?.call(
      'POOL_AUDIT action=$action videoId=$videoId reason=${reason ?? event}',
    );
  }

  void logPoolSnapshot({
    required PlaybackControllerPool pool,
    required Set<String> pinnedVideoIds,
    required Set<String> initializingControllers,
    required Map<String, DateTime> cooldownUntil,
    String? reason,
    void Function(String message)? log,
  }) {
    final String snapshot = pool.keys
        .map((String videoId) => pool.snapshotTokenFor(videoId))
        .join(', ');
    final int livePinnedCount = pinnedVideoIds
        .where((String videoId) => pool.containsKey(videoId))
        .length;
    log?.call(
      '📊 POOL_SNAPSHOT: size=${pool.length} pinned=$livePinnedCount '
      'init=${initializingControllers.length} cooldown=${cooldownUntil.length} '
      'reason=${reason ?? "periodic"} [$snapshot]',
    );
  }
}
