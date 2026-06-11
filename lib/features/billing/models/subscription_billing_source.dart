import '../tier_display_names.dart';
import 'subscription_snapshot.dart';

/// `source` / `subscriptionProvider` from `/api/user/entitlements`.
enum SubscriptionBillingSource {
  starterDefault,
  stripe,
  apple,
  google,
  ownerOverride,
  manualOverride,
  unknown,
}

SubscriptionBillingSource subscriptionBillingSourceFromApi(String? raw) {
  final String s = (raw ?? '').trim().toLowerCase();
  switch (s) {
    case 'stripe':
      return SubscriptionBillingSource.stripe;
    case 'apple':
    case 'ios':
      return SubscriptionBillingSource.apple;
    case 'google':
    case 'android':
      return SubscriptionBillingSource.google;
    case 'starter_default':
    case 'starter':
      return SubscriptionBillingSource.starterDefault;
    case 'owner_override':
      return SubscriptionBillingSource.ownerOverride;
    case 'manual_override':
      return SubscriptionBillingSource.manualOverride;
    default:
      return SubscriptionBillingSource.unknown;
  }
}

/// Cross-platform IAP / manage-subscription rules (APP_BILLING_GUIDE).
extension SubscriptionSnapshotBilling on SubscriptionSnapshot {
  SubscriptionBillingSource get billingSource =>
      subscriptionBillingSourceFromApi(
        source.isNotEmpty ? source : null,
      );

  /// Paid on website — do not sell the same subscription again via IAP.
  bool get shouldBlockInAppStorePurchase {
    if (!isPaid || isStarter) {
      return false;
    }
    return billingSource == SubscriptionBillingSource.stripe;
  }

  bool get isPaidViaApple =>
      billingSource == SubscriptionBillingSource.apple;

  bool get isPaidViaGoogle =>
      billingSource == SubscriptionBillingSource.google;

  bool get isPaidViaMobileStore => isPaidViaApple || isPaidViaGoogle;

  String get billingSourceDisplayLabel {
    switch (billingSource) {
      case SubscriptionBillingSource.stripe:
        return 'Website (Stripe)';
      case SubscriptionBillingSource.apple:
        return 'App Store';
      case SubscriptionBillingSource.google:
        return 'Google Play';
      case SubscriptionBillingSource.ownerOverride:
      case SubscriptionBillingSource.manualOverride:
        return 'StreamersTip';
      case SubscriptionBillingSource.starterDefault:
        return tierDisplayNameForApi('starter');
      case SubscriptionBillingSource.unknown:
        return 'Subscription';
    }
  }
}
