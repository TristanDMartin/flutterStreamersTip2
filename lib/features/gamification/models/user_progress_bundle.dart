import 'daily_mission_model.dart';
import 'gamification_summary_model.dart';
import 'usage_metrics_model.dart';
import 'user_entitlements_model.dart';
import 'user_subscription_model.dart';

/// Single snapshot for progression tab + future headers (read-only).
class UserProgressBundle {
  final GamificationSummaryModel progress;
  final UserSubscriptionModel? subscription;
  final UserEntitlementsModel entitlements;
  final UsageMetricsModel? usage;
  final List<DailyMissionModel> missions;

  const UserProgressBundle({
    required this.progress,
    this.subscription,
    required this.entitlements,
    this.usage,
    required this.missions,
  });

  factory UserProgressBundle.fallback() {
    return UserProgressBundle(
      progress: GamificationSummaryModel.fromFirestoreMap(null),
      subscription: null,
      entitlements: const UserEntitlementsModel(),
      usage: null,
      missions: const <DailyMissionModel>[],
    );
  }
}
