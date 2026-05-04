import '../gamification/models/subscription_plan.dart';

/// Aligned with cloud_functions `src/shared/subscription_tier.js`.
class SubscriptionTierResolution {
  const SubscriptionTierResolution({
    required this.plan,
    required this.sourceField,
  });

  final SubscriptionPlan plan;
  final String sourceField;
}

String? _stringField(Map<String, dynamic>? map, String key) {
  if (map == null) {
    return null;
  }
  final Object? v = map[key];
  return v is String ? v : null;
}

SubscriptionTierResolution resolveSubscriptionTierFromUserDocument(
  Map<String, dynamic>? raw,
) {
  if (raw == null || raw.isEmpty) {
    return const SubscriptionTierResolution(
      plan: SubscriptionPlan.unknown,
      sourceField: 'none',
    );
  }
  final Object? sub = raw['subscription'];
  final Map<String, dynamic>? subMap =
      sub is Map<String, dynamic> ? sub : null;
  final Object? ent = raw['entitlements'];
  final Map<String, dynamic>? entMap =
      ent is Map<String, dynamic> ? ent : null;
  Map<String, dynamic>? tippyEnt;
  final Object? tippyObj = entMap?['tippyAi'] ?? entMap?['tippy_ai'];
  if (tippyObj is Map<String, dynamic>) {
    tippyEnt = tippyObj;
  }
  final List<MapEntry<String, String?>> candidates = <MapEntry<String, String?>>[
    MapEntry<String, String?>(
      'subscription.tier',
      _stringField(subMap, 'tier'),
    ),
    MapEntry<String, String?>(
      'subscription.plan',
      _stringField(subMap, 'plan'),
    ),
    MapEntry<String, String?>(
      'stripeRole',
      raw['stripeRole'] is String ? raw['stripeRole'] as String : null,
    ),
    MapEntry<String, String?>(
      'subscriptionTier',
      raw['subscriptionTier'] is String
          ? raw['subscriptionTier'] as String
          : null,
    ),
    MapEntry<String, String?>(
      'plan',
      raw['plan'] is String ? raw['plan'] as String : null,
    ),
    MapEntry<String, String?>(
      'entitlements.tippyAi.plan',
      _stringField(tippyEnt, 'plan'),
    ),
    MapEntry<String, String?>(
      'entitlements.tippyAi.tier',
      _stringField(tippyEnt, 'tier'),
    ),
    MapEntry<String, String?>(
      'tier',
      raw['tier'] is String ? raw['tier'] as String : null,
    ),
  ];
  for (final MapEntry<String, String?> e in candidates) {
    final SubscriptionPlan p = subscriptionPlanFromString(e.value);
    if (p != SubscriptionPlan.unknown) {
      return SubscriptionTierResolution(
        plan: p,
        sourceField: e.key,
      );
    }
  }
  return const SubscriptionTierResolution(
    plan: SubscriptionPlan.unknown,
    sourceField: 'none',
  );
}
