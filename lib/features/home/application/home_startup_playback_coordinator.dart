import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Deduplicates cold-start / resume playback claims during Home startup.
abstract final class HomeStartupPlaybackCoordinator {
  static String? _lastVideoId;
  static int? _lastIndex;
  static DateTime? _lastClaimAt;
  static bool _sessionStartupClaimed = false;
  static bool _playbackStarted = false;
  static bool _textureVisible = false;
  static bool _pageViewScrollEnabled = false;
  static Timer? _scrollFailOpenTimer;
  static Completer<void>? _textureCompleter;
  static VoidCallback? onPageViewScrollEnabled;
  static VoidCallback? onStartupTextureVisible;
  static VoidCallback? onStartupFeedReady;

  static const Duration dedupeWindow = Duration(milliseconds: 750);
  static const Duration startupClaimTtl = Duration(milliseconds: 1500);
  static const Duration scrollFailOpenDelay = Duration(milliseconds: 1000);

  static bool get hasStartupClaimed => _sessionStartupClaimed;
  static String? get claimedVideoId => _lastVideoId;
  static int? get claimedIndex => _lastIndex;
  static bool get isTextureVisible => _textureVisible;
  static bool get isPageViewScrollEnabled => _pageViewScrollEnabled;

  /// Swipe is never blocked waiting for texture — kept for legacy call sites.
  static bool get isScrollLocked => false;

  /// True while playback has started but index-0 texture is not yet visible.
  static bool get isPlaybackStartupPending =>
      _playbackStarted && !_textureVisible;

  /// Blocks HomeContent rebuild churn between GPM PLAY and texture paint.
  static bool get shouldBlockHomeRebuild => isPlaybackStartupPending;

  static bool get isStartupClaimActive {
    if (!_sessionStartupClaimed) {
      return false;
    }
    final DateTime? claimedAt = _lastClaimAt;
    if (claimedAt == null) {
      return false;
    }
    if (DateTime.now().difference(claimedAt) > startupClaimTtl) {
      releaseClaim(reason: 'startup_claim_ttl');
      return false;
    }
    return true;
  }

  static void beginStartupLock() {
    secureLog('HOME_STARTUP_LOCK');
  }

  static void markControllerReady({
    required String videoId,
    required int index,
  }) {
    if (index != 0) {
      return;
    }
    secureLog(
      'HOME_STARTUP_CONTROLLER_READY videoId=$videoId index=$index',
    );
  }

  static void markPlaybackStarted({required String videoId}) {
    if (_playbackStarted) {
      return;
    }
    _playbackStarted = true;
    secureLog('STARTUP_PLAYBACK_STARTED videoId=$videoId');
    _armScrollFailOpen();
  }

  static void _armScrollFailOpen() {
    if (_pageViewScrollEnabled) {
      return;
    }
    _scrollFailOpenTimer?.cancel();
    _scrollFailOpenTimer = Timer(scrollFailOpenDelay, () {
      enablePageViewScroll(reason: 'texture_timeout_1s');
    });
  }

  static void enablePageViewScroll({required String reason}) {
    if (_pageViewScrollEnabled) {
      return;
    }
    _pageViewScrollEnabled = true;
    _scrollFailOpenTimer?.cancel();
    _scrollFailOpenTimer = null;
    secureLog('PAGEVIEW_SCROLL_ENABLED reason=$reason');
    final VoidCallback? callback = onPageViewScrollEnabled;
    if (callback != null) {
      callback();
    }
  }

  static void markFirstFrame({
    required String videoId,
    required int index,
  }) {
    if (index != 0) {
      secureLog(
        'HOME_STARTUP_FIRST_FRAME_IGNORED videoId=$videoId index=$index',
      );
      return;
    }
    secureLog('HOME_STARTUP_FIRST_FRAME videoId=$videoId index=$index');
  }

