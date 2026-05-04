import '../features/gamification/models/subscription_plan.dart';

enum CreatorCommandCenterState { closed, expanded, collapsed }

enum HomeFeedScrollDirection { idle, up, down }

class CreatorCommandSnapshot {
  const CreatorCommandSnapshot({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.level,
    required this.streakDays,
    required this.subscriptionPlan,
    required this.tippyAiEnabled,
    required this.draftCount,
    required this.consistencyScorePercent,
    required this.alertCount,
    required this.requiresAttentionCount,
    required this.pendingWorkCount,
    required this.scheduledQueueCount,
    this.growthPercent,
    this.nextPostDueAt,
    this.nextPostOverdue = false,
  });

  final String userId;
  final String username;
  final String displayName;
  final int level;
  final int streakDays;
  final SubscriptionPlan subscriptionPlan;
  final bool tippyAiEnabled;
  final int draftCount;
  final int consistencyScorePercent;
  final int alertCount;
  final int requiresAttentionCount;
  final int pendingWorkCount;
  final int scheduledQueueCount;
  final double? growthPercent;
  final DateTime? nextPostDueAt;
  final bool nextPostOverdue;

  String get identityLabel =>
      '${displayName.isNotEmpty ? displayName : username} • Level $level';

  String get streakLabel =>
      streakDays == 1 ? '1 day streak' : '$streakDays day streak';

  String get collapsedSummary {
    final String name = displayName.isNotEmpty ? displayName : username;
    final String momentum = streakDays > 0
        ? '🔥 ${streakDays}d streak'
        : 'Lv$level';
    final String work = scheduledQueueCount > 0
        ? ' • $scheduledQueueCount in queue'
        : (draftCount > 0
            ? ' • $draftCount ${draftCount == 1 ? 'draft' : 'drafts'}'
            : '');
    return '$name • $momentum$work';
  }
}
