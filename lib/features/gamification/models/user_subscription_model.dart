import 'package:flutter/foundation.dart';

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

  const UserSubscriptionModel({
    required this.plan,
    required this.status,
    this.currentPeriodEnd,
    this.willCancel = false,
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
    );
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
        '🔐 ProgressionSubscription: bypass studio override applied for uid=$uid',
      );
      return const UserSubscriptionModel(
        plan: SubscriptionPlan.studio,
        status: 'active',
      );
    }

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
      debugPrint(
        '🔐 ProgressionSubscription: no subscription fields found | nested=false | rootPlan=$rootPlan | rootStatus=$rootStatus',
      );
      return const UserSubscriptionModel(
        plan: SubscriptionPlan.unknown,
        status: 'unknown',
      );
    }

    final UserSubscriptionModel resolved =
        UserSubscriptionModel.fromFirestoreMap(merged);
    final String source = hasNestedSubscription
        ? (rootPlan != null || rootStatus != null ? 'nested+root' : 'nested')
        : 'root';
    debugPrint(
      '🔐 ProgressionSubscription: source=$source | nestedPlan=${nestedMap?['plan'] ?? nestedMap?['tier'] ?? nestedMap?['productId']} | nestedStatus=${nestedMap?['status'] ?? nestedMap?['subscriptionStatus']} | rootPlan=$rootPlan | rootStatus=$rootStatus | resolvedPlan=${subscriptionPlanToApiValue(resolved.plan)} | resolvedStatus=${resolved.status} | willCancel=${resolved.willCancel} | currentPeriodEnd=${resolved.currentPeriodEnd?.toIso8601String()}',
    );
    return resolved;
  }
}
