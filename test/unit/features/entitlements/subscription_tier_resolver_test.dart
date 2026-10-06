import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/entitlements/subscription_tier_resolver.dart';
import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';

void main() {
  group('resolveSubscriptionTierFromUserDocument', () {
    test('prefers server-owned subscriptionTier', () {
      const Map<String, dynamic> raw = <String, dynamic>{
        'subscriptionTier': 'pro',
        'entitlements': <String, dynamic>{
          'tippyAi': <String, Object>{'tier': 'studio'},
        },
      };
      final SubscriptionTierResolution r =
          resolveSubscriptionTierFromUserDocument(raw);
      expect(r.plan, SubscriptionPlan.pro);
      expect(r.sourceField, 'subscriptionTier');
    });

    test('ignores client-writable subscription map, plan and stripeRole', () {
      const Map<String, dynamic> raw = <String, dynamic>{
        'subscription': <String, String>{
          'tier': 'studio',
          'status': 'active',
        },
        'stripeRole': 'studio',
        'plan': 'studio',
      };
      final SubscriptionTierResolution r =
          resolveSubscriptionTierFromUserDocument(raw);
      expect(r.plan, SubscriptionPlan.unknown);
      expect(r.sourceField, 'none');
    });

    test('reads entitlements.tippyAi.plan', () {
      const Map<String, dynamic> raw = <String, dynamic>{
        'entitlements': <String, dynamic>{
          'tippyAi': <String, Object>{
            'plan': 'studio',
            'enabled': true,
          },
        },
      };
      final SubscriptionTierResolution r =
          resolveSubscriptionTierFromUserDocument(raw);
      expect(r.plan, SubscriptionPlan.studio);
      expect(r.sourceField, 'entitlements.tippyAi.plan');
    });
  });
}
