import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/billing_tier_limits.dart';
import 'package:streamers_tip/features/billing/get_user_tier.dart';
import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';

void main() {
  group('BillingTierAccess.fromUserDocument', () {
    test('active pro maps to pro', () {
      final BillingTierAccess a = BillingTierAccess.fromUserDocument(
        <String, dynamic>{
          'subscriptionTier': 'pro',
          'subscriptionStatus': 'active',
        },
      );
      expect(a.usedCanonicalFields, isTrue);
      expect(a.effectivePlan, SubscriptionPlan.pro);
      expect(a.isProTrialing, isFalse);
    });

    test('trialing pro sets isProTrialing', () {
      final BillingTierAccess a = BillingTierAccess.fromUserDocument(
        <String, dynamic>{
          'subscriptionTier': 'pro',
          'subscriptionStatus': 'trialing',
          'subscriptionTrialEndAt': Timestamp.fromMillisecondsSinceEpoch(
            DateTime.utc(2026, 5, 1).millisecondsSinceEpoch,
          ),
        },
      );
      expect(a.effectivePlan, SubscriptionPlan.pro);
      expect(a.isProTrialing, isTrue);
      expect(a.subscriptionTrialEndAt, isNotNull);
    });

    test('studio canceled behaves as starter', () {
      final BillingTierAccess a = BillingTierAccess.fromUserDocument(
        <String, dynamic>{
          'subscriptionTier': 'studio',
          'subscriptionStatus': 'canceled',
        },
      );
      expect(a.usedCanonicalFields, isTrue);
      expect(a.effectivePlan, SubscriptionPlan.starter);
    });

    test('missing subscriptionTier falls back to legacy', () {
      final BillingTierAccess a = BillingTierAccess.fromUserDocument(
        <String, dynamic>{'stripeRole': 'studio'},
      );
      expect(a.usedCanonicalFields, isFalse);
      expect(a.effectivePlan, SubscriptionPlan.unknown);
    });
  });

  group('BillingTierLimits', () {
    test('starter AI credits is 10', () {
      expect(BillingTierLimits.starter.aiCreditsPerMonth, 10);
      expect(BillingTierLimits.pro.aiCreditsPerMonth, 250);
      expect(BillingTierLimits.studio.aiCreditsPerMonth, 1000);
    });

    test('unknown plan uses starter limits', () {
      expect(
        BillingTierLimits.forEffectivePlan(SubscriptionPlan.unknown),
        BillingTierLimits.starter,
      );
    });
  });
}
