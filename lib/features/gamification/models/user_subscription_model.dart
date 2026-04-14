import '../gamification_firestore_utils.dart';
import 'subscription_plan.dart';

/// Read model for `users/{uid}.subscription` (or root fields mirrored from billing).
class UserSubscriptionModel {
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

  factory UserSubscriptionModel.fromFirestoreMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const UserSubscriptionModel(
        plan: SubscriptionPlan.starter,
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
}
