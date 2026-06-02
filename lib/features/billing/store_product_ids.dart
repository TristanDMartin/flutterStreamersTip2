/// Store product identifiers — must match **exactly** in:
/// - App Store Connect → Subscriptions (bundle `com.streamerstip.streamersTipApp`)
/// - Google Play Console → Monetize → Subscriptions (app `com.streamerstip.streamersTipApp`)
///
/// After creating products, deploy [verifyMobilePurchase] with store secrets
/// (`APP_STORE_SHARED_SECRET`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, etc.).
const String kStreamersTipProMonthlyId = 'streamerstip_pro_monthly';
const String kStreamersTipProYearlyId = 'streamerstip_pro_yearly';
const String kStreamersTipStudioMonthlyId = 'streamerstip_studio_monthly';
const String kStreamersTipStudioYearlyId = 'streamerstip_studio_yearly';

const Set<String> kStreamersTipSubscriptionProductIds = <String>{
  kStreamersTipProMonthlyId,
  kStreamersTipProYearlyId,
  kStreamersTipStudioMonthlyId,
  kStreamersTipStudioYearlyId,
};
