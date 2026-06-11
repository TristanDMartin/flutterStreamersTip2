import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui';
import 'dart:async';
import 'services/analytics_service.dart';
import 'services/error_handler_service.dart';
import 'utils/performance_utils.dart';
import 'services/memory_optimization_service.dart';
import 'services/network_config_service.dart';
import 'services/network_connectivity_service.dart';
import 'services/google_services_fix.dart';
import 'services/unified_avatar_service.dart' as nav;
import 'services/unified_bookmark_service.dart';
import 'services/ios_memory_service.dart';
import 'services/firebase_ios_service.dart';
import 'services/firestore_optimization_service.dart';
import 'services/firestore_cache_service.dart';
import 'services/push_notification_service.dart';
import 'services/global_playback_manager.dart';
import 'services/audio_enhancement_service.dart';
import 'services/algorithm_cache_service.dart';
import 'services/performance_emergency_service.dart';
import 'services/navigation_observer.dart';
import 'routing/app_routes.dart';
import 'widgets/ios_minimal_startup.dart';
import 'providers/service_providers.dart';
import 'services/robust_auth_service.dart';
import 'components/onboarding/onboarding_gate.dart';
import 'features/gamification/widgets/gamification_celebration_overlay.dart';
import 'services/streamers_tip_like_service.dart';
import 'services/favorites_service_optimized.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'core/design/streamers_tip_design.dart';
import 'features/home/application/home_first_frame_gate.dart';
import 'features/billing/iap_billing_coordinator.dart';
import 'core/firebase_app_check_startup.dart';
import 'qa/qa_runtime.dart';

void main() async {
  final appStartTime = DateTime.now();
  debugPrint('🚀 APP STARTUP: Starting at $appStartTime');

  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ WidgetsFlutterBinding: Initialized at ${DateTime.now()}');
  STSystemUi.configureDefault();

  // Firebase must be ready before auth/feed providers build. Native iOS may
  // configure Firebase in AppDelegate, but Dart plugins still need this call.
  await _initializeFirebaseForStartup();
  await _preloadHomeFeedForInstantStart();

  if (Firebase.apps.isNotEmpty) {
    debugPrint('⏰ Crashlytics: Installing handlers before runApp');
    await AnalyticsService.instance.installCrashHandlers();
    debugPrint('✅ Crashlytics: Handlers installed');
  } else {
    _initializeGlobalErrorHandler();
    debugPrint('⚠️ Crashlytics: Firebase unavailable; console-only errors');
  }

  debugPrint('🏃 Running app at ${DateTime.now()}');
  runApp(const ProviderScope(child: IOSMinimalStartup(child: MyApp())));

  // Initialize heavier services after runApp so the first Flutter frame is not
  // blocked by network/auth/feed work.
  scheduleMicrotask(() async {
    try {
      await HomeFirstFrameGate.instance.waitForFirstFrameOrTimeout(
        timeout: const Duration(seconds: 4),
      );
      debugPrint(
        '⏰ All Services: Starting initialization after first frame at ${DateTime.now()}',
      );
      await _initializeAllServices();
      debugPrint('✅ Startup Phase 1 completed at ${DateTime.now()}');

      final appReadyTime = DateTime.now();
      final totalStartupTime = appReadyTime.difference(appStartTime);
      debugPrint(
        '🎉 APP READY: Total startup time: ${totalStartupTime.inMilliseconds}ms',
      );
    } catch (e) {
      debugPrint('❌ Service initialization failed: $e');
      // Don't crash - app is already running
    }
  });
}

Future<void> _preloadHomeFeedForInstantStart() async {
  try {
    String? userId;
    if (Firebase.apps.isNotEmpty) {
      userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    }
    final AlgorithmCacheService cache = AlgorithmCacheService();
    await cache.preloadForYouFeedMemory(userId: userId);
    final warm = cache.peekForYouWarmFeed();
    if (warm != null && warm.videos.isNotEmpty) {
      debugPrint(
        '⚡ STARTUP: Pre-warming ${warm.videos.length} cached videos before runApp',
      );
      await GlobalPlaybackManager.instance.warmFirstFeedController(
        warm.videos,
      );
      GlobalPlaybackManager.instance.preloadStartupWindow(
        warm.videos,
        requestFocusOnStart: false,
      );
    }
  } catch (e) {
    debugPrint('⚠️ STARTUP: Feed preload failed (non-fatal): $e');
  }
}

