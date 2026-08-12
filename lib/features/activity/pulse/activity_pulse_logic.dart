import '../../../models/activity_notification.dart';
import '../../gamification/models/user_progress_bundle.dart';
import '../activity_notification_rules.dart';
import 'activity_pulse_tokens.dart';

/// Filter chips on Creator Pulse.
/// Order + keys match website `ACTIVITY_PAGE_TABS`.
enum ActivityPulseFilter {
  all,
  follows,
  likes,
  comments,
  mentions,
  threads,
  global,
}

extension ActivityPulseFilterLabel on ActivityPulseFilter {
  String get label {
    switch (this) {
      case ActivityPulseFilter.all:
        return 'All';
      case ActivityPulseFilter.follows:
        return 'Follows';
      case ActivityPulseFilter.likes:
        return 'Likes';
      case ActivityPulseFilter.comments:
        return 'Comments';
      case ActivityPulseFilter.mentions:
        return 'Mentions';
      case ActivityPulseFilter.threads:
        return 'Threads';
      case ActivityPulseFilter.global:
        return 'Global';
    }
  }

  /// Website `ActivityFilterKey` string.
  String get contractKey {
    switch (this) {
      case ActivityPulseFilter.all:
        return 'all';
      case ActivityPulseFilter.follows:
        return 'follows';
      case ActivityPulseFilter.likes:
        return 'likes';
      case ActivityPulseFilter.comments:
        return 'comments';
      case ActivityPulseFilter.mentions:
        return 'mentions';
      case ActivityPulseFilter.threads:
        return 'threads';
      case ActivityPulseFilter.global:
        return 'global';
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
    final String at = (actionType ?? '').trim().toLowerCase();
    if (at == 'retention_prompt' || at == 'retention') {
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

  bool get _looksLikeThreadTarget =>
      (threadId?.isNotEmpty == true || postId?.isNotEmpty == true) &&
      (videoId == null || videoId!.isEmpty);

  bool get isThreadType {
    final String fromAction = normalizeActivityFilterType(actionType);
    if (fromAction.isNotEmpty) {
      return fromAction == 'COMMENT_THREAD' ||
          fromAction == 'REPLY_THREAD_COMMENT' ||
          fromAction == 'COLLAB_INVITE';
    }
    return (type == ActivityNotificationType.comment ||
            type == ActivityNotificationType.commentReply) &&
        _looksLikeThreadTarget;
  }

  /// Canonical type key for tab filters (website `normalizeActivityNotificationType`).
  String get canonicalFilterType {
    final String fromAction = normalizeActivityFilterType(actionType);
    if (fromAction.isNotEmpty) {
      return fromAction;
    }
    switch (type) {
      case ActivityNotificationType.follow:
        return 'FOLLOW';
      case ActivityNotificationType.like:
        return 'LIKE_VIDEO';
      case ActivityNotificationType.comment:
        return _looksLikeThreadTarget ? 'COMMENT_THREAD' : 'COMMENT_VIDEO';
      case ActivityNotificationType.commentReply:
        return _looksLikeThreadTarget
            ? 'REPLY_THREAD_COMMENT'
            : 'REPLY_VIDEO_COMMENT';
      case ActivityNotificationType.mention:
      case ActivityNotificationType.tag:
        return 'MENTION';
      case ActivityNotificationType.liveStream:
        return 'newEvent';
      case ActivityNotificationType.adminBroadcast:
        if (isTippyType) {
          return 'tippy_coach';
        }
        if (isContentPlanType) {
          return 'content_plan_queue';
        }
        return 'admin_broadcast';
      case ActivityNotificationType.newVideo:
      case ActivityNotificationType.milestone:
        return '';
    }
  }

  ActivityPulseAccent get pulseAccent {
    if (isTippyType) {
      return ActivityPulseAccent.tippy;
    }
    if (isContentPlanType) {
      return ActivityPulseAccent.action;
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
    if (filter == ActivityPulseFilter.all) {
      return true;
    }
    final String key = canonicalFilterType;
    if (key.isNotEmpty &&
        activityTypeMatchesFilterTab(
          rawType: key,
          filterKey: filter.contractKey,
        )) {
      return true;
    }
    // Fallbacks when Firestore type was coarse / missing.
    switch (filter) {
      case ActivityPulseFilter.follows:
        return type == ActivityNotificationType.follow &&
            normalizeActivityFilterType(actionType) != 'COLLAB_INVITE';
      case ActivityPulseFilter.likes:
        return type == ActivityNotificationType.like;
      case ActivityPulseFilter.comments:
        return (type == ActivityNotificationType.comment ||
                type == ActivityNotificationType.commentReply) &&
            !isThreadType;
      case ActivityPulseFilter.mentions:
        return type == ActivityNotificationType.mention ||
            type == ActivityNotificationType.tag;
      case ActivityPulseFilter.threads:
        return isThreadType;
      case ActivityPulseFilter.global:
        return isTippyType ||
            isContentPlanType ||
            type == ActivityNotificationType.adminBroadcast ||
            type == ActivityNotificationType.liveStream;
      case ActivityPulseFilter.all:
        return true;
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
        filter == ActivityPulseFilter.global) {
      final List<ActivityPulseInsight> insights =
          insightsFromBundle(bundle).where((ActivityPulseInsight i) {
        if (filter == ActivityPulseFilter.global) {
          return i.accent == ActivityPulseAccent.tippy ||
              i.accent == ActivityPulseAccent.action ||
              i.accent == ActivityPulseAccent.momentum;
        }
        return true;
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
