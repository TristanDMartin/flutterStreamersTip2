import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/entitlements/subscription_tier_resolver.dart';
import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';

void main() {
  group('resolveSubscriptionTierFromUserDocument', () {
    test('prefers subscription.tier', () {
      const Map<String, dynamic> raw = <String, dynamic>{
        'subscription': <String, String>{
          'tier': 'studio',
          'status': 'active',
        },
        'plan': 'starter',
      };
      final SubscriptionTierResolution r =
          resolveSubscriptionTierFromUserDocument(raw);
      expect(r.plan, SubscriptionPlan.studio);
      expect(r.sourceField, 'subscription.tier');
    });

    test('reads stripeRole when subscription map empty', () {
      const Map<String, dynamic> raw = <String, String>{
        'stripeRole': 'studio',
        'plan': 'starter',
      };
      final SubscriptionTierResolution r =
          resolveSubscriptionTierFromUserDocument(raw);
      expect(r.plan, SubscriptionPlan.studio);
      expect(r.sourceField, 'stripeRole');
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
