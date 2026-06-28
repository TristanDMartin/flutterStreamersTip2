import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Defers non-critical Home startup work until the first feed frame renders.
class HomeFirstFrameGate {
  HomeFirstFrameGate._();
  static final HomeFirstFrameGate instance = HomeFirstFrameGate._();

  bool _firstFrameRendered = false;
  bool _firstFramePlaybackStarted = false;
  bool _backgroundWorkResumed = false;
  final List<VoidCallback> _pendingTasks = <VoidCallback>[];
  final List<Completer<void>> _playbackWaiters = <Completer<void>>[];
  Completer<void>? _firstFrameCompleter;
  Timer? _fallbackTimer;

  bool get isFirstFrameRendered => _firstFrameRendered;
  bool get isFirstFramePlaybackStarted => _firstFramePlaybackStarted;

  void armFallbackUnblock({Duration delay = const Duration(seconds: 8)}) {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(delay, () {
      if (_firstFramePlaybackStarted) {
        return;
      }
      secureLog(
        '⚠️ HomeFirstFrameGate: fallback timer elapsed without playback frame '
        '(${delay.inSeconds}s)',
      );
    });
  }

  void markStartupPlaybackReady({
    required String videoId,
    String source = 'startup_ready',
  }) {
    if (videoId.isEmpty) {
      return;
    }
    secureLog(
      'STARTUP_PLAYBACK_READY videoId=$videoId source=$source',
    );
    markFirstFrameRendered(videoId: videoId, source: source);
  }

  void markFirstFrameRendered({String? videoId, String source = 'playback'}) {
    final bool hasVideoId = videoId != null && videoId.isNotEmpty;
    if (!hasVideoId) {
      if (source == 'fallback_timeout' || source == 'wait_timeout') {
        secureLog(
          '⚠️ HomeFirstFrameGate: ignoring first frame without videoId '
          '(source=$source)',
        );
        return;
      }
      secureLog(
        '⚠️ HomeFirstFrameGate: markFirstFrameRendered without videoId '
        '(source=$source)',
      );
      return;
    }
    if (!_firstFramePlaybackStarted) {
      _firstFramePlaybackStarted = true;
      _firstFrameRendered = true;
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      secureLog(
        '✅ HomeFirstFrameGate: first frame ($source) video=$videoId',
      );
      secureLog(
        'FIRST_FRAME_PLAYBACK_STARTED video=$videoId source=$source',
      );
      if (_firstFrameCompleter != null && !_firstFrameCompleter!.isCompleted) {
        _firstFrameCompleter!.complete();
      }
      for (final Completer<void> waiter in _playbackWaiters) {
        if (!waiter.isCompleted) {
          waiter.complete();
        }
      }
      _playbackWaiters.clear();
      final List<VoidCallback> tasks = List<VoidCallback>.from(_pendingTasks);
      _pendingTasks.clear();
      if (tasks.isNotEmpty) {
        unawaited(_drainTasks(tasks));
      }
      return;
    }
    if (!_firstFrameRendered) {
      _firstFrameRendered = true;
    }
  }

  Future<void> _drainTasks(List<VoidCallback> tasks) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final VoidCallback task in tasks) {
      try {
        task();
      } catch (error, stackTrace) {
        secureLog('⚠️ HomeFirstFrameGate: deferred task failed: $error');
        secureLog('Stack trace: $stackTrace');
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  void runAfterFirstFrame(VoidCallback task) {
    if (_firstFrameRendered) {
      scheduleMicrotask(task);
      return;
    }
    _pendingTasks.add(task);
  }

  Future<void> waitForFirstFrameOrTimeout({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_firstFrameRendered) {
      return;
    }
    _firstFrameCompleter ??= Completer<void>();
    try {
      await _firstFrameCompleter!.future.timeout(timeout);
    } on TimeoutException {
      secureLog(
        '⚠️ HomeFirstFrameGate: waitForFirstFrameOrTimeout expired '
        '(${timeout.inSeconds}s)',
      );
    }
  }

  Future<void> waitForFirstFramePlaybackOrTimeout({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_firstFramePlaybackStarted) {
      return;
    }
    final Completer<void> waiter = Completer<void>();
    _playbackWaiters.add(waiter);
    try {
      await waiter.future.timeout(timeout);
    } on TimeoutException {
      secureLog(
        '⚠️ HomeFirstFrameGate: playback first frame wait expired '
        '(${timeout.inSeconds}s)',
      );
      _playbackWaiters.remove(waiter);
    }
  }

  /// Defers startup background work until first-frame playback has started.
  Future<void> runAfterFirstFramePlayback(Future<void> Function() work) async {
    if (!_firstFramePlaybackStarted) {
      if (!_backgroundWorkResumed) {
        secureLog('STARTUP_BACKGROUND_WORK_DEFERRED');
      }
      await waitForFirstFramePlaybackOrTimeout();
    }
    if (!_firstFramePlaybackStarted) {
      secureLog(
        '⚠️ HomeFirstFrameGate: background work skipped — no playback frame',
      );
      return;
    }
    if (!_backgroundWorkResumed) {
      _backgroundWorkResumed = true;
      secureLog('STARTUP_BACKGROUND_WORK_RESUMED_AFTER_FIRST_FRAME');
    }
    await work();
  }

  void resetForColdStart() {
    _firstFrameRendered = false;
    _firstFramePlaybackStarted = false;
    _backgroundWorkResumed = false;
    _pendingTasks.clear();
    for (final Completer<void> waiter in _playbackWaiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _playbackWaiters.clear();
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _firstFrameCompleter = null;
  }

  @visibleForTesting
  void resetForTest() {
    resetForColdStart();
  }
}
