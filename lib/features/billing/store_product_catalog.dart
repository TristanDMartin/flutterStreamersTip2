import 'package:in_app_purchase/in_app_purchase.dart';

import 'store_product_ids.dart';
import '../gamification/models/subscription_plan.dart';

/// Maps App Store / Play product IDs to subscription tiers.
SubscriptionPlan subscriptionPlanForStoreProductId(String productId) {
  final String id = productId.trim().toLowerCase();
  if (id.contains('studio')) {
    return SubscriptionPlan.studio;
  }
  if (id.contains('pro')) {
    return SubscriptionPlan.pro;
  }
  return SubscriptionPlan.starter;
}

String storeProductIdForPlanAndPeriod({
  required SubscriptionPlan plan,
  required bool isYearly,
  BillingStorePlatform? platform,
}) {
  switch (plan) {
    case SubscriptionPlan.pro:
      return isYearly
          ? storeProYearlyId(platform: platform)
          : storeProMonthlyId(platform: platform);
    case SubscriptionPlan.studio:
      return isYearly
          ? storeStudioYearlyId(platform: platform)
          : storeStudioMonthlyId(platform: platform);
    case SubscriptionPlan.starter:
    case SubscriptionPlan.unknown:
      throw ArgumentError('Starter has no store product.');
  }
}

String formatStorePrice(ProductDetails? details, String fallbackLabel) {
  if (details == null || details.price.trim().isEmpty) {
    return fallbackLabel;
  }
  return details.price;
}

String? storeCadenceLabel(ProductDetails? details) {
  if (details == null) {
    return null;
  }
  final String raw = details.id.toLowerCase();
  if (raw.contains('yearly') || raw.contains('annual')) {
    return '/year';
  }
  if (raw.contains('monthly')) {
    return '/month';
  }
  return null;
}
