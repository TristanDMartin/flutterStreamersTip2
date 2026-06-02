import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routing/app_routes.dart';
import 'level_one_checklist.dart';
import 'onboarding_celebration_modal.dart';
import 'onboarding_intro_modal.dart';
import 'onboarding_mission_actions.dart';
import 'onboarding_models.dart';
import 'onboarding_service.dart';
import 'onboarding_tester_config.dart';
import 'product_tour_overlay.dart';

class StreamersTipOnboarding extends StatefulWidget {
  const StreamersTipOnboarding({
    super.key,
    required this.userId,
    required this.child,
    this.email,
    this.username,
    this.service,
    this.onTourStepChanged,
  });

  final String userId;
  final Widget child;
  final String? email;
  final String? username;
  final OnboardingService? service;
  final ValueChanged<String>? onTourStepChanged;

  @override
  State<StreamersTipOnboarding> createState() => _StreamersTipOnboardingState();
}

class _StreamersTipOnboardingState extends State<StreamersTipOnboarding> {
  bool _showChecklist = false;
  bool _showOptionalProductTour = false;
  OnboardingMission? _celebratedMission;
  StreamSubscription<OnboardingState>? _subscription;
  StreamSubscription<OnboardingMissionResult>? _missionSubscription;
  OnboardingState _state = OnboardingState.initial();
  late OnboardingService _service;
  bool _checkedTesterSessionReset = false;
  bool _loadedLocalOnboardingState = false;
  bool _localCompletedOnboarding = false;
  bool _receivedRemoteOnboardingState = false;
  bool _didLevelOneEvidenceSync = false;
  bool _levelOneChecklistUserDismissed = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingService();
    unawaited(_loadLocalOnboardingState());
    _listen();
    _listenForMissionCompletions();
  }

  @override
  void didUpdateWidget(StreamersTipOnboarding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.service != widget.service) {
      _subscription?.cancel();
      _missionSubscription?.cancel();
      _service = widget.service ?? OnboardingService();
      _checkedTesterSessionReset = false;
      _loadedLocalOnboardingState = false;
      _localCompletedOnboarding = false;
      _receivedRemoteOnboardingState = false;
      _didLevelOneEvidenceSync = false;
      _levelOneChecklistUserDismissed = false;
      unawaited(_loadLocalOnboardingState());
      _listen();
      _listenForMissionCompletions();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _missionSubscription?.cancel();
    super.dispose();
  }

  void _listen() {
    _subscription = _service.watchOnboarding(widget.userId).listen(
      (OnboardingState state) {
        if (!mounted) return;
        if (state.hasCompletedOnboarding) {
          _levelOneChecklistUserDismissed = false;
          unawaited(_persistLocalCompletedOnboarding());
        }
        setState(() {
          _receivedRemoteOnboardingState = true;
          _state = state;
          if (!_levelOneChecklistUserDismissed &&
              state.hasCompletedProductTour &&
              !state.hasCompletedOnboarding &&
              !state.skippedSteps.contains('level_one_checklist')) {
            _showChecklist = true;
          }
        });
        unawaited(_resetTesterOnboardingForSessionIfNeeded());
        final bool isTester = OnboardingTesterConfig.isTesterUser(
          userId: widget.userId,
          email: widget.email,
          username: widget.username,
        );
        if (!_didLevelOneEvidenceSync &&
            !isTester &&
            !state.hasCompletedOnboarding) {
          _didLevelOneEvidenceSync = true;
          unawaited(
            _service.syncLevelOneMissionsFromAccountEvidence(widget.userId),
          );
        }
      },
    );
  }

  void _listenForMissionCompletions() {
    _missionSubscription = OnboardingMissionActions.completedMissions.listen(
      (OnboardingMissionResult result) {
        if (!mounted || result.wasAlreadyComplete) return;
        setState(() {
          _celebratedMission = result.mission;
          if (!_levelOneChecklistUserDismissed &&
              _state.hasCompletedProductTour &&
              !_state.hasCompletedOnboarding) {
            _showChecklist = true;
          }
        });
        if (result.completedLevelOne) {
          unawaited(_service.completeOnboarding(widget.userId));
        }
      },
    );
  }

  String get _localCompletedKey =>
      'streamerstip.onboarding.completed.${widget.userId}';

  Future<void> _loadLocalOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_localCompletedKey) ?? false;
    if (!mounted) return;
    setState(() {
      _localCompletedOnboarding = completed;
      _loadedLocalOnboardingState = true;
    });
  }

  Future<void> _persistLocalCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localCompletedKey, true);
    if (!mounted) return;
    setState(() {
      _localCompletedOnboarding = true;
      _loadedLocalOnboardingState = true;
    });
  }

  Future<void> _resetTesterOnboardingForSessionIfNeeded() async {
    if (_checkedTesterSessionReset) return;
    _checkedTesterSessionReset = true;
    if (!OnboardingTesterConfig.isTesterUser(
      userId: widget.userId,
      email: widget.email,
      username: widget.username,
    )) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _state = OnboardingState.initial();
      _showChecklist = false;
      _showOptionalProductTour = false;
      _localCompletedOnboarding = false;
      _loadedLocalOnboardingState = true;
      _receivedRemoteOnboardingState = true;
      _levelOneChecklistUserDismissed = false;
    });
    await _service.resetForDeveloperTesterInstall(widget.userId);
  }

  void _openMission(OnboardingMission mission) {
    switch (mission.id) {
      case 'complete_profile':
        Navigator.of(context).pushNamed(AppRoutes.profile);
        break;
      case 'upload_first_post':
        Navigator.of(context).pushNamed(AppRoutes.camera);
        break;
      case 'connect_platform':
        Navigator.of(context).pushNamed(AppRoutes.linkedPlatforms);
        break;
      case 'create_content_plan':
        Navigator.of(context).pushNamed(AppRoutes.contentPlanner);
        break;
      case 'share_creator_card':
        break;
    }
    setState(() => _showChecklist = false);
  }

  Future<void> _finishProductTour() async {
    setState(() {
      _showChecklist = true;
      _showOptionalProductTour = false;
    });
    await _service.completeProductTour(widget.userId);
  }

  Future<void> _skipProductTour(int step) async {
    setState(() {
      _showChecklist = true;
      _showOptionalProductTour = false;
    });
    await _service.skipProductTour(widget.userId, step);
  }

  Future<void> _startExploring(String creatorGoal) async {
    await _service.completeIntro(widget.userId, creatorGoal);
    await _service.completeProductTour(widget.userId);
  }

  Future<void> _watchQuickTour(String creatorGoal) async {
    await _service.completeIntro(widget.userId, creatorGoal);
    if (!mounted) return;
    setState(() => _showOptionalProductTour = true);
  }

  Future<void> _persistChecklistDismissed() async {
    await _service.dismissLevelOneChecklist(widget.userId);
    await _service.completeOnboarding(widget.userId);
  }

  void _onLevelOneChecklistSwipeDismiss() {
    if (!mounted) {
      return;
    }
    setState(() {
      _levelOneChecklistUserDismissed = true;
      _showChecklist = false;
    });
    unawaited(_persistChecklistDismissed());
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets safePadding = MediaQuery.paddingOf(context);
    final bool compact = size.height < 720 || size.width < 380;
    final bool isTester = OnboardingTesterConfig.isTesterUser(
      userId: widget.userId,
      email: widget.email,
      username: widget.username,
    );
    final bool suppressOnboarding = !isTester &&
        (!_loadedLocalOnboardingState ||
            !_receivedRemoteOnboardingState ||
            _localCompletedOnboarding);
    if (suppressOnboarding) {
      return widget.child;
    }
    return Stack(
      children: <Widget>[
        widget.child,
        if (!_state.hasSeenIntro)
          Positioned(
            left: 10,
            right: 10,
            bottom: safePadding.bottom > 0 ? 8 : 14,
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: OnboardingIntroModal(
                onComplete: (String creatorGoal) =>
                    unawaited(_startExploring(creatorGoal)),
                onWatchQuickTour: (String creatorGoal) =>
                    unawaited(_watchQuickTour(creatorGoal)),
                onSkip: () {
                  unawaited(_startExploring('grow_audience'));
                },
              ),
            ),
          )
        else if (_showOptionalProductTour)
          Positioned.fill(
            child: ProductTourOverlay(
              initialStep: _state.currentOnboardingStep,
              waitForFeedVideo: true,
              onStepChanged: widget.onTourStepChanged,
              onFinish: () => unawaited(_finishProductTour()),
              onSkip: (int step) => unawaited(_skipProductTour(step)),
            ),
          ),
        if (_showChecklist && _state.hasCompletedProductTour)
          Positioned(
            left: compact ? 8 : 12,
            right: compact ? 8 : 12,
            bottom: safePadding.bottom + (compact ? 74 : 88),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Material(
                  color: Colors.transparent,
                  child: _LevelOneChecklistDragDismiss(
                    onSwipeDismiss: _onLevelOneChecklistSwipeDismiss,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: <Widget>[
                              const SizedBox(width: 40),
                              Expanded(
                                child: Semantics(
                                  label: 'Swipe down to dismiss checklist',
                                  container: true,
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.35),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Semantics(
                                label: 'Dismiss checklist',
                                button: true,
                                child: IconButton.filledTonal(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: _onLevelOneChecklistSwipeDismiss,
                                ),
                              ),
                            ],
                          ),
                        ),
                        LevelOneChecklist(
                          state: _state,
                          onMissionTap: _openMission,
                          compact: compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_celebratedMission != null)
          OnboardingCelebrationModal(
            mission: _celebratedMission!,
            nextMission: _state.nextMission,
            onClose: () => setState(() => _celebratedMission = null),
          ),
      ],
    );
  }
}

