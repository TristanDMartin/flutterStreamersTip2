import 'dart:async';

import 'package:flutter/foundation.dart';

import 'interaction_diagnostics.dart';

/// Guards the like/scroll hot path from profile/feed/global refresh side effects.
abstract final class LikeInteractionBoundary {
  static int _activeLikeTaps = 0;
  static int _activeUserInteractions = 0;
  static int _activePageScrolls = 0;
  static bool _hasFirstUserInteraction = false;
  static DateTime? _lastGestureEndedAt;
  static final List<VoidCallback> _pendingTasks = <VoidCallback>[];
  static final List<VoidCallback> _afterFirstInteractionTasks =
      <VoidCallback>[];
  static Timer? _flushTimer;
  static Timer? _scrollSettleTimer;

  static const Duration _watchWindowAfterTap = Duration(milliseconds: 300);
  static const Duration _postGestureDeferWindow = Duration(milliseconds: 250);
  static const Duration _scrollSettleDelay = Duration(milliseconds: 200);

  static bool get isActive =>
      _activeLikeTaps > 0 ||
      _activeUserInteractions > 0 ||
      _activePageScrolls > 0 ||
      _isWithinPostTapWatchWindow();

  static bool get shouldDeferHeavyWork =>
      _activeLikeTaps > 0 ||
      _activeUserInteractions > 0 ||
      _activePageScrolls > 0 ||
      _isWithinPostGestureDeferWindow();

  static bool get hasFirstUserInteraction => _hasFirstUserInteraction;

  static void beginLikeTap() {
    markFirstUserInteraction();
    _flushTimer?.cancel();
    _activeLikeTaps++;
    InteractionDiagnostics.logLikeTapStart();
  }

  static void endLikeTap({bool lightweight = false}) {
    if (_activeLikeTaps > 0) {
      _activeLikeTaps--;
    }
    InteractionDiagnostics.logLikeTapEnd();
    _lastGestureEndedAt = DateTime.now();
    if (lightweight) {
      return;
    }
    _schedulePendingFlush();
  }

  static void beginUserInteraction(String reason) {
    markFirstUserInteraction();
    _flushTimer?.cancel();
    _activeUserInteractions++;
  }

  static void endUserInteraction(String reason) {
    if (_activeUserInteractions > 0) {
      _activeUserInteractions--;
    }
    _lastGestureEndedAt = DateTime.now();
    _schedulePendingFlush();
  }

  static void beginPageScroll() {
    markFirstUserInteraction();
    _flushTimer?.cancel();
    _scrollSettleTimer?.cancel();
    _activePageScrolls++;
    InteractionDiagnostics.logPageViewDragStart();
  }

  static void endPageScroll() {
    _scrollSettleTimer?.cancel();
    InteractionDiagnostics.logPageViewScrollSettleStart();
    _scrollSettleTimer = Timer(_scrollSettleDelay, () {
      _scrollSettleTimer = null;
      if (_activePageScrolls > 0) {
        _activePageScrolls--;
      }
      _lastGestureEndedAt = DateTime.now();
      InteractionDiagnostics.logPageViewScrollIdle();
      _schedulePendingFlush();
    });
  }

  static void markFirstUserInteraction() {
    if (_hasFirstUserInteraction) {
      return;
    }
    _hasFirstUserInteraction = true;
    final List<VoidCallback> tasks =
        List<VoidCallback>.from(_afterFirstInteractionTasks);
    _afterFirstInteractionTasks.clear();
    for (final VoidCallback task in tasks) {
      scheduleMicrotask(task);
    }
  }

  static void runAfterFirstInteraction(
    VoidCallback task, {
    Duration fallbackTimeout = const Duration(seconds: 20),
  }) {
    if (_hasFirstUserInteraction) {
      scheduleMicrotask(task);
      return;
    }
    _afterFirstInteractionTasks.add(task);
    Timer(fallbackTimeout, () {
      if (_hasFirstUserInteraction) {
        return;
      }
      markFirstUserInteraction();
    });
  }

  static void runOrQueue(VoidCallback task, {required String reason}) {
    if (!shouldDeferHeavyWork) {
      task();
      return;
    }
    _pendingTasks.add(task);
    _schedulePendingFlush();
  }

  static Future<void> waitUntilIdle({
    Duration pollInterval = const Duration(milliseconds: 50),
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (shouldDeferHeavyWork && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
    }
  }

  static void _schedulePendingFlush() {
    _flushTimer?.cancel();
    final Duration delay = shouldDeferHeavyWork
        ? _postGestureDeferWindow
        : _watchWindowAfterTap;
    _flushTimer = Timer(delay, _flushPendingTasks);
  }

  static void _flushPendingTasks() {
    if (shouldDeferHeavyWork) {
      _schedulePendingFlush();
      return;
    }
    final List<VoidCallback> tasks = List<VoidCallback>.from(_pendingTasks);
    _pendingTasks.clear();
    for (final VoidCallback task in tasks) {
      task();
    }
  }

  static bool _isWithinPostTapWatchWindow() {
    final DateTime? ended = _lastGestureEndedAt;
    if (ended == null) {
      return false;
    }
    return DateTime.now().difference(ended) <= _watchWindowAfterTap;
  }

  static bool _isWithinPostGestureDeferWindow() {
    final DateTime? ended = _lastGestureEndedAt;
    if (ended == null) {
      return false;
    }
    return DateTime.now().difference(ended) <= _postGestureDeferWindow;
  }

  static void reportProfileRebuild({required String source}) {
    if (!shouldDeferHeavyWork) {
      return;
    }
    InteractionDiagnostics.logProfileRebuildDuringLike(source: source);
    if (kDebugMode) {
      debugPrint('PROFILE_REBUILD_DURING_LIKE source=$source');
    }
  }

  static void reportVideoServiceReload({required String source}) {
    if (!shouldDeferHeavyWork) {
      return;
    }
    InteractionDiagnostics.logVideoServiceReloadDuringLike(source: source);
    if (kDebugMode) {
      debugPrint('VIDEO_SERVICE_RELOAD_DURING_LIKE source=$source');
    }
  }

  static void reportFeedRefresh({required String source}) {
    if (!shouldDeferHeavyWork) {
      return;
    }
    InteractionDiagnostics.logFeedRefreshDuringLike(source: source);
    if (kDebugMode) {
      debugPrint('FEED_REFRESH_DURING_LIKE source=$source');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _activeLikeTaps = 0;
    _activeUserInteractions = 0;
    _activePageScrolls = 0;
    _hasFirstUserInteraction = false;
    _lastGestureEndedAt = null;
    _pendingTasks.clear();
    _afterFirstInteractionTasks.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    _scrollSettleTimer?.cancel();
    _scrollSettleTimer = null;
  }
}
