import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../widgets/profile/profile_platforms_update_helper.dart';
import '../../utils/auth_post_login_navigation.dart';
import 'onboarding_models.dart';
import 'onboarding_service.dart';
import 'onboarding_style.dart';
import 'screens/onboarding_creator_card_screen.dart';
import 'screens/onboarding_level_unlock_screen.dart';
import 'screens/onboarding_personalize_screen.dart';
import 'screens/onboarding_welcome_screen.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    required this.userId,
    required this.initialState,
    required this.onCompleted,
    this.service,
    this.showTesterSkip = false,
  });

  final String userId;
  final OnboardingState initialState;
  final VoidCallback onCompleted;
  final OnboardingService? service;
  final bool showTesterSkip;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  late final PageController _pageController;
  late OnboardingService _service;
  late int _step;
  late List<String> _goals;
  late List<String> _platforms;
  bool _isCompleting = false;
  Map<String, dynamic>? _profileSeed;
  bool _emailBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingService();
    _step = _resolveInitialStep(widget.initialState);
    _goals = List<String>.from(widget.initialState.creatorGoals);
    _platforms = List<String>.from(widget.initialState.platforms);
    _emailBannerDismissed = widget.initialState.emailBannerDismissed;
    _profileSeed = _buildFallbackProfileSeed();
    _pageController = PageController(initialPage: _step);
    // Tippy already collected focus + creator identity — never replay classic.
    // If funnel is still incomplete, gate should show Tippy; do not force
    // tippyFunnelCompleted via classic replacement.
    if (widget.initialState.isTippyFunnelIncomplete) {
      return;
    }
    if (widget.initialState.slim7Completed ||
        widget.initialState.tippyOnboardingV1Attached ||
        widget.initialState.tippyFunnelCompleted) {
      unawaited(_finishBecauseTippyAlreadyCompleted());
      return;
    }
    unawaited(_loadProfileSeedOnce());
  }

  Future<void> _finishBecauseTippyAlreadyCompleted() async {
    if (_isCompleting) {
      return;
    }
    setState(() {
      _isCompleting = true;
    });
    try {
      await _service.completeClassicOnboardingReplacedByTippy(widget.userId);
    } catch (_) {}
    if (mounted) {
      widget.onCompleted();
    }
  }

  Map<String, dynamic> _buildFallbackProfileSeed() {
    final fa.User? authUser = fa.FirebaseAuth.instance.currentUser;
    return <String, dynamic>{
      'id': widget.userId,
      'uid': widget.userId,
      'displayName': authUser?.displayName?.trim() ?? '',
      'username': '',
      'bio': '',
      'categoryId': '',
      'platforms': const <Map<String, dynamic>>[],
      'avatarURL': authUser?.photoURL,
      'photoURL': authUser?.photoURL,
    };
  }

  Future<void> _loadProfileSeedOnce() async {
    try {
      final Map<String, dynamic> seed = await _loadProfileSeed().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profileSeed = seed;
      });
    } catch (error) {
      debugPrint('OnboardingView: profile seed load failed: $error');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _resolveInitialStep(OnboardingState state) {
    if (state.currentStep >= 3) {
      return 3;
    }
    if (state.currentStep >= 2) {
      return 2;
    }
    // Slim 7 Tippy answers replace the personalize (goals/platforms) step.
    if (state.slim7Completed || state.tippyOnboardingV1Attached) {
      return 2;
    }
    if (state.currentStep >= 1 || state.hasSeenIntro) {
      return 1;
    }
    return 0;
  }

  Future<void> _skipOnboarding() async {
    if (_isCompleting) {
      return;
    }
    setState(() {
      _isCompleting = true;
    });
    await _service.skipOnboardingAsTester(widget.userId);
    if (mounted) {
      widget.onCompleted();
    }
  }

  Widget _buildTesterSkipBar() {
    if (!widget.showTesterSkip) {
      return const SizedBox.shrink();
    }
    final double topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _isCompleting ? null : _skipOnboarding,
          child: Text(
            'Skip',
            style: TextStyle(
              color: OnboardingStyle.textSecondaryFor(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _goToStep(int step) async {
    setState(() {
      _step = step;
    });
    await _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<Map<String, dynamic>> _loadProfileSeed() async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final fa.User? authUser = fa.FirebaseAuth.instance.currentUser;
    final List<Map<String, dynamic>> platforms =
        ProfilePlatformsUpdateHelper.readPlatforms(data);
    return <String, dynamic>{
      'id': widget.userId,
      'uid': widget.userId,
      'displayName': (data['displayName'] as String?)?.trim() ??
          authUser?.displayName ??
          '',
      'username': (data['username'] as String?)?.trim() ?? '',
      'bio': (data['bio'] as String?)?.trim() ?? '',
      'categoryId': (data['categoryId'] as String?)?.trim() ??
          (data['category'] as String?)?.trim() ??
          '',
      'platforms': platforms,
      'avatarURL': (data['avatarURL'] as String?)?.trim() ??
          (data['photoURL'] as String?)?.trim() ??
          authUser?.photoURL,
      'photoURL': (data['photoURL'] as String?)?.trim() ??
          (data['avatarURL'] as String?)?.trim() ??
          authUser?.photoURL,
    };
  }

  Widget _buildCreatorCardStep() {
    return OnboardingCreatorCardScreen(
      key: const ValueKey<String>('onboarding-creator-card'),
      initialUser: _profileSeed ?? _buildFallbackProfileSeed(),
      onBack: () => _goToStep(1),
      onContinue: (Map<String, dynamic> user) async {
        await _service.saveCreatorCard(
          userId: widget.userId,
          displayName: (user['displayName'] as String?) ?? '',
          username: (user['username'] as String?) ?? '',
          bio: (user['bio'] as String?) ?? '',
          categoryId: (user['categoryId'] as String?) ?? '',
          avatarUrl: (user['avatarURL'] as String?)?.trim(),
          platforms: ProfilePlatformsUpdateHelper.readPlatforms(user),
        );
        setState(() {
          _profileSeed = user;
        });
        await _goToStep(3);
      },
    );
  }

  String get _displayNameForUnlock {
    return (_profileSeed?['displayName'] as String?)?.trim() ?? 'Creator';
  }

  bool get _shouldShowEmailBanner {
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    return user != null && firebaseUserNeedsEmailVerification(user);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialState.isTippyFunnelIncomplete) {
      return const SizedBox.shrink();
    }
    if (_isCompleting &&
        (widget.initialState.slim7Completed ||
            widget.initialState.tippyOnboardingV1Attached ||
            widget.initialState.tippyFunnelCompleted)) {
      return const Scaffold(
        backgroundColor: OnboardingStyle.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: OnboardingStyle.background,
      resizeToAvoidBottomInset: true,
      body: DefaultTextStyle(
        style: OnboardingStyle.plainTextStyle(
          Theme.of(context).textTheme.bodyMedium ??
              const TextStyle(fontSize: 14),
        ),
        child: PopScope(
          canPop: false,
          child: Column(
            children: <Widget>[
              _buildTesterSkipBar(),
              Expanded(
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (BuildContext context, Widget? child) {
                    final double page = _pageController.hasClients
                        ? (_pageController.page ?? _step.toDouble())
                        : _step.toDouble();
                    final double delta = (page - _step).abs().clamp(0.0, 1.0);
                    final double opacity = 1 - (delta * 0.18);
                    final double scale = 1 - (delta * 0.02);
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: child,
                      ),
                    );
                  },
                  child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (int index) {
                    setState(() {
                      _step = index;
                    });
                  },
                  children: <Widget>[
                    OnboardingWelcomeScreen(
                      userId: widget.userId,
                      emailBannerDismissed: _emailBannerDismissed,
                      showEmailBanner: _shouldShowEmailBanner,
                      email:
                          fa.FirebaseAuth.instance.currentUser?.email ?? '',
                      onGetStarted: () async {
                        await _service.advanceToStep(widget.userId, 1);
                        await _goToStep(1);
                      },
                    ),
                    OnboardingPersonalizeScreen(
                      initialGoals: _goals,
                      initialPlatforms: _platforms,
                      onBack: () => _goToStep(0),
                      onContinue: (({
                        List<String> goals,
                        List<String> platforms,
                      }) data) async {
                        _goals = data.goals;
                        _platforms = data.platforms;
                        await _service.savePersonalize(
                          userId: widget.userId,
                          goals: data.goals,
                          platforms: data.platforms,
                        );
                        await _goToStep(2);
                      },
                      onSkip: () async {
                        await _service.advanceToStep(widget.userId, 2);
                        await _goToStep(2);
                      },
                    ),
                    _buildCreatorCardStep(),
                    OnboardingLevelUnlockScreen(
                      userId: widget.userId,
                      displayName: _displayNameForUnlock,
                      isLoading: _isCompleting,
                      onBack: () => _goToStep(2),
                      onEnterApp: () async {
                        if (_isCompleting) {
                          return;
                        }
                        setState(() {
                          _isCompleting = true;
                        });
                        await _service.completeOnboarding(widget.userId);
                        if (mounted) {
                          widget.onCompleted();
                        }
                      },
                    ),
                  ],
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
