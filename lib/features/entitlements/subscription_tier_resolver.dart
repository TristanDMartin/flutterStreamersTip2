import '../../utils/firestore_map_readers.dart';
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

SubscriptionTierResolution resolveSubscriptionTierFromUserDocument(
  Map<String, dynamic>? raw,
) {
  if (raw == null || raw.isEmpty) {
    return const SubscriptionTierResolution(
      plan: SubscriptionPlan.unknown,
      sourceField: 'none',
    );
  }
  final Object? ent = raw['entitlements'];
  final Map<String, dynamic>? entMap = ent is Map<String, dynamic> ? ent : null;
  Map<String, dynamic>? tippyEnt;
  final Object? tippyObj = entMap?['tippyAi'] ?? entMap?['tippy_ai'];
  if (tippyObj is Map<String, dynamic>) {
    tippyEnt = tippyObj;
  }
  // Server-owned fields only; `subscription`, `plan` and `stripeRole` are
  // client-writable on users/{uid} and must not grant a tier.
  final List<MapEntry<String, String?>> candidates =
      <MapEntry<String, String?>>[
    MapEntry<String, String?>(
      'subscriptionTier',
      raw['subscriptionTier'] is String
          ? raw['subscriptionTier'] as String
          : null,
    ),
    MapEntry<String, String?>(
      'entitlements.tippyAi.plan',
      stringFieldFromMap(tippyEnt, 'plan'),
    ),
    MapEntry<String, String?>(
      'entitlements.tippyAi.tier',
      stringFieldFromMap(tippyEnt, 'tier'),
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