Future<void> _initializeFirebaseForStartup() async {
  if (Firebase.apps.isNotEmpty) {
    debugPrint('✅ FIREBASE: Already initialized before startup warmup');
    return;
  }

  debugPrint(
      '🔥 FIREBASE: Initializing before first route at ${DateTime.now()}');
  try {
    var firebaseTimedOut = false;
    await FirebaseIOSService.initialize().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        firebaseTimedOut = true;
        debugPrint(
          '⚠️ FIREBASE: Initialization timed out - continuing startup in degraded mode',
        );
      },
    );
    if (!firebaseTimedOut) {
      await activateAppCheckIfEnabled();
      debugPrint(
        '✅ FIREBASE: Firebase initialized successfully at ${DateTime.now()}',
      );
    }
  } catch (e) {
    debugPrint('❌ FIREBASE: Initialization failed: $e');
  }
}

/// Initialize global error handler for the entire app
void _initializeGlobalErrorHandler() {
  // Set up basic error handling without any Firebase dependencies
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🚨 Flutter Error: ${details.exception}');
    debugPrint('📍 Stack trace: ${details.stack}');

    // Only log to console, no Firebase analytics until Firebase is ready
    if (details.exception.toString().contains('[core/no-app]')) {
      debugPrint(
          '⚠️ Firebase not initialized yet - this is expected during startup');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 Platform Error: $error');
    debugPrint('📍 Stack trace: $stack');
    return true;
  };

  debugPrint('✅ Basic error handler initialized (Firebase-independent)');
}

/// 🚀 CONSOLIDATED: Initialize all services from single point
Future<void> _initializeAllServices() async {
  debugPrint('🚀 ServiceManager: Starting phased service initialization...');
  debugPrint('⏰ ServiceManager: Start time: ${DateTime.now()}');

  try {
    // PHASE 1: only cheap, local startup guards. Firebase, auth/feed cache,
    // and playback warmup already ran before/inside runApp.
    debugPrint('📡 Initializing Phase 1 startup services...');
    debugPrint('⏰ NetworkConfigService: Start time: ${DateTime.now()}');
    NetworkConfigService.initialize();
    debugPrint('✅ NetworkConfigService: Completed at ${DateTime.now()}');

    debugPrint('⏰ IOSMemoryService: Start time: ${DateTime.now()}');
    IOSMemoryService.initialize();
    debugPrint('✅ IOSMemoryService: Completed at ${DateTime.now()}');

    debugPrint('⏰ PerformanceEmergencyService: Start time: ${DateTime.now()}');
    PerformanceEmergencyService().initialize();
    debugPrint('✅ PerformanceEmergencyService: Completed at ${DateTime.now()}');

    // 🔥 FIREBASE: Already initialized in main() before runApp()
    // Just verify it's ready
    if (Firebase.apps.isEmpty) {
      debugPrint('⚠️ FIREBASE: Not initialized, initializing now...');
      await FirebaseIOSService.initialize();
    } else {
      debugPrint('✅ FIREBASE: Already initialized');
    }

    // Keep error handling cheap and local during the first interactive window.
    debugPrint('⏰ ErrorHandlerService: Start time: ${DateTime.now()}');
    await _initializeServiceSafely('ErrorHandlerService', () async {
      ErrorHandlerService.instance.initialize();
    });
    debugPrint('✅ ErrorHandlerService: Completed at ${DateTime.now()}');

    _initializePerformanceOptimizations();

    debugPrint('✅ Phase 1 startup services initialized');
    _scheduleDeferredServicePhases();
  } catch (e) {
    debugPrint('❌ ServiceManager: Phase 1 initialization failed: $e');
    // Continue anyway - app should still work
  }
}

void _scheduleDeferredServicePhases() {
  unawaited(Future<void>.delayed(const Duration(seconds: 5), () async {
    await _initializePhase2Services();
  }));
  unawaited(Future<void>.delayed(const Duration(seconds: 20), () async {
    await _initializeBackgroundServices();
  }));
}

