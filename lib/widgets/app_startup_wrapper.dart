import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/robust_auth_service.dart';
import '../services/calendar_cleanup_service.dart';
import '../services/scheduled_post_publisher_service.dart';
import '../widgets/auth_modal_view.dart';
import '../pages/main_tab_view.dart';

/// App startup wrapper that handles authentication flow
class AppStartupWrapper extends ConsumerStatefulWidget {
  const AppStartupWrapper({super.key});

  @override
  ConsumerState<AppStartupWrapper> createState() => _AppStartupWrapperState();
}

class _AppStartupWrapperState extends ConsumerState<AppStartupWrapper> {
  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
  }

  @override
  void dispose() {
    _resetSystemUIOverlayStyle();
    super.dispose();
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF6137EB),
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF6137EB),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _resetSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  /// Run calendar cleanup for logged-in user
  void _runCalendarCleanup() {
    final authService = ref.read(robustAuthServiceProvider);
    final currentUser = authService.currentUser;

    if (currentUser != null) {
      // Run cleanup in background (non-blocking)
      CalendarCleanupService().cleanupExpiredEvents(currentUser.id).then((_) {
        debugPrint('✅ App startup: Calendar cleanup completed');
      }).catchError((error) {
        debugPrint('⚠️ App startup: Calendar cleanup error: $error');
      });
    }
  }

  /// Start scheduled post publisher service for logged-in user
  void _startScheduledPostPublisher() {
    final authService = ref.read(robustAuthServiceProvider);
    final currentUser = authService.currentUser;

    if (currentUser != null) {
      // Start the scheduled post publisher service (checks every minute)
      ScheduledPostPublisherService().startPeriodicCheck(
        interval: const Duration(minutes: 1),
      );
      debugPrint('✅ App startup: Scheduled post publisher started');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth service to rebuild when state changes
    final authService = ref.watch(robustAuthServiceProvider);
    
    // CRITICAL: Check if Firebase is ready before accessing auth service
    if (Firebase.apps.isEmpty) {
      debugPrint(
          '⚠️ AppStartupWrapper: Firebase not ready yet - showing splash screen');
      return _buildLoadingScreen();
    }

    // Listen to auth state changes and force rebuild
    ref.listen(robustAuthServiceProvider, (previous, next) {
      if (previous != null) {
        final loadingChanged = previous.shouldShowLoading != next.shouldShowLoading;
        final loginChanged = previous.isLoggedIn != next.isLoggedIn;
        
        if (loadingChanged || loginChanged) {
          debugPrint('🔄 AppStartupWrapper: Auth state changed');
          debugPrint('   Loading: ${previous.shouldShowLoading} -> ${next.shouldShowLoading}');
          debugPrint('   Logged in: ${previous.isLoggedIn} -> ${next.isLoggedIn}');
          
          if (mounted) {
            setState(() {});
          }
        }
      }
    });

    // Debug logging
    debugPrint(
        '🎯 AppStartupWrapper: isLoggedIn=${authService.isLoggedIn}, shouldShowLoading=${authService.shouldShowLoading}, isCheckingAuth=${authService.isCheckingAuth}');

    // Show splash screen while loading or checking auth
    if (authService.shouldShowLoading) {
      return _buildLoadingScreen();
    }

    // Show main app if logged in
    if (authService.isLoggedIn) {
      debugPrint('🏠 AppStartupWrapper: Returning MainTabView');
      // Run calendar cleanup in background
      _runCalendarCleanup();
      // Start scheduled post publisher service
      _startScheduledPostPublisher();
      return const MainTabView();
    }

    // Show auth modal if not logged in
    debugPrint('🔐 AppStartupWrapper: Showing auth modal');
    return const AuthModalView();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF6137EB),
      body: Container(
        color: const Color(0xFF6137EB),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo - White icon matching splash screen design
              Container(
                width: 120,
                height: 120,
                child: Image.asset(
                  'assets/091225_ST_logo_white.PNG',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to regular logo with white color filter
                    return Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      color: Colors.white,
                      errorBuilder: (context, error, stackTrace) {
                        // Final fallback to icon
                        return const Icon(
                          Icons.gamepad,
                          color: Colors.white,
                          size: 80,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),

              // App Name
              const Text(
                'StreamersTip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              // Tagline
              const Text(
                'Connect • Create • Share',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
