import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/subscription_billing_source.dart';
import 'models/subscription_snapshot.dart';

/// Opens platform subscription management (never Stripe on mobile).
class SubscriptionManageService {
  const SubscriptionManageService();

  static const String kAppleSubscriptionsUrl =
      'https://apps.apple.com/account/subscriptions';

  static const String kGoogleSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';

  String manageDestinationHint(SubscriptionSnapshot snapshot) {
    if (snapshot.shouldBlockInAppStorePurchase) {
      return 'Your plan is billed on streamerstip.com. Manage it in your '
          'Stripe customer portal from the website.';
    }
    switch (snapshot.billingSource) {
      case SubscriptionBillingSource.apple:
        return 'Manage in iOS Settings → Apple ID → Subscriptions.';
      case SubscriptionBillingSource.google:
        return 'Manage in Google Play → Payments & subscriptions.';
      case SubscriptionBillingSource.stripe:
        return 'Manage on streamerstip.com (Stripe).';
      default:
        if (!kIsWeb && Platform.isIOS) {
          return 'Manage in the App Store subscriptions settings.';
        }
        if (!kIsWeb && Platform.isAndroid) {
          return 'Manage in Google Play subscriptions.';
        }
        return 'Manage your subscription on the platform where you subscribed.';
    }
  }

  Future<bool> openManageSubscription(SubscriptionSnapshot snapshot) async {
    if (snapshot.shouldBlockInAppStorePurchase) {
      return false;
    }
    final Uri? uri = _manageUri(snapshot);
    if (uri == null) {
      return false;
    }
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Uri? _manageUri(SubscriptionSnapshot snapshot) {
    if (kIsWeb) {
      return null;
    }
    switch (snapshot.billingSource) {
      case SubscriptionBillingSource.apple:
        return Uri.parse(kAppleSubscriptionsUrl);
      case SubscriptionBillingSource.google:
        return Uri.parse(kGoogleSubscriptionsUrl);
      case SubscriptionBillingSource.stripe:
        return null;
      default:
        if (Platform.isIOS) {
          return Uri.parse(kAppleSubscriptionsUrl);
        }
        if (Platform.isAndroid) {
          return Uri.parse(kGoogleSubscriptionsUrl);
        }
        return null;
    }
  }
}
