import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../core/theme/support_shell_style.dart';
import '../../../widgets/streamer_card_sections.dart';
import '../models/subscription_plan.dart';
import '../models/user_subscription_model.dart';

/// Premium-looking subscription summary fed from the shared backend plan state.
class TierBadgeStrip extends StatelessWidget {
  final UserSubscriptionModel? subscription;

  const TierBadgeStrip({super.key, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final UserSubscriptionModel sub = subscription ??
        const UserSubscriptionModel(
          plan: SubscriptionPlan.unknown,
          status: 'unknown',
        );
    debugPrint(
      '💳 TierBadgeStrip: rendering plan=${sub.plan.name} | status=${sub.status} | resolved=${sub.isResolved}',
    );
    final String label = _planLabel(sub.plan);
    final String statusLabel = _statusLabel(sub.status);
    final _PlanVisual visual = _visualFor(sub.plan);
    final String detail = _detailLine(sub, statusLabel);
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    final List<Color> gradientColors = isLight
        ? <Color>[
            visual.start.withValues(alpha: 0.12),
            visual.end.withValues(alpha: 0.08),
            shell.surfaceCard,
          ]
        : const <Color>[
            Color(0xFF2A1F4D),
            Color(0xFF161320),
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: isLight
              ? shell.surfaceCardBorder
              : StreamerCardBackStyle.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLight
                  ? null
                  : StreamerCardBackStyle.accent.withValues(alpha: 0.2),
              gradient: isLight
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        visual.start,
                        visual.end,
                      ],
                    )
                  : null,
              border: Border.all(
                color: isLight
                    ? Theme.of(context).colorScheme.onPrimary.withValues(
                          alpha: 0.35,
                        )
                    : StreamerCardBackStyle.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              visual.icon,
              color: isLight
                  ? Theme.of(context).colorScheme.onPrimary
                  : StreamerCardBackStyle.lavender,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Current plan',
                  style: TextStyle(
                    color: isLight
                        ? shell.muted
                        : StreamerCardBackStyle.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isLight
                              ? shell.onChrome
                              : StreamerCardBackStyle.softText,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isLight
                            ? shell.surfaceCard.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isLight
                              ? shell.surfaceCardBorder
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: isLight
                              ? visual.accent
                              : StreamerCardBackStyle.lavender,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: TextStyle(
                    color: isLight
                        ? shell.muted
                        : StreamerCardBackStyle.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
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

  static String _planLabel(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.starter:
        return 'Starter';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.studio:
        return 'Studio';
      case SubscriptionPlan.unknown:
        return 'Plan syncing';
    }
  }

  static String _statusLabel(String raw) {
    final String normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'active':
        return 'Active';
      case 'trialing':
        return 'Trial';
      case 'past_due':
        return 'Past due';
      case 'canceled':
      case 'cancelled':
        return 'Canceled';
      case 'incomplete':
        return 'Incomplete';
      case 'unknown':
        return 'Pending';
      default:
        if (normalized.isEmpty) return 'Pending';
        return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
    }
  }

  static String _detailLine(UserSubscriptionModel sub, String statusLabel) {
    if (sub.plan == SubscriptionPlan.unknown) {
      return 'We are still syncing your creator subscription state.';
    }
    if (sub.willCancel) {
      return '$statusLabel until ${sub.currentPeriodEnd != null ? _formatDate(sub.currentPeriodEnd!) : 'period close'}';
    }
    if (sub.currentPeriodEnd != null) {
      return '$statusLabel through ${_formatDate(sub.currentPeriodEnd!)}';
    }
    return '$statusLabel plan benefits are available now.';
  }

  static _PlanVisual _visualFor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.starter:
        return _PlanVisual(
          start: AppColors.primary,
          end: const Color(0xFF9C6BFF),
          shadow: const Color(0xFF4A2B7F),
          accent: const Color(0xFFDAB8FF),
          icon: Icons.rocket_launch_rounded,
        );
      case SubscriptionPlan.pro:
        return _PlanVisual(
          start: const Color(0xFF00BFA5),
          end: const Color(0xFF45E0C2),
          shadow: const Color(0xFF0A6659),
          accent: const Color(0xFFA7FFF1),
          icon: Icons.workspace_premium_rounded,
        );
      case SubscriptionPlan.studio:
        return _PlanVisual(
          start: const Color(0xFFFF9F43),
          end: const Color(0xFFFFD166),
          shadow: const Color(0xFF8A4D08),
          accent: const Color(0xFFFFE7A7),
          icon: Icons.auto_awesome_rounded,
        );
      case SubscriptionPlan.unknown:
        return _PlanVisual(
          start: AppColors.supportAccent,
          end: AppColors.primary,
          shadow: Colors.black,
          accent: Colors.white,
          icon: Icons.bolt_rounded,
        );
    }
  }

  static String _formatDate(DateTime date) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _PlanVisual {
  final Color start;
  final Color end;
  final Color shadow;
  final Color accent;
  final IconData icon;

  const _PlanVisual({
    required this.start,
    required this.end,
    required this.shadow,
    required this.accent,
    required this.icon,
  });
}
