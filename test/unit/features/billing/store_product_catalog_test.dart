import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/store_product_catalog.dart';
import 'package:streamers_tip/features/billing/store_product_ids.dart';
import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';

void main() {
  group('subscriptionPlanForStoreProductId', () {
    test('maps iOS pro products', () {
      expect(
        subscriptionPlanForStoreProductId(kIosProMonthlyId),
        SubscriptionPlan.pro,
      );
      expect(
        subscriptionPlanForStoreProductId(kIosProYearlyId),
        SubscriptionPlan.pro,
      );
    });

    test('maps android studio products', () {
      expect(
        subscriptionPlanForStoreProductId(kAndroidStudioMonthlyId),
        SubscriptionPlan.studio,
      );
    });
  });

  group('storeProductIdForPlanAndPeriod', () {
    test('returns iOS product ids when platform is ios', () {
      expect(
        storeProductIdForPlanAndPeriod(
          plan: SubscriptionPlan.pro,
          isYearly: false,
          platform: BillingStorePlatform.ios,
        ),
        kIosProMonthlyId,
      );
      expect(
        storeProductIdForPlanAndPeriod(
          plan: SubscriptionPlan.studio,
          isYearly: true,
          platform: BillingStorePlatform.android,
        ),
        kAndroidStudioYearlyId,
      );
    });
  });
}
