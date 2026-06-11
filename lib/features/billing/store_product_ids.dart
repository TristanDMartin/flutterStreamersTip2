/// Store product identifiers — must match App Store Connect / Google Play Console.
///
/// Pricing v2 (preferred): `creator_pro_*`, `creator_studio_*`.
/// Legacy ids remain queryable until consoles are migrated.
///
/// Server maps product id → `subscriptionTier` (`pro` | `studio`) after verify.
/// See PRICING_V2.md — limits come from `/api/user/entitlements`, not the client.
const String kCreatorProMonthlyId = 'creator_pro_monthly';
const String kCreatorProYearlyId = 'creator_pro_yearly';
const String kCreatorStudioMonthlyId = 'creator_studio_monthly';
const String kCreatorStudioYearlyId = 'creator_studio_yearly';

/// Pre–Pricing v2 App Store / Play SKUs (still accepted by verify endpoint).
const String kLegacyProMonthlyId = 'streamerstip_pro_monthly';
const String kLegacyProYearlyId = 'streamerstip_pro_yearly';
const String kLegacyStudioMonthlyId = 'streamerstip_studio_monthly';
const String kLegacyStudioYearlyId = 'streamerstip_studio_yearly';

/// Primary ids used for new purchases in the upgrade UI.
const String kStreamersTipProMonthlyId = kCreatorProMonthlyId;
const String kStreamersTipProYearlyId = kCreatorProYearlyId;
const String kStreamersTipStudioMonthlyId = kCreatorStudioMonthlyId;
const String kStreamersTipStudioYearlyId = kCreatorStudioYearlyId;

const Set<String> kStreamersTipSubscriptionProductIds = <String>{
  kCreatorProMonthlyId,
  kCreatorProYearlyId,
  kCreatorStudioMonthlyId,
  kCreatorStudioYearlyId,
  kLegacyProMonthlyId,
  kLegacyProYearlyId,
  kLegacyStudioMonthlyId,
  kLegacyStudioYearlyId,
};

/// Play Console subscription id (not base-plan sku) for API verify body.
String googlePlaySubscriptionIdForProduct(String productId) {
  final String id = productId.trim().toLowerCase();
  if (id.contains('studio')) {
    return 'creator_studio';
  }
  return 'creator_pro';
}
