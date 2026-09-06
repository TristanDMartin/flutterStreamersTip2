import 'dart:async';
import 'tippy_onboarding_debug_log.dart';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../constants/app_colors.dart';
import '../../constants/playback_owners.dart';
import '../../controllers/home_view_controller.dart';
import '../../features/billing/upgrade_tier_marketing.dart';
import '../../routing/app_routes.dart';
import '../../services/global_playback_manager.dart';
import '../../services/pending_auth_redirect_service.dart';
import '../../services/robust_auth_service.dart';
import '../../views/upgrade_view.dart';
import '../../widgets/signup_view.dart';
import '../../components/onboarding/onboarding_service.dart';
import '../../components/onboarding/account_navigation.dart';
import '../../components/onboarding/account_status_client.dart';
import '../../components/onboarding/activation_state.dart';
import '../../components/onboarding/complete_verified_activation.dart';
import '../../components/onboarding/email_verification.dart';
import '../../components/onboarding/email_verification_intent_store.dart';
import '../../components/onboarding/email_verification_sender.dart';
import '../../services/contacts_service.dart';
import '../tippy/mascot/tippy_mascot.dart';
import '../tippy/mascot/tippy_mascot_types.dart';
import '../tippy/tippy_brain_client.dart';
import '../tippy/tippy_brain_contract.dart';
import 'tippy_guided_profile_host.dart';
import 'tippy_onboarding_analytics.dart';
import 'tippy_onboarding_attach_pending.dart';
import 'tippy_onboarding_attach_service.dart';
import 'tippy_onboarding_contract.dart';
import 'tippy_onboarding_feedback.dart';
import 'tippy_onboarding_host_presence.dart';
import 'tippy_onboarding_session.dart';
import 'tippy_profile_draft.dart';
import 'tippy_twitch_connect_service.dart';

const List<Color> _webOnboardingPrimaryGradient = <Color>[
  Color(0xFF6B3AA0),
  Color(0xFF4A2570),
];

const Duration _tippyWelcomeBeatTransitionDuration =
    Duration(milliseconds: 140);

/// Tippy-first onboarding funnel (pre-auth + post-auth stages).
class TippyOnboardingView extends ConsumerStatefulWidget {
  const TippyOnboardingView({
    super.key,
    this.initialSession,
    this.startAtWelcome = true,
    this.onCompleted,
  });

  final TippyOnboardingGuestSession? initialSession;

  /// When true and there is no progress yet, open on Meet Tippy.
  /// Mid-progress sessions always resume the exact step.
  final bool startAtWelcome;

  /// Fired after landing choice so [OnboardingGate] can dismiss the overlay.
  final VoidCallback? onCompleted;

  @override
  ConsumerState<TippyOnboardingView> createState() =>
      _TippyOnboardingViewState();
}

