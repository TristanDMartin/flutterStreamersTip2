import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import '../core/theme/st_theme_tokens.dart';
import '../services/auth_transition_state.dart';
import '../services/robust_auth_service.dart';
import '../services/calendar_cleanup_service.dart';
import '../utils/auth_post_login_navigation.dart';
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

enum StartupShell { firebaseWaiting, loading, home, auth }

StartupShell resolveStartupShell({
  required bool firebaseInitialized,
  required bool startupGracePeriodElapsed,
  required ConnectionState authConnectionState,
  required bool hasFirebaseUser,
  required bool isSigningOut,
  required bool isCheckingAuth,
  required bool isOauthInProgress,
}) {
  // Keep splash until Firebase is ready — avoids auth flash on slow cold start.
  if (!firebaseInitialized) {
    return StartupShell.loading;
  }
  if (resolveStartupShowsAuthLoading(
    isSigningOut: isSigningOut,
    hasFirebaseUser: hasFirebaseUser,
    isCheckingAuth: isCheckingAuth,
    isOauthInProgress: isOauthInProgress,
    authConnectionState: authConnectionState,
  )) {
    return StartupShell.loading;
  }
  return hasFirebaseUser ? StartupShell.home : StartupShell.auth;
}

class _AppStartupWrapperState extends ConsumerState<AppStartupWrapper> {
  bool _firebaseStartupGracePeriodElapsed = false;
  bool _calendarCleanupStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyThemeSystemUi();
  }

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    ref.listenManual<(bool, bool)>(
      robustAuthServiceProvider.select(
        (RobustAuthenticationService auth) =>
            (auth.shouldShowLoading, auth.isLoggedIn),
      ),
      _onAuthStateChanged,
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

  void _onAuthStateChanged(
    (bool, bool)? previous,
    (bool, bool) next,
  ) {
    if (previous == null) {
      return;
    }
    final bool loadingChanged = previous.$1 != next.$1;
    final bool loginChanged = previous.$2 != next.$2;
    if (!loadingChanged && !loginChanged) {
      return;
    }
    if (next.$2 && !next.$1) {
      _runCalendarCleanup();
    }
    if (kDebugMode) {
      debugPrint('🔄 AppStartupWrapper: Auth state changed');
      debugPrint(
        '   Loading: ${previous.$1} -> ${next.$1}',
      );
      debugPrint(
        '   Logged in: ${previous.$2} -> ${next.$2}',
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

  void _setSystemUIOverlayStyle() {
    // Default chrome until [didChangeDependencies] applies theme-aware values.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _applyThemeSystemUi() {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: theme.colorScheme.surface,
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
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
    if (Firebase.apps.isEmpty) {
      final StartupShell shell = resolveStartupShell(
        firebaseInitialized: false,
        startupGracePeriodElapsed: _firebaseStartupGracePeriodElapsed,
        authConnectionState: ConnectionState.waiting,
        hasFirebaseUser: false,
        isSigningOut: authService.isSigningOut,
        isCheckingAuth: authService.isCheckingAuth,
        isOauthInProgress: authService.isOauthInProgress,
      );
      if (shell == StartupShell.firebaseWaiting && kDebugMode) {
        debugPrint(
          '⚠️ AppStartupWrapper: Firebase not ready yet - showing splash screen',
        );
      }
      if (shell == StartupShell.auth) {
        return const KeyedSubtree(
          key: ValueKey<String>('app_startup_auth'),
          child: AuthModalView(),
        );
      }
      return KeyedSubtree(
        key: const ValueKey<String>('app_startup_loading'),
        child: _buildLoadingScreen(),
      );
    }

    return StreamBuilder<fa.User?>(
      stream: fa.FirebaseAuth.instance.authStateChanges(),
      initialData: fa.FirebaseAuth.instance.currentUser,
      builder: (BuildContext context, AsyncSnapshot<fa.User?> snapshot) {
        if (kDebugMode) {
          debugPrint(
            'AUTH STATE CHANGED: ${snapshot.data?.uid ?? 'SIGNED OUT'} '
            'connection=${snapshot.connectionState.name}',
          );
        }
        final StartupShell shell = resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: _firebaseStartupGracePeriodElapsed,
          authConnectionState: snapshot.connectionState,
          hasFirebaseUser: snapshot.data != null,
          isSigningOut: authService.isSigningOut,
          isCheckingAuth: authService.isCheckingAuth,
          isOauthInProgress: authService.isOauthInProgress,
        );
        if (kDebugMode) {
          final String routeDecision = switch (shell) {
            StartupShell.home => 'HomeView/MainTabView',
            StartupShell.auth => 'SignInView/AuthModalView',
            StartupShell.loading => 'Loading',
            StartupShell.firebaseWaiting => 'FirebaseWaiting',
          };
          debugPrint(
            '🎯 AppStartupWrapper route=$routeDecision '
            'firebaseUid=${snapshot.data?.uid ?? 'null'} '
            'isSigningOut=${authService.isSigningOut} '
            'oauthInProgress=${authService.isOauthInProgress}',
          );
        }
        return _buildResolvedShell(shell, authService);
      },
    );
  }

  Widget _buildResolvedShell(
    StartupShell shell,
    RobustAuthenticationService authService,
  ) {
    if (shell == StartupShell.firebaseWaiting && kDebugMode) {
      debugPrint(
        '⚠️ AppStartupWrapper: Firebase not ready yet - showing splash screen',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '🎯 AppStartupWrapper: shell=$shell, authTransition=${authService.authTransitionState}, isLoggedIn=${authService.isLoggedIn}, shouldShowLoading=${authService.shouldShowLoading}',
      );
    }

    switch (shell) {
      case StartupShell.firebaseWaiting:
      case StartupShell.loading:
        return KeyedSubtree(
          key: const ValueKey<String>('app_startup_loading'),
          child: _buildLoadingScreen(),
        );
      case StartupShell.home:
        if (kDebugMode) {
          debugPrint('🏠 AppStartupWrapper: Returning verified shell');
        }
        return KeyedSubtree(
          key: const ValueKey<String>('app_startup_home'),
          child: _EmailVerificationOrHome(
            initialTabIndex: widget.initialTabIndex,
          ),
        );
      case StartupShell.auth:
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color onSurface = scheme.onSurface;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[
                    StThemeColors.darkBackground,
                    scheme.surfaceContainerLow,
                    scheme.surface,
                  ]
                : <Color>[
                    scheme.primary.withValues(alpha: 0.45),
                    scheme.surfaceContainerLow,
                    scheme.surface,
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Image.asset(
                      'assets/app_logo.PNG',
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                        return Icon(
                          Icons.play_circle_filled,
                          color: scheme.primary,
                          size: 120,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'StreamersTip',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect - Create - Share',
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.72),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
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
    _verified = !firebaseUserNeedsEmailVerification(user);
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
    final bool nextVerified = !firebaseUserNeedsEmailVerification(fresh);
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
