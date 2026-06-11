import 'package:flutter/foundation.dart';

/// Debug tracing for feed/video listener registration and VideoService loads.
abstract final class VideoFeedDiagnostics {
  static int _homeForYouListenerCount = 0;

  static void logVideoLoadStart({required String source}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('VIDEO_LOAD_START source=$source');
  }

  static void logVideoLoadSkipped({required String reason}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('VIDEO_LOAD_SKIPPED reason=$reason');
  }

  static void logVideoLoadDone({required int videoCount}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('VIDEO_LOAD_DONE count=$videoCount');
  }

  static void logHomeForYouListenerRegistered({required String queryLabel}) {
    if (!kDebugMode) {
      return;
    }
    _homeForYouListenerCount++;
    debugPrint(
      'VIDEO_LISTENER_REGISTERED listener=home_for_you '
      'query=$queryLabel active=$_homeForYouListenerCount',
    );
  }

  static void logHomeForYouListenerDisposed({required String reason}) {
    if (!kDebugMode) {
      return;
    }
    if (_homeForYouListenerCount > 0) {
      _homeForYouListenerCount--;
    }
    debugPrint(
      'VIDEO_LISTENER_DISPOSED listener=home_for_you '
      'reason=$reason active=$_homeForYouListenerCount',
    );
  }
}
