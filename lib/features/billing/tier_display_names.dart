import 'models/billing_tier.dart';

/// Pricing v2 display names — mirrors web `getTierDisplayName` in `lib/billing/tiers`.
///
/// DB / API tier ids remain `starter` | `pro` | `studio`.
String tierDisplayNameForApi(String? tierApi) {
  switch (billingTierFromApi(tierApi)) {
    case BillingTier.pro:
      return 'Creator Pro';
    case BillingTier.studio:
      return 'Creator Studio';
    case BillingTier.starter:
      return 'Creator';
  }
}

String subscriptionStatusDisplayLabel(String? status) {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'trialing':
      return 'Free trial';
    case 'active':
      return 'Active';
    case 'past_due':
      return 'Past due';
    case 'grace_period':
      return 'Grace period';
    case 'canceled':
      return 'Canceled';
    case 'expired':
      return 'Expired';
    default:
      return 'Free';
  }
}