class _TippyOnboardingViewState extends ConsumerState<TippyOnboardingView>
    with WidgetsBindingObserver {
  final TippyOnboardingSessionStore _store = TippyOnboardingSessionStore();
  final TippyOnboardingAttachService _attachService =
      TippyOnboardingAttachService();
  final TippyOnboardingAnalyticsTracker _analytics =
      const TippyOnboardingAnalyticsTracker();
  final TippyTwitchConnectService _twitchConnectService =
      TippyTwitchConnectService();
  final TextEditingController _textController = TextEditingController();

  TippyOnboardingGuestSession? _session;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _providerSignInBusy = false;
  String? _error;
  TippyMascotState _mascotState = TippyMascotState.enter;
  List<String> _multiDraft = <String>[];

  /// 0 = meet Tippy, 1 = explain the seven questions.
  int _welcomeBeat = 0;
  TippyGuidedProfileBackConsumer? _guidedProfileBackConsumer;
  bool _trialCheckoutOffered = false;
  bool _awaitingTwitchOAuth = false;
  bool _twitchJustConnected = false;
  bool _stageMotionForward = true;
  String? _intendedVerificationUid;
  String? _intendedVerificationEmail;
  bool _isActivatingAccount = false;
  bool _isConfirmingVerification = false;
  String? _signupClosedFloor;
  bool _verifyFloorReleased = false;
  bool _postSignupHandled = false;
  bool _startedFromWelcome = false;
  bool _isFinishingLanding = false;
  bool _appleAvailable = false;
  Timer? _verifyEmailPollTimer;
  Timer? _twitchOAuthPollTimer;
  static const Duration _verifyEmailPollInterval = Duration(seconds: 2);
  static const Duration _twitchOAuthPollInterval = Duration(seconds: 2);

  Future<TippyOnboardingAttachResult> _attachSession(
    TippyOnboardingGuestSession session,
  ) async {
    if (!_startedFromWelcome) {
      _startedFromWelcome = await _store.peekStartedFromWelcome() ||
          session.hasSeenTippyIntro;
    }
    try {
      return await _attachService.attach(
        session,
        startedFromWelcome: _startedFromWelcome,
      );
    } on TippyOnboardingAttachException catch (error) {
      if (!isStaleOnboardingAttach(
            statusCode: error.statusCode,
            code: error.code,
            message: error.message,
          ) ||
          _startedFromWelcome) {
        rethrow;
      }
      _startedFromWelcome = true;
      await _store.markStartedFromWelcome();
      return _attachService.attach(
        session,
        startedFromWelcome: true,
      );
    }
  }

  Future<void> _attachSessionSoft(
    TippyOnboardingGuestSession session,
    String context,
  ) async {
    try {
      await _attachSession(session);
    } catch (error) {
      debugPrint('Tippy $context attach soft-skip: $error');
    }
  }

  Future<void> _sendVerificationEmailSoft({
    required firebase_auth.User user,
    required String sessionId,
  }) async {
    try {
      await sendBoundEmailVerification(
        user: user,
        onboardingSessionId: sessionId,
        resumePath: '/onboarding',
      );
    } catch (error) {
      debugPrint('Tippy verification email soft-skip: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TippyOnboardingHostPresence.enter();
    if (!kIsWeb) {
      unawaited(
        SignInWithApple.isAvailable().then((bool available) {
          if (mounted) {
            setState(() {
              _appleAvailable = available;
            });
          }
        }),
      );
    }
    unawaited(_bootstrap());
    ref.listenManual<RobustAuthenticationService>(
      robustAuthServiceProvider,
      (RobustAuthenticationService? previous,
          RobustAuthenticationService next) {
        if (!next.isLoggedIn) {
          return;
        }
        final firebase_auth.User? user =
            firebase_auth.FirebaseAuth.instance.currentUser;
        final bool needsVerify = user != null &&
            !user.emailVerified &&
            user.providerData.any(
              (firebase_auth.UserInfo info) => info.providerId == 'password',
            );
        if (needsVerify && !_verifyFloorReleased) {
          _lockSignupClosedAtVerifyEmailSync(
            uid: user.uid,
            email: user.email,
          );
        }
        if (_session == null || _postSignupHandled) {
          return;
        }
        if (_verifyFloorReleased && needsVerify) {
          return;
        }
        if (_session!.stage != TippyOnboardingStages.signup && !needsVerify) {
          return;
        }
        unawaited(_handleAuthenticated());
      },
    );
  }

  Future<void> _bootstrap() async {
    final bool deleteFlag = await _store.peekForceFreshAfterAccountDeletion();
    TippyOnboardingGuestSession session =
        widget.initialSession ?? await _store.loadOrCreate();
    _signupClosedFloor = await _store.peekSignupClosedFloor();
    _verifyFloorReleased = await _store.peekVerifyFloorReleased();
    if (_verifyFloorReleased) {
      _signupClosedFloor = null;
      await _store.clearSignupClosedFloor();
      if (session.stage == TippyOnboardingStages.verifyEmail) {
        session = session.copyWith(stage: TippyOnboardingStages.signup);
      }
    }
    final bool isAuthenticated =
        firebase_auth.FirebaseAuth.instance.currentUser != null;
    if (widget.startAtWelcome &&
        TippyOnboardingStages.shouldResetSessionAfterAccountDeletion(
          hasDeleteFlag: deleteFlag,
          isAuthenticated: isAuthenticated,
          stage: session.stage,
          questionIndex: session.questionIndex,
          answers: session.answers,
          hasSeenTippyIntro: session.hasSeenTippyIntro,
        )) {
      session = TippyOnboardingGuestSession.empty();
      await _store.save(session);
    }
    // Deletion already clears via the store force-fresh flag. Never treat a
    // live signup/verify session as a deleted account just because Auth
    // has not hydrated yet.
    if (widget.startAtWelcome &&
        TippyOnboardingStages.shouldForceMeetTippyIntroForGuest(
          stage: session.stage,
          isAuthenticated: isAuthenticated,
          hasLiveVerificationIntent: _signupClosedFloor != null,
        )) {
      session = session.forceMeetTippyIntro();
      await _store.save(session);
    }
    // First-time Get Started only — never wipe mid-progress for return visits.
    // Resume the exact Tippy step (no "Welcome back" interstitial).
    if (widget.startAtWelcome &&
        !isAuthenticated &&
        !_isPostQuizStage(session.stage) &&
        !session.hasMeaningfulProgress) {
      session = session.forceMeetTippyIntro();
      await _store.save(session);
    } else if (!isAuthenticated &&
        !session.hasSeenTippyIntro &&
        !_isPostQuizStage(session.stage) &&
        !session.hasMeaningfulProgress) {
      session = session.forceMeetTippyIntro();
      await _store.save(session);
    }
    // Gate / post-auth resume: use canonical resolver — never force avatar
    // just because the local session was wiped or photo is missing.
    if (!widget.startAtWelcome) {
      final firebase_auth.User? user =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final AccountStatusSnapshot status = await fetchAccountStatus();
          final AccountNavigation nav = status.navigation;
          debugPrint(
            '[Onboarding] tippy_resume activation=${status.activationState} '
            'hint=${nav.tippyStageHint} reason=${status.activationReason} '
            'lifecycle=${status.lifecycle}',
          );
          final bool passwordNeedsVerify = !user.emailVerified &&
              user.providerData.any(
                (firebase_auth.UserInfo info) => info.providerId == 'password',
              );
          if (nav.route == 'app' && !passwordNeedsVerify) {
            await _store.clear();
            if (!mounted) {
              return;
            }
            widget.onCompleted?.call();
            return;
          }
          if (passwordNeedsVerify) {
            session = session.copyWith(
              stage: TippyOnboardingStages.verifyEmail,
              hasSeenTippyIntro: true,
            );
            await _store.save(session);
          } else if (status.activationReason == 'identity_recycled_restart' &&
              !session.hasMeaningfulProgress) {
            session = TippyOnboardingGuestSession.empty();
            await _store.save(session);
          }
          final String? hint = nav.tippyStageHint;
          if (!passwordNeedsVerify && hint != null && hint.isNotEmpty) {
            final String next = TippyOnboardingStages.resumeStage(
              currentStage: session.stage,
              proposedStage: hint,
            );
            if (next != TippyOnboardingStages.normalize(session.stage)) {
              session = session.copyWith(
                stage: next,
                hasSeenTippyIntro: true,
              );
              await _store.save(session);
            }
          }
        } catch (error) {
          debugPrint('Tippy resume status load soft-skip: $error');
        }
      }
    }
    if (!mounted) {
      return;
    }
    final String visibleStage = _visibleStageFor(session);
    if (visibleStage != session.stage) {
      session = session.copyWith(stage: visibleStage);
    }
    session = session.withReservedUsername(
      await _store.peekSignupUsername(
        uid: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
      ),
    );
    if (!_verifyFloorReleased) {
      await _hydrateVerificationOwner(
        user: firebase_auth.FirebaseAuth.instance.currentUser,
        sessionId: session.sessionId,
      );
    }
    if (firebase_auth.FirebaseAuth.instance.currentUser != null) {
      session = await _hydrateSessionFromBrain(session);
    }
    final bool peekedWelcome = await _store.peekStartedFromWelcome();
    setState(() {
      _session = session;
      _isLoading = false;
      _welcomeBeat = 0;
      _startedFromWelcome = peekedWelcome || session.hasSeenTippyIntro;
      _mascotState = TippyMascotState.wave;
      _hydrateQuestionDraft(session);
    });
    _analytics.started(sessionId: session.sessionId);
    unawaited(_offerProTrialCheckoutIfNeeded(session));
  }

  bool _isPostQuizStage(String stage) {
    return TippyOnboardingStages.isPostQuizStage(stage);
  }

  Future<TippyOnboardingGuestSession> _hydrateSessionFromBrain(
    TippyOnboardingGuestSession session,
  ) async {
    try {
      final TippyBrainLayers? brain = await TippyBrainClient().fetchBrain();
      if (brain == null || !hasConfirmedPlatformsInBrain(brain)) {
        return session;
      }
      final List<String> platforms = confirmedPlatformIdsFromBrain(brain);
      final Map<String, dynamic> answers = applyConfirmedPlatformsToAnswers(
        session.answers,
        platforms,
      );
      final int? next = nextUnansweredOnboardingIndex(answers);
      return session.copyWith(
        answers: answers,
        questionIndex: next ?? session.questionIndex,
      );
    } catch (_) {
      return session;
    }
  }

  void _hydrateQuestionDraft(TippyOnboardingGuestSession session) {
    if (session.stage != TippyOnboardingStages.questions) {
      return;
    }
    if (session.questionIndex < 0 ||
        session.questionIndex >= kTippyOnboardingQuestions.length) {
      return;
    }
    final TippyOnboardingQuestion question =
        kTippyOnboardingQuestions[session.questionIndex];
    final Object? existing = session.answers[question.id];
    if (question.inputType == TippyOnboardingInputType.text) {
      _textController.text = existing is String ? existing : '';
    } else if (question.inputType == TippyOnboardingInputType.multiSelect) {
      _multiDraft =
          existing is List ? existing.whereType<String>().toList() : <String>[];
    }
  }

  TippyMascotState _mascotForStage(String stage) {
    switch (stage) {
      case TippyOnboardingStages.welcome:
        return TippyMascotState.wave;
      case TippyOnboardingStages.questions:
        return TippyMascotState.thinking;
      case TippyOnboardingStages.creatorSpaceReady:
        return TippyMascotState.celebrate;
      case TippyOnboardingStages.signup:
      case TippyOnboardingStages.notifications:
        return TippyMascotState.speaking;
      default:
        return TippyMascotState.idle;
    }
  }

  bool get _isUiBusy => _isBusy || _providerSignInBusy;

  Future<void> _persist(
    TippyOnboardingGuestSession next, {
    bool waitForStorage = true,
  }) async {
    final String stage = TippyOnboardingStages.resolveVisibleStage(
      storedStage: next.stage,
      signupClosedFloor: _verifyFloorReleased ? null : _signupClosedFloor,
      emailVerified:
          firebase_auth.FirebaseAuth.instance.currentUser?.emailVerified ==
              true,
    );
    final TippyOnboardingGuestSession floored =
        stage == next.stage ? next : next.copyWith(stage: stage);
    // Update UI first so permission-dialog gaps / storage failures cannot leave
    // the user stuck on the previous Tippy stage.
    _applySession(floored);
    Future<void> save() async {
      try {
        await _store.save(floored);
      } catch (error) {
        debugPrint('Tippy session persist soft-fail: $error');
      }
    }

    if (waitForStorage) {
      await save();
      return;
    }
    unawaited(save());
  }

  void _applySession(TippyOnboardingGuestSession floored) {
    void apply() {
      if (!mounted) {
        return;
      }
      setState(() {
        _session = floored;
        _mascotState = _mascotForStage(floored.stage);
        _error = null;
      });
      _syncVerifyEmailPoll(floored);
    }

    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      apply();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => apply());
  }

  void _syncVerifyEmailPoll(TippyOnboardingGuestSession session) {
    final bool onVerify =
        TippyOnboardingStages.normalize(session.stage) ==
        TippyOnboardingStages.verifyEmail;
    if (onVerify) {
      if (_verifyEmailPollTimer != null) {
        return;
      }
      _verifyEmailPollTimer = Timer.periodic(_verifyEmailPollInterval, (_) {
        if (!mounted) {
          return;
        }
        unawaited(_confirmEmailVerification(silent: true));
      });
      return;
    }
    _verifyEmailPollTimer?.cancel();
    _verifyEmailPollTimer = null;
  }

  void _lockSignupClosedAtVerifyEmailSync({
    required String uid,
    String? email,
  }) {
    _verifyFloorReleased = false;
    unawaited(_store.clearVerifyFloorReleased());
    _signupClosedFloor = TippyOnboardingStages.verifyEmail;
    _intendedVerificationUid = uid;
    final String? trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      _intendedVerificationEmail = trimmedEmail;
    }
    unawaited(_store.persistSignupClosedFloor(uid: uid));
    unawaited(_applyReservedSignupUsername(uid: uid));
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (TippyOnboardingStages.isAtOrAfter(
      current.stage,
      TippyOnboardingStages.verifyEmail,
    )) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final TippyOnboardingGuestSession next = current.copyWith(
      stage: TippyOnboardingStages.verifyEmail,
    );
    _session = next;
    _mascotState = _mascotForStage(next.stage);
    if (mounted) {
      setState(() {
        _error = null;
      });
    }
    unawaited(_store.save(next));
  }

  Future<void> _applyReservedSignupUsername({String? uid}) async {
    final String? reserved = await _store.peekSignupUsername();
    if (reserved == null || reserved.isEmpty) {
      return;
    }
    if (uid != null && uid.isNotEmpty) {
      await _store.persistSignupClosedFloor(uid: uid, username: reserved);
    }
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      return;
    }
    final TippyOnboardingGuestSession next =
        current.withReservedUsername(reserved);
    if (next.profileDraft.username == current.profileDraft.username) {
      return;
    }
    _session = next;
    await _store.save(next);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _hydrateVerificationOwner({
    required firebase_auth.User? user,
    required String sessionId,
  }) async {
    final EmailVerificationIntent? stored =
        await EmailVerificationIntentStore.read();
    final String? floorUid = await _store.peekSignupClosedFloorUid();
    final ({String uid, String email}) owner = resolveLiveVerificationOwner(
      storedUid: _intendedVerificationUid ?? stored?.uid ?? floorUid,
      storedEmail: _intendedVerificationEmail ?? stored?.normalizedEmail,
      currentUid: user?.uid,
      currentEmail: user?.email,
      currentEmailVerified: user?.emailVerified == true,
    );
    if (owner.uid.isEmpty || owner.email.isEmpty) {
      return;
    }
    _intendedVerificationUid = owner.uid;
    _intendedVerificationEmail = owner.email;
    if (stored != null && stored.uid == owner.uid) {
      return;
    }
    try {
      await EmailVerificationIntentStore.save(
        createEmailVerificationIntent(
          uid: owner.uid,
          email: owner.email,
          origin: resolveAppEmailVerificationOrigin(),
          onboardingSessionId: sessionId,
        ),
      );
    } catch (error) {
      debugPrint('Tippy verification intent hydrate soft-skip: $error');
    }
  }

  Future<void> _releaseVerifyEmailAndReturnToSignup(
    TippyOnboardingGuestSession session,
  ) async {
    _verifyFloorReleased = true;
    _signupClosedFloor = null;
    _intendedVerificationUid = null;
    _intendedVerificationEmail = null;
    _postSignupHandled = false;
    await _store.persistVerifyFloorReleased();
    await _store.clearSignupClosedFloor();
    await EmailVerificationIntentStore.clear();
    await _persist(
      session.copyWith(stage: TippyOnboardingStages.signup),
    );
  }

  String _visibleUsername(TippyOnboardingGuestSession session) {
    final String draft = tippyIdentityFromUsername(
      session.profileDraft.username,
    ).username;
    if (draft.isNotEmpty) {
      return draft;
    }
    final String authHandle = tippyIdentityFromUsername(
      ref.read(robustAuthServiceProvider).currentUser?.username ?? '',
    ).username;
    if (authHandle.isNotEmpty && authHandle != 'user') {
      return authHandle;
    }
    return tippyIdentityFromUsername(
      firebase_auth.FirebaseAuth.instance.currentUser?.displayName ?? '',
    ).username;
  }

  String _visibleStageFor(TippyOnboardingGuestSession session) {
    return TippyOnboardingStages.resolveVisibleStage(
      storedStage: session.stage,
      signupClosedFloor: _verifyFloorReleased ? null : _signupClosedFloor,
      emailVerified:
          firebase_auth.FirebaseAuth.instance.currentUser?.emailVerified ==
              true,
    );
  }

  Future<void> _advanceStage(String stage) async {
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      return;
    }
    _stageMotionForward = true;
    await _persist(
      current.copyWith(
        stage: stage,
        firstResultAt: stage == TippyOnboardingStages.dnaReveal
            ? (current.firstResultAt ?? DateTime.now().toUtc())
            : null,
      ),
      waitForStorage: false,
    );
  }

  void _enterStreamerTipFromCreatorSpace() {
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      return;
    }
    tippyConfirmHaptic(context);
    _stageMotionForward = true;
    final TippyOnboardingGuestSession next = current.copyWith(
      stage: TippyOnboardingStages.firstMission,
    );
    setState(() {
      _isBusy = false;
      _error = null;
    });
    _applySession(next);
    unawaited(_store.save(next));
  }

  bool _isPostVerifyCheckoutStage(String stage) {
    final String normalized = TippyOnboardingStages.normalize(stage);
    return TippyOnboardingStages.isGuidedProfileStage(normalized) ||
        normalized == TippyOnboardingStages.creatorSpaceReady ||
        normalized == TippyOnboardingStages.firstMission;
  }

  /// After account create + verify: open Pro IAP checkout once when
  /// the guest chose Start Free Trial (`trialIntent`).
  Future<void> _offerProTrialCheckoutIfNeeded(
    TippyOnboardingGuestSession session,
  ) async {
    if (_trialCheckoutOffered || !session.trialIntent) {
      return;
    }
    if (!_isPostVerifyCheckoutStage(session.stage)) {
      return;
    }
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final bool needsVerify = !user.emailVerified &&
        user.providerData.any(
          (firebase_auth.UserInfo info) => info.providerId == 'password',
        );
    if (needsVerify) {
      return;
    }
    _trialCheckoutOffered = true;
    await _persist(session.copyWith(trialIntent: false));
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.upgrade,
      arguments: const UpgradeRouteArgs(autoStartPro: true),
    );
  }

  Future<void> _exitAsReturningUser() async {
    await _store.clear();
    if (!mounted) {
      return;
    }
    await _dismissTippyToHome(choice: 'returning');
  }

  /// Prefer dismissing Tippy over remounting Home via `/home`.
  ///
  /// Until ACTIVATED, [OnboardingGate] mounts this shell without the app
  /// navigator. Gate Tippy always passes [onCompleted]; Auth Get Started
  /// Tippy does not.
  Future<void> _dismissTippyToHome({required String choice}) async {
    widget.onCompleted?.call();
    if (widget.onCompleted != null) {
      debugPrint('TIPPY_LANDING_DONE overlay_mode choice=$choice');
      _scheduleHomePlaybackRestoreAfterTippy();
      return;
    }
    debugPrint('TIPPY_LANDING_DONE route_mode choice=$choice');
    if (!mounted) {
      return;
    }
    await PendingAuthRedirectService.instance.consumeOrGoHome(context);
    _scheduleHomePlaybackRestoreAfterTippy();
  }

  void _scheduleHomePlaybackRestoreAfterTippy() {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    if (manager.isPlaybackBlocked) {
      manager.forceUnblock();
    }
    manager.setVisibleOwner(PlaybackOwners.home);
    manager.setActiveOwner(PlaybackOwners.home);
    void restore() {
      if (!mounted) {
        return;
      }
      if (!GlobalPlaybackManager.instance.isHomeMainTabSelected) {
        return;
      }
      ref
          .read(homeViewControllerProvider.notifier)
          .resumeAfterOnboardingCompleted();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Duration.zero, () {
        restore();
      });
    });
  }

  Future<void> _handleAuthenticated() async {
    final TippyOnboardingGuestSession? session = _session;
    if (session == null || _isBusy || _postSignupHandled) {
      return;
    }
    _postSignupHandled = true;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final firebase_auth.User? user =
          firebase_auth.FirebaseAuth.instance.currentUser;
      final bool needsVerify = user != null &&
          !user.emailVerified &&
          user.providerData.any(
            (firebase_auth.UserInfo info) => info.providerId == 'password',
          );
      if (_verifyFloorReleased && needsVerify) {
        _postSignupHandled = false;
        return;
      }
      if (_verifyFloorReleased) {
        _verifyFloorReleased = false;
        unawaited(_store.clearVerifyFloorReleased());
      }
      if (user != null) {
        if (needsVerify) {
          _intendedVerificationUid = user.uid;
          _intendedVerificationEmail = user.email;
        }
        final String reservedUsername =
            tippyIdentityFromUsername(session.profileDraft.username).username;
        final String? peekedUsername = reservedUsername.isNotEmpty
            ? reservedUsername
            : await _store.peekSignupUsername();
        final TippyOnboardingGuestSession next = session
            .withReservedUsername(peekedUsername)
            .copyWith(
          stage: needsVerify
              ? TippyOnboardingStages.verifyEmail
              : TippyOnboardingStages.accountSecured,
        );
        _applySession(next);
        unawaited(_store.save(next));
        if (mounted) {
          setState(() {
            _isBusy = false;
            _providerSignInBusy = false;
          });
        }
      }
      if (user != null) {
        // Existing Google/Apple accounts must not restart Tippy as a new signup.
        if (!needsVerify && await isReturningCompleteTippyUser(user.uid)) {
          await _exitAsReturningUser();
          return;
        }
        // Write Tippy ownership flags before/without attach API so the gate
        // never falls through to classic "creator focus".
        unawaited(OnboardingService().markTippyFunnelInProgress(user.uid));
      }
      final firebase_auth.User? fresh =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (needsVerify) {
        if (fresh != null) {
          final String draftHandle = tippyIdentityFromUsername(
            session.profileDraft.username,
          ).username;
          final String reservedUsername = draftHandle.isNotEmpty
              ? draftHandle
              : (await _store.peekSignupUsername() ?? '');
          if (reservedUsername.isNotEmpty) {
            unawaited(
              createPendingAccount(
                preferredUsername: reservedUsername,
                displayName: session.profileDraft.displayName.trim().isNotEmpty
                    ? session.profileDraft.displayName.trim()
                    : reservedUsername,
                onboardingSessionId: session.sessionId,
              ).catchError((Object error) {
                debugPrint('Tippy pending username retry soft-skip: $error');
              }),
            );
          }
          unawaited(
            _sendVerificationEmailSoft(
              user: fresh,
              sessionId: session.sessionId,
            ),
          );
          _intendedVerificationUid = fresh.uid;
          _intendedVerificationEmail = fresh.email;
        }
      } else {
        unawaited(
          _attachSession(session).then((_) {
            _analytics.signupAttached(sessionId: session.sessionId);
          }).catchError((Object attachError) {
            debugPrint('Tippy attach deferred after auth: $attachError');
          }),
        );
      }
      if (!needsVerify) {
        final TippyOnboardingGuestSession after = _session ?? session;
        await _offerProTrialCheckoutIfNeeded(after);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _providerSignInBusy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TippyOnboardingHostPresence.leave();
    _verifyEmailPollTimer?.cancel();
    _verifyEmailPollTimer = null;
    _twitchOAuthPollTimer?.cancel();
    _twitchOAuthPollTimer = null;
    _textController.dispose();
    _attachService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_awaitingTwitchOAuth || _isTwitchConnectPending())) {
      unawaited(_checkTwitchConnectionAfterOAuth());
    }
    if (state == AppLifecycleState.resumed &&
        _session?.stage == TippyOnboardingStages.verifyEmail) {
      unawaited(_confirmEmailVerification(silent: true));
    }
  }

  bool _isTwitchConnectPending() {
    final TippyOnboardingGuestSession? session = _session;
    if (session == null) {
      return false;
    }
    if (TippyOnboardingStages.normalize(session.stage) !=
        TippyOnboardingStages.twitchConnect) {
      return false;
    }
    final String status =
        (session.twitchConnectionStatus ?? '').trim().toUpperCase();
    return status != TippyTwitchConnectionStatus.connected &&
        status != TippyTwitchConnectionStatus.skipped;
  }

  void _syncTwitchOAuthPoll({required bool awaiting}) {
    if (awaiting) {
      if (_twitchOAuthPollTimer != null) {
        return;
      }
      _twitchOAuthPollTimer = Timer.periodic(_twitchOAuthPollInterval, (_) {
        if (!mounted) {
          return;
        }
        unawaited(_checkTwitchConnectionAfterOAuth());
      });
      return;
    }
    _twitchOAuthPollTimer?.cancel();
    _twitchOAuthPollTimer = null;
  }

  Future<void> _checkTwitchConnectionAfterOAuth() async {
    final TippyOnboardingGuestSession? session = _session;
    final String? uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (session == null || uid == null) {
      return;
    }
    try {
      final bool connected =
          await _twitchConnectService.hasTwitchConnection(uid);
      if (!connected || !mounted) {
        return;
      }
      _awaitingTwitchOAuth = false;
      _syncTwitchOAuthPoll(awaiting: false);
      await _twitchConnectService.persistConnectionStatus(
        uid: uid,
        status: TippyTwitchConnectionStatus.connected,
      );
      setState(() => _twitchJustConnected = true);
      if (mounted) {
        tippySuccessHaptic(context);
      }
      // Integration state only — do not invent next stage or rewind past Twitch.
      final String nextStage =
          TippyOnboardingStages.isAtOrAfter(
            session.stage,
            TippyOnboardingStages.notifications,
          )
              ? session.stage
              : TippyOnboardingStages.twitchConnect;
      await _persist(
        session.copyWith(
          twitchConnectionStatus: TippyTwitchConnectionStatus.connected,
          stage: nextStage,
        ),
        waitForStorage: false,
      );
    } catch (error) {
      debugPrint('Tippy Twitch resume check: $error');
    }
  }

  Future<void> _persistProfileDraft(TippyProfileDraft draft) async {
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      return;
    }
    await _persist(current.copyWith(profileDraft: draft));
  }

  static const Color _tippySolidBackground = AppColors.tippyBackground;

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _session == null) {
      return const Material(
        color: _tippySolidBackground,
        child: Scaffold(
          backgroundColor: _tippySolidBackground,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }
    final TippyOnboardingGuestSession session = _session!;
    final String visibleStage = _visibleStageFor(session);
    final TippyOnboardingGuestSession visibleSession =
        visibleStage == session.stage
            ? session
            : session.copyWith(stage: visibleStage);
    return Material(
      color: _tippySolidBackground,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) {
            return;
          }
          final TippyOnboardingGuestSession? current = _session;
          if (current != null) {
            unawaited(_handleBack(
              current.copyWith(stage: _visibleStageFor(current)),
            ));
          }
        },
        child: Scaffold(
          backgroundColor: _tippySolidBackground,
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: <Widget>[
                      _buildBackBar(visibleSession),
                      if (visibleSession.stage ==
                          TippyOnboardingStages.questions)
                        _buildQuestionProgress(visibleSession),
                      Expanded(
                        child: _buildStageSwitcher(visibleSession),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 8),
                        SelectableText.rich(
                          TextSpan(
                            text: _error,
                            style: const TextStyle(color: Color(0xFFFF6B6B)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_providerSignInBusy)
                  const Positioned.fill(child: _TippyThinkingOverlay()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackBar(TippyOnboardingGuestSession session) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: _isUiBusy ? null : () => unawaited(_handleBack(session)),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: Colors.white,
        tooltip: 'Back',
      ),
    );
  }

  Future<void> _handleBack(TippyOnboardingGuestSession session) async {
    if (_isUiBusy) {
      return;
    }
    if (_guidedProfileBackConsumer?.call() == true) {
      return;
    }
    _stageMotionForward = false;
    switch (session.stage) {
      case TippyOnboardingStages.welcome:
        if (_welcomeBeat > 0) {
          setState(() {
            _welcomeBeat = 0;
            _mascotState = TippyMascotState.wave;
          });
          return;
        }
        Navigator.of(context).maybePop();
        return;
      case TippyOnboardingStages.questions:
        if (session.questionIndex > 0) {
          final TippyOnboardingGuestSession previousQuestion =
              session.copyWith(questionIndex: session.questionIndex - 1);
          await _persist(previousQuestion);
          _textController.clear();
          _multiDraft = <String>[];
          _hydrateQuestionDraft(previousQuestion);
          return;
        }
        final firebase_auth.User? authUser =
            firebase_auth.FirebaseAuth.instance.currentUser;
        final String? previousFromQuestions =
            TippyOnboardingStages.reviewPrevious(
          stage: session.stage,
          isAuthenticated: authUser != null,
          emailVerified: authUser?.emailVerified == true,
        );
        if (previousFromQuestions == null) {
          return;
        }
        setState(() {
          _welcomeBeat = 1;
        });
        await _persist(
          session.copyWith(stage: TippyOnboardingStages.welcome),
        );
        return;
      case TippyOnboardingStages.verifyEmail:
        await _releaseVerifyEmailAndReturnToSignup(session);
        return;
      default:
        final firebase_auth.User? authUser =
            firebase_auth.FirebaseAuth.instance.currentUser;
        final String? previous = TippyOnboardingStages.reviewPrevious(
          stage: session.stage,
          isAuthenticated: authUser != null,
          emailVerified: authUser?.emailVerified == true,
          answers: session.answers,
          selectedPlatforms: session.profileDraft.platformIds,
        );
        if (previous == null) {
          return;
        }
        await _persist(session.copyWith(stage: previous));
    }
  }

  Widget _buildQuestionProgress(TippyOnboardingGuestSession session) {
    final int step = session.questionIndex + 1;
    final double progress = step / kTippyOnboardingTotalQuestions;
    return Column(
      children: <Widget>[
        Text(
          'Step $step of $kTippyOnboardingTotalQuestions',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildStageSwitcher(TippyOnboardingGuestSession session) {
    if (TippyOnboardingStages.isGuidedProfileStage(session.stage)) {
      return TippyGuidedProfileHost(
        session: session,
        onPersist: _persistProfileDraft,
        onAdvanceStage: _advanceStage,
        busy: _isBusy,
        error: _error,
        onBackConsumerChanged: (TippyGuidedProfileBackConsumer? consumer) {
          _guidedProfileBackConsumer = consumer;
        },
      );
    }
    return AnimatedSwitcher(
      duration: tippyStageTransitionDuration(context),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (
        Widget? currentChild,
        List<Widget> previousChildren,
      ) {
        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Offset begin = _stageMotionForward
            ? const Offset(0.06, 0)
            : const Offset(-0.06, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(
          '${session.stage}_${session.questionIndex}',
        ),
        child: _buildStage(session),
      ),
    );
  }

  Widget _buildStage(TippyOnboardingGuestSession session) {
    final String stage = TippyOnboardingStages.normalize(session.stage);
    switch (stage) {
      case TippyOnboardingStages.welcome:
        return _buildMeetTippyIntro();
      case TippyOnboardingStages.questions:
        if (session.startedFromCheckup &&
            !session.checkupHandoffConfirmResolved) {
          return _buildCheckupBroughtOver(session);
        }
        return _buildQuestions(session);
      case TippyOnboardingStages.dnaReveal:
        return _buildDnaReveal(session);
      case TippyOnboardingStages.twitchConnect:
        return _buildTwitchConnect(session);
      case TippyOnboardingStages.notifications:
        return _buildNotifications(session);
      case TippyOnboardingStages.signup:
        return _buildSignup(session);
      case TippyOnboardingStages.verifyEmail:
        return _buildVerifyEmail();
      case TippyOnboardingStages.accountSecured:
      case TippyOnboardingStages.avatar:
      case TippyOnboardingStages.displayName:
      case TippyOnboardingStages.username:
      case TippyOnboardingStages.bio:
      case TippyOnboardingStages.platformHandles:
      case TippyOnboardingStages.profileReview:
        return const SizedBox.shrink();
      case TippyOnboardingStages.creatorSpaceReady:
        final Object? contactSync = session.answers['contactSync'];
        final String? contactSpeech = _contactSyncResultSpeech(
          contactSync: contactSync is String ? contactSync : null,
        );
        return _buildCreatorSpaceReady(
          session: session,
          contactSpeech: contactSpeech,
        );
      case TippyOnboardingStages.firstMission:
        return _buildLandingChoice(session);
      default:
        return _tippyScene(
          speech: TippyOnboardingCopy.welcome,
          primaryLabel: 'CONTINUE',
          onPrimary: () => _advanceStage(TippyOnboardingStages.questions),
        );
    }
  }

  /// Compact Path B consume — not a Checkup UI, not a second Hey I'm Tippy.
  Widget _buildCheckupBroughtOver(TippyOnboardingGuestSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Spacer(flex: 2),
        _SpeechBubble(
          text: TippyOnboardingCopy.checkupBroughtOver,
          showTail: true,
        ),
        const SizedBox(height: 12),
        Text(
          TippyOnboardingCopy.checkupBroughtOverBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        if ((session.checkupPresenceSummary ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            session.checkupPresenceSummary!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
        const Spacer(flex: 3),
        _PrimaryButton(
          label: TippyOnboardingCopy.checkupLooksRight,
          busy: _isBusy,
          onPressed: () {
            unawaited(_resolveCheckupHandoffConfirm(edit: false));
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            unawaited(_resolveCheckupHandoffConfirm(edit: true));
          },
          child: const Text(
            TippyOnboardingCopy.checkupEdit,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Future<void> _resolveCheckupHandoffConfirm({required bool edit}) async {
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      return;
    }
    Map<String, dynamic> answers = Map<String, dynamic>.from(current.answers);
    if (edit) {
      answers.remove('creator_type');
      answers.remove('niche');
      answers.remove('content_formats');
    }
    final int nextIndex = nextUnansweredOnboardingIndex(answers) ?? 0;
    await _persist(
      current.copyWith(
        answers: answers,
        checkupHandoffConfirmResolved: true,
        questionIndex: nextIndex,
        hasSeenTippyIntro: true,
      ),
    );
  }

  /// Duolingo-style Tippy introduction before any questions.
  Widget _buildMeetTippyIntro() {
    final String speech = switch (_welcomeBeat) {
      0 => TippyOnboardingCopy.welcomeHi,
      1 => TippyOnboardingCopy.welcomeBeat1,
      _ => TippyOnboardingCopy.welcomeBeat2,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Spacer(flex: 2),
        AnimatedSwitcher(
          duration: _tippyWelcomeBeatTransitionDuration,
          switchInCurve: Curves.easeOutCubic,
          child: _SpeechBubble(
            key: ValueKey<int>(_welcomeBeat),
            text: speech,
            showTail: true,
          ),
        ),
        const SizedBox(height: 8),
        TippyMascot(
          state: _welcomeBeat == 0
              ? TippyMascotState.wave
              : TippyMascotState.speaking,
          size: 196,
        ),
        if (_welcomeBeat >= 2) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            TippyOnboardingCopy.welcomeSupport,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
        const Spacer(flex: 3),
        _PrimaryButton(
          label:
              _welcomeBeat >= 2 ? TippyOnboardingCopy.welcomeCta : 'CONTINUE',
          busy: _isBusy,
          onPressed: () {
            unawaited(_handleWelcomeContinue());
          },
        ),
      ],
    );
  }

  Future<void> _handleWelcomeContinue() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _mascotState = TippyMascotState.wave;
    });
    try {
      if (_welcomeBeat < 2) {
        setState(() {
          _welcomeBeat += 1;
          _mascotState = TippyMascotState.speaking;
        });
        return;
      }
      final TippyOnboardingGuestSession? current = _session;
      if (current != null) {
        _startedFromWelcome = true;
        await _store.markStartedFromWelcome();
        await _persist(
          current.copyWith(
            stage: TippyOnboardingStages.questions,
            questionIndex: 0,
            hasSeenTippyIntro: true,
          ),
          waitForStorage: false,
        );
      } else {
        await _advanceStage(TippyOnboardingStages.questions);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Widget _buildCreatorSpaceReady({
    required TippyOnboardingGuestSession session,
    required String? contactSpeech,
  }) {
    final String username = _visibleUsername(session);
    final List<String> dnaSummary = buildCreatorDnaSummary(session.answers);
    final String primaryGoalLabel = _creatorSpacePrimaryGoal(dnaSummary);
    final String summaryLine =
        "I've personalized your workspace around $primaryGoalLabel, and the platforms you use.";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          TippyOnboardingCopy.creatorSpaceTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 18),
        TippyMascot(state: TippyMascotState.celebrate, size: 120),
        const SizedBox(height: 18),
        Text(
          '${TippyOnboardingCopy.creatorSpaceWelcome}'
          '${username.isNotEmpty ? ', @$username' : ''}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          contactSpeech ?? summaryLine,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF9248D2).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF9248D2).withValues(alpha: 0.40),
            ),
          ),
          child: Column(
            children: <Widget>[
              const Text(
                TippyOnboardingCopy.creatorSpaceXpLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFC4A3F0),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: tippyMotionAllowed(context) ? 0.94 : 1,
                  end: 1,
                ),
                duration: tippyMotionAllowed(context)
                    ? const Duration(milliseconds: 280)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                builder: (
                  BuildContext context,
                  double scale,
                  Widget? child,
                ) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Text(
                  '+$kTippyOnboardingXpReward XP',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Awarded when you finish setup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _PrimaryButton(
          label: TippyOnboardingCopy.creatorSpaceCta,
          onPressed: _enterStreamerTipFromCreatorSpace,
        ),
      ],
    );
  }

  String _creatorSpacePrimaryGoal(List<String> dnaSummary) {
    final RegExp goalPattern = RegExp(
      r'grow|consistent|content|community|audience|brand|earn',
      caseSensitive: false,
    );
    for (final String line in dnaSummary) {
      if (goalPattern.hasMatch(line)) {
        return line;
      }
    }
    return 'your goals';
  }

  Widget _tippyScene({
    required String speech,
    required String primaryLabel,
    required Future<void> Function() onPrimary,
    String? secondarySpeech,
    String? secondaryLabel,
    Future<void> Function()? onSecondary,
    TippyMascotState? mascotOverride,
    Widget? extra,
    bool primaryShowsBusy = true,
    bool secondaryShowsBusy = true,
  }) {
    return Column(
      children: <Widget>[
        const Spacer(),
        _SpeechBubble(text: speech),
        if (secondarySpeech != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            secondarySpeech,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 18),
        TippyMascot(
          state: mascotOverride ?? _mascotState,
          size: 168,
        ),
        if (extra != null) ...<Widget>[
          const SizedBox(height: 20),
          extra,
        ],
        const Spacer(),
        _PrimaryButton(
          label: primaryLabel,
          busy: primaryShowsBusy && _isBusy,
          onPressed: () async {
            if (primaryShowsBusy && _isBusy) {
              return;
            }
            if (primaryShowsBusy) {
              setState(() => _isBusy = true);
            }
            try {
              await onPrimary();
            } finally {
              if (primaryShowsBusy && mounted) {
                setState(() => _isBusy = false);
              }
            }
          },
        ),
        if (secondaryLabel != null && onSecondary != null) ...<Widget>[
          const SizedBox(height: 10),
          TextButton(
            onPressed: secondaryShowsBusy && _isBusy
                ? null
                : () async {
                    if (secondaryShowsBusy) {
                      setState(() => _isBusy = true);
                    }
                    try {
                      await onSecondary();
                    } finally {
                      if (secondaryShowsBusy && mounted) {
                        setState(() => _isBusy = false);
                      }
                    }
                  },
            child: Text(
              secondaryLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuestions(TippyOnboardingGuestSession session) {
    final TippyOnboardingQuestion question =
        kTippyOnboardingQuestions[session.questionIndex];
    return Column(
      children: <Widget>[
        _SpeechBubble(text: question.tippySpeech),
        const SizedBox(height: 6),
        Text(
          question.why,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        TippyMascot(state: _mascotState, size: 72),
        const SizedBox(height: 12),
        Expanded(child: _buildQuestionInput(question)),
        _PrimaryButton(
          label: session.questionIndex >= kTippyOnboardingTotalQuestions - 1
              ? 'CONTINUE'
              : 'NEXT',
          busy: _isBusy,
          onPressed: () => unawaited(_submitQuestion(question)),
        ),
      ],
    );
  }

  Widget _buildDnaReveal(TippyOnboardingGuestSession session) {
    return Column(
      children: <Widget>[
        _SpeechBubble(text: TippyOnboardingCopy.dnaRevealIntro),
        const SizedBox(height: 12),
        TippyMascot(state: TippyMascotState.thinking, size: 90),
        const SizedBox(height: 14),
        _CreatorDnaCard(lines: buildCreatorDnaSummary(session.answers)),
        const SizedBox(height: 14),
        Text(
          TippyOnboardingCopy.dnaRevealBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const Spacer(),
        _PrimaryButton(
          label: TippyOnboardingCopy.dnaRevealCta,
          onPressed: () => _advanceStage(TippyOnboardingStages.signup),
        ),
      ],
    );
  }

  Widget _buildQuestionInput(TippyOnboardingQuestion question) {
    switch (question.inputType) {
      case TippyOnboardingInputType.text:
        return TextField(
          controller: _textController,
          maxLength: question.maxLength ?? 60,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: question.placeholder,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        );
      case TippyOnboardingInputType.singleSelect:
        return ListView(
          children: question.options.map((TippyOnboardingOption option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionChip(
                label: option.label,
                iconName: option.icon,
                selected: false,
                onTap: () => unawaited(_selectSingle(question, option.id)),
              ),
            );
          }).toList(),
        );
      case TippyOnboardingInputType.multiSelect:
        return SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: question.options.map((TippyOnboardingOption option) {
              final bool selected = _multiDraft.contains(option.id);
              return _CompactOptionChip(
                label: option.label,
                selected: selected,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _multiDraft.remove(option.id);
                    } else {
                      if (question.maxSelections != null &&
                          _multiDraft.length >= question.maxSelections!) {
                        return;
                      }
                      _multiDraft.add(option.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        );
    }
  }

  Future<void> _selectSingle(
    TippyOnboardingQuestion question,
    String id,
  ) async {
    setState(() => _mascotState = TippyMascotState.reactPositive);
    await _commitAnswer(question.id, id);
  }

  Future<void> _submitQuestion(TippyOnboardingQuestion question) async {
    Object? value;
    switch (question.inputType) {
      case TippyOnboardingInputType.text:
        value = _textController.text.trim();
        break;
      case TippyOnboardingInputType.multiSelect:
        value = List<String>.from(_multiDraft);
        break;
      case TippyOnboardingInputType.singleSelect:
        return;
    }
    if (!isValidTippyOnboardingAnswer(question, value)) {
      setState(() {
        _error = 'Please answer this question to continue.';
      });
      return;
    }
    setState(() => _mascotState = TippyMascotState.reactPositive);
    await _commitAnswer(question.id, value);
  }

  Future<void> _commitAnswer(String questionId, Object value) async {
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      return;
    }
    final Map<String, dynamic> answers =
        Map<String, dynamic>.from(current.answers);
    answers[questionId] = value;
    final int nextIndex = current.startedFromCheckup
        ? (nextUnansweredOnboardingIndex(answers, current.questionIndex + 1) ??
            kTippyOnboardingTotalQuestions)
        : current.questionIndex + 1;
    if (nextIndex >= kTippyOnboardingTotalQuestions) {
      await _persist(
        current.copyWith(
          answers: answers,
          profileDraft: applyDnaAnswersToProfileDraft(
            draft: current.profileDraft,
            answers: answers,
            checkupProfiles: current.checkupProfiles,
          ),
          questionIndex: kTippyOnboardingTotalQuestions - 1,
          stage: TippyOnboardingStages.dnaReveal,
          completedQuestionsAt: DateTime.now().toUtc(),
          firstResultAt: current.firstResultAt ?? DateTime.now().toUtc(),
        ),
        waitForStorage: false,
      );
      _analytics.questionsCompleted(sessionId: current.sessionId);
      final firebase_auth.User? signedIn =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (signedIn != null) {
        unawaited(
          OnboardingService().markTippyFunnelInProgress(signedIn.uid),
        );
      }
      return;
    }
    final TippyOnboardingGuestSession next = current.copyWith(
      answers: answers,
      questionIndex: nextIndex,
    );
    await _persist(next, waitForStorage: false);
    _analytics.stepCompleted(
      sessionId: current.sessionId,
      stage: TippyOnboardingStages.questions,
      questionIndex: current.questionIndex,
    );
    _textController.clear();
    _multiDraft = <String>[];
    _hydrateQuestionDraft(next);
  }

  Widget _buildTwitchConnect(TippyOnboardingGuestSession session) {
    final bool connected = _twitchJustConnected ||
        session.twitchConnectionStatus == TippyTwitchConnectionStatus.connected;
    if (connected) {
      return _tippyScene(
        speech: TippyOnboardingCopy.twitchConnectSuccessBody,
        primaryLabel: TippyOnboardingCopy.twitchConnectSuccessCta,
        onPrimary: () async {
          setState(() => _twitchJustConnected = false);
          final TippyOnboardingGuestSession next = session.copyWith(
            twitchConnectionStatus: TippyTwitchConnectionStatus.connected,
            stage: TippyOnboardingStages.notifications,
          );
          await _persist(next, waitForStorage: false);
          final String? uid =
              firebase_auth.FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            unawaited(
              _twitchConnectService.persistConnectionStatus(
                uid: uid,
                status: TippyTwitchConnectionStatus.connected,
              ).catchError((Object error) {
                debugPrint('Tippy Twitch status soft-skip: $error');
              }),
            );
          }
        },
        primaryShowsBusy: false,
      );
    }
    return _tippyScene(
      speech: '${TippyOnboardingCopy.twitchConnectIntro}\n\n'
          '${TippyOnboardingCopy.twitchConnectBody}',
      primaryLabel: TippyOnboardingCopy.twitchConnectCta,
      onPrimary: () async {
        setState(() {
          _isBusy = true;
          _error = null;
        });
        try {
          await _twitchConnectService.startOAuth();
          _awaitingTwitchOAuth = true;
          _syncTwitchOAuthPoll(awaiting: true);
        } catch (error) {
          _awaitingTwitchOAuth = false;
          _syncTwitchOAuthPoll(awaiting: false);
          setState(() {
            _error = error.toString().replaceFirst('Bad state: ', '');
          });
        } finally {
          if (mounted) {
            setState(() => _isBusy = false);
          }
        }
      },
      secondaryLabel: TippyOnboardingCopy.twitchConnectSkip,
      onSecondary: () async {
        _awaitingTwitchOAuth = false;
        _syncTwitchOAuthPoll(awaiting: false);
        final TippyOnboardingGuestSession next = session.copyWith(
          twitchConnectionStatus: TippyTwitchConnectionStatus.skipped,
          stage: TippyOnboardingStages.notifications,
        );
        await _persist(next, waitForStorage: false);
        final String? uid =
            firebase_auth.FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(
            _twitchConnectService.persistConnectionStatus(
              uid: uid,
              status: TippyTwitchConnectionStatus.skipped,
            ).catchError((Object error) {
              debugPrint('Tippy Twitch status soft-skip: $error');
            }),
          );
        }
      },
      secondaryShowsBusy: false,
    );
  }

  Widget _buildNotifications(TippyOnboardingGuestSession session) {
    return Column(
      children: <Widget>[
        const Spacer(),
        Text(
          TippyOnboardingCopy.notificationsTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _SpeechBubble(text: TippyOnboardingCopy.notificationsExplain),
        const SizedBox(height: 18),
        TippyMascot(state: _mascotState, size: 168),
        const Spacer(),
        _PrimaryButton(
          label: TippyOnboardingCopy.notificationsCta,
          busy: _isBusy,
          onPressed: () async {
            if (_isBusy) {
              return;
            }
            setState(() => _isBusy = true);
            try {
              if (!kIsWeb) {
                await FirebaseMessaging.instance.requestPermission(
                  alert: true,
                  badge: true,
                  sound: true,
                );
              }
            } catch (_) {}
            try {
              final TippyOnboardingGuestSession next = session.copyWith(
                notificationsChoice: 'enabled',
                stage: TippyOnboardingStages.creatorSpaceReady,
              );
              await _persist(next, waitForStorage: false);
              unawaited(
                _attachSessionSoft(next, 'notifications'),
              );
            } finally {
              if (mounted) {
                setState(() => _isBusy = false);
              }
            }
          },
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _isBusy
              ? null
              : () async {
                  setState(() => _isBusy = true);
                  try {
                    final TippyOnboardingGuestSession next =
                        session.copyWith(
                      notificationsChoice: 'declined',
                      stage: TippyOnboardingStages.creatorSpaceReady,
                    );
                    await _persist(next, waitForStorage: false);
                    unawaited(
                      _attachSessionSoft(next, 'notifications'),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isBusy = false);
                    }
                  }
                },
          child: Text(
            TippyOnboardingCopy.notificationsSkip,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrial(TippyOnboardingGuestSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SpeechBubble(text: TippyOnboardingCopy.trialIntro),
        const SizedBox(height: 10),
        TippyMascot(state: TippyMascotState.speaking, size: 96),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: _UpgradeStyleProTrialCard(
              onStartTrial: () async {
                await _persist(
                  session.copyWith(
                    trialIntent: true,
                    stage: TippyOnboardingStages.signup,
                  ),
                );
              },
              onMaybeLater: () async {
                await _persist(
                  session.copyWith(
                    trialIntent: false,
                    stage: TippyOnboardingStages.signup,
                  ),
                );
              },
              busy: _isBusy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignup(TippyOnboardingGuestSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SpeechBubble(
          text: _providerSignInBusy
              ? "Give me a second — I'm connecting your account."
              : TippyOnboardingCopy.preSignup,
        ),
        const SizedBox(height: 10),
        TippyMascot(
          state: _providerSignInBusy
              ? TippyMascotState.thinking
              : TippyMascotState.speaking,
          size: 96,
        ),
        const Spacer(),
        Text(
          'Choose how to create your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (_shouldShowAppleSignIn) ...<Widget>[
          _PrimaryButton(
            label: 'CONTINUE WITH APPLE',
            busy: _isUiBusy,
            onPressed: () => unawaited(_signUpWithApple()),
          ),
          const SizedBox(height: 10),
        ],
        _PrimaryButton(
          label: 'CONTINUE WITH GOOGLE',
          busy: _isUiBusy,
          onPressed: () => unawaited(_signUpWithGoogle()),
        ),
        const SizedBox(height: 10),
        _PrimaryButton(
          label: 'CONTINUE WITH EMAIL',
          busy: _isUiBusy,
          onPressed: () async {
            _analytics.signupStarted(sessionId: session.sessionId);
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => SignupView(
                  dismiss: () => Navigator.of(context).maybePop(),
                  onAccountCreated: () {
                    final firebase_auth.User? created =
                        firebase_auth.FirebaseAuth.instance.currentUser;
                    if (created == null) {
                      return;
                    }
                    _lockSignupClosedAtVerifyEmailSync(
                      uid: created.uid,
                      email: created.email,
                    );
                  },
                  onAuthenticatedStay: () {
                    Navigator.of(context).maybePop();
                  },
                  deferUsernameSelection: false,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool get _shouldShowAppleSignIn => _appleAvailable;

  Future<void> _signUpWithGoogle() async {
    await _signUpWithProvider(
      label: 'Google',
      signIn: (RobustAuthenticationService auth) {
        return auth.debouncedSignInWithGoogle();
      },
      afterSuccess: (firebase_auth.User created) async {
        try {
          await createPendingAccount(
            displayName: created.displayName,
          );
        } catch (error) {
          logTippyActivationProof(
        '[ACTIVATION_PROOF] event=google_pending_failed error=$error',
          );
        }
      },
    );
  }

  Future<void> _signUpWithApple() async {
    await _signUpWithProvider(
      label: 'Apple',
      signIn: (RobustAuthenticationService auth) {
        return auth.debouncedSignInWithApple();
      },
    );
  }

  Future<void> _signUpWithProvider({
    required String label,
    required Future<AuthRequestResult> Function(
      RobustAuthenticationService auth,
    ) signIn,
    Future<void> Function(firebase_auth.User created)? afterSuccess,
  }) async {
    if (_isUiBusy) {
      return;
    }
    setState(() {
      _providerSignInBusy = true;
      _error = null;
      _mascotState = TippyMascotState.thinking;
    });
    logTippyActivationProof(
        '[ACTIVATION_PROOF] event=provider_signin_start provider=$label');
    try {
      final RobustAuthenticationService auth =
          ref.read(robustAuthServiceProvider);
      final AuthRequestResult result = await signIn(auth);
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=provider_signin_result provider=$label success=${result.success} error=${result.error ?? 'null'}',
      );
      if (!result.success) {
        if (!mounted) {
          return;
        }
        setState(() {
          _providerSignInBusy = false;
          if (!_isProviderSignInCancelled(result.error)) {
            _error = result.error;
          }
        });
        return;
      }
      final firebase_auth.User? created =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (created != null && afterSuccess != null) {
        await afterSuccess(created);
      }
      if (!mounted) {
        return;
      }
      if (_postSignupHandled || _isBusy) {
        if (!_isBusy && _providerSignInBusy) {
          setState(() {
            _providerSignInBusy = false;
          });
        }
        return;
      }
      if (_session?.stage == TippyOnboardingStages.signup) {
        unawaited(_handleAuthenticated());
      } else {
        setState(() {
          _providerSignInBusy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _providerSignInBusy = false;
          _error = error.toString();
        });
      }
    }
  }

  bool _isProviderSignInCancelled(String? error) {
    final String text = (error ?? '').toLowerCase();
    return text.contains('cancel');
  }

  Future<void> _confirmEmailVerification({bool silent = false}) async {
    if (_isConfirmingVerification) {
      return;
    }
    final firebase_auth.User? current =
        firebase_auth.FirebaseAuth.instance.currentUser;
    await _hydrateVerificationOwner(
      user: current,
      sessionId: _session?.sessionId ?? '',
    );
    final EmailVerificationIntent? stored =
        await EmailVerificationIntentStore.read();
    final ({String uid, String email}) owner = resolveLiveVerificationOwner(
      storedUid: _intendedVerificationUid ?? stored?.uid,
      storedEmail: _intendedVerificationEmail ?? stored?.normalizedEmail,
      currentUid: current?.uid,
      currentEmail: current?.email,
      currentEmailVerified: current?.emailVerified == true,
    );
    final String intendedUid = owner.uid;
    final String intendedEmail = owner.email;
    final VerificationIdentityResult result =
        await confirmBoundEmailVerification(
      intendedUid: intendedUid,
      intendedEmail: intendedEmail,
    );
    if (!mounted) {
      return;
    }
    if (result.status == VerificationIdentityStatus.mismatch) {
      setState(() {
        _error =
            'This browser is signed in as a different account. Sign in as $intendedEmail to continue.';
      });
      return;
    }
    if (result.status != VerificationIdentityStatus.ready) {
      if (!silent) {
        setState(() {
          _error = 'Email not verified yet. Check your inbox and try again.';
        });
      }
      return;
    }
    _isConfirmingVerification = true;
    setState(() {
      _error = null;
      _isActivatingAccount = true;
      _isBusy = true;
    });
    // Optimistic floor — leave verify before activation finishes (1J.2 / web parity).
    await _advanceStage(TippyOnboardingStages.accountSecured);
    Future<void> completeInBackground() async {
      try {
        final AccountStatusSnapshot status = await completeVerifiedActivation(
          intendedUid: intendedUid.isEmpty ? null : intendedUid,
        );
        await EmailVerificationIntentStore.clear();
        try {
          final TippyOnboardingGuestSession? session = _session;
          if (session != null) {
            await _attachSession(session);
            _analytics.signupAttached(sessionId: session.sessionId);
          }
        } catch (attachError) {
          debugPrint('Tippy attach deferred after verify: $attachError');
        }
        if (!mounted) {
          return;
        }
        final AccountNavigation nav = status.navigation;
        if (nav.route == 'app') {
          await _store.clear();
          widget.onCompleted?.call();
          return;
        }
        if (nav.route == 'onboarding' && status.provisioned) {
          final String next = TippyOnboardingStages.resumeStage(
            currentStage: TippyOnboardingStages.accountSecured,
            proposedStage: nav.tippyStageHint,
          );
          await _advanceStage(next);
          final TippyOnboardingGuestSession? after = _session;
          if (after != null) {
            await _offerProTrialCheckoutIfNeeded(after);
          }
        }
      } on VerifiedActivationException catch (error) {
        if (!mounted) {
          return;
        }
        if (error.code == 'EMAIL_VERIFICATION_REQUIRED') {
          if (!silent) {
            setState(() {
              _error =
                  'Email not verified yet. Check your inbox and try again.';
            });
          }
          return;
        }
        if (error.code == 'IDENTITY_MISMATCH') {
          setState(() {
            _error =
                'This browser is signed in as a different account. Sign in as $intendedEmail to continue.';
          });
          return;
        }
        setState(() {
          _error = kVerifiedActivationPersistentError;
        });
      } catch (error) {
        debugPrint('Tippy verify handoff background failed: $error');
      } finally {
        _isConfirmingVerification = false;
        if (mounted) {
          setState(() {
            _isActivatingAccount = false;
            _isBusy = false;
          });
        }
      }
    }

    unawaited(completeInBackground());
  }

  Future<void> _resendVerificationEmail() async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error =
            'Resend is only available for the account that started signup.';
      });
      return;
    }
    await _hydrateVerificationOwner(
      user: user,
      sessionId: _session?.sessionId ?? '',
    );
    final EmailVerificationIntent? stored =
        await EmailVerificationIntentStore.read();
    final ({String uid, String email}) owner = resolveLiveVerificationOwner(
      storedUid: _intendedVerificationUid ?? stored?.uid,
      storedEmail: _intendedVerificationEmail ?? stored?.normalizedEmail,
      currentUid: user.uid,
      currentEmail: user.email,
      currentEmailVerified: user.emailVerified,
    );
    if (owner.uid.isEmpty ||
        owner.email.isEmpty ||
        !isIntendedVerificationUser(
          intendedUid: owner.uid,
          intendedEmail: owner.email,
          currentUid: user.uid,
          currentEmail: user.email,
        )) {
      setState(() {
        _error =
            'Resend is only available for the account that started signup.';
      });
      return;
    }
    try {
      await sendBoundEmailVerification(
        user: user,
        onboardingSessionId: _session?.sessionId,
        resumePath: '/onboarding',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not resend right now. Try again shortly.';
      });
    }
  }

  Widget _buildVerifyEmail() {
    final String email = _intendedVerificationEmail?.trim() ??
        firebase_auth.FirebaseAuth.instance.currentUser?.email?.trim() ??
        '';
    return _tippyScene(
      speech: _isActivatingAccount
          ? 'Email verified\nContinuing…'
          : TippyOnboardingCopy.verifyEmail,
      secondarySpeech: _isActivatingAccount || email.isEmpty
          ? null
          : '${TippyOnboardingCopy.verifyEmailBody}\n$email',
      primaryLabel: _isActivatingAccount
          ? 'CONTINUING…'
          : 'Already verified? Continue',
      onPrimary: _isActivatingAccount
          ? () async {}
          : () => _confirmEmailVerification(),
      secondaryLabel: 'Resend email',
      onSecondary: _isActivatingAccount
          ? () async {}
          : _resendVerificationEmail,
    );
  }

  Widget _buildFindFriends() {
    return _tippyScene(
      speech: TippyOnboardingCopy.findFriends,
      primaryLabel: 'SYNC CONTACTS',
      onPrimary: () => _syncContactsAndContinue(),
      secondaryLabel: 'Continue without contacts',
      onSecondary: () async {
        await _finishFindFriends(
          contactSync: 'skipped',
          matchCount: 0,
        );
      },
    );
  }

  String? _contactSyncResultSpeech({
    required String? contactSync,
  }) {
    switch (contactSync) {
      case 'pending':
        return 'Checking your contacts for creators you may know…';
      case 'enabled':
        return 'Contacts synced. I\'ll suggest people to follow when '
            'friends join StreamersTip.';
      case 'denied':
        return 'No worries — you can sync contacts later in Settings.';
      case 'failed':
        return 'Contact sync had a hiccup. Your profile is still ready.';
      case 'skipped':
        return null;
      default:
        return null;
    }
  }

  Future<void> _syncContactsAndContinue() async {
    debugPrint('TIPPY_CONTACT_SYNC start');
    if (kIsWeb) {
      setState(() {
        _error = 'Contact sync is available in the mobile app.';
      });
      return;
    }
    // Advance immediately so the permission dialog cannot strand this stage.
    await _finishFindFriends(
      contactSync: 'pending',
      matchCount: 0,
    );
    final ContactsService contacts = ContactsService();
    try {
      final bool granted = await contacts.requestContactsPermission();
      debugPrint('TIPPY_CONTACT_SYNC permission granted=$granted');
      if (!granted) {
        await _finishFindFriends(contactSync: 'denied', matchCount: 0);
        return;
      }
      int uploadedCount = 0;
      try {
        final List<ContactHash> hashed =
            await contacts.getContactsWithHashing();
        debugPrint('TIPPY_CONTACT_SYNC hashed=${hashed.length}');
        if (hashed.isNotEmpty) {
          await contacts.uploadHashedContacts(hashed);
          uploadedCount = hashed.length;
          // Match lookup is server-side only (client users queries are denied).
          await contacts.findMatchingUsers(hashed);
        }
      } catch (error) {
        debugPrint('TIPPY_CONTACT_SYNC hash/upload soft-skip: $error');
      }
      debugPrint('TIPPY_CONTACT_SYNC done uploaded=$uploadedCount');
      await _finishFindFriends(
        contactSync: 'enabled',
        matchCount: uploadedCount,
      );
    } catch (error, stackTrace) {
      debugPrint('TIPPY_CONTACT_SYNC failed: $error');
      debugPrint('$stackTrace');
      await _finishFindFriends(contactSync: 'failed', matchCount: 0);
    }
  }

  Future<void> _finishFindFriends({
    required String contactSync,
    required int matchCount,
  }) async {
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      debugPrint('TIPPY_CONTACT_SYNC finish aborted: no session');
      return;
    }
    final Map<String, dynamic> answers =
        Map<String, dynamic>.from(current.answers);
    answers['contactSync'] = contactSync;
    answers['contactMatchCount'] = matchCount;
    debugPrint(
      'TIPPY_CONTACT_SYNC finish sync=$contactSync matches=$matchCount '
      'mounted=$mounted',
    );
    await _persist(
      current.copyWith(
        answers: answers,
        stage: TippyOnboardingStages.creatorSpaceReady,
      ),
      waitForStorage: false,
    );
  }

  Widget _buildLandingChoice(TippyOnboardingGuestSession session) {
    return Column(
      children: <Widget>[
        _SpeechBubble(text: TippyOnboardingCopy.firstMissionTitle),
        const SizedBox(height: 12),
        TippyMascot(state: TippyMascotState.idle, size: 120),
        const SizedBox(height: 12),
        Text(
          TippyOnboardingCopy.firstMissionBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        if (_isFinishingLanding)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        _LandingCard(
          title: TippyOnboardingCopy.firstMissionName,
          subtitle: TippyOnboardingCopy.firstMissionCta,
          badge: 'Recommended',
          onTap: _isFinishingLanding
              ? null
              : () => unawaited(_finishLanding(session, 'recommended')),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isFinishingLanding
              ? null
              : () => unawaited(_finishLanding(session, 'explore')),
          child: Text(
            TippyOnboardingCopy.firstMissionSkip,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _finishLanding(
    TippyOnboardingGuestSession session,
    String choice,
  ) async {
    debugPrint('TIPPY_LANDING_START choice=$choice');
    if (_isFinishingLanding) {
      return;
    }
    setState(() {
      _isBusy = true;
      _isFinishingLanding = true;
      _error = null;
    });
    final String reservedUsername = _visibleUsername(session);
    final TippyOnboardingGuestSession next = session
        .withReservedUsername(reservedUsername)
        .copyWith(
      landingChoice: choice,
      firstMissionChoice: choice == 'recommended' ? 'accept' : 'skip',
      stage: TippyOnboardingStages.firstMission,
    );
    await _persist(next);
    try {
      final firebase_auth.User? user =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('AUTH_REQUIRED');
      }
      try {
        await user.getIdToken(true);
      } catch (error) {
        debugPrint('TIPPY_LANDING token refresh soft-skip: $error');
      }
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=first_mission_submitted t=${DateTime.now().toUtc().toIso8601String()} choice=$choice username=$reservedUsername',
      );
      TippyOnboardingAttachResult? attachResult;
      Object? lastError;
      bool activated = false;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          attachResult = await _attachSession(next);
          lastError = null;
        } catch (error) {
          lastError = error;
          if (attempt == 0) {
            try {
              await user.getIdToken(true);
            } catch (_) {}
          }
          continue;
        }
        logTippyActivationProof(
          '[ACTIVATION_PROOF] event=first_mission_api t=${DateTime.now().toUtc().toIso8601String()} httpStatus=200 choice=$choice activationState=${attachResult.activationState} allowApp=${attachResult.allowApp} firstGrowthPlanId=${attachResult.firstGrowthPlanId != null}',
        );
        activated = attachResult.isActivated;
        if (!activated) {
          try {
            final AccountStatusSnapshot status = await fetchAccountStatus(
              force: true,
            );
            logTippyActivationProof(
              '[ACTIVATION_PROOF] event=status_returned t=${DateTime.now().toUtc().toIso8601String()} activationState=${status.activationState} allowApp=${status.allowApp} reason=${status.activationReason}',
            );
            activated = canCommitFirstMissionActivation(
              attachActivated: attachResult.isActivated,
              statusAllowApp: status.allowApp,
              statusActivationState: status.activationState,
              statusReason: status.activationReason,
              firstMissionChoice: next.firstMissionChoice,
            );
          } catch (statusError) {
            debugPrint('TIPPY_LANDING status soft-skip: $statusError');
          }
        }
        if (activated) {
          break;
        }
        lastError = StateError('ACTIVATION_NOT_COMMITTED');
      }
      final bool emailVerified = user.emailVerified == true;
      if (!activated && emailVerified) {
        debugPrint(
          'TIPPY_LANDING completing locally after attach '
          'activated=$activated error=$lastError',
        );
      } else if (attachResult == null || !activated) {
        throw lastError ?? StateError('ATTACH_FAILED');
      }
      if (mounted && choice == 'recommended') {
        tippySuccessHaptic(context);
      }
      await OnboardingService().completeTippyLanding(
        userId: user.uid,
        landingChoice: choice,
        firstMissionChoice: next.firstMissionChoice,
      );
      await _store.clearStartedFromWelcomeAfterDeletion();
      await _store.clear();
      _analytics.landingChoice(sessionId: session.sessionId, choice: choice);
      _analytics.completed(
        sessionId: session.sessionId,
        startedAt: session.startedAt,
        firstResultAt: session.firstResultAt,
      );
      if (!mounted) {
        return;
      }
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=mission_control_rendered t=${DateTime.now().toUtc().toIso8601String()}',
      );
      await _dismissTippyToHome(choice: choice);
    } catch (error, stackTrace) {
      if (error is TippyOnboardingAttachException) {
        logTippyActivationProof(
        '[ACTIVATION_PROOF] event=first_mission_api t=${DateTime.now().toUtc().toIso8601String()} httpStatus=${error.statusCode} choice=$choice code=${error.code} error=$error',
        );
      }
      debugPrint('TIPPY_LANDING_FAILED: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        setState(() {
          _error = _finishLandingError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isFinishingLanding = false;
        });
      }
    }
  }

  String _finishLandingError(Object error) {
    final String raw = error.toString().toLowerCase();
    if (raw.contains('auth_required') ||
        raw.contains('session expired') ||
        raw.contains('401')) {
      return 'Could not finish setup. Stay signed in and try again.';
    }
    if (raw.contains('403') || raw.contains('attestation')) {
      return 'Could not finish setup. Restart the app after App Check is registered, then try again.';
    }
    if (raw.contains('permission-denied')) {
      return 'Could not finish setup. Verify your email, then try again.';
    }
    return 'Could not finish setup. Check your connection and try again.';
  }
}

class _TippyThinkingOverlay extends StatelessWidget {
  const _TippyThinkingOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: AppColors.tippyBackground.withValues(alpha: 0.82),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TippyMascot(
                  state: TippyMascotState.thinking,
                  size: 128,
                ),
                SizedBox(height: 16),
                Text(
                  "Give me a second — I'm connecting your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    super.key,
    required this.text,
    this.showTail = true,
  });

  final String text;
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            if (showTail)
              CustomPaint(
                size: const Size(28, 14),
                painter: _ChatBubbleTailPainter(
                  fill: Colors.white.withValues(alpha: 0.12),
                  border: Colors.white.withValues(alpha: 0.14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubbleTailPainter extends CustomPainter {
  const _ChatBubbleTailPainter({
    required this.fill,
    required this.border,
  });

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(size.width * 0.2, 0)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.15,
        size.width * 0.5,
        size.height,
      )
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.15,
        size.width * 0.8,
        0,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ChatBubbleTailPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.border != border;
  }
}

class _CreatorDnaCard extends StatelessWidget {
  const _CreatorDnaCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final List<String> visibleLines = lines.isEmpty
        ? <String>['Creator profile started']
        : lines.take(7).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Your Creator DNA',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...visibleLines.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.85 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: _webOnboardingPrimaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF6B3AA0).withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4A2570).withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: busy ? null : onPressed,
              borderRadius: BorderRadius.circular(18),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactOptionChip extends StatelessWidget {
  const _CompactOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconName,
  });

  final String label;
  final String? iconName;
  final bool selected;
  final VoidCallback onTap;

  IconData? get _iconData {
    switch (iconName) {
      case 'video':
        return Icons.videocam_outlined;
      case 'play':
        return Icons.play_circle_outline;
      case 'scissors':
        return Icons.content_cut;
      case 'zap':
        return Icons.bolt_outlined;
      case 'sprout':
        return Icons.eco_outlined;
      case 'rocket':
        return Icons.rocket_launch_outlined;
      case 'flame':
        return Icons.local_fire_department_outlined;
      case 'trophy':
        return Icons.emoji_events_outlined;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final IconData? icon = _iconData;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? const Color(0xFFC4A3F0)
                      : const Color(0xFF9AA6B8),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeStyleProTrialCard extends StatelessWidget {
  const _UpgradeStyleProTrialCard({
    required this.onStartTrial,
    required this.onMaybeLater,
    required this.busy,
  });

  final Future<void> Function() onStartTrial;
  final Future<void> Function() onMaybeLater;
  final bool busy;

  static const Color _checkBlue = Color(0xFF49C0F8);
  static const Color _ctaBlue = Color(0xFF49C0F8);
  static const Color _muted = Color(0xFF9AA6B8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFF7B3FE4),
                  Color(0xFF2BB8C8),
                ],
              ),
            ),
            child: const Text(
              'RECOMMENDED · 7-DAY FREE TRIAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Creator Pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Unlock everything for your first 7 days',
                            style: TextStyle(
                              color: Color(0xB8FFFFFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Then \$12.99/month · cancel anytime',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xFF66FCF1),
                            Color(0xFF9248D2),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...UpgradeTierMarketing.proBullets.map(
                  (String feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.check_rounded,
                            color: _checkBlue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () {
                            unawaited(onStartTrial());
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ctaBlue,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                    child: const Text(
                      'START FREE 7-DAY TRIAL',
                      style: TextStyle(
                        color: _ctaBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        decoration: TextDecoration.underline,
                        decorationColor: _ctaBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            unawaited(onMaybeLater());
                          },
                    child: const Text(
                      'Maybe Later',
                      style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No charge until the trial ends. You can cancel anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingCard extends StatelessWidget {
  const _LandingCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
