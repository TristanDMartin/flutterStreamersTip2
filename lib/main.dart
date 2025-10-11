import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/app_startup_wrapper.dart';
import 'services/analytics_service.dart';
import 'services/error_handler_service.dart';
import 'utils/performance_utils.dart';
import 'services/memory_optimization_service.dart';
import 'services/network_config_service.dart';
import 'services/google_services_fix.dart';
import 'services/unified_avatar_service.dart' as nav;
import 'services/unified_bookmark_service.dart';
import 'services/ios_memory_service.dart';
import 'services/firebase_ios_service.dart';
import 'services/firestore_optimization_service.dart';
import 'services/firestore_cache_service.dart';
import 'services/push_notification_service.dart';
import 'services/performance_emergency_service.dart';
// import 'services/global_post_count_fix.dart'; // ❌ REMOVED: Interferes with PostCounterService
import 'services/navigation_observer.dart';
import 'widgets/ios_minimal_startup.dart';
import 'providers/service_providers.dart';
import 'services/streamers_tip_like_service.dart';
import 'services/favorites_service_optimized.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔧 GLOBAL ERROR HANDLER: Centralized error tracking
  _initializeGlobalErrorHandler();

  // 🚀 CONSOLIDATED INITIALIZATION: Single point of service initialization
  await _initializeAllServices();

  // Run app immediately
  runApp(const ProviderScope(child: IOSMinimalStartup(child: MyApp())));
}

/// Initialize global error handler for the entire app
void _initializeGlobalErrorHandler() {
  // Use ErrorHandlerService which already has FlutterError.onError setup
  ErrorHandlerService.instance.initialize();
  debugPrint('✅ Global error handler initialized via ErrorHandlerService');
}

/// 🚀 CONSOLIDATED: Initialize all services from single point
Future<void> _initializeAllServices() async {
  debugPrint(
      '🚀 ServiceManager: Starting consolidated service initialization...');

  try {
    // CRITICAL SERVICES (blocking)
    debugPrint('📡 Initializing critical services...');
    NetworkConfigService.initialize();
    IOSMemoryService.initialize();
    PerformanceEmergencyService().initialize();
    await FirebaseIOSService.initialize();

    // PERFORMANCE OPTIMIZATIONS
    _initializePerformanceOptimizations();

    // TIKTOK SERVICES (needed for UI)
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

  // ❌ REMOVED: GlobalPostCountFix interfered with real-time post counting
  // await _initializeServiceSafely('GlobalPostCountFix', () async {
  //   await GlobalPostCountFix().fixAllUsersPostCounts();
  // });

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
  try {
    await initFunction();
    debugPrint('✅ ServiceManager: $serviceName initialized successfully');
  } catch (e) {
    debugPrint('❌ ServiceManager: $serviceName initialization failed: $e');
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

  await _initializeServiceSafely('AnalyticsService', () async {
    await AnalyticsService.instance.initialize();
  });

  await _initializeServiceSafely('ErrorHandlerService', () async {
    ErrorHandlerService.instance.initialize();
  });

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
    // Initialize the EventTriggerService provider to ensure it's set up
    ref.read(eventTriggerServiceProvider);

    return MaterialApp(
      title: 'StreamersTip',
      navigatorKey: nav.NavigationService.navigatorKey,
      navigatorObservers: [AppNavigationObserver()],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppStartupWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