  static void markTextureVisible({
    required String videoId,
    required int index,
    bool enableScroll = false,
  }) {
    if (_textureVisible) {
      return;
    }
    if (index != 0) {
      secureLog(
        'HOME_STARTUP_TEXTURE_IGNORED videoId=$videoId index=$index '
        'expected=0',
      );
      return;
    }
    final String? claimed = _lastVideoId;
    if (claimed != null && claimed.isNotEmpty && videoId != claimed) {
      secureLog(
        'HOME_STARTUP_TEXTURE_IGNORED videoId=$videoId claimed=$claimed',
      );
      return;
    }
    _textureVisible = true;
    _scrollFailOpenTimer?.cancel();
    _scrollFailOpenTimer = null;
    if (enableScroll) {
      enablePageViewScroll(reason: 'texture_visible');
    }
    secureLog('HOME_STARTUP_TEXTURE_VISIBLE videoId=$videoId index=$index');
    secureLog('HOME_STARTUP_UNLOCK');
    final Completer<void>? waiter = _textureCompleter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
    final VoidCallback? feedReady = onStartupFeedReady;
    if (feedReady != null) {
      feedReady();
    }
    final VoidCallback? textureCallback = onStartupTextureVisible;
    if (textureCallback != null) {
      textureCallback();
    }
  }

  static Future<void> waitForStartupTextureOrTimeout({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_textureVisible) {
      return;
    }
    _textureCompleter ??= Completer<void>();
    try {
      await _textureCompleter!.future.timeout(timeout);
    } on TimeoutException {
      secureLog(
        '⚠️ HomeStartupPlaybackCoordinator: texture wait expired '
        '(${timeout.inSeconds}s)',
      );
    }
  }

  static void notifyStartupFeedReady() {
    final VoidCallback? callback = onStartupFeedReady;
    if (callback != null) {
      callback();
    }
  }

  static bool shouldSkipResume({
    required String videoId,
    required int index,
    required String reason,
    bool isStartupClaim = false,
  }) {
    final DateTime now = DateTime.now();
    if (_lastVideoId == videoId &&
        _lastIndex == index &&
        _lastClaimAt != null &&
        now.difference(_lastClaimAt!) < dedupeWindow) {
      secureLog(
        'HOME_STARTUP_PLAYBACK_SKIPPED_DUPLICATE '
        'reason=$reason video=$videoId index=$index',
      );
      return true;
    }
    if (isStartupClaim && _sessionStartupClaimed) {
      secureLog(
        'HOME_STARTUP_PLAYBACK_SKIPPED_ALREADY_CLAIMED reason=$reason',
      );
      return true;
    }
    return false;
  }

  static void recordClaim({
    required String videoId,
    required int index,
    bool isStartupClaim = false,
  }) {
    _lastVideoId = videoId;
    _lastIndex = index;
    _lastClaimAt = DateTime.now();
    if (isStartupClaim && !_sessionStartupClaimed) {
      _sessionStartupClaimed = true;
      secureLog(
        'HOME_STARTUP_PLAYBACK_CLAIMED_ONCE video=$videoId index=$index',
      );
    }
  }

  static void releaseClaim({required String reason}) {
    if (!_sessionStartupClaimed && _lastVideoId == null && _lastIndex == null) {
      return;
    }
    secureLog(
      'HOME_STARTUP_PLAYBACK_CLAIM_RELEASED reason=$reason '
      'video=${_lastVideoId ?? 'none'} index=${_lastIndex ?? -1}',
    );
    _lastVideoId = null;
    _lastIndex = null;
    _lastClaimAt = null;
    _sessionStartupClaimed = false;
    _playbackStarted = false;
    _textureVisible = false;
    _pageViewScrollEnabled = false;
    _scrollFailOpenTimer?.cancel();
    _scrollFailOpenTimer = null;
  }

  /// Clears session dedupe state on cold app open (also used in tests).
  static void resetSession() {
    _lastVideoId = null;
    _lastIndex = null;
    _lastClaimAt = null;
    _sessionStartupClaimed = false;
    _playbackStarted = false;
    _textureVisible = false;
    _pageViewScrollEnabled = false;
    _scrollFailOpenTimer?.cancel();
    _scrollFailOpenTimer = null;
    _textureCompleter = null;
    onPageViewScrollEnabled = null;
    onStartupTextureVisible = null;
    onStartupFeedReady = null;
  }

  @visibleForTesting
  static void resetForTest() => resetSession();
}
