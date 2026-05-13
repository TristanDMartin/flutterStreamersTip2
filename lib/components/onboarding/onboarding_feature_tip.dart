import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String prefKey = 'streamerstip.first_tap_tip.$userId.${tip.id}';
  if (prefs.getBool(prefKey) == true) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final bool? acknowledged = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    isScrollControlled: true,
    builder: (BuildContext context) => OnboardingFeatureTipSheet(tip: tip),
  );
  if (acknowledged == true) {
    await prefs.setBool(prefKey, true);
    return true;
  }
  return false;
}

class OnboardingFeatureTipSheet extends StatelessWidget {
  const OnboardingFeatureTipSheet({super.key, required this.tip});

  final OnboardingFeatureTip tip;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.height < 720 || size.width < 380;
    final Color surface = OnboardingStyle.surfaceFor(context);
    final Color textPrimary = OnboardingStyle.textPrimaryFor(context);
    final Color textSecondary = OnboardingStyle.textSecondaryFor(context);
    final Color border = OnboardingStyle.borderFor(context);

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(compact ? 8 : 12, 0, compact ? 8 : 12, 12),
        padding: EdgeInsets.fromLTRB(
          compact ? 18 : 22,
          compact ? 16 : 22,
          compact ? 18 : 22,
          padding.bottom + (compact ? 12 : 14),
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: 'Close',
                button: true,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close_rounded, color: textPrimary),
                ),
              ),
            ),
            Container(
              width: compact ? 76 : 90,
              height: compact ? 76 : 90,
              decoration: BoxDecoration(
                gradient: OnboardingStyle.primaryGradient,
                borderRadius: BorderRadius.circular(compact ? 24 : 28),
              ),
              child:
                  Icon(tip.icon, color: Colors.white, size: compact ? 38 : 46),
            ),
            SizedBox(height: compact ? 16 : 22),
            Text(
              tip.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: compact ? 24 : 29,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tip.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: compact ? 14 : 16,
                height: 1.35,
              ),
            ),
            SizedBox(height: compact ? 18 : 22),
            ...tip.points.map(
              (String point) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF4897D2),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: compact ? 14 : 16,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GradientPillButton(
                label: tip.action,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
