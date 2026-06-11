import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/models/subscription_billing_source.dart';
import 'package:streamers_tip/features/billing/models/subscription_snapshot.dart';

void main() {
  test('blocks IAP when paid via Stripe on web', () {
    final SubscriptionSnapshot snap =
        SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
      'tier': 'pro',
      'subscriptionStatus': 'active',
      'isPaid': true,
      'source': 'stripe',
      'entitlements': <String, dynamic>{
        'canBulkPublish': true,
      },
    });
    expect(snap.shouldBlockInAppStorePurchase, isTrue);
    expect(snap.billingSource, SubscriptionBillingSource.stripe);
  });

  test('allows IAP manage for Apple source', () {
    final SubscriptionSnapshot snap =
        SubscriptionSnapshot.fromResponseJson(<String, dynamic>{
      'tier': 'pro',
      'subscriptionStatus': 'active',
      'isPaid': true,
      'source': 'apple',
    });
    expect(snap.shouldBlockInAppStorePurchase, isFalse);
    expect(snap.isPaidViaApple, isTrue);
  });
}
