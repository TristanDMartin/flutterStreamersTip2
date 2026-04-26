/// Feature checks aligned with Starter / Pro / Studio (see billing docs).
///
/// Entitlements still come from Firestore; these are UX hints only.
bool isBillingTierStarter(String resolvedTier) {
  return resolvedTier == 'starter';
}

bool needsProForCrossPostOrScheduling(String resolvedTier) {
  return resolvedTier == 'starter';
}

bool needsProForAdvancedAnalytics(String resolvedTier) {
  return resolvedTier == 'starter';
}

bool canShowStudioUpsell(String resolvedTier) {
  return resolvedTier == 'pro';
}
