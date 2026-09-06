import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/playback_owners.dart';
import '../../controllers/home_view_controller.dart';
import '../../features/onboarding_tippy/tippy_onboarding_session.dart';
import '../../features/onboarding_tippy/tippy_onboarding_view.dart';
import '../../services/global_playback_manager.dart';
import '../../utils/secure_log.dart';
import 'account_navigation.dart';
import 'account_status_client.dart';
import 'authenticated_app_shell_ready.dart';
import 'onboarding_engagement_coordinator.dart';
import 'onboarding_models.dart';
import 'onboarding_service.dart';
import '../../services/tester_promo_data_service.dart';
import '../../services/app_session_cache.dart';
import 'onboarding_tester_config.dart';
import 'onboarding_style.dart';
import 'widgets/onboarding_full_screen_shell.dart';

/// Single onboarding gate — /api/account/status owns navigation.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({
    super.key,
    required this.userId,
    required this.child,
    this.email,
    this.username,
    this.displayName,
    this.service,
  });

  final String userId;
  final Widget child;
  final String? email;
  final String? username;
  final String? displayName;
  final OnboardingService? service;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  late OnboardingService _service;
  OnboardingState _state = OnboardingState.initial();
  AccountStatusSnapshot? _accountStatus;
  bool _isReady = false;
  bool _testerSessionDismissed = false;
  bool _checkedTesterReset = false;
  bool _isTesterSession = false;
  bool _onboardingPlaybackBlocked = false;
  bool _activationCommitted = false;
  StreamSubscription<OnboardingState>? _subscription;
  TippyOnboardingGuestSession? _localTippySession;
  String? _signupClosedFloor;
  bool _verifyFloorReleased = false;

  bool get _localOnboardingComplete =>
      _state.completed && !_state.isTippyFunnelIncomplete;

  bool get _passwordNeedsVerify {
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    if (user == null || user.emailVerified) {
      return false;
    }
    return user.providerData.any(
      (fa.UserInfo info) => info.providerId == 'password',
    );
  }

  String? get _effectiveStatusRoute => effectiveOnboardingStatusRoute(
        statusRoute: _accountStatus?.navigation.route,
        passwordNeedsVerify: _passwordNeedsVerify,
        hasSignupClosedFloor: _signupClosedFloor != null,
        verifyFloorReleased: _verifyFloorReleased,
      );

  bool get _shouldShowTippyOnboarding {
    if (!_isReady) {
      return false;
    }
    return shouldShowAuthenticatedOnboardingShell(
      activationCommitted: _activationCommitted,
      isTesterSession: _isTesterSession,
      testerSessionDismissed: _testerSessionDismissed,
      statusRoute: _effectiveStatusRoute,
      localOnboardingComplete: _localOnboardingComplete,
    );
  }

  bool get _shouldShowMainApp {
    if (!_isReady) {
      return false;
    }
    if (_passwordNeedsVerify && !_verifyFloorReleased) {
      return false;
    }
    return shouldBootAuthenticatedAppShell(
      activationCommitted: _activationCommitted,
      isTesterSession: _isTesterSession,
      testerSessionDismissed: _testerSessionDismissed,
      statusRoute: _effectiveStatusRoute,
      localOnboardingComplete: _localOnboardingComplete,
    );
  }

  bool get _isShowingOnboarding => _shouldShowTippyOnboarding;

  void _syncAuthenticatedAppShellReady() {
    final bool ready = _shouldShowMainApp;
    final bool current = ref.read(authenticatedAppShellReadyProvider);
    if (current != ready) {
      ref.read(authenticatedAppShellReadyProvider.notifier).state = ready;
    }
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingService();
    OnboardingEngagementCoordinator.instance.markAppLaunched();
    unawaited(_bootstrap());
  }

  @override
  void didUpdateWidget(OnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.service != widget.service) {
      _subscription?.cancel();
      _service = widget.service ?? OnboardingService();
      _isReady = false;
      _testerSessionDismissed = false;
      _checkedTesterReset = false;
      _accountStatus = null;
      _activationCommitted = false;
      _releaseOnboardingPlaybackBlock();
      unawaited(_bootstrap());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _releaseOnboardingPlaybackBlock();
    try {
      ref.read(authenticatedAppShellReadyProvider.notifier).state = false;
    } catch (_) {
      /* provider may already be disposed */
    }
    super.dispose();
  }

  void _blockPlaybackForOnboarding() {
    if (_onboardingPlaybackBlocked) {
      return;
    }
    _onboardingPlaybackBlocked = true;
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    manager.block(reason: 'onboarding');
    manager.pauseAll();
  }

  void _releaseOnboardingPlaybackBlock() {
    if (!_onboardingPlaybackBlocked) {
      return;
    }
    GlobalPlaybackManager.instance.unblock();
    _onboardingPlaybackBlocked = false;
  }

  void _syncOnboardingPlaybackState() {
    if (_isShowingOnboarding) {
      _blockPlaybackForOnboarding();
      return;
    }
    _releaseOnboardingPlaybackBlock();
  }

  void _scheduleHomePlaybackRestoreAfterOnboarding() {
    _releaseOnboardingPlaybackBlock();
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    if (!manager.isHomeMainTabSelected) {
      return;
    }
    if (manager.isPlaybackBlocked) {
      manager.forceUnblock();
    }
    manager.setVisibleOwner(PlaybackOwners.home);
    manager.setActiveOwner(PlaybackOwners.home);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isShowingOnboarding) {
        return;
      }
      if (!GlobalPlaybackManager.instance.isHomeMainTabSelected) {
        return;
      }
      Future<void>.delayed(Duration.zero, () {
        if (!mounted || _isShowingOnboarding) {
          return;
        }
        ref
            .read(homeViewControllerProvider.notifier)
            .resumeAfterOnboardingCompleted();
      });
    });
  }

  OnboardingState _resolveBootstrapTimeoutState() {
    final OnboardingState? cached =
        AppSessionCache.instance.peekOnboarding(widget.userId);
    if (cached != null) {
      if (cached.needsTippyGuidedProfile || !cached.completed) {
        secureLog(
          'ONBOARDING_KEEP_INCOMPLETE reason=cached_incomplete',
        );
        return cached;
      }
      if (cached.completed && cached.essentialProfileComplete) {
        secureLog(
          'ONBOARDING_CONFIRMED_SKIPPED_EXISTING_USER reason=cached_completed',
        );
        return cached;
      }
    }
    if (_localTippySession != null) {
      secureLog(
        'ONBOARDING_KEEP_INCOMPLETE reason=local_tippy_session',
      );
      return cached ?? OnboardingState.initial();
    }
    secureLog(
      'ONBOARDING_KEEP_INCOMPLETE reason=bootstrap_timeout_wait_status',
    );
    return cached ?? OnboardingState.initial();
  }

  OnboardingState _resolveBootstrapFailureState() {
    return _resolveBootstrapTimeoutState();
  }

  Future<void> _bootstrap() async {
    await _refreshLocalTippyResume();
    final TippyOnboardingSessionStore tippyStore = TippyOnboardingSessionStore();
    _signupClosedFloor = await tippyStore.peekSignupClosedFloor();
    _verifyFloorReleased = await tippyStore.peekVerifyFloorReleased();
    if (_passwordNeedsVerify && !_verifyFloorReleased) {
      _accountStatus = const AccountStatusSnapshot(
        activationState: 'EMAIL_VERIFICATION_REQUIRED',
        tippyStageHint: 'verify_email',
        allowApp: false,
        lifecycle: 'PENDING_VERIFICATION',
        provisioned: false,
      );
      if (mounted) {
        setState(() {
          _isReady = true;
        });
        _syncOnboardingPlaybackState();
        _syncAuthenticatedAppShellReady();
      }
    }
    final OnboardingState? cached =
        AppSessionCache.instance.peekOnboarding(widget.userId);
    if (cached != null && mounted) {
      setState(() {
        _state = cached;
        _isReady = true;
      });
      _syncOnboardingPlaybackState();
      _syncAuthenticatedAppShellReady();
    }
    try {
      // 1J.5: status first — do not run ensureMigrated / heavy user writes
      // until the server says this account may use the app shell.
      AccountStatusSnapshot? status;
      if (!_isTesterSession) {
        try {
          status = await fetchAccountStatus();
        } catch (error) {
          secureLog('ONBOARDING_STATUS_FAILED error=$error');
        }
      }
      final String? statusRoute = effectiveOnboardingStatusRoute(
        statusRoute: status?.navigation.route,
        passwordNeedsVerify: _passwordNeedsVerify,
        hasSignupClosedFloor: _signupClosedFloor != null,
        verifyFloorReleased: _verifyFloorReleased,
      );
      final bool needsOnboardingShell =
          statusRoute == 'onboarding' || statusRoute == 'verify-email';

      final OnboardingState migrated = needsOnboardingShell
          ? await _service.fetchOnboarding(widget.userId).timeout(
                const Duration(seconds: 10),
                onTimeout: _resolveBootstrapTimeoutState,
              )
          : await _loadOnboardingState().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint(
                  'OnboardingGate: bootstrap timed out — keeping incomplete until status',
                );
                return _resolveBootstrapTimeoutState();
              },
            );
      if (!mounted) {
        return;
      }
      await _refreshLocalTippyResume();
      _signupClosedFloor = await tippyStore.peekSignupClosedFloor();
      _verifyFloorReleased = await tippyStore.peekVerifyFloorReleased();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = migrated;
        if (status != null &&
            !(_passwordNeedsVerify &&
                !_verifyFloorReleased &&
                status.navigation.route == 'app')) {
          _accountStatus = status;
        }
        _isReady = true;
      });
      AppSessionCache.instance.putOnboarding(widget.userId, migrated);
      debugPrint(
        'OnboardingGate: ready completed=${migrated.completed} '
        'step=${migrated.currentStep} tippy=$_shouldShowTippyOnboarding',
      );
      _syncOnboardingPlaybackState();
      _syncAuthenticatedAppShellReady();
      _ensureAppShellListeners();
      // Tippy owns local session during onboarding — no continuous users/{uid} watch.
    } catch (error, stackTrace) {
      debugPrint('OnboardingGate bootstrap failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) {
        return;
      }
      await _refreshLocalTippyResume();
      setState(() {
        _state = _resolveBootstrapFailureState();
        if (!(_passwordNeedsVerify && !_verifyFloorReleased)) {
          _accountStatus = null;
        }
        _isReady = true;
      });
      _syncOnboardingPlaybackState();
      _syncAuthenticatedAppShellReady();
    }
  }

  Future<void> _refreshLocalTippyResume() async {
    try {
      final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
      final TippyOnboardingGuestSession? session = await store.loadActive();
      _localTippySession = session;
    } catch (_) {
      _localTippySession = null;
    }
  }

  Future<void> _refreshAccountStatus() async {
    if (_isTesterSession) {
      return;
    }
    try {
      final AccountStatusSnapshot status = await fetchAccountStatus();
      if (!mounted) {
        return;
      }
      if (_passwordNeedsVerify &&
          !_verifyFloorReleased &&
          status.navigation.route == 'app') {
        return;
      }
      final bool wasShowingOnboarding = _isShowingOnboarding;
      setState(() {
        _accountStatus = status;
      });
      _syncAuthenticatedAppShellReady();
      _ensureAppShellListeners();
      if (wasShowingOnboarding && _shouldShowMainApp) {
        _scheduleHomePlaybackRestoreAfterOnboarding();
      } else {
        _syncOnboardingPlaybackState();
      }
    } catch (error) {
      secureLog('ONBOARDING_STATUS_REFRESH_FAILED error=$error');
    }
  }

  void _ensureAppShellListeners() {
    if (!_shouldShowMainApp || _subscription != null) {
      return;
    }
    _subscription = _service.watchOnboarding(widget.userId).listen(
      (OnboardingState state) {
        if (!mounted) {
          return;
        }
        final bool wasShowingOnboarding = _isShowingOnboarding;
        final bool tippyDone =
            state.tippyFunnelCompleted && state.essentialProfileComplete;
        setState(() {
          _state = state;
          if (tippyDone ||
              (state.completed && !state.isTippyFunnelIncomplete)) {
            _localTippySession = null;
          }
        });
        AppSessionCache.instance.putOnboarding(widget.userId, state);
        unawaited(_refreshAccountStatus());
        if (wasShowingOnboarding && _shouldShowMainApp) {
          _scheduleHomePlaybackRestoreAfterOnboarding();
        } else {
          _syncOnboardingPlaybackState();
        }
        _syncAuthenticatedAppShellReady();
      },
    );
  }

  Future<OnboardingState> _loadOnboardingState() async {
    final bool isTester = OnboardingTesterConfig.isTesterUser(
      userId: widget.userId,
      email: widget.email,
      username: widget.username,
      displayName: widget.displayName,
    );
    _isTesterSession = isTester;
    if (isTester) {
      _checkedTesterReset = true;
      await _service.resetForDeveloperTesterInstall(widget.userId);
      unawaited(_seedTesterPromoData(refreshRef: ref));
    } else {
      await _resetTesterIfNeeded();
    }
    if (isTester) {
      return _service.fetchOnboarding(widget.userId);
    }
    return _service.ensureMigrated(widget.userId);
  }

  Future<void> _resetTesterIfNeeded() async {
    if (_checkedTesterReset) {
      return;
    }
    _checkedTesterReset = true;
    final bool isTester = OnboardingTesterConfig.isTesterUser(
      userId: widget.userId,
      email: widget.email,
      username: widget.username,
      displayName: widget.displayName,
    );
    if (isTester) {
      _isTesterSession = true;
      await _service.resetForDeveloperTesterInstall(widget.userId);
    }
  }

  Future<void> _seedTesterPromoData({WidgetRef? refreshRef}) async {
    await TesterPromoDataService.instance.ensureSeeded(
      userId: widget.userId,
      email: widget.email ?? fa.FirebaseAuth.instance.currentUser?.email,
      username: widget.username,
      displayName: widget.displayName,
      refreshRef: refreshRef,
    );
  }

  void _onOnboardingCompleted() {
    if (_passwordNeedsVerify && !_verifyFloorReleased) {
      return;
    }
    if (_isTesterSession) {
      setState(() {
        _testerSessionDismissed = true;
      });
      unawaited(_seedTesterPromoData(refreshRef: ref));
      _scheduleHomePlaybackRestoreAfterOnboarding();
      return;
    }
    setState(() {
      _activationCommitted = true;
      _localTippySession = null;
    });
    _syncAuthenticatedAppShellReady();
    _ensureAppShellListeners();
    unawaited(_refreshAccountStatus());
    unawaited(_refreshOnboardingAfterCompletion());
  }

  Future<void> _refreshOnboardingAfterCompletion() async {
    final OnboardingState state = await _service.fetchOnboarding(widget.userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _state = state;
    });
    if (state.completed) {
      _scheduleHomePlaybackRestoreAfterOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const _AuthenticatedOnboardingSplash();
    }
    if (_shouldShowTippyOnboarding) {
      return OnboardingFullScreenShell(
        child: _OnboardingNavigator(
          child: TippyOnboardingView(
            startAtWelcome: false,
            initialSession: _localTippySession,
            onCompleted: _onOnboardingCompleted,
          ),
        ),
      );
    }
    if (_shouldShowMainApp) {
      return widget.child;
    }
    return const _AuthenticatedOnboardingSplash();
  }
}

class _AuthenticatedOnboardingSplash extends StatelessWidget {
  const _AuthenticatedOnboardingSplash();

  @override
  Widget build(BuildContext context) {
    // 1J.5 / 1J.1: chrome-only — no full-page spinner flash.
    return const OnboardingFullScreenShell(
      child: SizedBox.expand(),
    );
  }
}

/// Local navigator so onboarding sheets and pushes render above the flow.
class _OnboardingNavigator extends StatelessWidget {
  const _OnboardingNavigator({required this.child});

  final Widget child;

  static const String rootRoute = '/onboarding-root';

  Widget _wrapWithMaterial(BuildContext context) {
    return Material(
      color: OnboardingStyle.background,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope.none(
      child: Navigator(
        onGenerateInitialRoutes: (
          NavigatorState navigator,
          String initialRoute,
        ) {
          return <Route<dynamic>>[
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: rootRoute),
              builder: _wrapWithMaterial,
            ),
          ];
        },
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: _wrapWithMaterial,
          );
        },
      ),
    );
  }
}
