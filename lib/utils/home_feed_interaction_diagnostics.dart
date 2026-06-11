import 'package:flutter/foundation.dart';

/// Debug-only logs for like/scroll/bottom-nav interaction regressions.
abstract final class HomeFeedInteractionDiagnostics {
  static void logLikeTapStart(String videoId) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_TAP_START video=$videoId');
  }

  static void logLikeTapEnd(String videoId) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_TAP_END video=$videoId');
  }

  static void logHomeScrollState({
    required String physicsLabel,
    required bool canScroll,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'HOME_SCROLL_STATE physics=$physicsLabel canScroll=$canScroll',
    );
  }

  static void logBottomNavTap({
    required int index,
    required bool isInteractionBlocked,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'BOTTOM_NAV_TAP index=$index blocked=$isInteractionBlocked',
    );
  }

  static void logOverlayState({
    required bool isAbsorbing,
    required bool isIgnoring,
    required bool overlayVisible,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'OVERLAY_STATE absorbing=$isAbsorbing '
      'ignoring=$isIgnoring visible=$overlayVisible',
    );
  }

  static void logPageControllerState({
    required bool hasClients,
    required double? page,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'PAGE_CONTROLLER_STATE hasClients=$hasClients page=$page',
    );
  }

  static void logLikeTap(String videoId) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_TAP video=$videoId');
  }

  static void logFeedReplaceAttempt({
    required String reason,
    required int incomingCount,
    required int currentCount,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'FEED_REPLACE_ATTEMPT reason=$reason '
      'incoming=$incomingCount current=$currentCount',
    );
  }

  static void logFeedReplaceBlocked({required String reason}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('FEED_REPLACE_BLOCKED reason=$reason');
  }

  static void logPageViewItemCount({
    required int count,
    required int activeIndex,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGEVIEW_ITEM_COUNT count=$count activeIndex=$activeIndex');
  }

  static void logFeedReplaceApplied({
    required String reason,
    required int resultCount,
    int? msSinceScroll,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'FEED_REPLACE_APPLIED reason=$reason result=$resultCount '
      'ms_since_scroll=${msSinceScroll ?? 'n/a'}',
    );
  }

  static void logBgRefreshPhase(
    String phase, {
    int? ms,
    String? reason,
  }) {
    if (!kDebugMode) {
      return;
    }
    final String timing = ms != null ? ' ms=$ms' : '';
    final String extra = reason != null ? ' reason=$reason' : '';
    debugPrint('BG_REFRESH_$phase$timing$extra');
  }

  static void logPageChanged({
    required String source,
    required int index,
    required int ms,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGE_CHANGED source=$source index=$index ms=$ms');
  }

  static void logPageAnimate({
    required String phase,
    required int targetIndex,
    required int ms,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGE_ANIMATE_$phase target=$targetIndex ms=$ms');
  }
}
