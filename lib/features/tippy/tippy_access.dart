import '../gamification/models/subscription_plan.dart';
import '../gamification/models/user_progress_bundle.dart';
import '../gamification/models/user_subscription_model.dart';

bool resolveTippyEnabled(UserProgressBundle bundle) {
  if (bundle.entitlements.tippyAi) {
    return true;
  }
  final UserSubscriptionModel? sub = bundle.subscription;
  if (sub == null) {
    return false;
  }
  final String status = sub.status.trim().toLowerCase();
  final bool billingOpen = status == 'active' ||
      status == 'trialing' ||
      status == 'past_due';
  if (!billingOpen) {
    return false;
  }
  switch (sub.plan) {
    case SubscriptionPlan.pro:
    case SubscriptionPlan.studio:
      return true;
    case SubscriptionPlan.starter:
    case SubscriptionPlan.unknown:
      return false;
  }
}
