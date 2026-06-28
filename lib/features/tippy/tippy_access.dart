import '../billing/get_user_tier.dart';
import '../billing/models/subscription_snapshot.dart';
import '../gamification/models/subscription_plan.dart';
import '../gamification/models/user_progress_bundle.dart';
import '../gamification/models/user_subscription_model.dart';

const Set<String> _tippyPaidSubscriptionStatuses = <String>{
  'active',
  'trialing',
  'past_due',
};

bool _isPaidPlan(SubscriptionPlan plan) {
  return plan == SubscriptionPlan.pro || plan == SubscriptionPlan.studio;
}

bool _statusAllowsTippy(String status) {
  return _tippyPaidSubscriptionStatuses.contains(
    status.trim().toLowerCase(),
  );
}

/// Prefer [resolveTippyEnabledFromSnapshot] for gated UI.
bool resolveTippyEnabledFromSnapshot(SubscriptionSnapshot? snapshot) {
  if (snapshot == null) {
    return false;
  }
  if (snapshot.hasFullAccess) {
    return true;
  }
  return snapshot.canUseTippy;
}

/// Whether Tippy chat / assist entry points are available for the signed-in user.
bool resolveTippyEnabled(UserProgressBundle bundle) {
  if (bundle.entitlements.tippyAi) {
    return true;
  }
  final UserSubscriptionModel? sub = bundle.subscription;
  if (sub == null) {
    return true;
  }
  if (sub.plan == SubscriptionPlan.starter ||
      sub.plan == SubscriptionPlan.unknown) {
    return true;
  }
  if (_isPaidPlan(sub.plan) && _statusAllowsTippy(sub.status)) {
    return true;
  }
  if (_isPaidPlan(sub.plan)) {
    return true;
  }
  return false;
}

/// New Post and other screens: API snapshot first, then legacy bundle/Firestore.
bool resolveTippyEnabledForPublish({
  UserProgressBundle? bundle,
  SubscriptionSnapshot? entitlements,
  BillingTierAccess? billing,
}) {
  if (entitlements != null && resolveTippyEnabledFromSnapshot(entitlements)) {
    return true;
  }
  if (bundle != null && bundle.entitlements.tippyAi) {
    return true;
  }
  if (billing != null && billing.usedCanonicalFields) {
    if (billing.effectivePlan == SubscriptionPlan.starter ||
        billing.effectivePlan == SubscriptionPlan.unknown) {
      return true;
    }
    if (_isPaidPlan(billing.effectivePlan) &&
        _statusAllowsTippy(billing.subscriptionStatusForDisplay ?? '')) {
      return true;
    }
  }
  if (bundle != null) {
    return resolveTippyEnabled(bundle);
  }
  return false;
}