class _LevelOneChecklistDragDismiss extends StatefulWidget {
  const _LevelOneChecklistDragDismiss({
    required this.child,
    required this.onSwipeDismiss,
  });

  final Widget child;
  final VoidCallback onSwipeDismiss;

  @override
  State<_LevelOneChecklistDragDismiss> createState() =>
      _LevelOneChecklistDragDismissState();
}

class _LevelOneChecklistDragDismissState
    extends State<_LevelOneChecklistDragDismiss> {
  static const double _commitDragPx = 72;
  static const double _commitVelocity = 380;
  double _dragDy = 0;
  bool _committed = false;

  void _commit() {
    if (_committed) {
      return;
    }
    _committed = true;
    widget.onSwipeDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onVerticalDragUpdate: (DragUpdateDetails details) {
        if (_committed) {
          return;
        }
        final double delta = details.primaryDelta ?? 0;
        if (delta <= 0) {
          return;
        }
        setState(() {
          _dragDy = (_dragDy + delta).clamp(0.0, 400.0);
        });
      },
      onVerticalDragEnd: (DragEndDetails details) {
        if (_committed) {
          return;
        }
        final double velocity = details.primaryVelocity ?? 0;
        if (velocity > _commitVelocity || _dragDy > _commitDragPx) {
          _commit();
          return;
        }
        setState(() => _dragDy = 0);
      },
      child: Transform.translate(
        offset: Offset(0, _dragDy),
        child: widget.child,
      ),
    );
  }
}

class OnboardingMissionEmitter {
  const OnboardingMissionEmitter._();

  static Future<OnboardingMissionResult> completeOnboardingMission({
    required OnboardingService service,
    required String userId,
    required String missionId,
  }) {
    return service.completeMission(userId, missionId);
  }
}