Future<void> _initializePhase2Services() async {
  debugPrint('🚀 ServiceManager: Starting Phase 2 service initialization...');
  final Duration serviceTimeout = QaRuntime.isMobileFeedE2e
      ? const Duration(seconds: 15)
      : const Duration(seconds: 30);

  await _initializeServiceSafely('NetworkConnectivityService', () async {
    await NetworkConnectivityService().checkConnectivity();
  }, timeout: serviceTimeout);
  await _yieldBetweenDeferredServices();

  await _initializeServiceSafely('AnalyticsService', () async {
    await AnalyticsService.instance.initialize();
  }, timeout: serviceTimeout);
  await _yieldBetweenDeferredServices();

  await _initializeServiceSafely('IapBillingCoordinator', () async {
    if (kIsWeb) {
      return;
    }
    await IapBillingCoordinator.instance.warmStart();
  }, timeout: serviceTimeout);
  await _yieldBetweenDeferredServices();

  await _initializeServiceSafely('AudioEnhancementService', () async {
    await AudioEnhancementService().initialize();
  }, timeout: serviceTimeout);
  await _yieldBetweenDeferredServices();

  await _initializeServiceSafely('StreamersTipLikeService', () async {
    final String? userId =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    await StreamersTipLikeService().initialize(userId: userId);
  }, timeout: serviceTimeout);
  await _yieldBetweenDeferredServices();

  await _initializeServiceSafely('FavoritesServiceOptimized', () async {
    await FavoritesServiceOptimized().initialize();
  }, timeout: serviceTimeout);
  await _yieldBetweenDeferredServices();

  await _initializeProductionServices(timeout: serviceTimeout);
  debugPrint('✅ ServiceManager: Phase 2 services initialized');
}

Future<void> _yieldBetweenDeferredServices() {
  return Future<void>.delayed(const Duration(milliseconds: 300));
}

/// Initialize remaining services in background to avoid blocking startup
Future<void> _initializeBackgroundServices() async {
  debugPrint(
      '🚀 ServiceManager: Starting Phase 3 background service initialization...');

  final Duration serviceTimeout = QaRuntime.isMobileFeedE2e
      ? const Duration(seconds: 25)
      : const Duration(minutes: 2);

  Future<void> initFirestoreOptimization() async {
    await FirestoreOptimizationService.initialize();
  }

  Future<void> initFirestoreCache() async {
    await FirestoreCacheService.initialize();
  }

  Future<void> initGoogleServices() async {
    await GoogleServicesFix.initialize();
  }

  if (QaRuntime.isMobileFeedE2e) {
    debugPrint(
      '⏭️ E2E: background services run with ${serviceTimeout.inSeconds}s caps; '
      'push skipped',
    );
    unawaited(
      _initializeServiceSafely(
        'FirestoreOptimizationService',
        initFirestoreOptimization,
        timeout: serviceTimeout,
      ),
    );
    unawaited(
      _initializeServiceSafely(
        'FirestoreCacheService',
        initFirestoreCache,
        timeout: serviceTimeout,
      ),
    );
    unawaited(
      _initializeServiceSafely(
        'GoogleServicesFix',
        initGoogleServices,
        timeout: serviceTimeout,
      ),
    );
    _initializeServiceSafelyAsync('UnifiedAvatarService', () async {
      await nav.UnifiedAvatarService().initialize();
    });
    debugPrint(
      '✅ ServiceManager: E2E background services scheduled (non-blocking)',
    );
    return;
  }

  await _initializeServiceSafely(
    'FirestoreOptimizationService',
    initFirestoreOptimization,
    timeout: serviceTimeout,
  );
  await _yieldBetweenDeferredServices();

  await _initializeServiceSafely(
    'FirestoreCacheService',
    initFirestoreCache,
    timeout: serviceTimeout,
  );
  await _yieldBetweenDeferredServices();

  _initializeServiceSafelyAsync('PushNotificationService', () async {
    await PushNotificationService().initialize();
  });
  await _yieldBetweenDeferredServices();

  await _initializeServiceSafely(
    'GoogleServicesFix',
    initGoogleServices,
    timeout: serviceTimeout,
  );

  _initializeServiceSafelyAsync('UnifiedAvatarService', () async {
    await nav.UnifiedAvatarService().initialize();
  });

  debugPrint('✅ ServiceManager: Phase 3 background services initialized');
}

