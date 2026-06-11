import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../services/production_logging_service.dart';

final ProductionLoggingService _playbackLog = ProductionLoggingService();

/// True when [controller] is alive and initialized for playback.
bool isVideoControllerReady(VideoPlayerController? controller) {
  return readVideoControllerOr(
    controller,
    (VideoPlayerValue value) => value.isInitialized && !value.hasError,
    false,
    context: 'isVideoControllerReady',
  );
}

/// True when [controller] is non-null and its [VideoPlayerValue] can be read.
bool isVideoControllerAlive(
  VideoPlayerController? controller, {
  bool logDisposed = true,
}) {
  if (controller == null) {
    return false;
  }
  try {
    void noop() {}
    controller.addListener(noop);
    controller.removeListener(noop);
    controller.value;
    return true;
  } catch (e) {
    if (logDisposed) {
      _playbackLog.debug(
        'Disposed video controller',
        error: e,
        tag: 'VideoPlayback',
      );
    }
    return false;
  }
}

/// Reads [read] when the controller is alive; otherwise returns [orElse].
T readVideoControllerOr<T>(
  VideoPlayerController? controller,
  T Function(VideoPlayerValue value) read,
  T orElse, {
  String? context,
}) {
  if (!isVideoControllerAlive(controller)) {
    return orElse;
  }
  try {
    return read(controller!.value);
  } catch (e, stack) {
    logPlaybackSwallowed(context ?? 'readVideoControllerOr', e, stack);
    return orElse;
  }
}

void logPlaybackSwallowed(String context, Object error, [StackTrace? stack]) {
  assert(() {
    debugPrint('VideoPlayback [$context]: $error');
    return true;
  }());
  if (kDebugMode) {
    _playbackLog.debug(
      'Swallowed playback error: $context',
      error: error,
      stackTrace: stack,
      tag: 'VideoPlayback',
    );
  } else {
    _playbackLog.warn(
      'Swallowed playback error: $context',
      error: error,
      stackTrace: stack,
      tag: 'VideoPlayback',
    );
  }
}
