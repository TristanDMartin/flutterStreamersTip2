import '../../../models/activity_notification.dart';
import '../../gamification/models/user_progress_bundle.dart';
import '../activity_notification_rules.dart';
import 'activity_pulse_tokens.dart';

/// Filter chips on Creator Pulse.
enum ActivityPulseFilter {
  all,
  threads,
  mentions,
  likes,
  follows,
  momentum,
  tippy,
  live,
}

extension ActivityPulseFilterLabel on ActivityPulseFilter {
  String get label {
    switch (this) {
      case ActivityPulseFilter.all:
        return 'All';
      case ActivityPulseFilter.threads:
        return 'Threads';
      case ActivityPulseFilter.mentions:
        return 'Mentions';
      case ActivityPulseFilter.likes:
        return 'Likes';
      case ActivityPulseFilter.follows:
        return 'Follows';
      case ActivityPulseFilter.momentum:
        return 'Momentum';
      case ActivityPulseFilter.tippy:
        return 'Tippy';
      case ActivityPulseFilter.live:
        return 'Live';
    }
  }
}

/// One row in the pulse feed (single, grouped, or insight).
sealed class ActivityPulseEntry {
  const ActivityPulseEntry();
  DateTime get sortTime;
}

final class ActivityPulseSingle extends ActivityPulseEntry {
  const ActivityPulseSingle(this.notification);
  final ActivityNotification notification;
  @override
  DateTime get sortTime => notification.timestamp;
}

final class ActivityPulseGrouped extends ActivityPulseEntry {
  const ActivityPulseGrouped({
    required this.type,
    required this.notifications,
  });
  final ActivityNotificationType type;
  final List<ActivityNotification> notifications;
  @override
  DateTime get sortTime => notifications.first.timestamp;
}

final class ActivityPulseInsight extends ActivityPulseEntry {
  const ActivityPulseInsight({
    required this.id,
    required this.title,
    required this.body,
    required this.emoji,
    required this.accent,
    required this.timestamp,
  });
  final String id;
  final String title;
  final String body;
  final String emoji;
  final ActivityPulseAccent accent;
  final DateTime timestamp;
  @override
  DateTime get sortTime => timestamp;
}

extension ActivityPulseNotificationX on ActivityNotification {
  bool get isHighPriority {
    switch (type) {
      case ActivityNotificationType.commentReply:
      case ActivityNotificationType.mention:
      case ActivityNotificationType.follow:
      case ActivityNotificationType.milestone:
      case ActivityNotificationType.liveStream:
        return true;
      case ActivityNotificationType.tag:
        return commentText != null && commentText!.isNotEmpty;
      case ActivityNotificationType.adminBroadcast:
        return isTippyType || isContentPlanType;
      case ActivityNotificationType.like:
      case ActivityNotificationType.comment:
      case ActivityNotificationType.newVideo:
        return false;
    }
  }

  String get _typeBlob =>
      '${actionType ?? ''} ${actionUrl ?? ''} ${milestoneType ?? ''} '
              '${commentText ?? ''}'
          .toLowerCase();

  bool get isContentPlanType =>
      isContentPlanNotificationType(actionType) ||
      activityActionUrlLooksLikeContentPlan(actionUrl) ||
      _typeBlob.contains('content_plan') ||
      _typeBlob.contains('content-planning');

  bool get isTippyType {
    if (isTippyCoachNotificationType(actionType)) {
      return true;
    }
    if (activityActionUrlLooksLikeTrendDiscovery(actionUrl)) {
      return type == ActivityNotificationType.adminBroadcast;
    }
    if (type != ActivityNotificationType.adminBroadcast) {
      return false;
    }
    return _typeBlob.contains('tippy') || _typeBlob.contains('ai_');
  }

  bool get isMomentumType =>
      type == ActivityNotificationType.milestone || _isStreakMilestone;

  bool get _isStreakMilestone {
    final String? mt = milestoneType?.toLowerCase();
    return mt != null && (mt.contains('streak') || mt.contains('day'));
  }

  bool get isLiveType =>
      type == ActivityNotificationType.liveStream ||
      (type == ActivityNotificationType.newVideo &&
          commentText != null &&
          commentText!.toLowerCase().contains('live'));

  bool get isThreadType =>
      type == ActivityNotificationType.commentReply ||
      (type == ActivityNotificationType.comment &&
          (threadId?.isNotEmpty == true || postId?.isNotEmpty == true));

  ActivityPulseAccent get pulseAccent {
    if (isTippyType) {
      return ActivityPulseAccent.tippy;
    }
    if (isContentPlanType) {
      return ActivityPulseAccent.momentum;
    }
    if (isMomentumType || type == ActivityNotificationType.milestone) {
      return ActivityPulseAccent.momentum;
    }
    if (isLiveType) {
      return ActivityPulseAccent.live;
    }
    switch (type) {
      case ActivityNotificationType.commentReply:
      case ActivityNotificationType.comment:
        return ActivityPulseAccent.thread;
      case ActivityNotificationType.like:
        return ActivityPulseAccent.like;
      case ActivityNotificationType.follow:
        return ActivityPulseAccent.follow;
      case ActivityNotificationType.mention:
      case ActivityNotificationType.tag:
        return ActivityPulseAccent.mention;
      default:
        return ActivityPulseAccent.standard;
    }
  }

