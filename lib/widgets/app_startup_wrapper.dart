import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../core/firebase_bootstrap.dart';
import '../core/firebase_bootstrap_ready_provider.dart';
import '../core/theme/st_theme_tokens.dart';
import '../services/auth_transition_state.dart';
import '../services/robust_auth_service.dart';
import '../services/calendar_cleanup_service.dart';
import '../services/global_playback_manager.dart';
import '../pages/main_tab_view.dart';
import 'account_status_guard.dart';
import 'auth_modal_view.dart';

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
  required bool isSigningIn,
  bool allowDegradedAuthShell = false,
  bool isAwaiting2FA = false,
}) {
  if (!firebaseInitialized) {
    if (allowDegradedAuthShell && startupGracePeriodElapsed) {
      return StartupShell.auth;
    }
    return StartupShell.loading;
  }
  if (resolveStartupShowsAuthLoading(
    isSigningOut: isSigningOut,
    hasFirebaseUser: hasFirebaseUser,
    isCheckingAuth: isCheckingAuth,
    isOauthInProgress: isOauthInProgress,
    isSigningIn: isSigningIn,
    authConnectionState: authConnectionState,
  )) {
    return StartupShell.loading;
  }
  if (isAwaiting2FA && hasFirebaseUser) {
    return StartupShell.auth;
  }
  return hasFirebaseUser ? StartupShell.home : StartupShell.auth;
}

class _AppStartupWrapperState extends ConsumerState<AppStartupWrapper> {
  final bool _firebaseStartupGracePeriodElapsed = true;
  bool _calendarCleanupStarted = false;
  Timer? _firebaseReadyPollTimer;
  Widget? _cachedHomeShell;
  String? _cachedHomeUid;
  static const Duration _firebaseReadyPollInterval =
      Duration(milliseconds: 150);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyThemeSystemUi();
  }

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    _startFirebaseReadyPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      precacheImage(
        const AssetImage('assets/logo.png'),
        context,
      );
    });
    ref.listenManual<(bool, bool)>(
      robustAuthServiceProvider.select(
        (RobustAuthenticationService auth) =>
            (auth.shouldShowLoading, auth.isLoggedIn),
      ),
      _onAuthStateChanged,
    );
  }

  void _startFirebaseReadyPolling() {
    if (FirebaseBootstrap.isReady) {
      return;
    }
    unawaited(
      FirebaseBootstrap.ensureInitialized().then((bool ready) {
        if (ready && mounted) {
          setState(() {});
        }
      }),
    );
    _firebaseReadyPollTimer?.cancel();
    _firebaseReadyPollTimer = Timer.periodic(
      _firebaseReadyPollInterval,
      (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (FirebaseBootstrap.isReady) {
          timer.cancel();
          _firebaseReadyPollTimer = null;
          setState(() {});
          return;
        }
        unawaited(
          FirebaseBootstrap.ensureInitialized().then((bool ready) {
            if (ready && mounted) {
              timer.cancel();
              _firebaseReadyPollTimer = null;
              setState(() {});
            }
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _firebaseReadyPollTimer?.cancel();
    _firebaseReadyPollTimer = null;
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
    // AuthModalView shows its own overlay during OAuth; skip root rebuilds
    // that would remount the sign-in screen while the picker is opening.
    if (loadingChanged && !loginChanged) {
      bool isOauthInProgress = false;
      try {
        isOauthInProgress =
            ref.read(robustAuthServiceProvider).isOauthInProgress;
      } catch (_) {
        return;
      }
      if (isOauthInProgress) {
        return;
      }
    }
    if (GlobalPlaybackManager.instance.isStartupLocked &&
        !loginChanged &&
        next.$2) {
      if (kDebugMode) {
        debugPrint(
          '⏸️ AppStartupWrapper: Skipping auth rebuild during startup lock',
        );
      }
      return;
    }
    if (next.$2 && !next.$1) {
      _runCalendarCleanup();
    }
    if (next.$2 && !previous.$2) {
      GlobalPlaybackManager.instance.forceUnblock();
    }
    if (!next.$2 && previous.$2) {
      GlobalPlaybackManager.instance.teardownForSignOut();
      _cachedHomeShell = null;
      _cachedHomeUid = null;
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
    final bool firebaseReady = ref.watch(firebaseBootstrapReadyProvider) &&
        FirebaseBootstrap.isReady;
    if (!firebaseReady) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ AppStartupWrapper: Firebase not ready yet - showing splash screen',
        );
      }
      final StartupShell shell = resolveStartupShell(
        firebaseInitialized: false,
        startupGracePeriodElapsed: _firebaseStartupGracePeriodElapsed,
        allowDegradedAuthShell: true,
        authConnectionState: ConnectionState.waiting,
        hasFirebaseUser: false,
        isSigningOut: authService.isSigningOut,
        isCheckingAuth: authService.isCheckingAuth,
        isOauthInProgress: authService.isOauthInProgress,
        isSigningIn: authService.isSigningIn,
        isAwaiting2FA: authService.isAwaiting2FA,
      );
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
        final fa.User? firebaseUser =
            snapshot.data ?? fa.FirebaseAuth.instance.currentUser;
        final ConnectionState authConnectionState =
            resolveEffectiveAuthConnectionState(
          authConnectionState: snapshot.connectionState,
          hasAuthSnapshotData: snapshot.hasData,
          hasFirebaseUser: firebaseUser != null,
        );
        if (kDebugMode) {
          debugPrint(
            'AUTH STATE CHANGED: ${snapshot.data?.uid ?? 'SIGNED OUT'} '
            'connection=${snapshot.connectionState.name} '
            'effective=${authConnectionState.name}',
          );
        }
        final StartupShell shell = resolveStartupShell(
          firebaseInitialized: true,
          startupGracePeriodElapsed: _firebaseStartupGracePeriodElapsed,
          authConnectionState: authConnectionState,
          hasFirebaseUser: firebaseUser != null,
          isSigningOut: authService.isSigningOut,
          isCheckingAuth: authService.isCheckingAuth,
          isOauthInProgress: authService.isOauthInProgress,
          isSigningIn: authService.isSigningIn,
          isAwaiting2FA: authService.isAwaiting2FA,
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
        if (GlobalPlaybackManager.instance.isStartupLocked &&
            _cachedHomeShell != null &&
            shell == StartupShell.home &&
            firebaseUser?.uid != null &&
            firebaseUser!.uid == _cachedHomeUid) {
          if (kDebugMode) {
            debugPrint(
              '⏸️ AppStartupWrapper: Returning cached home shell '
              'during startup lock',
            );
          }
          return _cachedHomeShell!;
        }
        final Widget resolved = _buildResolvedShell(shell, authService);
        if (shell == StartupShell.home && firebaseUser?.uid != null) {
          _cachedHomeShell = resolved;
          _cachedHomeUid = firebaseUser!.uid;
        }
        return resolved;
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
                  errorBuilder: (BuildContext context, Object error,
                      StackTrace? stackTrace) {
                    return Image.asset(
                      'assets/app_logo.PNG',
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object error,
                          StackTrace? stackTrace) {
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

/// Routes signed-in users to [MainTabView]. Email verification is a soft gate
/// during onboarding, not a hard block on the app shell.
class _EmailVerificationOrHome extends StatelessWidget {
  const _EmailVerificationOrHome({required this.initialTabIndex});

  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('app_startup_main_tab'),
      child: AccountStatusGuard(
        child: MainTabView(
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }
}
