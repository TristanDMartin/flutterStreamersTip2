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

/// Prefer [resolveTippyEnabledFromSnapshot] for Tippy chat / general UI.
bool resolveTippyEnabledFromSnapshot(SubscriptionSnapshot? snapshot) {
  if (snapshot == null) {
    return false;
  }
  if (snapshot.hasFullAccess) {
    return true;
  }
  return snapshot.canUseTippy;
}

/// Publish caption/hashtag Tippy assist — Creator Pro / Studio only.
bool resolveTippyPublishAssistUnlocked(SubscriptionSnapshot snapshot) {
  if (snapshot.hasFullAccess) {
    return true;
  }
  if (snapshot.entitlements.canUseAICaptionRewrite) {
    return true;
  }
  return snapshot.isPro || snapshot.isStudio;
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

/// New Post Tippy caption/hashtag assist: Pro/Studio via canonical entitlements.
bool resolveTippyEnabledForPublish({
  UserProgressBundle? bundle,
  SubscriptionSnapshot? entitlements,
  BillingTierAccess? billing,
}) {
  if (entitlements != null) {
    return resolveTippyPublishAssistUnlocked(entitlements);
  }
  if (billing != null && billing.usedCanonicalFields) {
    return _isPaidPlan(billing.effectivePlan) &&
        _statusAllowsTippy(billing.subscriptionStatusForDisplay ?? 'active');
  }
  if (bundle != null && bundle.entitlements.tippyAi) {
    return true;
  }
  final UserSubscriptionModel? sub = bundle?.subscription;
  if (sub != null &&
      _isPaidPlan(sub.plan) &&
      _statusAllowsTippy(sub.status)) {
    return true;
  }
  return false;
}
