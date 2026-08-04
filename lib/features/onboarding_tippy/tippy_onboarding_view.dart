import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../features/billing/upgrade_tier_marketing.dart';
import '../../routing/app_routes.dart';
import '../../services/robust_auth_service.dart';
import '../../views/upgrade_view.dart';
import '../../widgets/signup_view.dart';
import '../../components/onboarding/onboarding_service.dart';
import '../../services/contacts_service.dart';
import '../tippy/mascot/tippy_mascot.dart';
import '../tippy/mascot/tippy_mascot_types.dart';
import 'tippy_guided_profile_host.dart';
import 'tippy_onboarding_analytics.dart';
import 'tippy_onboarding_attach_service.dart';
import 'tippy_onboarding_contract.dart';
import 'tippy_onboarding_session.dart';
import 'tippy_profile_draft.dart';

/// Tippy-first onboarding funnel (pre-auth + post-auth stages).
class TippyOnboardingView extends ConsumerStatefulWidget {
  const TippyOnboardingView({
    super.key,
    this.initialSession,
    this.startAtWelcome = true,
    this.onCompleted,
  });

  final TippyOnboardingGuestSession? initialSession;

  /// Get Started should always open on Meet Tippy (not a mid-quiz resume).
  final bool startAtWelcome;

  /// Fired after landing choice so [OnboardingGate] can dismiss the overlay.
  final VoidCallback? onCompleted;

  @override
  ConsumerState<TippyOnboardingView> createState() =>
      _TippyOnboardingViewState();
}

class _TippyOnboardingViewState extends ConsumerState<TippyOnboardingView> {
  final TippyOnboardingSessionStore _store = TippyOnboardingSessionStore();
  final TippyOnboardingAttachService _attachService =
      TippyOnboardingAttachService();
  final TippyOnboardingAnalyticsTracker _analytics =
      const TippyOnboardingAnalyticsTracker();
  final TextEditingController _textController = TextEditingController();

