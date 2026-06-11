import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/api_feature_gate.dart';
import 'package:streamers_tip/features/billing/models/subscription_snapshot.dart';

void main() {
  SubscriptionSnapshot proSnapshot() {
    return SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
      'tier': 'pro',
      'subscriptionStatus': 'active',
      'isPaid': true,
      'entitlements': <String, dynamic>{
        'canUseAdvancedAnalytics': true,
        'canBulkPublish': true,
        'canCrossPost': true,
        'maxPlatforms': 5,
      },
    });
  }

  SubscriptionSnapshot starterSnapshot() {
    return SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
      'tier': 'starter',
      'subscriptionStatus': 'active',
      'isPaid': false,
      'isStarter': true,
      'entitlements': <String, dynamic>{
        'canUseAdvancedAnalytics': false,
        'canBulkPublish': false,
      },
    });
  }

  test('pro has advanced analytics from API flags', () {
    expect(
      hasApiBillingFeature(
        proSnapshot(),
        ApiBillingFeature.advancedAnalytics,
      ),
      isTrue,
    );
    expect(needsProForAdvancedAnalyticsApi(starterSnapshot()), isTrue);
  });

  test('max platforms respects unlimited sentinel', () {
    final SubscriptionSnapshot studio =
        SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
      'tier': 'studio',
      'entitlements': <String, dynamic>{'maxPlatforms': -1},
    });
    expect(maxPlatformsFromSnapshot(studio), 999);
  });
}
