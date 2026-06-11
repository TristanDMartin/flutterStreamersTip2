/// API tier ids: `starter` | `pro` | `studio`.
enum BillingTier {
  starter,
  pro,
  studio,
}

BillingTier billingTierFromApi(String? raw) {
  final String t = (raw ?? '').trim().toLowerCase();
  switch (t) {
    case 'pro':
    case 'professional':
    case 'creatorpro':
      return BillingTier.pro;
    case 'studio':
    case 'enterprise':
    case 'creatorstudio':
      return BillingTier.studio;
    case 'starter':
    case 'free':
    case 'creator':
    default:
      return BillingTier.starter;
  }
}

String billingTierToApiValue(BillingTier tier) {
  switch (tier) {
    case BillingTier.starter:
      return 'starter';
    case BillingTier.pro:
      return 'pro';
    case BillingTier.studio:
      return 'studio';
  }
}
