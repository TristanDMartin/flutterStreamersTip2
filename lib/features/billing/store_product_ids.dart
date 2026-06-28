import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Store product identifiers — must match App Store Connect / Google Play Console.
///
/// iOS and Android use separate SKUs. Server maps any verified product id → tier
/// (`pro` | `studio`). Limits come from `/api/user/entitlements`, not the client.
///
/// See PRICING_V2.md and subscription-tier-entitlements rule.

/// iOS App Store subscription product identifiers.
const String kIosProMonthlyId = 'streamerstip_pro_monthly_ios';
const String kIosProYearlyId = 'streamerstip_pro_yearly_ios';
const String kIosStudioMonthlyId = 'streamerstip_studio_monthly_ios';
const String kIosStudioYearlyId = 'streamerstip_studio_yearly_ios';

/// Google Play subscription product identifiers.
const String kAndroidProMonthlyId = 'streamerstip_pro_monthly_android';
const String kAndroidProYearlyId = 'streamerstip_pro_yearly_android';
const String kAndroidStudioMonthlyId = 'streamerstip_studio_monthly_android';
const String kAndroidStudioYearlyId = 'streamerstip_studio_yearly_android';

/// Pricing v2 ids (legacy — still verified server-side for existing subscribers).
const String kCreatorProMonthlyId = 'creator_pro_monthly';
const String kCreatorProYearlyId = 'creator_pro_yearly';
const String kCreatorStudioMonthlyId = 'creator_studio_monthly';
const String kCreatorStudioYearlyId = 'creator_studio_yearly';

/// Pre–platform-split App Store / Play SKUs (legacy verify only).
const String kLegacyProMonthlyId = 'streamerstip_pro_monthly';
const String kLegacyProYearlyId = 'streamerstip_pro_yearly';
const String kLegacyStudioMonthlyId = 'streamerstip_studio_monthly';
const String kLegacyStudioYearlyId = 'streamerstip_studio_yearly';

enum BillingStorePlatform {
  ios,
  android,
  unsupported,
}

/// Detects the native store for in-app purchases on this device.
BillingStorePlatform currentBillingStorePlatform() {
  if (kIsWeb) {
    return BillingStorePlatform.unsupported;
  }
  if (Platform.isIOS) {
    return BillingStorePlatform.ios;
  }
  if (Platform.isAndroid) {
    return BillingStorePlatform.android;
  }
  return BillingStorePlatform.unsupported;
}

/// Product ids to query from the store on this device (platform-specific only).
Set<String> storeSubscriptionProductIds({BillingStorePlatform? platform}) {
  final BillingStorePlatform resolved =
      platform ?? currentBillingStorePlatform();
  switch (resolved) {
    case BillingStorePlatform.ios:
      return const <String>{
        kIosProMonthlyId,
        kIosProYearlyId,
        kIosStudioMonthlyId,
        kIosStudioYearlyId,
      };
    case BillingStorePlatform.android:
      return const <String>{
        kAndroidProMonthlyId,
        kAndroidProYearlyId,
        kAndroidStudioMonthlyId,
        kAndroidStudioYearlyId,
      };
    case BillingStorePlatform.unsupported:
      return const <String>{};
  }
}

String storeProMonthlyId({BillingStorePlatform? platform}) {
  final BillingStorePlatform resolved =
      platform ?? currentBillingStorePlatform();
  switch (resolved) {
    case BillingStorePlatform.ios:
      return kIosProMonthlyId;
    case BillingStorePlatform.android:
      return kAndroidProMonthlyId;
    case BillingStorePlatform.unsupported:
      return kIosProMonthlyId;
  }
}

String storeProYearlyId({BillingStorePlatform? platform}) {
  final BillingStorePlatform resolved =
      platform ?? currentBillingStorePlatform();
  switch (resolved) {
    case BillingStorePlatform.ios:
      return kIosProYearlyId;
    case BillingStorePlatform.android:
      return kAndroidProYearlyId;
    case BillingStorePlatform.unsupported:
      return kIosProYearlyId;
  }
}

String storeStudioMonthlyId({BillingStorePlatform? platform}) {
  final BillingStorePlatform resolved =
      platform ?? currentBillingStorePlatform();
  switch (resolved) {
    case BillingStorePlatform.ios:
      return kIosStudioMonthlyId;
    case BillingStorePlatform.android:
      return kAndroidStudioMonthlyId;
    case BillingStorePlatform.unsupported:
      return kIosStudioMonthlyId;
  }
}

String storeStudioYearlyId({BillingStorePlatform? platform}) {
  final BillingStorePlatform resolved =
      platform ?? currentBillingStorePlatform();
  switch (resolved) {
    case BillingStorePlatform.ios:
      return kIosStudioYearlyId;
    case BillingStorePlatform.android:
      return kAndroidStudioYearlyId;
    case BillingStorePlatform.unsupported:
      return kIosStudioYearlyId;
  }
}

/// All subscription product ids accepted by server verify (legacy + platform).
const Set<String> kAllVerifiedSubscriptionProductIds = <String>{
  kIosProMonthlyId,
  kIosProYearlyId,
  kIosStudioMonthlyId,
  kIosStudioYearlyId,
  kAndroidProMonthlyId,
  kAndroidProYearlyId,
  kAndroidStudioMonthlyId,
  kAndroidStudioYearlyId,
  kCreatorProMonthlyId,
  kCreatorProYearlyId,
  kCreatorStudioMonthlyId,
  kCreatorStudioYearlyId,
  kLegacyProMonthlyId,
  kLegacyProYearlyId,
  kLegacyStudioMonthlyId,
  kLegacyStudioYearlyId,
};

/// Play Console subscription id (parent product) for API verify body.
String googlePlaySubscriptionIdForProduct(String productId) {
  final String id = productId.trim().toLowerCase();
  if (id.contains('studio')) {
    if (id.contains('_android') || id.startsWith('streamerstip_studio')) {
      return 'streamerstip_studio';
    }
    return 'creator_studio';
  }
  if (id.contains('_android') || id.startsWith('streamerstip_pro')) {
    return 'streamerstip_pro';
  }
  return 'creator_pro';
}
