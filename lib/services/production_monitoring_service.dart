import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

/// Production breadcrumbs and launch SLO signals for Crashlytics / Analytics.
class ProductionMonitoringService {
  ProductionMonitoringService._();

  static ProductionMonitoringService? _instance;
  static ProductionMonitoringService get instance =>
      _instance ??= ProductionMonitoringService._();

  FirebaseCrashlytics? _crashlytics;
  int _feedErrorCount = 0;
  int _firstFrameCount = 0;
  int _badIndexProxyCount = 0;
  bool _coldFirstFrameReported = false;

  FirebaseCrashlytics? get _crashlyticsOrNull {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return _crashlytics ??= FirebaseCrashlytics.instance;
  }

  Future<void> recordStartupHealth({
    required bool firebaseReady,
    required bool appCheckEnabled,
    required bool appCheckReady,
    String? appCheckDetail,
  }) async {
    final FirebaseCrashlytics? crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) {
      return;
    }
    try {
      await crashlytics.setCustomKey('startup_firebase_ready', firebaseReady);
      await crashlytics.setCustomKey(
        'startup_app_check_enabled',
        appCheckEnabled,
      );
      await crashlytics.setCustomKey('startup_app_check_ready', appCheckReady);
      await crashlytics.log(
        'startup_health firebase=$firebaseReady '
        'app_check_enabled=$appCheckEnabled app_check_ready=$appCheckReady',
      );
      if (appCheckEnabled && !appCheckReady && appCheckDetail != null) {
        await crashlytics.log('app_check_startup: $appCheckDetail');
      }
    } catch (e) {
      debugPrint('ProductionMonitoringService.recordStartupHealth: $e');
    }
  }

  Future<void> recordReleaseConfigHealth({
    required bool isGiphyConfigured,
    required bool isBillingVerifyConfigured,
    required List<String> missingKeys,
  }) async {
    final FirebaseCrashlytics? crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) {
      return;
    }
    try {
      await crashlytics.setCustomKey(
        'release_giphy_configured',
        isGiphyConfigured,
      );
      await crashlytics.setCustomKey(
        'release_billing_verify_configured',
        isBillingVerifyConfigured,
      );
      await crashlytics.setCustomKey(
        'release_missing_defines',
        missingKeys.join(','),
      );
      await crashlytics.log(
        'release_config giphy=$isGiphyConfigured '
        'billing=$isBillingVerifyConfigured missing=${missingKeys.join(",")}',
      );
    } catch (e) {
      debugPrint('ProductionMonitoringService.recordReleaseConfigHealth: $e');
    }
  }

  Future<void> logBreadcrumb(String message) async {
    final FirebaseCrashlytics? crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) {
      return;
    }
    try {
      await crashlytics.log(message);
    } catch (e) {
      debugPrint('ProductionMonitoringService.logBreadcrumb: $e');
    }
  }

  Future<void> recordHttpFailure({
    required String endpoint,
    required int statusCode,
  }) async {
    final FirebaseCrashlytics? crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) {
      return;
    }
    try {
      await crashlytics.setCustomKey('last_http_endpoint', endpoint);
      await crashlytics.setCustomKey('last_http_status', statusCode);
      await crashlytics.log(
        'http_failure endpoint=$endpoint status=$statusCode',
      );
    } catch (e) {
      debugPrint('ProductionMonitoringService.recordHttpFailure: $e');
    }
  }

  Future<void> recordAppCheckBlocked(String surface) async {
    final FirebaseCrashlytics? crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) {
      return;
    }
    try {
      await crashlytics.setCustomKey('app_check_blocked_surface', surface);
      await crashlytics.log('app_check_blocked surface=$surface');
    } catch (e) {
      debugPrint('ProductionMonitoringService.recordAppCheckBlocked: $e');
    }
  }

  /// Warm/cold first-frame timing for the launch SLO dashboard.
  /// First call in a process is treated as cold-session first frame.
  Future<void> recordFirstFrame({
    required String videoId,
    required String source,
    int? activationToFirstFrameMs,
    bool isColdSession = false,
  }) async {
    _firstFrameCount += 1;
    final bool treatAsCold = isColdSession || !_coldFirstFrameReported;
    if (treatAsCold) {
      _coldFirstFrameReported = true;
    }
    final FirebaseCrashlytics? crashlytics = _crashlyticsOrNull;
    try {
      if (crashlytics != null) {
        await crashlytics.setCustomKey(
          'slo_first_frame_count',
          _firstFrameCount,
        );
        if (activationToFirstFrameMs != null) {
          await crashlytics.setCustomKey(
            'slo_last_first_frame_ms',
            activationToFirstFrameMs,
          );
        }
        await crashlytics.log(
          'slo_first_frame source=$source '
          'ms=${activationToFirstFrameMs ?? 'n/a'} '
          'cold=$treatAsCold video=${_shortId(videoId)}',
        );
      }
      await AnalyticsService.instance.trackEvent(
        'slo_first_frame',
        parameters: <String, Object>{
          'source': source,
          if (activationToFirstFrameMs != null)
            'activation_to_first_frame_ms': activationToFirstFrameMs,
          'is_cold_session': treatAsCold ? 1 : 0,
        },
      );
      if (treatAsCold) {
        await AnalyticsService.instance.trackEvent(
          'slo_cold_first_frame',
          parameters: <String, Object>{
            'source': source,
            if (activationToFirstFrameMs != null)
              'activation_to_first_frame_ms': activationToFirstFrameMs,
          },
        );
      }
    } catch (e) {
      debugPrint('ProductionMonitoringService.recordFirstFrame: $e');
    }
  }

  /// Feed playback / load failures for feed error-rate SLO.
  Future<void> recordFeedError({
    required String reason,
    String? videoId,
  }) async {
    _feedErrorCount += 1;
    final bool isBadIndexProxy = reason.contains('first_frame_watchdog') ||
        reason.contains('surface_recovery') ||
        reason.contains('BAD_INDEX');
    if (isBadIndexProxy) {
      _badIndexProxyCount += 1;
    }
    final FirebaseCrashlytics? crashlytics = _crashlyticsOrNull;
    try {
      if (crashlytics != null) {
        await crashlytics.setCustomKey('slo_feed_error_count', _feedErrorCount);
        await crashlytics.setCustomKey(
          'slo_bad_index_proxy_count',
          _badIndexProxyCount,
        );
        await crashlytics.setCustomKey('slo_last_feed_error', reason);
        await crashlytics.log(
          'slo_feed_error reason=$reason video=${_shortId(videoId ?? '')}',
        );
        if (isBadIndexProxy) {
          await crashlytics.log('slo_bad_index_proxy reason=$reason');
        }
      }
      final String safeReason =
          reason.length > 80 ? reason.substring(0, 80) : reason;
      await AnalyticsService.instance.trackEvent(
        'slo_feed_error',
        parameters: <String, Object>{
          'reason': safeReason,
          'is_bad_index_proxy': isBadIndexProxy ? 1 : 0,
        },
      );
      if (isBadIndexProxy) {
        await AnalyticsService.instance.trackEvent(
          'slo_bad_index_proxy',
          parameters: <String, Object>{
            'reason': safeReason,
          },
        );
      }
    } catch (e) {
      debugPrint('ProductionMonitoringService.recordFeedError: $e');
    }
  }

  String _shortId(String id) {
    if (id.length <= 12) {
      return id;
    }
    return id.substring(0, 12);
  }
}
