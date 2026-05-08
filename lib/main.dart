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
import 'services/performance_emergency_service.dart';
import 'services/navigation_observer.dart';
import 'routing/app_routes.dart';
import 'widgets/ios_minimal_startup.dart';
import 'providers/service_providers.dart';
import 'services/streamers_tip_like_service.dart';
import 'services/favorites_service_optimized.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'features/billing/iap_billing_coordinator.dart';
import 'utils/responsive_layout.dart';

void main() async {
  final appStartTime = DateTime.now();
  debugPrint('🚀 APP STARTUP: Starting at $appStartTime');

  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ WidgetsFlutterBinding: Initialized at ${DateTime.now()}');

  // 🔧 GLOBAL ERROR HANDLER: Centralized error tracking
  debugPrint('⏰ Global Error Handler: Starting at ${DateTime.now()}');
  _initializeGlobalErrorHandler();
  debugPrint('✅ Global Error Handler: Completed at ${DateTime.now()}');

  // 🔥 CRITICAL: Initialize Firebase BEFORE runApp to prevent "[core/no-app]" errors
  // Firebase must be ready before any Firebase-dependent services are accessed
  debugPrint(
      '🔥 FIREBASE: Initializing Firebase BEFORE runApp at ${DateTime.now()}');
  try {
    var firebaseTimedOut = false;
    await FirebaseIOSService.initialize().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        firebaseTimedOut = true;
        debugPrint(
            '⚠️ FIREBASE: Initialization timed out - continuing startup in degraded mode');
      },
    );
    if (!firebaseTimedOut) {
      debugPrint(
          '✅ FIREBASE: Firebase initialized successfully at ${DateTime.now()}');
    }
  } catch (e) {
    debugPrint('❌ FIREBASE: Initialization failed: $e');
    // Continue anyway - app will show splash screen and retry
  }

  // CRITICAL: Run app AFTER Firebase is initialized
  debugPrint('🏃 Running app at ${DateTime.now()}');
  runApp(const ProviderScope(child: IOSMinimalStartup(child: MyApp())));

  // 🚀 CONSOLIDATED INITIALIZATION: Initialize remaining services AFTER runApp
  // This prevents blocking the first frame and triggering iOS watchdog
  scheduleMicrotask(() async {
    try {
      debugPrint(
          '⏰ All Services: Starting initialization after runApp at ${DateTime.now()}');
      await _initializeAllServices();
      debugPrint(
          '✅ All Services: Initialization completed at ${DateTime.now()}');

      final appReadyTime = DateTime.now();
      final totalStartupTime = appReadyTime.difference(appStartTime);
      debugPrint(
          '🎉 APP READY: Total startup time: ${totalStartupTime.inMilliseconds}ms');
    } catch (e) {
      debugPrint('❌ Service initialization failed: $e');
      // Don't crash - app is already running
    }
  });
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
  debugPrint(
      '🚀 ServiceManager: Starting consolidated service initialization...');
  debugPrint('⏰ ServiceManager: Start time: ${DateTime.now()}');

  try {
    // CRITICAL SERVICES (blocking)
    debugPrint('📡 Initializing critical services...');
    debugPrint('⏰ NetworkConfigService: Start time: ${DateTime.now()}');
    NetworkConfigService.initialize();
    debugPrint('✅ NetworkConfigService: Completed at ${DateTime.now()}');

    // 🌐 CONNECTIVITY: Check network connectivity
    debugPrint('⏰ NetworkConnectivityService: Start time: ${DateTime.now()}');
    await _initializeServiceSafely('NetworkConnectivityService', () async {
      await NetworkConnectivityService().checkConnectivity();
    });
    debugPrint('✅ NetworkConnectivityService: Completed at ${DateTime.now()}');

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

    // 🔥 ANALYTICS: Initialize analytics immediately after Firebase
    debugPrint('⏰ AnalyticsService: Start time: ${DateTime.now()}');
    await _initializeServiceSafely('AnalyticsService', () async {
      await AnalyticsService.instance.initialize();
    });
    debugPrint('✅ AnalyticsService: Completed at ${DateTime.now()}');

    // 🔥 ERROR HANDLER: Initialize error handler after Firebase and Analytics
    debugPrint('⏰ ErrorHandlerService: Start time: ${DateTime.now()}');
    await _initializeServiceSafely('ErrorHandlerService', () async {
      ErrorHandlerService.instance.initialize();
    });
    debugPrint('✅ ErrorHandlerService: Completed at ${DateTime.now()}');

    await _initializeServiceSafely('IapBillingCoordinator', () async {
      if (kIsWeb) {
        return;
      }
      await IapBillingCoordinator.instance.warmStart();
    });

    // PERFORMANCE OPTIMIZATIONS
    _initializePerformanceOptimizations();

    // StreamersTip SERVICES (needed for UI)
    // Note: Full initialization with userId happens after login in HomeView
    StreamersTipLikeService().initialize().catchError((e) {
      debugPrint('⚠️ StreamersTipLikeService init failed: $e');
    });

    // Initialize FavoritesServiceOptimized
    await _initializeServiceSafely('FavoritesServiceOptimized', () async {
      await FavoritesServiceOptimized().initialize();
    });

    debugPrint('✅ Critical services initialized');

    // BACKGROUND SERVICES (non-blocking)
    _initializeBackgroundServices();
  } catch (e) {
    debugPrint('❌ ServiceManager: Critical services initialization failed: $e');
    // Continue anyway - app should still work
  }
}

