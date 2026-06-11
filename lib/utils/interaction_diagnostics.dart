import 'package:flutter/foundation.dart';

/// Debug-only interaction tracing (likes, profile, home, gamification, nav).
abstract final class InteractionDiagnostics {
  static void logLikeTapStart() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_TAP_START');
  }

  static void logDoubleTapStart({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('DOUBLE_TAP_START video=$videoId');
  }

  static void logDoubleTapUiDone({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('DOUBLE_TAP_UI_DONE video=$videoId');
  }

  static void logDoubleTapBackgroundSyncStart({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('DOUBLE_TAP_BACKGROUND_SYNC_START video=$videoId');
  }

  static void logDoubleTapBackgroundSyncDone({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('DOUBLE_TAP_BACKGROUND_SYNC_DONE video=$videoId');
  }

  static void logLikeTapEnd() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_TAP_END');
  }

  static void logLikeOptimisticDone({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_OPTIMISTIC_DONE video=$videoId');
  }

  static void logLikeFirestoreStart({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_FIRESTORE_START video=$videoId');
  }

  static void logLikeFirestoreQueued({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_FIRESTORE_QUEUED video=$videoId');
  }

  static void logLikeFirestoreDone({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_FIRESTORE_DONE video=$videoId');
  }

  static void logLikeGamificationStart({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_GAMIFICATION_START video=$videoId');
  }

  static void logLikeGamificationDone({required String videoId}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKE_GAMIFICATION_DONE video=$videoId');
  }

  static void logLikeActionStart() => logLikeTapStart();

  static void logLikeActionEnd() => logLikeTapEnd();

  static void logProfileRebuildDuringLike({required String source}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PROFILE_REBUILD_DURING_LIKE source=$source');
    debugPrint('PROFILE_REBUILD_DURING_DOUBLE_TAP source=$source');
  }

  static void logVideoServiceReloadDuringLike({required String source}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('VIDEO_SERVICE_RELOAD_DURING_LIKE source=$source');
    debugPrint('VIDEO_SERVICE_RELOAD_DURING_DOUBLE_TAP source=$source');
  }

  static void logLikedVideosReloadDuringLike({required String source}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('LIKED_VIDEOS_RELOAD_DURING_DOUBLE_TAP source=$source');
  }

  static void logFeedRefreshDuringLike({required String source}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('FEED_REFRESH_DURING_LIKE source=$source');
  }

  static void logPageViewBlockedDuringLike() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGEVIEW_BLOCKED_DURING_LIKE');
    debugPrint('PAGEVIEW_BLOCKED_DURING_DOUBLE_TAP');
  }

  static void logPageViewDragStart() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGEVIEW_DRAG_START');
  }

  static void logPageViewDragAccepted() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGEVIEW_DRAG_ACCEPTED');
  }

  static void logPageViewScrollSettleStart() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGEVIEW_SCROLL_SETTLE_START');
  }

  static void logPageViewScrollIdle() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGEVIEW_SCROLL_IDLE');
  }

  static void logRefreshSkipped({required String reason}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('REFRESH_SKIPPED reason=$reason');
  }

  static void logRefreshExecuted({
    required String source,
    required int feedIndex,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('REFRESH_EXECUTED source=$source index=$feedIndex');
  }

  static void logPageChangedDeferred({required String reason}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PAGE_CHANGED_DEFERRED reason=$reason');
  }

  static void logOverlayHeartRemoved() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('OVERLAY_HEART_REMOVED');
  }

  static void logGestureAbsorberActive({required String source}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('GESTURE_ABSORBER_ACTIVE source=$source');
  }

  static void logBottomNavBlockedDuringLike() {
    if (!kDebugMode) {
      return;
    }
    debugPrint('BOTTOM_NAV_BLOCKED_DURING_LIKE');
  }

  static void logProfileNotify({required String reason}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PROFILE_NOTIFY reason=$reason');
  }

  static void logProfileRebuild({required String source}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PROFILE_REBUILD source=$source');
  }

  static void logProfileRebuildTrigger({required String source}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PROFILE_REBUILD_TRIGGER source=$source');
  }

  static void logProfileNotifyListeners({required String reason}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('PROFILE_NOTIFY_LISTENERS reason=$reason');
  }

  static void logUserDocChanged({
    required List<String> changedFields,
    required bool notifiesProfile,
  }) {
    if (!kDebugMode) {
      return;
    }
    final String fields =
        changedFields.isEmpty ? '(none)' : changedFields.join(',');
    debugPrint(
      'USER_DOC_CHANGED fields=$fields notifiesProfile=$notifiesProfile',
    );
  }

  static void logHomeRebuild({
    required int videoCount,
    required String feed,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('HOME_REBUILD feed=$feed videos=$videoCount');
  }

  static void logGamificationEventStart({required String type}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('GAMIFICATION_EVENT_START type=$type');
  }

  static void logGamificationEventEnd({required String type}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('GAMIFICATION_EVENT_END type=$type');
  }

  static void logBottomNavTap({
    required int index,
    required bool blocked,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('BOTTOM_NAV_TAP index=$index blocked=$blocked');
  }

  static void logBlockedFeedReplacement({
    required int incomingCount,
    required int currentCount,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'BLOCKED_FEED_REPLACEMENT incoming=$incomingCount '
      'current=$currentCount',
    );
  }

  static void logRealtimeFeedBuild({
    required int docCount,
    required int builtCount,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('REALTIME_FEED_BUILD docs=$docCount built=$builtCount');
    if (docCount >= 3 && builtCount < docCount ~/ 2) {
      debugPrint(
        '⚠️ REALTIME_FEED_BUILD: few playable videos from snapshot '
        '(docs=$docCount built=$builtCount)',
      );
    }
  }
}