/// 🔒 SAFETY: Initialize a single service with individual error handling
Future<void> _initializeServiceSafely(
  String serviceName,
  Future<void> Function() initFunction, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  final startTime = DateTime.now();
  debugPrint('⏰ ServiceManager: Starting $serviceName at $startTime');

  try {
    await initFunction().timeout(
      timeout,
      onTimeout: () {
        debugPrint(
          '⏱️ ServiceManager: $serviceName timed out after '
          '${timeout.inSeconds}s — continuing startup',
        );
      },
    );
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    debugPrint(
        '✅ ServiceManager: $serviceName initialized successfully in ${duration.inMilliseconds}ms');
  } catch (e) {
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    debugPrint(
        '❌ ServiceManager: $serviceName initialization failed after ${duration.inMilliseconds}ms: $e');
    // Don't rethrow - allow other services to continue
  }
}

/// 🔒 SAFETY: Initialize a service asynchronously (non-blocking)
void _initializeServiceSafelyAsync(
    String serviceName, Future<void> Function() initFunction) {
  Future.microtask(() async {
    await _initializeServiceSafely(serviceName, initFunction);
  });
}

Future<void> _initializeProductionServices({
  Duration timeout = const Duration(minutes: 2),
}) async {
  debugPrint('🚀 ServiceManager: Initializing production services...');

  // AnalyticsService and ErrorHandlerService are now initialized in critical services after Firebase

  // Initialize UnifiedBookmarkService with current user
  await _initializeServiceSafely(
    'UnifiedBookmarkService',
    () async {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await UnifiedBookmarkService.instance.initialize(currentUser.uid);
        debugPrint(
            '📚 UnifiedBookmarkService: Initialized for user ${currentUser.uid}');
      } else {
        debugPrint(
            '⚠️ UnifiedBookmarkService: No user logged in, skipping initialization');
      }
    },
    timeout: timeout,
  );

  debugPrint('✅ ServiceManager: Production services initialization completed');
}

void _initializePerformanceOptimizations() {
  // Enable performance optimizations
  WidgetsBinding.instance.addObserver(PerformanceObserver());

  // Initialize memory optimization
  MemoryOptimizationService().optimizeMemory();

  debugPrint('✅ Performance optimizations initialized');
}

class PerformanceObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        // Optimize memory when app is paused
        MemoryOptimizationService().optimizeMemory();
        break;
      case AppLifecycleState.resumed:
        // Clean up when app is resumed
        PerformanceUtils.cleanup();
        break;
      case AppLifecycleState.detached:
        // Full cleanup when app is detached
        MemoryOptimizationService().clearAll();
        PerformanceUtils.cleanup();
        GlobalPlaybackManager.instance.dispose();
        break;
      default:
        break;
    }
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CRITICAL: Check if Firebase is ready before accessing EventTriggerService
    // This prevents the red error screen when Firebase isn't initialized yet
    try {
      if (Firebase.apps.isNotEmpty) {
        // Only initialize EventTriggerService if Firebase is ready
        ref.read(eventTriggerServiceProvider);
      }
    } catch (e) {
      debugPrint('⚠️ MyApp: Error accessing EventTriggerService: $e');
      // Continue anyway - app will work without EventTriggerService initially
    }

    final AppThemeMode appTheme = ref.watch(appThemeModeProvider);
    return MaterialApp(
      title: 'StreamersTip',
      theme: StAppTheme.light,
      darkTheme: StAppTheme.dark,
      themeMode: appTheme.themeMode,
      scrollBehavior: const STScrollBehavior(),
      navigatorKey: nav.NavigationService.navigatorKey,
      navigatorObservers: [AppNavigationObserver()],
      onGenerateRoute: AppRoutes.onGenerateRoute,
      initialRoute: AppRoutes.root,
      builder: (context, child) {
        final Widget navigatorChild = child ?? const SizedBox.shrink();
        final MediaQueryData mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(1.0)),
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) {
              final (
                String userId,
                String? username,
                String? displayName,
              ) = ref.watch(
                robustAuthServiceProvider.select(
                  (RobustAuthenticationService auth) {
                    final u = auth.currentUser;
                    return (
                      u?.id ?? '',
                      u?.username,
                      u?.displayName,
                    );
                  },
                ),
              );
              if (userId.isEmpty) {
                return navigatorChild;
              }
              return GamificationCelebrationOverlay(
                child: OnboardingGate(
                  userId: userId,
                  email: firebase_auth.FirebaseAuth.instance.currentUser?.email,
                  username: username,
                  displayName: displayName,
                  child: navigatorChild,
                ),
              );
            },
          ),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
