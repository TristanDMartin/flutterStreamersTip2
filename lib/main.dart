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
import 'services/ios_memory_service.dart';
import 'services/firebase_ios_service.dart';
import 'services/firestore_optimization_service.dart';
import 'services/firestore_cache_service.dart';
import 'services/push_notification_service.dart';
import 'services/performance_emergency_service.dart';
import 'widgets/ios_minimal_startup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // MINIMAL STARTUP: Initialize only essential services synchronously
  NetworkConfigService.initialize();
  IOSMemoryService.initialize();
  
  // Initialize emergency performance monitoring
  PerformanceEmergencyService().initialize();
  
  // Initialize Firebase immediately (required for app functionality)
  await FirebaseIOSService.initialize();
  
  // Initialize performance optimizations immediately
  _initializePerformanceOptimizations();
  
  // Run app immediately with loading screen
  runApp(const ProviderScope(child: IOSMinimalStartup(child: MyApp())));
  
  // Initialize remaining services in background after app starts
  _initializeBackgroundServices();
}

/// Initialize remaining services in background to avoid blocking startup
void _initializeBackgroundServices() async {
  try {
    // Initialize Firestore services (non-blocking)
    await FirestoreOptimizationService.initialize();
    await FirestoreCacheService.initialize();
    await PushNotificationService().initialize();
    
    // Initialize Google Services fix in background
    await GoogleServicesFix.initialize();
    
    // Initialize Unified Avatar Service in background (non-blocking)
    nav.UnifiedAvatarService().initialize().catchError((e) {
      debugPrint('⚠️ Avatar service init failed (non-critical): $e');
    });
    
    // Initialize production services in background
    await _initializeProductionServices();
    
    debugPrint('✅ All background services initialized');
  } catch (e) {
    debugPrint('❌ Background service initialization failed: $e');
  }
}

Future<void> _initializeProductionServices() async {
  try {
    // Initialize analytics and crashlytics
    await AnalyticsService.instance.initialize();
    
    // Initialize error handling
    ErrorHandlerService.instance.initialize();
    
    debugPrint('✅ Production services initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing production services: $e');
  }
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamersTip',
      navigatorKey: nav.NavigationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppStartupWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