  bool matchesFilter(ActivityPulseFilter filter) {
    switch (filter) {
      case ActivityPulseFilter.all:
        return true;
      case ActivityPulseFilter.threads:
        return isThreadType;
      case ActivityPulseFilter.mentions:
        return type == ActivityNotificationType.mention ||
            type == ActivityNotificationType.tag;
      case ActivityPulseFilter.likes:
        return type == ActivityNotificationType.like;
      case ActivityPulseFilter.follows:
        return type == ActivityNotificationType.follow;
      case ActivityPulseFilter.momentum:
        return isMomentumType || isContentPlanType;
      case ActivityPulseFilter.tippy:
        return isTippyType;
      case ActivityPulseFilter.live:
        return isLiveType || type == ActivityNotificationType.newVideo;
    }
  }

  String? get effectiveThreadId {
    if (threadId != null && threadId!.isNotEmpty) {
      return threadId;
    }
    if (postId != null && postId!.isNotEmpty) {
      return postId;
    }
    return null;
  }

  bool get showThreadContinueCta =>
      type == ActivityNotificationType.commentReply &&
      effectiveThreadId != null;
}

abstract final class ActivityPulseLogic {
  static const List<ActivityPulseFilter> filters = ActivityPulseFilter.values;

  /// Client-side coaching cards. Disabled: they are not written to
  /// `notifications/{uid}/items`, so the website Activity feed never shows
  /// them and they reappear on every open (false "new notification" feel).
  /// Real Tippy / score events should arrive via Firestore notifications.
  static List<ActivityPulseInsight> insightsFromBundle(
    UserProgressBundle? bundle,
  ) {
    return const <ActivityPulseInsight>[];
  }

  static Map<String, List<ActivityPulseEntry>> processGrouped({
    required Map<String, List<ActivityNotification>> grouped,
    required ActivityPulseFilter filter,
    UserProgressBundle? bundle,
  }) {
    final Map<String, List<ActivityPulseEntry>> result =
        <String, List<ActivityPulseEntry>>{};
    for (final MapEntry<String, List<ActivityNotification>> entry
        in grouped.entries) {
      final List<ActivityNotification> filtered = entry.value
          .where((ActivityNotification n) => n.matchesFilter(filter))
          .toList();
      if (filtered.isEmpty) {
        continue;
      }
      result[entry.key] = groupNotifications(filtered);
    }
    if (filter == ActivityPulseFilter.all ||
        filter == ActivityPulseFilter.momentum ||
        filter == ActivityPulseFilter.tippy) {
      final List<ActivityPulseInsight> insights =
          insightsFromBundle(bundle).where((ActivityPulseInsight i) {
        switch (filter) {
          case ActivityPulseFilter.momentum:
            return i.accent == ActivityPulseAccent.momentum;
          case ActivityPulseFilter.tippy:
            return i.accent == ActivityPulseAccent.tippy;
          default:
            return true;
        }
      }).toList();
      if (insights.isNotEmpty) {
        final List<ActivityPulseEntry> today =
            result.putIfAbsent('Today', () => <ActivityPulseEntry>[]);
        today.insertAll(0, insights);
      }
    }
    return result;
  }

  static List<ActivityPulseEntry> groupNotifications(
    List<ActivityNotification> items,
  ) {
    final List<ActivityNotification> sorted =
        List<ActivityNotification>.from(items)
          ..sort(
            (ActivityNotification a, ActivityNotification b) =>
                b.timestamp.compareTo(a.timestamp),
          );
    final List<ActivityPulseEntry> out = <ActivityPulseEntry>[];
    int index = 0;
    while (index < sorted.length) {
      final ActivityNotification current = sorted[index];
      if (current.type == ActivityNotificationType.like) {
        final String? videoKey = current.videoId;
        final List<ActivityNotification> batch = <ActivityNotification>[
          current,
        ];
        int j = index + 1;
        while (j < sorted.length) {
          final ActivityNotification next = sorted[j];
          if (next.type != ActivityNotificationType.like) {
            break;
          }
          if (videoKey != null &&
              videoKey.isNotEmpty &&
              next.videoId != videoKey) {
            break;
          }
          batch.add(next);
          j++;
        }
        if (batch.length > 1) {
          out.add(
            ActivityPulseGrouped(
              type: ActivityNotificationType.like,
              notifications: batch,
            ),
          );
        } else {
          out.add(ActivityPulseSingle(current));
        }
        index = j;
        continue;
      }
      out.add(ActivityPulseSingle(current));
      index++;
    }
    return out;
  }
}
