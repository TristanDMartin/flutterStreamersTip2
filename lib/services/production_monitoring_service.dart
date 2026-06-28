import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Production breadcrumbs and non-fatal signals for Crashlytics.
class ProductionMonitoringService {
  ProductionMonitoringService._();

  static ProductionMonitoringService? _instance;
  static ProductionMonitoringService get instance =>
      _instance ??= ProductionMonitoringService._();

  FirebaseCrashlytics? _crashlytics;

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
      await crashlytics.log('http_failure endpoint=$endpoint status=$statusCode');
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
}
