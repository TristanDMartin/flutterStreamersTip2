import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/models/billing_tier.dart';
import 'package:streamers_tip/features/billing/models/subscription_snapshot.dart';

void main() {
  group('SubscriptionSnapshot.fromResponseJson', () {
    test('parses site API flat body', () {
      final SubscriptionSnapshot snap =
          SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
        'tier': 'pro',
        'effectiveTier': 'pro',
        'storedTier': 'pro',
        'subscriptionStatus': 'active',
        'isPaid': true,
        'isPro': true,
        'creditsUsed': 12,
        'creditsLimit': 250,
        'creditsRemaining': 238,
        'usage': <String, dynamic>{
          'periodKey': '2026-06',
          'monthlyCreditsUsed': 12,
          'monthlyCreditsRemaining': 238,
        },
        'entitlements': <String, dynamic>{
          'maxPlatforms': 5,
          'monthlyAiCredits': 250,
          'contentPlansLimit': -1,
          'analyticsWindowDays': 90,
          'canBulkPublish': true,
          'canUseAICaptionRewrite': true,
        },
        'aiCreditCosts': <String, dynamic>{
          'contentPlan': 5,
        },
      });
      expect(snap.tier, BillingTier.pro);
      expect(snap.isPaid, isTrue);
      expect(snap.entitlements.maxPlatforms, 5);
      expect(snap.entitlements.canBulkPublish, isTrue);
      expect(snap.usage.monthlyCreditsRemaining, 238);
      expect(snap.aiCreditCosts.costFor('contentPlan'), 5);
    });

    test('parses legacy CF body with limits and aiCreditCosts', () {
      final SubscriptionSnapshot snap =
          SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'tier': 'starter',
          'effectiveTier': 'starter',
          'subscriptionStatus': 'active',
          'tippyAi': <String, dynamic>{
            'enabled': true,
            'monthlyCredits': 25,
            'usedCredits': 3,
            'remainingCredits': 22,
          },
          'entitlements': <String, dynamic>{
            'maxPlatforms': 1,
            'monthlyAiCredits': 25,
            'contentPlansLimit': 1,
            'canUseContentPlanner': true,
          },
          'aiCreditCosts': <String, dynamic>{
            'contentPlan': 5,
            'growthAnalysis': 10,
          },
          'usage': <String, dynamic>{
            'monthlyCreditsUsed': 3,
            'monthlyCreditsRemaining': 22,
          },
        },
      });
      expect(snap.tier, BillingTier.starter);
      expect(snap.entitlements.contentPlansLimit, 1);
      expect(snap.aiCreditCosts.costFor('contentPlan'), 5);
      expect(snap.aiCreditCosts.costFor('growthAnalysis'), 10);
      expect(snap.usage.monthlyCreditsRemaining, 22);
    });

    test('falls back to canonical aiCreditCosts when omitted', () {
      final SubscriptionSnapshot snap =
          SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
        'tier': 'starter',
      });
      expect(snap.aiCreditCosts.costFor('contentPlan'), 5);
      expect(snap.aiCreditCosts.costFor('growthAnalysis'), 10);
    });

    test('unknown tier falls back to starter', () {
      final SubscriptionSnapshot snap =
          SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
        'tier': 'unknown_plan',
      });
      expect(snap.tier, BillingTier.starter);
    });
  });
}
