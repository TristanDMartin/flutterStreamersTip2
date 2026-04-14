import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../models/subscription_plan.dart';
import '../models/user_subscription_model.dart';

/// Plan badge + short status (Starter / Pro / Studio from shared backend).
class TierBadgeStrip extends StatelessWidget {
  final UserSubscriptionModel? subscription;

  const TierBadgeStrip({super.key, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final UserSubscriptionModel sub = subscription ??
        const UserSubscriptionModel(
          plan: SubscriptionPlan.starter,
          status: 'active',
        );
    final String label = _planLabel(sub.plan);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.primary.withValues(alpha: 0.5),
                  AppColors.supportAccent.withValues(alpha: 0.35),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
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
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub.status,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
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
        return 'Plan';
    }
  }
}
