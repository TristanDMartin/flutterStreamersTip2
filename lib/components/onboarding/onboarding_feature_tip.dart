import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_service.dart';
import 'onboarding_style.dart';

class OnboardingFeatureTip {
  const OnboardingFeatureTip({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.points,
    required this.action,
  });

  final String id;
  final IconData icon;
  final String title;
  final String body;
  final List<String> points;
  final String action;

  static OnboardingFeatureTip? forTabIndex(int index) {
    switch (index) {
      case 0:
        return const OnboardingFeatureTip(
          id: 'home',
          icon: Icons.play_circle_rounded,
          title: 'Your For You feed',
          body: 'Discover creators, clips, and trending content.',
          points: <String>[
            'Swipe through videos',
            'Open comments to join creator conversations',
          ],
          action: 'Got it',
        );
      case 1:
        return const OnboardingFeatureTip(
          id: 'network',
          icon: Icons.people_alt_rounded,
          title: 'Build your creator circle',
          body:
              'Network helps you find people worth following and working with.',
          points: <String>[
            'Follow creators in your niche',
            'Keep connections organized',
          ],
          action: 'Open Network',
        );
      case 2:
        return const OnboardingFeatureTip(
          id: 'create',
          icon: Icons.add_rounded,
          title: 'Create when you are ready',
          body:
              'This is where clips become drafts, scheduled posts, or uploads.',
          points: <String>[
            'Upload or record a clip',
            'Save drafts before posting',
          ],
          action: 'Start creating',
        );
      case 3:
        return const OnboardingFeatureTip(
          id: 'inbox',
          icon: Icons.mail_rounded,
          title: 'Keep up without hunting',
          body: 'Inbox gathers creator messages and important activity.',
          points: <String>[
            'See replies and messages',
            'Jump back into conversations',
          ],
          action: 'Open Inbox',
        );
      case 4:
        return const OnboardingFeatureTip(
          id: 'profile',
          icon: Icons.account_circle_rounded,
          title: 'Your creator home base',
          body:
              'Profile is where people understand who you are and what you make.',
          points: <String>[
            'Edit your Creator Card',
            'Share your profile anywhere',
          ],
          action: 'Open Profile',
        );
      default:
        return null;
    }
  }
}

Future<bool> showOnboardingFeatureTipIfNeeded({
  required BuildContext context,
  required String userId,
  required OnboardingFeatureTip tip,
  Alignment alignment = Alignment.bottomCenter,
  bool forceShow = false,
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String prefKey = 'streamerstip.first_tap_tip.$userId.${tip.id}';
  if (!forceShow && prefs.getBool(prefKey) == true) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  if (!forceShow) {
    await prefs.setBool(prefKey, true);
  }
  if (!context.mounted) {
    return true;
  }
  if (!forceShow) {
    unawaited(OnboardingService().markContextualTipSeen(userId, tip.id));
  }
  _showFloatingFeatureTip(
    context: context,
    tip: tip,
    alignment: alignment,
  );
  return true;
}

void _showFloatingFeatureTip({
  required BuildContext context,
  required OnboardingFeatureTip tip,
  required Alignment alignment,
}) {
  final OverlayState? overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  Timer? timer;
  void dismiss() {
    timer?.cancel();
    if (entry.mounted) {
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (BuildContext context) {
      final EdgeInsets safe = MediaQuery.paddingOf(context);
      return _FloatingFeatureTipOverlay(
        tip: tip,
        alignment: alignment,
        safePadding: safe,
        onDismiss: dismiss,
      );
    },
  );
  overlay.insert(entry);
  timer = Timer(const Duration(seconds: 7), dismiss);
}

class _FloatingFeatureTipOverlay extends StatefulWidget {
  const _FloatingFeatureTipOverlay({
    required this.tip,
    required this.alignment,
    required this.safePadding,
    required this.onDismiss,
  });

  final OnboardingFeatureTip tip;
  final Alignment alignment;
  final EdgeInsets safePadding;
  final VoidCallback onDismiss;

  @override
  State<_FloatingFeatureTipOverlay> createState() =>
      _FloatingFeatureTipOverlayState();
}

class _FloatingFeatureTipOverlayState
    extends State<_FloatingFeatureTipOverlay> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final Color surface = OnboardingStyle.surfaceFor(context);
    final Color textPrimary = OnboardingStyle.textPrimaryFor(context);
    final Color textSecondary = OnboardingStyle.textSecondaryFor(context);
    final Color border = OnboardingStyle.borderFor(context);
    final bool bottom = widget.alignment.y >= 0;
    return Positioned(
      left: 16,
      right: 16,
      top: bottom ? null : widget.safePadding.top + 14,
      bottom: bottom ? widget.safePadding.bottom + 92 : null,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: widget.alignment,
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : Offset(0, bottom ? 0.12 : -0.12),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width.clamp(0, 390).toDouble(),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: border),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                gradient: OnboardingStyle.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.tip.icon,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    widget.tip.title,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.tip.body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 13,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Got it',
                              visualDensity: VisualDensity.compact,
                              onPressed: widget.onDismiss,
                              icon: Icon(
                                Icons.close_rounded,
                                color: textSecondary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
