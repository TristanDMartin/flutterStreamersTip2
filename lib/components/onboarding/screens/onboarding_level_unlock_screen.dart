import 'package:flutter/material.dart';

import '../../../services/app_store_review_service.dart';
import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';
import '../widgets/onboarding_full_screen_shell.dart';
import '../widgets/onboarding_progress_header.dart';
import '../widgets/onboarding_soft_rating_widget.dart';
import '../widgets/xp_pop_animation.dart';

class OnboardingLevelUnlockScreen extends StatefulWidget {
  const OnboardingLevelUnlockScreen({
    super.key,
    required this.userId,
    required this.onEnterApp,
    required this.onBack,
    this.isLoading = false,
    this.displayName = 'Creator',
  });

  final String userId;
  final VoidCallback onEnterApp;
  final VoidCallback onBack;
  final bool isLoading;
  final String displayName;

  @override
  State<OnboardingLevelUnlockScreen> createState() =>
      _OnboardingLevelUnlockScreenState();
}

class _OnboardingLevelUnlockScreenState extends State<OnboardingLevelUnlockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _xpPopShown = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showXpPop());
  }

  void _showXpPop() {
    if (_xpPopShown || !mounted) {
      return;
    }
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    _xpPopShown = true;
    XpPopAnimation.show(
      context: context,
      xpAmount: '+${OnboardingV1Constants.levelOneUnlockRewardXp} XP',
      onComplete: () {},
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String headlineName = widget.displayName.trim().isEmpty
        ? 'Creator'
        : widget.displayName.trim();
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool isCompact = screenHeight < 760;
    final double badgeSize = isCompact ? 72 : 88;
    final double titleSize = isCompact ? 22 : 28;
    final double sectionGap = isCompact ? 12 : 24;
    final double missionGap = isCompact ? 8 : 10;
    final double missionPaddingV = isCompact ? 10 : 14;
    return OnboardingScreenLayout(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1A1033),
            Color(0xFF0F172A),
            Color(0xFF162447),
          ],
        ),
      ),
      child: Column(
        children: <Widget>[
          OnboardingProgressHeader(
            step: 4,
            totalSteps: OnboardingV1Constants.totalSteps,
            showBack: true,
            onBack: widget.onBack,
          ),
          Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, isCompact ? 4 : 8, 24, 12),
                child: Column(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (BuildContext context, Widget? child) {
                        final double glow =
                            12 + (_pulseController.value * 16);
                        return Container(
                          width: badgeSize,
                          height: badgeSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: OnboardingStyle.primaryGradient,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFF9248D2)
                                    .withValues(alpha: 0.35 + _pulseController.value * 0.25),
                                blurRadius: glow,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 34 : 40,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 12 : 20),
                    Text(
                      'You\'re Level 1, $headlineName!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OnboardingStyle.textPrimaryFor(context),
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 8),
                    Text(
                      '+${OnboardingV1Constants.levelOneUnlockRewardXp} XP',
                      style: TextStyle(
                        color: const Color(0xFF00F5A0),
                        fontWeight: FontWeight.w900,
                        fontSize: isCompact ? 16 : 18,
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    ...OnboardingLevelOneMissions.starterMissions.map(
                      (({String id, String title, String emoji}) mission) {
                        final bool isComplete =
                            OnboardingLevelOneMissions.isMissionComplete(
                          missionId: mission.id,
                          creatorCardCompleted: true,
                        );
                        return Padding(
                          padding: EdgeInsets.only(bottom: missionGap),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: missionPaddingV,
                            ),
                            decoration: BoxDecoration(
                              color: OnboardingStyle.surfaceFor(context)
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: OnboardingStyle.borderFor(context),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  mission.emoji,
                                  style: TextStyle(
                                    fontSize: isCompact ? 18 : 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    mission.title,
                                    style: TextStyle(
                                      color: isComplete
                                          ? OnboardingStyle.textSecondaryFor(
                                              context,
                                            )
                                          : OnboardingStyle.textPrimaryFor(
                                              context,
                                            ),
                                      decoration: isComplete
                                          ? TextDecoration.lineThrough
                                          : null,
                                      fontWeight: FontWeight.w700,
                                      fontSize: isCompact ? 14 : 15,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isComplete
                                      ? Icons.check_circle_rounded
                                      : Icons.lock_rounded,
                                  color: isComplete
                                      ? const Color(0xFF00F5A0)
                                      : OnboardingStyle.textSecondaryFor(
                                          context,
                                        ),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: isCompact ? 10 : 16),
                    OnboardingSoftRatingWidget(
                      userId: widget.userId,
                      onRequestReview: requestAppStoreReview,
                      compact: isCompact,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, isCompact ? 16 : 28),
              child: SizedBox(
                width: double.infinity,
                child: GradientPillButton(
                  useSolidPurple: true,
                  label: widget.isLoading
                      ? 'Loading...'
                      : 'Enter StreamersTip →',
                  onPressed: widget.isLoading ? null : widget.onEnterApp,
                ),
              ),
            ),
          ],
        ),
    );
  }
}
