import '../billing/models/subscription_snapshot.dart';

export '../billing/models/subscription_snapshot.dart'
    show
        AiCreditCosts,
        ApiEntitlements,
        SubscriptionSnapshot,
        UsageSnapshot;
export 'tippy_ai_entitlement_payload.dart';

/// Legacy name — use [SubscriptionSnapshot].
typedef MeEntitlementsData = SubscriptionSnapshot;
