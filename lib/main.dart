import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'widgets/app_startup_wrapper.dart';
import 'services/analytics_service.dart';
import 'services/error_handler_service.dart';
import 'utils/performance_utils.dart';
import 'services/memory_optimization_service.dart';
import 'services/network_config_service.dart';
import 'services/google_services_fix.dart';
import 'services/unified_avatar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize network configuration first (for SSL certificate handling)
  NetworkConfigService.initialize();
  
  // Initialize Google Services fix
  await GoogleServicesFix.initialize();
  
  // Initialize Unified Avatar Service for instant loading
  await UnifiedAvatarService().initialize();
  
  // Verify logo asset is bundled
  try {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    if (manifest.contains('assets/logo.png')) {
      print('✅ Logo asset found in bundle');
    } else {
      print('❌ Logo asset NOT found in bundle. Manifest contains: ${manifest.substring(0, 200)}...');
    }
  } catch (e) {
    print('❌ Asset verification failed: $e');
  }
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize production services
  await _initializeProductionServices();
  
  // Initialize performance optimizations
  _initializePerformanceOptimizations();
  
  runApp(const ProviderScope(child: MyApp()));
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppStartupWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
