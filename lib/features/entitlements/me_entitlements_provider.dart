import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../billing/subscription_provider.dart';
import 'me_entitlements_models.dart';

export '../billing/subscription_provider.dart'
    show
        invalidateSubscriptionEntitlements,
        refreshSubscriptionEntitlements,
        subscriptionAuthUserProvider,
        subscriptionRepositoryProvider,
        subscriptionSnapshotProvider;

/// Legacy provider name — same as [subscriptionSnapshotProvider].
final AutoDisposeFutureProvider<SubscriptionSnapshot> meEntitlementsProvider =
    subscriptionSnapshotProvider;
