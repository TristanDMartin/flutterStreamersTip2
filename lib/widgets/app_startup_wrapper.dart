import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import '../services/robust_auth_service.dart';
import '../services/calendar_cleanup_service.dart';
import '../widgets/auth_modal_view.dart';
import '../widgets/email_verification_view.dart';
import '../pages/main_tab_view.dart';
import 'account_status_guard.dart';

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

enum _StartupShell { firebaseWaiting, loading, home, auth }

class _AppStartupWrapperState extends ConsumerState<AppStartupWrapper> {
  bool _firebaseStartupGracePeriodElapsed = false;
  bool _calendarCleanupStarted = false;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    ref.listenManual<RobustAuthenticationService>(
      robustAuthServiceProvider,
      _onAuthServiceChanged,
    );
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _scheduleRebuild(() {
        _firebaseStartupGracePeriodElapsed = true;
      });
    });
  }

  @override
  void dispose() {
    _resetSystemUIOverlayStyle();
    super.dispose();
  }

  void _onAuthServiceChanged(
    RobustAuthenticationService? previous,
    RobustAuthenticationService next,
  ) {
    if (previous == null) {
      return;
    }
    final bool loadingChanged =
        previous.shouldShowLoading != next.shouldShowLoading;
    final bool loginChanged = previous.isLoggedIn != next.isLoggedIn;
    if (!loadingChanged && !loginChanged) {
      return;
    }
    if (next.isLoggedIn && !next.shouldShowLoading) {
      _runCalendarCleanup();
    }
    if (kDebugMode) {
      debugPrint('🔄 AppStartupWrapper: Auth state changed');
      debugPrint(
        '   Loading: ${previous.shouldShowLoading} -> ${next.shouldShowLoading}',
      );
      debugPrint(
        '   Logged in: ${previous.isLoggedIn} -> ${next.isLoggedIn}',
      );
    }
    _scheduleRebuild(() {});
  }

  void _scheduleRebuild(VoidCallback updateState) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(updateState);
    });
  }

  _StartupShell _resolveShell(RobustAuthenticationService authService) {
    if (Firebase.apps.isEmpty && !_firebaseStartupGracePeriodElapsed) {
      return _StartupShell.firebaseWaiting;
    }
    if (authService.shouldShowLoading) {
      return _StartupShell.loading;
    }
    if (authService.isLoggedIn) {
      return _StartupShell.home;
    }
    return _StartupShell.auth;
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
    if (_calendarCleanupStarted) return;
    final authService = ref.read(robustAuthServiceProvider);
    final currentUser = authService.currentUser;

    if (currentUser != null) {
      _calendarCleanupStarted = true;
      // Run cleanup in background (non-blocking)
      CalendarCleanupService().cleanupExpiredEvents(currentUser.id).then((_) {
        if (kDebugMode) {
          debugPrint('✅ App startup: Calendar cleanup completed');
        }
      }).catchError((error) {
        if (kDebugMode) {
          debugPrint('⚠️ App startup: Calendar cleanup error: $error');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final RobustAuthenticationService authService =
        ref.watch(robustAuthServiceProvider);
    final _StartupShell shell = _resolveShell(authService);

    if (shell == _StartupShell.firebaseWaiting && kDebugMode) {
      debugPrint(
        '⚠️ AppStartupWrapper: Firebase not ready yet - showing splash screen',
      );
    } else if (Firebase.apps.isEmpty && kDebugMode) {
      debugPrint(
        '⚠️ AppStartupWrapper: Firebase unavailable after startup grace period - continuing to auth UI',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '🎯 AppStartupWrapper: shell=$shell, isLoggedIn=${authService.isLoggedIn}, shouldShowLoading=${authService.shouldShowLoading}, isCheckingAuth=${authService.isCheckingAuth}',
      );
    }

    switch (shell) {
      case _StartupShell.firebaseWaiting:
      case _StartupShell.loading:
        return KeyedSubtree(
          key: const ValueKey<String>('app_startup_loading'),
          child: _buildLoadingScreen(),
        );
      case _StartupShell.home:
        if (kDebugMode) {
          debugPrint('🏠 AppStartupWrapper: Returning verified shell');
        }
        return KeyedSubtree(
          key: const ValueKey<String>('app_startup_home'),
          child: _EmailVerificationOrHome(
            initialTabIndex: widget.initialTabIndex,
          ),
        );
      case _StartupShell.auth:
        if (kDebugMode) {
          debugPrint('🔐 AppStartupWrapper: Showing auth modal');
        }
        return const KeyedSubtree(
          key: ValueKey<String>('app_startup_auth'),
          child: AuthModalView(),
        );
    }
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
              const Text(
                'Connect - Create - Share',
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

/// Blocks [MainTabView] until Firebase reports [User.emailVerified] (web parity).
class _EmailVerificationOrHome extends StatefulWidget {
  const _EmailVerificationOrHome({required this.initialTabIndex});

  final int initialTabIndex;

  @override
  State<_EmailVerificationOrHome> createState() =>
      _EmailVerificationOrHomeState();
}

class _EmailVerificationOrHomeState extends State<_EmailVerificationOrHome> {
  final GlobalKey _mainTabKey = GlobalKey();
  late bool _verified;
  String _email = '';

  @override
  void initState() {
    super.initState();
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    _verified = user?.emailVerified ?? true;
    _email = user?.email ?? '';
    unawaited(_syncVerification());
  }

  Future<void> _syncVerification() async {
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _verified = true;
        });
      });
      return;
    }
    try {
      await user.reload().timeout(const Duration(seconds: 2));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Email verification refresh deferred: $e');
      }
    }
    final fa.User? fresh = fa.FirebaseAuth.instance.currentUser;
    if (!mounted) {
      return;
    }
    final bool nextVerified = fresh?.emailVerified ?? false;
    final String nextEmail = fresh?.email ?? '';
    if (_verified == nextVerified && _email == nextEmail) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _verified = nextVerified;
        _email = nextEmail;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_verified) {
      return KeyedSubtree(
        key: const ValueKey<String>('app_startup_email_verification'),
        child: EmailVerificationView(
          email: _email,
          navigateToHomeOnVerify: false,
          onVerified: () {
            _syncVerification();
          },
        ),
      );
    }
    return KeyedSubtree(
      key: const ValueKey<String>('app_startup_main_tab'),
      child: AccountStatusGuard(
        child: MainTabView(
          key: _mainTabKey,
          initialTabIndex: widget.initialTabIndex,
        ),
      ),
    );
  }
}