  TippyOnboardingGuestSession? _session;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;
  TippyMascotState _mascotState = TippyMascotState.enter;
  List<String> _multiDraft = <String>[];
  /// 0 = meet Tippy, 1 = explain the seven questions.
  int _welcomeBeat = 0;
  final GlobalKey<TippyGuidedProfileHostState> _guidedProfileKey =
      GlobalKey<TippyGuidedProfileHostState>();
  bool _trialCheckoutOffered = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
    ref.listenManual<RobustAuthenticationService>(
      robustAuthServiceProvider,
      (RobustAuthenticationService? previous,
          RobustAuthenticationService next) {
        if (!next.isLoggedIn || _session == null) {
          return;
        }
        if (_session!.stage != TippyOnboardingStages.signup) {
          return;
        }
        unawaited(_handleAuthenticated());
      },
    );
  }

  Future<void> _bootstrap() async {
    TippyOnboardingGuestSession session =
        widget.initialSession ?? await _store.loadOrCreate();
    // Abandoned incomplete funnels restart at Meet Tippy after idle timeout.
    if (session.isInactiveExpired()) {
      await _store.clear();
      session = TippyOnboardingGuestSession.empty();
      await _store.save(session);
    }
    // Get Started (and unfinished quiz resumes without intro) always Meet Tippy first.
    if (widget.startAtWelcome && !_isPostQuizStage(session.stage)) {
      session = session.forceMeetTippyIntro();
      await _store.save(session);
    } else if (!session.hasSeenTippyIntro &&
        !_isPostQuizStage(session.stage)) {
      session = session.forceMeetTippyIntro();
      await _store.save(session);
    }
    // Gate / post-auth resume: authenticated users with incomplete identity
    // should land in guided profile, not Meet Tippy or the feed.
    if (!widget.startAtWelcome) {
      final firebase_auth.User? user =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final String stage = TippyOnboardingStages.normalize(session.stage);
        final bool needsVerify = !user.emailVerified &&
            user.providerData.any(
              (firebase_auth.UserInfo info) => info.providerId == 'password',
            );
        final bool beforeGuided = stage == TippyOnboardingStages.welcome ||
            stage == TippyOnboardingStages.questions ||
            stage == TippyOnboardingStages.notifications ||
            stage == TippyOnboardingStages.trial ||
            stage == TippyOnboardingStages.signup ||
            stage == TippyOnboardingStages.verifyEmail;
        if (beforeGuided) {
          session = session.copyWith(
            stage: needsVerify
                ? TippyOnboardingStages.verifyEmail
                : TippyOnboardingStages.accountSecured,
            hasSeenTippyIntro: true,
          );
          await _store.save(session);
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _isLoading = false;
      _welcomeBeat = 0;
      _mascotState = TippyMascotState.wave;
      _hydrateQuestionDraft(session);
    });
    _analytics.started(sessionId: session.sessionId);
    unawaited(_offerProTrialCheckoutIfNeeded(session));
  }

  bool _isPostQuizStage(String stage) {
    return TippyOnboardingStages.isPostQuizStage(stage);
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
      _multiDraft = existing is List
          ? existing.whereType<String>().toList()
          : <String>[];
    }
  }

  TippyMascotState _mascotForStage(String stage) {
    switch (stage) {
      case TippyOnboardingStages.welcome:
        return TippyMascotState.wave;
      case TippyOnboardingStages.questions:
        return TippyMascotState.thinking;
      case TippyOnboardingStages.success:
        return TippyMascotState.celebrate;
      case TippyOnboardingStages.signup:
      case TippyOnboardingStages.trial:
      case TippyOnboardingStages.notifications:
        return TippyMascotState.speaking;
      default:
        return TippyMascotState.idle;
    }
  }

  Future<void> _persist(TippyOnboardingGuestSession next) async {
    // Update UI first so permission-dialog gaps / storage failures cannot leave
    // the user stuck on the previous Tippy stage.
    if (mounted) {
      setState(() {
        _session = next;
        _mascotState = _mascotForStage(next.stage);
        _error = null;
      });
    }
    try {
      await _store.save(next);
    } catch (error) {
      debugPrint('Tippy session persist soft-fail: $error');
    }
  }

  Future<void> _advanceStage(String stage) async {
    final TippyOnboardingGuestSession? current = _session;
    if (current == null) {
      return;
    }
    await _persist(current.copyWith(stage: stage));
  }

  bool _isPostVerifyCheckoutStage(String stage) {
    final String normalized = TippyOnboardingStages.normalize(stage);
    return TippyOnboardingStages.isGuidedProfileStage(normalized) ||
        normalized == TippyOnboardingStages.findFriends ||
        normalized == TippyOnboardingStages.success ||
        normalized == TippyOnboardingStages.landingChoice;
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

  Future<void> _handleAuthenticated() async {
    final TippyOnboardingGuestSession? session = _session;
    if (session == null || _isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final firebase_auth.User? user =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Write Tippy ownership flags before/without attach API so the gate
        // never falls through to classic "creator focus".
        await OnboardingService().markTippyFunnelInProgress(user.uid);
      }
      try {
        await _attachService.attach(session);
        _analytics.signupAttached(sessionId: session.sessionId);
      } catch (attachError) {
        debugPrint('Tippy attach deferred after auth: $attachError');
      }
      final firebase_auth.User? fresh =
          firebase_auth.FirebaseAuth.instance.currentUser;
      final bool needsVerify = fresh != null &&
          !fresh.emailVerified &&
          fresh.providerData.any(
            (firebase_auth.UserInfo info) => info.providerId == 'password',
          );
      await _advanceStage(
        needsVerify
            ? TippyOnboardingStages.verifyEmail
            : TippyOnboardingStages.accountSecured,
      );
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
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _attachService.dispose();
    super.dispose();
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
            unawaited(_handleBack(current));
          }
        },
        child: Scaffold(
          backgroundColor: _tippySolidBackground,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: <Widget>[
                  _buildBackBar(session),
                  if (session.stage == TippyOnboardingStages.questions)
                    _buildQuestionProgress(session),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      // Do not key on welcomeBeat — both Meet Tippy beats include
                      // TippyMascot, and cross-fading them stacks the brand logo twice.
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          '${session.stage}_${session.questionIndex}',
                        ),
                        child: _buildStage(session),
                      ),
                    ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildBackBar(TippyOnboardingGuestSession session) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: _isBusy ? null : () => unawaited(_handleBack(session)),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: Colors.white,
        tooltip: 'Back',
      ),
    );
  }

  Future<void> _handleBack(TippyOnboardingGuestSession session) async {
    if (_isBusy) {
      return;
    }
    if (_guidedProfileKey.currentState?.consumeBack() == true) {
      return;
    }
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
        setState(() {
          _welcomeBeat = 1;
        });
        await _persist(
          session.copyWith(stage: TippyOnboardingStages.welcome),
        );
        return;
      default:
        final String? previous =
            TippyOnboardingStages.previous(session.stage);
        if (previous == null) {
          Navigator.of(context).maybePop();
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

  Widget _buildStage(TippyOnboardingGuestSession session) {
    final String stage = TippyOnboardingStages.normalize(session.stage);
    switch (stage) {
      case TippyOnboardingStages.welcome:
        return _buildMeetTippyIntro();
      case TippyOnboardingStages.questions:
        return _buildQuestions(session);
      case TippyOnboardingStages.notifications:
        return _buildNotifications(session);
      case TippyOnboardingStages.trial:
        return _buildTrial(session);
      case TippyOnboardingStages.signup:
        return _buildSignup(session);
      case TippyOnboardingStages.verifyEmail:
        return _buildVerifyEmail();
      case TippyOnboardingStages.accountSecured:
      case TippyOnboardingStages.avatar:
      case TippyOnboardingStages.displayName:
      case TippyOnboardingStages.username:
      case TippyOnboardingStages.bio:
      case TippyOnboardingStages.platforms:
      case TippyOnboardingStages.categories:
      case TippyOnboardingStages.profileReview:
        return TippyGuidedProfileHost(
          key: _guidedProfileKey,
          session: session,
          onPersist: _persistProfileDraft,
          onAdvanceStage: _advanceStage,
          busy: _isBusy,
          error: _error,
        );
      case TippyOnboardingStages.findFriends:
        return _buildFindFriends();
      case TippyOnboardingStages.success:
        final Object? contactSync = session.answers['contactSync'];
        final String? contactSpeech = _contactSyncResultSpeech(
          contactSync: contactSync is String ? contactSync : null,
        );
        return _tippyScene(
          speech: TippyOnboardingCopy.success,
          secondarySpeech: contactSpeech,
          primaryLabel: 'CONTINUE',
          onPrimary: () => _advanceStage(TippyOnboardingStages.landingChoice),
          mascotOverride: TippyMascotState.celebrate,
        );
      case TippyOnboardingStages.landingChoice:
        return _buildLandingChoice(session);
      default:
        return _tippyScene(
          speech: TippyOnboardingCopy.welcome,
          primaryLabel: 'CONTINUE',
          onPrimary: () => _advanceStage(TippyOnboardingStages.questions),
        );
    }
  }

  /// Duolingo-style Tippy introduction before any questions.
  Widget _buildMeetTippyIntro() {
    final String speech = _welcomeBeat == 0
        ? TippyOnboardingCopy.welcomeHi
        : TippyOnboardingCopy.questionsIntro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Spacer(flex: 2),
        _SpeechBubble(
          text: speech,
          showTail: true,
        ),
        const SizedBox(height: 8),
        TippyMascot(
          state: _welcomeBeat == 0
              ? TippyMascotState.wave
              : TippyMascotState.speaking,
          size: 196,
        ),
        const Spacer(flex: 3),
        _PrimaryButton(
          label: 'CONTINUE',
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
      if (_welcomeBeat == 0) {
        setState(() {
          _welcomeBeat = 1;
          _mascotState = TippyMascotState.speaking;
        });
        return;
      }
      final TippyOnboardingGuestSession? current = _session;
      if (current != null) {
        await _persist(
          current.copyWith(
            stage: TippyOnboardingStages.questions,
            questionIndex: 0,
            hasSeenTippyIntro: true,
          ),
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

  Widget _tippyScene({
    required String speech,
    required String primaryLabel,
    required Future<void> Function() onPrimary,
    String? secondarySpeech,
    String? secondaryLabel,
    Future<void> Function()? onSecondary,
    TippyMascotState? mascotOverride,
    Widget? extra,
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
          busy: _isBusy,
          onPressed: () async {
            if (_isBusy) {
              return;
            }
            setState(() => _isBusy = true);
            try {
              await onPrimary();
            } finally {
              if (mounted) {
                setState(() => _isBusy = false);
              }
            }
          },
        ),
        if (secondaryLabel != null && onSecondary != null) ...<Widget>[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isBusy
                ? null
                : () async {
                    setState(() => _isBusy = true);
                    try {
                      await onSecondary();
                    } finally {
                      if (mounted) {
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
        const SizedBox(height: 8),
        Text(
          question.why,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        TippyMascot(state: _mascotState, size: 120),
        const SizedBox(height: 16),
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
                selected: false,
                onTap: () => unawaited(_selectSingle(question, option.id)),
              ),
            );
          }).toList(),
        );
      case TippyOnboardingInputType.multiSelect:
        return ListView(
          children: question.options.map((TippyOnboardingOption option) {
            final bool selected = _multiDraft.contains(option.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionChip(
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
              ),
            );
          }).toList(),
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
    final int nextIndex = current.questionIndex + 1;
    if (nextIndex >= kTippyOnboardingTotalQuestions) {
      await _persist(
        current.copyWith(
          answers: answers,
          questionIndex: kTippyOnboardingTotalQuestions - 1,
          stage: TippyOnboardingStages.notifications,
          completedQuestionsAt: DateTime.now().toUtc(),
        ),
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
    await _persist(next);
    _analytics.stepCompleted(
      sessionId: current.sessionId,
      stage: TippyOnboardingStages.questions,
      questionIndex: current.questionIndex,
    );
    _textController.clear();
    _multiDraft = <String>[];
    _hydrateQuestionDraft(next);
  }

  Widget _buildNotifications(TippyOnboardingGuestSession session) {
    return _tippyScene(
      speech: TippyOnboardingCopy.notificationsExplain,
      primaryLabel: 'ENABLE NOTIFICATIONS',
      onPrimary: () async {
        try {
          if (!kIsWeb) {
            await FirebaseMessaging.instance.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            );
          }
        } catch (_) {}
        await _persist(
          session.copyWith(
            notificationsChoice: 'enabled',
            stage: TippyOnboardingStages.trial,
          ),
        );
      },
      secondaryLabel: 'Not now',
      onSecondary: () async {
        await _persist(
          session.copyWith(
            notificationsChoice: 'declined',
            stage: TippyOnboardingStages.trial,
          ),
        );
      },
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
        const _SpeechBubble(text: TippyOnboardingCopy.preSignup),
        const SizedBox(height: 10),
        TippyMascot(state: TippyMascotState.speaking, size: 96),
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
        _PrimaryButton(
          label: 'CONTINUE WITH APPLE',
          busy: _isBusy,
          onPressed: () => unawaited(_signUpWithApple()),
        ),
        const SizedBox(height: 10),
        _PrimaryButton(
          label: 'CONTINUE WITH GOOGLE',
          busy: _isBusy,
          onPressed: () => unawaited(_signUpWithGoogle()),
        ),
        const SizedBox(height: 10),
        _PrimaryButton(
          label: 'CONTINUE WITH EMAIL',
          busy: _isBusy,
          onPressed: () async {
            _analytics.signupStarted(sessionId: session.sessionId);
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => SignupView(
                  dismiss: () => Navigator.of(context).maybePop(),
                  onAuthenticatedStay: () {
                    Navigator.of(context).maybePop();
                    unawaited(_handleAuthenticated());
                  },
                  deferUsernameSelection: true,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _signUpWithGoogle() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _error = null;
    });
    try {
      final RobustAuthenticationService auth =
          ref.read(robustAuthServiceProvider);
      await auth.debouncedSignInWithGoogle();
      // Auth listener advances from signup → guided profile.
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _signUpWithApple() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _error = null;
    });
    try {
      final RobustAuthenticationService auth =
          ref.read(robustAuthServiceProvider);
      await auth.debouncedSignInWithApple();
      // Auth listener advances from signup → guided profile.
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  Widget _buildVerifyEmail() {
    return _tippyScene(
      speech: TippyOnboardingCopy.verifyEmail,
      primaryLabel: 'I VERIFIED — CONTINUE',
      onPrimary: () async {
        final firebase_auth.User? user =
            firebase_auth.FirebaseAuth.instance.currentUser;
        await user?.reload();
        final firebase_auth.User? fresh =
            firebase_auth.FirebaseAuth.instance.currentUser;
        if (fresh != null && fresh.emailVerified) {
          await _advanceStage(TippyOnboardingStages.accountSecured);
          final TippyOnboardingGuestSession? after = _session;
          if (after != null) {
            await _offerProTrialCheckoutIfNeeded(after);
          }
          return;
        }
        setState(() {
          _error = 'Email not verified yet. Check your inbox and try again.';
        });
      },
      secondaryLabel: 'Resend email',
      onSecondary: () async {
        final firebase_auth.User? user =
            firebase_auth.FirebaseAuth.instance.currentUser;
        await user?.sendEmailVerification();
      },
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
        stage: TippyOnboardingStages.success,
      ),
    );
  }

  Widget _buildLandingChoice(TippyOnboardingGuestSession session) {
    return Column(
      children: <Widget>[
        _SpeechBubble(text: TippyOnboardingCopy.landingChoice),
        const SizedBox(height: 12),
        TippyMascot(state: TippyMascotState.idle, size: 120),
        const SizedBox(height: 20),
        if (_isBusy)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        _LandingCard(
          title: 'Build My Creator Workspace',
          subtitle:
              'Let Tippy guide you through your personalized setup and first recommendations.',
          badge: 'Recommended',
          onTap: _isBusy
              ? null
              : () => unawaited(_finishLanding(session, 'recommended')),
        ),
        const SizedBox(height: 12),
        _LandingCard(
          title: 'Explore StreamersTip',
          subtitle:
              'Jump into the For You feed and explore the community at your own pace.',
          onTap: _isBusy
              ? null
              : () => unawaited(_finishLanding(session, 'explore')),
        ),
      ],
    );
  }

  Future<void> _finishLanding(
    TippyOnboardingGuestSession session,
    String choice,
  ) async {
    debugPrint('TIPPY_LANDING_START choice=$choice');
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    final TippyOnboardingGuestSession next = session.copyWith(
      landingChoice: choice,
      stage: TippyOnboardingStages.landingChoice,
    );
    await _persist(next);
    try {
      final firebase_auth.User? user =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await _attachService.attach(next);
        } catch (attachError) {
          debugPrint('TIPPY_LANDING attach soft-skip: $attachError');
        }
        // Prefer service path (safe merge + session cache) so OnboardingGate
        // can dismiss the Tippy overlay without nested-navigator remounts.
        await OnboardingService().completeTippyLanding(
          userId: user.uid,
          landingChoice: choice,
        );
      }
      await _store.clear();
      _analytics.landingChoice(sessionId: session.sessionId, choice: choice);
      _analytics.completed(sessionId: session.sessionId);
      if (!mounted) {
        return;
      }
      final NavigatorState? rootNav =
          Navigator.maybeOf(context, rootNavigator: true);
      final NavigatorState? localNav = Navigator.maybeOf(context);
      final bool isOverlayOnHome =
          rootNav != null && localNav != null && !identical(rootNav, localNav);
      // Dismiss Tippy overlay immediately — do not wait on Firestore watch
      // (client writes may be soft-skipped on permission-denied).
      widget.onCompleted?.call();
      if (isOverlayOnHome) {
        // Home is already under OnboardingGate — do not pushNamed home on the
        // nested onboarding navigator (that remounts Tippy on a stale session).
        debugPrint('TIPPY_LANDING_DONE overlay_mode choice=$choice');
        return;
      }
      debugPrint('TIPPY_LANDING_DONE route_mode choice=$choice');
      await (rootNav ?? localNav)?.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (Route<dynamic> route) => false,
      );
    } catch (error, stackTrace) {
      debugPrint('TIPPY_LANDING_FAILED: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        setState(() {
          _error =
              'Could not finish setup. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
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
              colors: <Color>[
                AppColors.primary,
                Color(0xFF7768DF),
                Color(0xFF4897D2),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4897D2).withValues(alpha: 0.28),
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

class _OptionChip extends StatelessWidget {
  const _OptionChip({
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
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
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
