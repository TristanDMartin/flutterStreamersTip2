/// Aligned with website naming: Starter / Pro / Studio.
enum SubscriptionPlan {
  starter,
  pro,
  studio,
  unknown,
}

SubscriptionPlan subscriptionPlanFromString(String? raw) {
  if (raw == null || raw.isEmpty) return SubscriptionPlan.unknown;
  final String s = raw.trim().toLowerCase();
  if (s == 'starter' || s == 'free') return SubscriptionPlan.starter;
  if (s == 'pro' || s == 'professional') return SubscriptionPlan.pro;
  if (s == 'studio' || s == 'enterprise') return SubscriptionPlan.studio;
  return SubscriptionPlan.unknown;
}

String subscriptionPlanToApiValue(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.starter:
      return 'starter';
    case SubscriptionPlan.pro:
      return 'pro';
    case SubscriptionPlan.studio:
      return 'studio';
    case SubscriptionPlan.unknown:
      return 'unknown';
  }
}
