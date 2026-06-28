import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/design/st_radius.dart';
import '../../core/design/st_spacing.dart';
import '../../constants/playback_owners.dart';
import '../../routing/app_routes.dart';
import '../../services/global_playback_manager.dart';
import 'package:streamers_tip/utils/secure_log.dart';
import 'contextual_tips_service.dart';
import 'onboarding_style.dart';

class ContextualTipOverlay extends StatelessWidget {
  const ContextualTipOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.onDismiss,
    this.anchorBottom = 96,
    this.emoji,
  });

  final String title;
  final String message;
  final VoidCallback onDismiss;
  final double anchorBottom;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: STSpacing.lg,
      right: STSpacing.lg,
      bottom: anchorBottom,
      child: ContextualTipCard(
        title: title,
        message: message,
        emoji: emoji ?? '✨',
        onDismiss: onDismiss,
      ),
    );
  }
}

typedef ContextualTipSpec = ({
  String key,
  String title,
  String message,
  String emoji,
});

abstract final class ContextualTipCatalog {
  static const Map<int, ContextualTipSpec> tabTips = <int, ContextualTipSpec>{
    0: (
      key: 'homeFeedSeen',
      title: 'Home Feed',
      message: 'Swipe up to discover clips from creators you follow.',
      emoji: '🏠',
    ),
    1: (
      key: 'networkSeen',
      title: 'Network',
      message: 'Connect with creators and grow your circle.',
      emoji: '🤝',
    ),
    2: (
      key: 'uploadSeen',
      title: 'Upload',
      message: 'Tap here anytime to share your next clip.',
      emoji: '📤',
    ),
    3: (
      key: 'inboxSeen',
      title: 'Inbox',
      message: 'Messages and activity land here.',
      emoji: '💬',
    ),
    4: (
      key: 'profileSeen',
      title: 'Profile',
      message: 'Your creator card and stats live here.',
      emoji: '🪪',
    ),
  };

  static const ContextualTipSpec tippyTip = (
    key: 'tippySeen',
    title: 'Ask Tippy',
    message: 'Your AI creator coach — ask for hooks, captions, growth ideas, '
        'or content plans anytime.',
    emoji: '🤖',
  );

  static const ContextualTipSpec contentPlannerTip = (
    key: 'contentPlannerSeen',
    title: 'Content Planner',
    message: 'Plan your week, schedule posts, and stay consistent. '
        'Tap + to create your first plan.',
    emoji: '📅',
  );

  static void scheduleFeatureTipOnMount({
    required BuildContext context,
    required ContextualTipSpec tip,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      unawaited(_showTipIfNeeded(context: context, tip: tip));
    });
  }

  static Future<void> showTabTipIfNeeded({
    required BuildContext context,
    required String userId,
    required int tabIndex,
    required ContextualTipsService service,
    required ContextualTipsState tipsState,
  }) async {
    final ContextualTipSpec? tip = tabTips[tabIndex];
    if (tip == null) {
      return;
    }
    await _showTipIfNeeded(
      context: context,
      tip: tip,
      userId: userId,
      service: service,
      tipsState: tipsState,
    );
  }

  static Future<void> _showTipIfNeeded({
    required BuildContext context,
    required ContextualTipSpec tip,
    String? userId,
    ContextualTipsService? service,
    ContextualTipsState? tipsState,
  }) async {
    if (userId == null && Firebase.apps.isEmpty) {
      return;
    }
    final String resolvedUserId =
        userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (resolvedUserId.isEmpty) {
      return;
    }
    final ContextualTipsService tipsService =
        service ?? ContextualTipsService();
    final ContextualTipsState state =
        tipsState ?? await tipsService.fetchTips(resolvedUserId);
    if (state.hasSeen(tip.key)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _showAnimatedTipDialog(context: context, tip: tip);
    await tipsService.markTipSeen(resolvedUserId, tip.key);
  }

  static Future<void> _showAnimatedTipDialog({
    required BuildContext context,
    required ContextualTipSpec tip,
  }) {
    return showGeneralDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: AppRoutes.contextualTip),
      barrierDismissible: true,
      barrierLabel: 'Dismiss tip',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (
        BuildContext ctx,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (
        BuildContext ctx,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        void dismissTip() {
          Navigator.of(ctx).pop();
        }
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(curved),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: STSpacing.lg,
                  right: STSpacing.lg,
                  bottom: STSpacing.xxl + MediaQuery.paddingOf(ctx).bottom,
                ),
                child: ContextualTipCard(
                  title: tip.title,
                  message: tip.message,
                  emoji: tip.emoji,
                  onDismiss: dismissTip,
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(_resumeHomeFeedPlayback);
  }

  static void _resumeHomeFeedPlayback() {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    if (!manager.shouldRestoreHomeShellPlayback()) {
      secureLog('RESTORE_SKIPPED reason=non_video_tab');
      return;
    }
    final String? blockReason = manager.blockReason;
    if (blockReason != null && blockReason.startsWith('main_tab_')) {
      return;
    }
    if (manager.visibleOwner != PlaybackOwners.home) {
      return;
    }
    if (manager.isPlaybackBlocked) {
      return;
    }
    manager.restoreCurrentFeedFocus();
    manager.resumeAfterTabSwitch();
  }
}

class ContextualTipCard extends StatelessWidget {
  const ContextualTipCard({
    super.key,
    required this.title,
    required this.message,
    required this.emoji,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final String emoji;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: OnboardingStyle.plainTextStyle(
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14),
      ),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(STRadius.sheet),
          child: DecoratedBox(
            decoration: OnboardingStyle.tipCardDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _TipAccentBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    STSpacing.xl,
                    STSpacing.lg,
                    STSpacing.md,
                    STSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _TipEmojiBadge(emoji: emoji),
                          const SizedBox(width: STSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'QUICK TIP',
                                  style: OnboardingStyle.tipLabelFor(context),
                                ),
                                const SizedBox(height: STSpacing.xs),
                                Text(
                                  title,
                                  style: OnboardingStyle.tipTitleFor(context),
                                ),
                              ],
                            ),
                          ),
                          _TipCloseButton(onPressed: onDismiss),
                        ],
                      ),
                      const SizedBox(height: STSpacing.md),
                      Text(
                        message,
                        style: OnboardingStyle.tipBodyFor(context),
                      ),
                      const SizedBox(height: STSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: GradientPillButton(
                          label: 'Got it',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: onDismiss,
                        ),
                      ),
                    ],
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

class _TipAccentBar extends StatelessWidget {
  const _TipAccentBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: const BoxDecoration(
        gradient: OnboardingStyle.primaryGradient,
      ),
    );
  }
}

class _TipEmojiBadge extends StatelessWidget {
  const _TipEmojiBadge({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: OnboardingStyle.primaryGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF9248D2).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: OnboardingStyle.plainTextStyle(
          const TextStyle(fontSize: 26, height: 1),
        ),
      ),
    );
  }
}

class _TipCloseButton extends StatelessWidget {
  const _TipCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = OnboardingStyle.textSecondaryFor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(STRadius.pill),
        child: Padding(
          padding: const EdgeInsets.all(STSpacing.xs),
          child: Icon(
            Icons.close_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}
