import 'package:flutter/foundation.dart';

import '../../billing/get_user_tier.dart';
import '../../entitlements/subscription_tier_resolver.dart';
import '../gamification_firestore_utils.dart';
import 'subscription_plan.dart';

/// Read model for `users/{uid}.subscription` (or root fields mirrored from billing).
class UserSubscriptionModel {
  static const Set<String> _bypassStudioUids = <String>{
    'bU0RxyZ2L4ULAv1Co5L4f825yV73',
    'jsmbQMLQjoUyC5cUFvkrRbi9mkp1',
  };

  final SubscriptionPlan plan;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool willCancel;

  /// True when [plan] is Pro and [status] is Stripe `trialing` (canonical fields).
  final bool isProTrialing;

  /// Stripe trial end when webhook writes `subscriptionTrialEndAt`.
  final DateTime? subscriptionTrialEndAt;

  const UserSubscriptionModel({
    required this.plan,
    required this.status,
    this.currentPeriodEnd,
    this.willCancel = false,
    this.isProTrialing = false,
    this.subscriptionTrialEndAt,
  });

  bool get isResolved =>
      plan != SubscriptionPlan.unknown ||
      status.trim().toLowerCase() != 'unknown';

  factory UserSubscriptionModel.fromFirestoreMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const UserSubscriptionModel(
        plan: SubscriptionPlan.unknown,
        status: 'unknown',
      );
    }
    final String? planStr = raw['plan'] as String? ??
        raw['tier'] as String? ??
        raw['productId'] as String?;
    final String status = raw['status'] as String? ??
        raw['subscriptionStatus'] as String? ??
        'active';
    return UserSubscriptionModel(
      plan: subscriptionPlanFromString(planStr),
      status: status,
      currentPeriodEnd: readFirestoreDate(raw['currentPeriodEnd']) ??
          readFirestoreDate(raw['renewsAt']),
      willCancel: raw['cancelAtPeriodEnd'] as bool? ??
          raw['willCancel'] as bool? ??
          false,
      isProTrialing: subscriptionPlanFromString(planStr) == SubscriptionPlan.pro &&
          status.trim().toLowerCase() == 'trialing',
      subscriptionTrialEndAt: readFirestoreDate(raw['subscriptionTrialEndAt']),
    );
  }

  static String _readStatusFromUserDocument(
    Map<String, dynamic> raw,
  ) {
    final Object? sub = raw['subscription'];
    if (sub is Map<String, dynamic>) {
      final Object? st = sub['status'] ?? sub['subscriptionStatus'];
      if (st is String && st.trim().isNotEmpty) {
        return st;
      }
    }
    final Object? r = raw['subscriptionStatus'] ?? raw['subscription_status'];
    if (r is String && r.trim().isNotEmpty) {
      return r;
    }
    return 'unknown';
  }

  factory UserSubscriptionModel.fromUserDocument(
    Map<String, dynamic>? raw, {
    String? uid,
  }) {
    if (raw == null || raw.isEmpty) {
      debugPrint(
        '🔐 ProgressionSubscription: user document missing or empty -> plan=unknown, status=unknown',
      );
      return const UserSubscriptionModel(
        plan: SubscriptionPlan.unknown,
        status: 'unknown',
      );
    }

    if (uid != null && _bypassStudioUids.contains(uid)) {
      debugPrint(
        '🔐 ProgressionSubscription: bypass studio override for uid=$uid',
      );
      return const UserSubscriptionModel(
        plan: SubscriptionPlan.studio,
        status: 'active',
      );
    }

    final SubscriptionTierResolution tierRes =
        resolveSubscriptionTierFromUserDocument(raw);
    final BillingTierAccess billing = BillingTierAccess.fromUserDocument(raw);

    final Object? nested = raw['subscription'];
    final Map<String, dynamic> merged = nested is Map<String, dynamic>
        ? Map<String, dynamic>.from(nested)
        : <String, dynamic>{};
    final Map<String, dynamic>? nestedMap =
        nested is Map<String, dynamic> ? nested : null;
    final bool hasNestedSubscription = nested is Map<String, dynamic>;

    final String? rootPlan = raw['subscriptionTier'] as String? ??
        raw['subscription_plan'] as String? ??
        raw['tier'] as String? ??
        raw['plan'] as String?;
    final String? rootStatus = raw['subscriptionStatus'] as String? ??
        raw['subscription_status'] as String?;
    final Object? rootPeriodEnd = raw['subscriptionCurrentPeriodEnd'] ??
        raw['currentPeriodEnd'] ??
        raw['current_period_end'] ??
        raw['renewsAt'];
    final Object? rootCancelFlag = raw['cancelAtPeriodEnd'] ??
        raw['cancel_at_period_end'] ??
        raw['willCancel'];

    if (rootPlan is String && rootPlan.isNotEmpty) {
      merged['plan'] = rootPlan;
    }
    if (rootStatus is String && rootStatus.isNotEmpty) {
      merged['status'] = rootStatus;
    }
    if (rootPeriodEnd != null) {
      merged['currentPeriodEnd'] = rootPeriodEnd;
    }
    if (rootCancelFlag is bool) {
      merged['cancelAtPeriodEnd'] = rootCancelFlag;
    }

    if (merged.isEmpty) {
      if (billing.usedCanonicalFields) {
        final String st = _readStatusFromUserDocument(raw);
        debugPrint(
          '🔐 ProgressionSubscription: canonical billing tier '
          '${subscriptionPlanToApiValue(billing.effectivePlan)} status=$st',
        );
        return UserSubscriptionModel(
          plan: billing.effectivePlan,
          status: st,
          currentPeriodEnd: readFirestoreDate(raw['subscriptionCurrentPeriodEnd']) ??
              readFirestoreDate(raw['currentPeriodEnd']),
          willCancel: raw['cancelAtPeriodEnd'] as bool? ?? false,
          isProTrialing: billing.isProTrialing,
          subscriptionTrialEndAt: billing.subscriptionTrialEndAt,
        );
      }
      if (tierRes.plan != SubscriptionPlan.unknown) {
        final String st = _readStatusFromUserDocument(raw);
        debugPrint(
          '🔐 ProgressionSubscription: empty merge; tier from ${tierRes.sourceField} '
          '-> ${subscriptionPlanToApiValue(tierRes.plan)} status=$st',
        );
        final SubscriptionPlan p = tierRes.plan;
        return UserSubscriptionModel(
          plan: p,
          status: st,
          isProTrialing: p == SubscriptionPlan.pro &&
              st.trim().toLowerCase() == 'trialing',
          subscriptionTrialEndAt: readFirestoreDate(raw['subscriptionTrialEndAt']),
        );
      }
      debugPrint(
        '🔐 ProgressionSubscription: no subscription fields | rootPlan=$rootPlan | '
        'rootStatus=$rootStatus',
      );
      return const UserSubscriptionModel(
        plan: SubscriptionPlan.unknown,
        status: 'unknown',
      );
    }

    final UserSubscriptionModel resolved =
        UserSubscriptionModel.fromFirestoreMap(merged);
    final SubscriptionPlan effectivePlan = billing.usedCanonicalFields
        ? billing.effectivePlan
        : (tierRes.plan != SubscriptionPlan.unknown
            ? tierRes.plan
            : resolved.plan);
    final bool proTrial = billing.usedCanonicalFields
        ? billing.isProTrialing
        : (effectivePlan == SubscriptionPlan.pro &&
            resolved.status.trim().toLowerCase() == 'trialing');
    final DateTime? trialEnd = billing.usedCanonicalFields
        ? billing.subscriptionTrialEndAt
        : readFirestoreDate(raw['subscriptionTrialEndAt']);
    final UserSubscriptionModel out = UserSubscriptionModel(
      plan: effectivePlan,
      status: resolved.status,
      currentPeriodEnd: resolved.currentPeriodEnd,
      willCancel: resolved.willCancel,
      isProTrialing: proTrial,
      subscriptionTrialEndAt: trialEnd,
    );
    final String source = hasNestedSubscription
        ? (rootPlan != null || rootStatus != null ? 'nested+root' : 'nested')
        : 'root';
    debugPrint(
      '🔐 ProgressionSubscription: source=$source | tierField=${tierRes.sourceField} | '
      'nestedPlan=${nestedMap?['plan'] ?? nestedMap?['tier'] ?? nestedMap?['productId']} | '
      'nestedStatus=${nestedMap?['status'] ?? nestedMap?['subscriptionStatus']} | '
      'rootPlan=$rootPlan | rootStatus=$rootStatus | '
      'effectivePlan=${subscriptionPlanToApiValue(effectivePlan)} | '
      'status=${out.status} | willCancel=${out.willCancel} | '
      'currentPeriodEnd=${out.currentPeriodEnd?.toIso8601String()}',
    );
    return out;
  }
}
