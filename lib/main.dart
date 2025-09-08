import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'widgets/app_startup_wrapper.dart';
import 'services/analytics_service.dart';
import 'services/error_handler_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize production services
  await _initializeProductionServices();
  
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
