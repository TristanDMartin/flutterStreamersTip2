import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Defers non-critical Home startup work until the first feed frame renders.
class HomeFirstFrameGate {
  HomeFirstFrameGate._();
  static final HomeFirstFrameGate instance = HomeFirstFrameGate._();

  bool _firstFrameRendered = false;
  final List<VoidCallback> _pendingTasks = <VoidCallback>[];
  Completer<void>? _firstFrameCompleter;
  Timer? _fallbackTimer;

  bool get isFirstFrameRendered => _firstFrameRendered;

  void armFallbackUnblock({Duration delay = const Duration(seconds: 4)}) {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(delay, () {
      if (_firstFrameRendered) {
        return;
      }
      secureLog(
        '⚠️ HomeFirstFrameGate: fallback unblock after ${delay.inSeconds}s',
      );
      markFirstFrameRendered(source: 'fallback_timeout');
    });
  }

  void markFirstFrameRendered({String? videoId, String source = 'playback'}) {
    if (_firstFrameRendered) {
      return;
    }
    _firstFrameRendered = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    secureLog(
      '✅ HomeFirstFrameGate: first frame ($source) video=${videoId ?? 'unknown'}',
    );
    if (_firstFrameCompleter != null && !_firstFrameCompleter!.isCompleted) {
      _firstFrameCompleter!.complete();
    }
    final List<VoidCallback> tasks =
        List<VoidCallback>.from(_pendingTasks);
    _pendingTasks.clear();
    if (tasks.isEmpty) {
      return;
    }
    unawaited(_drainTasks(tasks));
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
      markFirstFrameRendered(source: 'wait_timeout');
    }
  }
}
