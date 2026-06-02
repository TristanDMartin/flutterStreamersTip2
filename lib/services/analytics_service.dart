import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';

class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();

  AnalyticsService._();

  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;
  static bool _isInitialized = false;
  static bool _initializationAttempted = false;
  static bool _crashHandlersInstalled = false;

  bool get isInitialized => _isInitialized;

  // Safe static getter that doesn't trigger singleton creation
  static bool get isReady => _isInitialized;

  /// Crash handlers only — call from [main] after Firebase init, before runApp.
  Future<void> installCrashHandlers() async {
    if (_crashHandlersInstalled || Firebase.apps.isEmpty) {
      return;
    }
    try {
      _crashlytics ??= FirebaseCrashlytics.instance;
      await _crashlytics!.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError = (FlutterErrorDetails details) {
        if (_isNonFatalFlutterLayoutError(details)) {
          _crashlytics?.recordFlutterError(details, fatal: false);
        } else {
          _crashlytics?.recordFlutterFatalError(details);
        }
        if (kDebugMode) {
          FlutterError.presentError(details);
        }
      };
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };
      _crashHandlersInstalled = true;
      debugPrint('✅ Crashlytics handlers installed');
    } catch (e) {
      debugPrint('❌ installCrashHandlers failed: $e');
    }
  }

  bool _isNonFatalFlutterLayoutError(FlutterErrorDetails details) {
    final String message = details.exceptionAsString();
    return message.contains('A RenderFlex overflowed') ||
        message.contains('Incorrect use of ParentDataWidget') ||
        message.contains('Competing ParentDataWidgets');
  }

  // Initialize analytics
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('✅ Analytics service already initialized');
      return;
    }

    if (_initializationAttempted) {
      debugPrint('⚠️ Analytics initialization already attempted, skipping');
      return;
    }

    _initializationAttempted = true;

    try {
      int attempts = 0;
      while (Firebase.apps.isEmpty && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 50));
        attempts++;
      }

      if (Firebase.apps.isEmpty) {
        debugPrint(
            '⚠️ Firebase not ready after 1 second, skipping analytics initialization');
        return;
      }

      await Future.delayed(const Duration(milliseconds: 200));

      try {
        _analytics = FirebaseAnalytics.instance;
        _crashlytics ??= FirebaseCrashlytics.instance;
      } catch (e) {
        debugPrint('❌ Error accessing Firebase instances: $e');
        return;
      }

      await _crashlytics!.setCrashlyticsCollectionEnabled(true);
      await installCrashHandlers();

      _isInitialized = true;
      debugPrint('✅ Analytics service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing analytics: $e');
    }
  }

  // Track user events
  Future<void> trackEvent(String eventName,
      {Map<String, Object>? parameters}) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint('⚠️ Analytics not initialized, skipping event: $eventName');
      return;
    }

    try {
      await _analytics!.logEvent(
        name: eventName,
        parameters: parameters,
      );
      debugPrint('📊 Tracked event: $eventName');
    } catch (e) {
      debugPrint('❌ Error tracking event: $e');
    }
  }

  // Track screen views
  Future<void> trackScreenView(String screenName) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint(
          '⚠️ Analytics not initialized, skipping screen view: $screenName');
      return;
    }

    try {
      await _analytics!.logScreenView(screenName: screenName);
      debugPrint('📱 Tracked screen view: $screenName');
    } catch (e) {
      debugPrint('❌ Error tracking screen view: $e');
    }
  }

  // Track user properties
  Future<void> setUserProperty(String name, String? value) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint('⚠️ Analytics not initialized, skipping user property: $name');
      return;
    }

    try {
      await _analytics!.setUserProperty(name: name, value: value);
      debugPrint('👤 Set user property: $name = $value');
    } catch (e) {
      debugPrint('❌ Error setting user property: $e');
    }
  }

  // Track app performance
  Future<void> trackPerformance(String name, Duration duration) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint('⚠️ Analytics not initialized, skipping performance: $name');
      return;
    }

    try {
      await _analytics!.logEvent(
        name: 'performance_metric',
        parameters: {
          'metric_name': name,
          'duration_ms': duration.inMilliseconds,
        },
      );
      debugPrint('⚡ Tracked performance: $name = ${duration.inMilliseconds}ms');
    } catch (e) {
      debugPrint('❌ Error tracking performance: $e');
    }
  }

  // Track errors
  Future<void> trackError(String error, StackTrace? stackTrace,
      {bool fatal = false}) async {
    if (!_isInitialized || _crashlytics == null) {
      debugPrint(
          '⚠️ Analytics not initialized, skipping error tracking: $error');
      return;
    }

    try {
      await _crashlytics!.recordError(error, stackTrace, fatal: fatal);
      debugPrint('🚨 Tracked error: $error');
    } catch (e) {
      debugPrint('❌ Error tracking error: $e');
    }
  }

  // Track user engagement
  Future<void> trackEngagement(String action, String target) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint('⚠️ Analytics not initialized, skipping engagement: $action');
      return;
    }

    try {
      await _analytics!.logEvent(
        name: 'user_engagement',
        parameters: {
          'action': action,
          'target': target,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('🎯 Tracked engagement: $action on $target');
    } catch (e) {
      debugPrint('❌ Error tracking engagement: $e');
    }
  }

  // Track network requests
  Future<void> trackNetworkRequest(
      String endpoint, int statusCode, Duration duration) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint(
          '⚠️ Analytics not initialized, skipping network request: $endpoint');
      return;
    }

    try {
      await _analytics!.logEvent(
        name: 'network_request',
        parameters: {
          'endpoint': endpoint,
          'status_code': statusCode,
          'duration_ms': duration.inMilliseconds,
          'success': statusCode >= 200 && statusCode < 300,
        },
      );
      debugPrint('🌐 Tracked network request: $endpoint ($statusCode)');
    } catch (e) {
      debugPrint('❌ Error tracking network request: $e');
    }
  }

  // Track memory usage
  Future<void> trackMemoryUsage(int memoryUsageMB) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint(
          '⚠️ Analytics not initialized, skipping memory usage tracking');
      return;
    }

    try {
      await _analytics!.logEvent(
        name: 'memory_usage',
        parameters: {
          'memory_mb': memoryUsageMB,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('💾 Tracked memory usage: ${memoryUsageMB}MB');
    } catch (e) {
      debugPrint('❌ Error tracking memory usage: $e');
    }
  }

  // Track app crashes
  Future<void> trackCrash(String crashType, String crashReason) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint(
          '⚠️ Analytics not initialized, skipping crash tracking: $crashType');
      return;
    }

    try {
      await _analytics!.logEvent(
        name: 'app_crash',
        parameters: {
          'crash_type': crashType,
          'crash_reason': crashReason,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('💥 Tracked crash: $crashType - $crashReason');
    } catch (e) {
      debugPrint('❌ Error tracking crash: $e');
    }
  }

  // Get analytics instance for direct use
  FirebaseAnalytics? get analytics => _analytics;
  FirebaseCrashlytics? get crashlytics => _crashlytics;
}