/// Initialize remaining services in background to avoid blocking startup
void _initializeBackgroundServices() async {
  debugPrint(
      '🚀 ServiceManager: Starting background service initialization...');

  // 🔒 INDIVIDUAL ERROR HANDLING: Each service initializes independently
  await _initializeServiceSafely('FirestoreOptimizationService', () async {
    await FirestoreOptimizationService.initialize();
  });

  await _initializeServiceSafely('FirestoreCacheService', () async {
    await FirestoreCacheService.initialize();
  });

  await _initializeServiceSafely('PushNotificationService', () async {
    await PushNotificationService().initialize();
  });

  await _initializeServiceSafely('GoogleServicesFix', () async {
    await GoogleServicesFix.initialize();
  });

  // Initialize Unified Avatar Service (non-blocking)
  _initializeServiceSafelyAsync('UnifiedAvatarService', () async {
    await nav.UnifiedAvatarService().initialize();
  });

  // Initialize production services
  await _initializeProductionServices();

  debugPrint('✅ ServiceManager: Background services initialization completed');
}

/// 🔒 SAFETY: Initialize a single service with individual error handling
Future<void> _initializeServiceSafely(
    String serviceName, Future<void> Function() initFunction) async {
  final startTime = DateTime.now();
  debugPrint('⏰ ServiceManager: Starting $serviceName at $startTime');

  try {
    await initFunction();
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

Future<void> _initializeProductionServices() async {
  debugPrint('🚀 ServiceManager: Initializing production services...');

  // AnalyticsService and ErrorHandlerService are now initialized in critical services after Firebase

  // Initialize UnifiedBookmarkService with current user
  await _initializeServiceSafely('UnifiedBookmarkService', () async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await UnifiedBookmarkService.instance.initialize(currentUser.uid);
      debugPrint(
          '📚 UnifiedBookmarkService: Initialized for user ${currentUser.uid}');
    } else {
      debugPrint(
          '⚠️ UnifiedBookmarkService: No user logged in, skipping initialization');
    }
  });

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
      navigatorKey: nav.NavigationService.navigatorKey,
      navigatorObservers: [AppNavigationObserver()],
      onGenerateRoute: AppRoutes.onGenerateRoute,
      initialRoute: AppRoutes.root,
      builder: (context, child) {
        return MediaQuery(
          data: AppResponsive.normalizedMediaQuery(MediaQuery.of(context)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
