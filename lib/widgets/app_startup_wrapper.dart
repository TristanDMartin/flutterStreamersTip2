import 'dart:async';
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
  const AppStartupWrapper({super.key});

  @override
  ConsumerState<AppStartupWrapper> createState() => _AppStartupWrapperState();
}

class _AppStartupWrapperState extends ConsumerState<AppStartupWrapper>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showSplash = true;
  Timer? _splashTimer;
  int _splashCountdown = 1; // Reduced from 3 to 1 second for faster startup

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.forward();

    // Show splash screen for minimum 3 seconds like TikTok with countdown
    _startSplashCountdown();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _splashTimer?.cancel();
    _resetSystemUIOverlayStyle();
    super.dispose();
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF1C135D),
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

  void _startSplashCountdown() {
    _splashTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _splashCountdown--;
        });

        if (_splashCountdown <= 0) {
          timer.cancel();
          setState(() {
            _showSplash = false;
          });

          // Run calendar cleanup on app startup
          _runCalendarCleanup();
        }
      }
    });
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
    return Consumer(
      builder: (context, ref, child) {
        // CRITICAL: Check if Firebase is ready before accessing auth service
        // This prevents the red error screen when Firebase isn't initialized yet
        if (Firebase.apps.isEmpty) {
          debugPrint(
              '⚠️ AppStartupWrapper: Firebase not ready yet - showing splash screen');
          return _buildLoadingScreen();
        }

        // Try to access auth service - wrap in try-catch to handle any errors
        RobustAuthenticationService? authService;
        try {
          authService = ref.watch(robustAuthServiceProvider);
        } catch (e) {
          debugPrint('❌ AppStartupWrapper: Error accessing auth service: $e');
          // Show splash screen if there's an error accessing auth service
          return _buildLoadingScreen();
        }

        // If authService is null, show splash screen
        if (authService == null) {
          debugPrint(
              '⚠️ AppStartupWrapper: Auth service is null - showing splash screen');
          return _buildLoadingScreen();
        }

        // Listen to auth state changes
        try {
          ref.listen(robustAuthServiceProvider, (previous, next) {
            if (previous != null && next.isLoggedIn != previous.isLoggedIn) {
              debugPrint('🔄 AppStartupWrapper: Auth state changed');
              debugPrint('   Previous: isLoggedIn=${previous.isLoggedIn}');
              debugPrint('   Next: isLoggedIn=${next.isLoggedIn}');

              if (next.isLoggedIn && next.currentUser != null) {
                debugPrint(
                    '✅ User logged in: ${next.currentUser!.displayName}');
                debugPrint('✅ AppStartupWrapper will show MainTabView');
                // Force rebuild when auth state changes
                if (mounted) {
                  setState(() {});
                }
              } else if (!next.isLoggedIn) {
                debugPrint('❌ User logged out - showing AuthModalView');
                // Force rebuild when auth state changes
                if (mounted) {
                  setState(() {});
                }
              }
            }
          });
        } catch (e) {
          debugPrint('❌ AppStartupWrapper: Error listening to auth state: $e');
          // Continue anyway - show splash screen
        }

        // Debug: Log current state
        debugPrint(
            '🎯 AppStartupWrapper build: isLoggedIn=${authService.isLoggedIn}, shouldShowLoading=${authService.shouldShowLoading}, _showSplash=$_showSplash');

        if (authService.currentUser != null) {
          debugPrint(
              '   Current user: ${authService.currentUser!.displayName}');
        }

        // Show main app if logged in (bypass splash screen)
        if (authService.isLoggedIn) {
          debugPrint('🏠 AppStartupWrapper: Returning MainTabView');
          return const MainTabView();
        }

        // Show splash screen for minimum duration like TikTok (only when not logged in)
        if (_showSplash) {
          debugPrint('🎬 AppStartupWrapper: Showing splash screen');
          return _buildLoadingScreen();
        }

        // Show loading while checking auth (but not if user is already logged in)
        if (authService.shouldShowLoading) {
          debugPrint('⏳ AppStartupWrapper: Showing loading screen');
          return _buildLoadingScreen();
        }

        // Show auth modal if not logged in
        debugPrint('🔐 AppStartupWrapper: Showing auth modal');
        return const AuthModalView();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C135D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: 0.8 + (0.2 * _fadeAnimation.value),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to gradient icon if logo fails to load
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6633CC),
                                      Color(0xFF1A1A4D)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                child: const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 80,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // App Name
                      const Text(
                        'StreamersTip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline
                      Text(
                        'Connect • Create • Share',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
