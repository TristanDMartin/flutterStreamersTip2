import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/robust_auth_service.dart';
import '../services/calendar_cleanup_service.dart';
import '../widgets/auth_modal_view.dart';
import '../pages/main_tab_view.dart';

/// App startup wrapper that handles authentication flow
class AppStartupWrapper extends ConsumerStatefulWidget {
  const AppStartupWrapper({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  ConsumerState<AppStartupWrapper> createState() => _AppStartupWrapperState();
}

class _AppStartupWrapperState extends ConsumerState<AppStartupWrapper> {
  bool _firebaseStartupGracePeriodElapsed = false;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _firebaseStartupGracePeriodElapsed = true);
    });
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

  @override
  Widget build(BuildContext context) {
    // Watch auth service to rebuild when state changes
    final authService = ref.watch(robustAuthServiceProvider);

    // Give Firebase a brief chance to finish cold-start initialization, but do
    // not trap users on the splash forever if initialization fails/degrades.
    if (Firebase.apps.isEmpty && !_firebaseStartupGracePeriodElapsed) {
      debugPrint(
          '⚠️ AppStartupWrapper: Firebase not ready yet - showing splash screen');
      return _buildLoadingScreen();
    } else if (Firebase.apps.isEmpty) {
      debugPrint(
          '⚠️ AppStartupWrapper: Firebase unavailable after startup grace period - continuing to auth UI');
    }

    // Listen to auth state changes and force rebuild
    ref.listen(robustAuthServiceProvider, (previous, next) {
      if (previous != null) {
        final loadingChanged =
            previous.shouldShowLoading != next.shouldShowLoading;
        final loginChanged = previous.isLoggedIn != next.isLoggedIn;

        if (loadingChanged || loginChanged) {
          debugPrint('🔄 AppStartupWrapper: Auth state changed');
          debugPrint(
              '   Loading: ${previous.shouldShowLoading} -> ${next.shouldShowLoading}');
          debugPrint(
              '   Logged in: ${previous.isLoggedIn} -> ${next.isLoggedIn}');

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
      return MainTabView(initialTabIndex: widget.initialTabIndex);
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
              // App Logo - Fits within a circular container with extra padding for rings
              Container(
                width: 192,
                height: 192,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                ),
                child: Center(
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Image.asset(
                      'assets/app_logo.PNG',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/091225_ST_logo_white.PNG',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              color: Colors.white,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.gamepad,
                                  color: Colors.white,
                                  size: 140,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
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
