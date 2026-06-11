import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/store_product_catalog.dart';
import 'package:streamers_tip/features/billing/store_product_ids.dart';
import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';

void main() {
  group('subscriptionPlanForStoreProductId', () {
    test('maps pro products', () {
      expect(
        subscriptionPlanForStoreProductId(kStreamersTipProMonthlyId),
        SubscriptionPlan.pro,
      );
      expect(
        subscriptionPlanForStoreProductId(kStreamersTipProYearlyId),
        SubscriptionPlan.pro,
      );
    });

    test('maps studio products', () {
      expect(
        subscriptionPlanForStoreProductId(kStreamersTipStudioMonthlyId),
        SubscriptionPlan.studio,
      );
    });
  });

  group('storeProductIdForPlanAndPeriod', () {
    test('returns Pricing v2 product ids', () {
      expect(
        storeProductIdForPlanAndPeriod(
          plan: SubscriptionPlan.pro,
          isYearly: false,
        ),
        kCreatorProMonthlyId,
      );
      expect(
        storeProductIdForPlanAndPeriod(
          plan: SubscriptionPlan.studio,
          isYearly: true,
        ),
        kStreamersTipStudioYearlyId,
      );
    });
  });
}
