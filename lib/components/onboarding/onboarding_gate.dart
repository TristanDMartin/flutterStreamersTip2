import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/playback_owners.dart';
import '../../controllers/home_view_controller.dart';
import '../../features/onboarding_tippy/tippy_onboarding_attach_pending.dart';
import '../../features/onboarding_tippy/tippy_onboarding_contract.dart';
import '../../features/onboarding_tippy/tippy_onboarding_session.dart';
import '../../features/onboarding_tippy/tippy_onboarding_view.dart';
import '../../services/global_playback_manager.dart';
import '../../utils/auth_post_login_navigation.dart';
import '../../utils/secure_log.dart';
import '../../widgets/email_verification_view.dart';
import 'onboarding_engagement_coordinator.dart';
import 'onboarding_models.dart';
import 'onboarding_service.dart';
import '../../services/tester_promo_data_service.dart';
import '../../services/app_session_cache.dart';
import 'onboarding_tester_config.dart';
import 'onboarding_style.dart';
import 'onboarding_v1_constants.dart';
import 'onboarding_view.dart';
import 'widgets/onboarding_full_screen_shell.dart';

/// Single onboarding gate — Firestore is source of truth.
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
  bool _isReady = false;
  bool _testerSessionDismissed = false;
  bool _checkedTesterReset = false;
  bool _isTesterSession = false;
  bool _onboardingPlaybackBlocked = false;
  bool _emailGateDismissed = false;
  bool _onboardingStatusConfirmed = false;
  StreamSubscription<OnboardingState>? _subscription;
  TippyOnboardingGuestSession? _localTippySession;
  bool _resumeLocalTippy = false;

  bool get _shouldShowTippyOnboarding {
    // Server-confirmed Tippy completion always wins over a stale local resume
    // flag (landing used to remount Tippy via nested Navigator → old stage).
    if (_state.tippyFunnelCompleted && _state.essentialProfileComplete) {
      return false;
    }
    if (_state.completed && !_state.isTippyFunnelIncomplete) {
      return false;
    }
    return _state.isTippyFunnelIncomplete || _resumeLocalTippy;
  }

  bool get _shouldShowMainApp {
    if (!_isReady) {
      return false;
    }
    if (_isTesterSession) {
      return _testerSessionDismissed;
    }
    // Tippy funnel owns the rest of setup — never drop into classic onboarding
    // or the feed after Google/Apple until landing choice is done.
    if (_shouldShowTippyOnboarding) {
      return false;
    }
    // Keep Home visible until Firestore confirms onboarding is incomplete.
    if (!_onboardingStatusConfirmed) {
      return true;
    }
    return _state.completed;
  }

  bool get _isShowingOnboarding => _isReady && !_shouldShowMainApp;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingService();
    OnboardingEngagementCoordinator.instance.markAppLaunched();
    unawaited(_bootstrap());
  }

  bool get _needsEmailGate {
    if (_emailGateDismissed || _isTesterSession) {
      return false;
    }
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    if (user == null || !firebaseUserNeedsEmailVerification(user)) {
      return false;
    }
    return !_state.hasSeenIntro && !_state.completed;
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
      _emailGateDismissed = false;
      _checkedTesterReset = false;
      _releaseOnboardingPlaybackBlock();
      unawaited(_bootstrap());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _releaseOnboardingPlaybackBlock();
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
      ref
          .read(homeViewControllerProvider.notifier)
          .resumeAfterOnboardingCompleted();
    });
  }

  OnboardingState _optimisticCompletedForExistingSession({
    OnboardingState? base,
  }) {
    final OnboardingState seed = base ?? _state;
    // Never promote Tippy / slim-7 users into the main app without an
    // essential creator identity (display name + unique username).
    if (seed.needsTippyGuidedProfile ||
        seed.isTippyFunnelIncomplete ||
        !seed.essentialProfileComplete) {
      final String username = widget.username?.trim() ?? '';
      if (username.isEmpty ||
          seed.slim7Completed ||
          seed.tippyOnboardingV1Attached ||
          seed.isTippyFunnelIncomplete) {
        return OnboardingState(
          version: seed.version,
          status: OnboardingStatus.inProgress,
          completed: false,
          currentStep: seed.currentStep,
          hasSeenIntro: seed.hasSeenIntro,
          creatorGoals: seed.creatorGoals,
          platforms: seed.platforms,
          premiumOfferDismissed: seed.premiumOfferDismissed,
          completedAt: seed.completedAt,
          lastSeenAt: seed.lastSeenAt,
          emailBannerDismissed: seed.emailBannerDismissed,
          softRatingDismissed: seed.softRatingDismissed,
          hasRated: seed.hasRated,
          hasSeenMissionBannerOnHome: seed.hasSeenMissionBannerOnHome,
          missionBannerDismissed: seed.missionBannerDismissed,
          slim7Completed: seed.slim7Completed,
          tippyOnboardingV1Attached: seed.tippyOnboardingV1Attached,
          tippyFunnelCompleted: seed.tippyFunnelCompleted,
          essentialProfileComplete: false,
        );
      }
    }
    return OnboardingState(
      version: OnboardingV1Constants.version,
      status: OnboardingStatus.completed,
      completed: true,
      currentStep: OnboardingV1Constants.completedStepMarker,
      hasSeenIntro: true,
      creatorGoals: seed.creatorGoals,
      platforms: seed.platforms,
      premiumOfferDismissed: seed.premiumOfferDismissed,
      completedAt: seed.completedAt,
      lastSeenAt: seed.lastSeenAt,
      emailBannerDismissed: seed.emailBannerDismissed,
      softRatingDismissed: seed.softRatingDismissed,
      hasRated: seed.hasRated,
      hasSeenMissionBannerOnHome: seed.hasSeenMissionBannerOnHome,
      missionBannerDismissed: seed.missionBannerDismissed,
      slim7Completed: seed.slim7Completed,
      tippyOnboardingV1Attached: seed.tippyOnboardingV1Attached,
      tippyFunnelCompleted: seed.tippyFunnelCompleted,
      essentialProfileComplete: seed.essentialProfileComplete,
    );
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
    final String username = widget.username?.trim() ?? '';
    if (username.isEmpty) {
      secureLog(
        'ONBOARDING_KEEP_INCOMPLETE reason=missing_username_bootstrap',
      );
      return OnboardingState.initial();
    }
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    if (user != null && user.uid == widget.userId) {
      secureLog(
        'ONBOARDING_CONFIRMED_SKIPPED_EXISTING_USER reason=bootstrap_timeout',
      );
      return _optimisticCompletedForExistingSession(base: cached);
    }
    return OnboardingState.initial();
  }

  OnboardingState _resolveBootstrapFailureState() {
    return _resolveBootstrapTimeoutState();
  }

  Future<void> _bootstrap() async {
    await _refreshLocalTippyResume();
    final OnboardingState? cached =
        AppSessionCache.instance.peekOnboarding(widget.userId);
    if (cached != null && mounted) {
      setState(() {
        _state = cached;
        _isReady = true;
      });
      _syncOnboardingPlaybackState();
    }
    try {
      final OnboardingState migrated = await _loadOnboardingState().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
            'OnboardingGate: bootstrap timed out — keeping Home for existing user',
          );
          return _resolveBootstrapTimeoutState();
        },
      );
      if (!mounted) {
        return;
      }
      await _refreshLocalTippyResume();
      setState(() {
        _state = migrated;
        _isReady = true;
        _onboardingStatusConfirmed = true;
      });
      AppSessionCache.instance.putOnboarding(widget.userId, migrated);
      debugPrint(
        'OnboardingGate: ready completed=${migrated.completed} '
        'step=${migrated.currentStep} tippy=$_shouldShowTippyOnboarding',
      );
      _syncOnboardingPlaybackState();
      _subscription?.cancel();
      _subscription = _service.watchOnboarding(widget.userId).listen(
        (OnboardingState state) {
          if (!mounted) {
            return;
          }
          final bool wasShowingOnboarding = _isShowingOnboarding;
          final bool tippyDone = state.tippyFunnelCompleted &&
              state.essentialProfileComplete;
          setState(() {
            _state = state;
            if (tippyDone || (state.completed && !state.isTippyFunnelIncomplete)) {
              _resumeLocalTippy = false;
              _localTippySession = null;
            }
          });
          AppSessionCache.instance.putOnboarding(widget.userId, state);
          if (wasShowingOnboarding && _shouldShowMainApp) {
            _scheduleHomePlaybackRestoreAfterOnboarding();
          } else {
            _syncOnboardingPlaybackState();
          }
        },
      );
    } catch (error, stackTrace) {
      debugPrint('OnboardingGate bootstrap failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) {
        return;
      }
      await _refreshLocalTippyResume();
      setState(() {
        _state = _resolveBootstrapFailureState();
        _isReady = true;
        _onboardingStatusConfirmed = true;
      });
      _syncOnboardingPlaybackState();
    }
  }

  Future<void> _refreshLocalTippyResume() async {
    try {
      final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
      final TippyOnboardingGuestSession? session = await store.loadActive();
      final bool resume = tippySessionNeedsResume(session) ||
          (session != null &&
              session.landingChoice == null &&
              (session.hasCompletedQuestions ||
                  TippyOnboardingStages.isPostQuizStage(session.stage)));
      if (!mounted) {
        _localTippySession = session;
        _resumeLocalTippy = resume;
        return;
      }
      _localTippySession = session;
      _resumeLocalTippy = resume;
    } catch (_) {
      _localTippySession = null;
      _resumeLocalTippy = false;
    }
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
      email: widget.email ??
          fa.FirebaseAuth.instance.currentUser?.email,
      username: widget.username,
      displayName: widget.displayName,
      refreshRef: refreshRef,
    );
  }

  void _onOnboardingCompleted() {
    if (_isTesterSession) {
      setState(() {
        _testerSessionDismissed = true;
      });
      unawaited(_seedTesterPromoData(refreshRef: ref));
      _scheduleHomePlaybackRestoreAfterOnboarding();
      return;
    }
    setState(() {
      _state = OnboardingState(
        version: _state.version,
        status: OnboardingStatus.completed,
        completed: true,
        currentStep: OnboardingV1Constants.completedStepMarker,
        hasSeenIntro: true,
        creatorGoals: _state.creatorGoals,
        platforms: _state.platforms,
        premiumOfferDismissed: _state.premiumOfferDismissed,
        completedAt: _state.completedAt,
        lastSeenAt: _state.lastSeenAt,
        emailBannerDismissed: _state.emailBannerDismissed,
        softRatingDismissed: _state.softRatingDismissed,
        hasRated: _state.hasRated,
        hasSeenMissionBannerOnHome: _state.hasSeenMissionBannerOnHome,
        missionBannerDismissed: _state.missionBannerDismissed,
        slim7Completed: true,
        tippyOnboardingV1Attached: true,
        tippyFunnelCompleted: true,
        essentialProfileComplete: true,
      );
      _resumeLocalTippy = false;
      _localTippySession = null;
    });
    _scheduleHomePlaybackRestoreAfterOnboarding();
    unawaited(_refreshOnboardingAfterCompletion());
  }

  Future<void> _refreshOnboardingAfterCompletion() async {
    final OnboardingState state =
        await _service.fetchOnboarding(widget.userId);
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

  void _onEmailGateContinue() {
    setState(() {
      _emailGateDismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShowMainApp) {
      return widget.child;
    }
    // Firestore bootstrap runs in parallel — shell stays visible underneath.
    if (!_isReady) {
      return widget.child;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        OnboardingFullScreenShell(
          child: _OnboardingNavigator(
            child: _needsEmailGate
                ? EmailVerificationView(
                    email: widget.email ??
                        fa.FirebaseAuth.instance.currentUser?.email ??
                        '',
                    navigateToHomeOnVerify: false,
                    manageSystemUi: false,
                    onContinueToSetup: _onEmailGateContinue,
                    onVerified: _onEmailGateContinue,
                  )
                : _shouldShowTippyOnboarding
                    ? TippyOnboardingView(
                        startAtWelcome: false,
                        initialSession: _localTippySession,
                        onCompleted: _onOnboardingCompleted,
                      )
                    : OnboardingView(
                        key: ValueKey<String>('onboarding-${widget.userId}'),
                        userId: widget.userId,
                        initialState: _state,
                        service: _service,
                        showTesterSkip: _isTesterSession,
                        onCompleted: _onOnboardingCompleted,
                      ),
          ),
        ),
      ],
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
