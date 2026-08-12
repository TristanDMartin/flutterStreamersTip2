import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/backend/site_api_base.dart';
import '../../models/activity_notification.dart';

/// Match website `HIDE_CONTENT_PLAN_EXPIRED_IN_ACTIVITY`.
const bool kHideContentPlanExpiredInActivity = true;

const Set<String> kTippyCoachNotificationTypes = <String>{
  'tippy_coach',
  'tippycoach',
};

const Set<String> kContentPlanNotificationTypes = <String>{
  'content_plan_queue',
  'content_plan_recap',
  'content_plan_expired',
  'contentplanexpired',
  'content_plan',
  'plan_expired',
};

const Set<String> kGlobalSystemNotificationTypes = <String>{
  ...kTippyCoachNotificationTypes,
  ...kContentPlanNotificationTypes,
  'admin_broadcast',
  'adminbroadcast',
  'broadcast',
  'message',
  'new_message',
  'newmessage',
  'dm',
  'direct_message',
  'directmessage',
  'newevent',
  'new_event',
  'retention_prompt',
  'retention',
  'session_summary',
  'sessionsummary',
  'coaching_report',
  'coachingreport',
  'agent_plan_outcome',
  'agentplanoutcome',
  'workspace_automation',
  'workspaceautomation',
};

/// Mirror website `ACTIVITY_LEGACY_TYPE_MAP` → canonical type keys.
const Map<String, String> kActivityLegacyTypeMap = <String, String>{
  'follow': 'FOLLOW',
  'forum_follow': 'FOLLOW',
  'like': 'LIKE_VIDEO',
  'forum_like': 'LIKE_THREAD',
  'comment': 'COMMENT_VIDEO',
  'commentreply': 'REPLY_VIDEO_COMMENT',
  'comment_reply': 'REPLY_VIDEO_COMMENT',
  'forum_reply': 'REPLY_THREAD_COMMENT',
  'thread_comment_reply': 'REPLY_THREAD_COMMENT',
  'thread_comment': 'COMMENT_THREAD',
  'mention': 'MENTION',
  'tag': 'MENTION',
};

/// Mirror website `ACTIVITY_TAB_NORMALIZED_TYPES` (web + app must match).
const Map<String, Set<String>> kActivityTabNormalizedTypes =
    <String, Set<String>>{
  'follows': <String>{'FOLLOW'},
  'likes': <String>{'LIKE_VIDEO', 'LIKE_THREAD', 'LIKE_COMMENT'},
  'comments': <String>{'COMMENT_VIDEO', 'REPLY_VIDEO_COMMENT'},
  'mentions': <String>{'MENTION'},
  'threads': <String>{
    'COMMENT_THREAD',
    'REPLY_THREAD_COMMENT',
    'COLLAB_INVITE',
  },
  'global': <String>{
    'admin_broadcast',
    'newEvent',
    'content_plan_expired',
    'content_plan_queue',
    'content_plan_recap',
    'tippy_coach',
    'message',
  },
};

/// Normalize a Firestore/activity type for tab filters (website parity).
String normalizeActivityFilterType(String? raw) {
  final String trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final String lower = trimmed.toLowerCase();
  final String? mapped = kActivityLegacyTypeMap[lower];
  if (mapped != null) {
    return mapped;
  }
  // Preserve known canonical casing used by the website contract.
  switch (lower) {
    case 'follow':
      return 'FOLLOW';
    case 'like_video':
      return 'LIKE_VIDEO';
    case 'like_thread':
      return 'LIKE_THREAD';
    case 'like_comment':
      return 'LIKE_COMMENT';
    case 'comment_video':
      return 'COMMENT_VIDEO';
    case 'reply_video_comment':
      return 'REPLY_VIDEO_COMMENT';
    case 'comment_thread':
      return 'COMMENT_THREAD';
    case 'reply_thread_comment':
      return 'REPLY_THREAD_COMMENT';
    case 'mention':
      return 'MENTION';
    case 'collab_invite':
      return 'COLLAB_INVITE';
    case 'admin_broadcast':
      return 'admin_broadcast';
    case 'newevent':
    case 'new_event':
      return 'newEvent';
    case 'content_plan_expired':
      return 'content_plan_expired';
    case 'content_plan_queue':
      return 'content_plan_queue';
    case 'content_plan_recap':
      return 'content_plan_recap';
    case 'tippy_coach':
      return 'tippy_coach';
    case 'message':
      return 'message';
    default:
      return trimmed;
  }
}

bool activityTypeMatchesFilterTab({
  required String? rawType,
  required String filterKey,
}) {
  if (filterKey == 'all') {
    return true;
  }
  final Set<String>? allowed = kActivityTabNormalizedTypes[filterKey];
  if (allowed == null) {
    return true;
  }
  return allowed.contains(normalizeActivityFilterType(rawType));
}

/// Canonical Activity row type. Unknown / system prompts must NOT default to
/// [ActivityNotificationType.like] (that produces false "liked your clip" UI).
ActivityNotificationType activityNotificationTypeFromString(String? raw) {
  final String normalized = (raw ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'follow_user':
    case 'follow':
    case 'follows':
    case 'collab_invite':
    case 'collabinvite':
    case 'thread_invite':
    case 'threadinvite':
      return ActivityNotificationType.follow;
    case 'like_video':
    case 'like_post':
    case 'like':
    case 'likes':
    case 'like_comment':
    case 'liked_comment':
    case 'like_thread':
      return ActivityNotificationType.like;
    case 'comment_video':
    case 'comment_post':
    case 'comment':
    case 'comments':
    case 'comment_thread':
    case 'thread_comment':
      return ActivityNotificationType.comment;
    case 'commentreply':
    case 'comment_reply':
    case 'reply_video_comment':
    case 'replyvideocomment':
    case 'video_comment_reply':
    case 'comment_video_reply':
    case 'reply':
    case 'replies':
    case 'reply_thread_comment':
    case 'thread_comment_reply':
    case 'forum_reply':
      return ActivityNotificationType.commentReply;
    case 'tag':
    case 'tags':
      return ActivityNotificationType.tag;
    case 'mention_user':
    case 'mention':
    case 'mentions':
      return ActivityNotificationType.mention;
    case 'newvideo':
    case 'new_video':
    case 'video':
      return ActivityNotificationType.newVideo;
    case 'milestone':
    case 'milestones':
      return ActivityNotificationType.milestone;
    case 'livestream':
    case 'live_stream':
    case 'live':
    case 'new_event':
    case 'newevent':
      return ActivityNotificationType.liveStream;
    case 'admin_broadcast':
    case 'adminbroadcast':
    case 'broadcast':
    case 'content_plan_expired':
    case 'contentplanexpired':
    case 'content_plan':
    case 'content_plan_queue':
    case 'content_plan_recap':
    case 'plan_expired':
    case 'tippy_coach':
    case 'tippycoach':
    case 'message':
    case 'new_message':
    case 'newmessage':
    case 'dm':
    case 'direct_message':
    case 'directmessage':
    case 'calendar_event_reminder':
    case 'calendareventreminder':
    case 'calendar_event_rescheduled':
    case 'calendar_event_cancelled':
    case 'retention_prompt':
    case 'retention':
    case 'session_summary':
    case 'sessionsummary':
    case 'coaching_report':
    case 'coachingreport':
    case 'agent_plan_outcome':
    case 'agentplanoutcome':
    case 'workspace_approval_requested':
    case 'workspace_approval_decided':
    case 'content_approval_requested':
    case 'content_approval_decided':
    case 'workspace_automation':
    case 'workspaceautomation':
      return ActivityNotificationType.adminBroadcast;
    default:
      if (normalized.isEmpty || isGlobalSystemNotificationType(normalized)) {
        return ActivityNotificationType.adminBroadcast;
      }
      // Prefer broadcast over like so Tippy/retention/XP prompts never look
      // like "creators liked your clip" for brand-new accounts.
      return ActivityNotificationType.adminBroadcast;
  }
}

/// Website hides these from the Activity feed and unread badge.
bool shouldHideFromActivityFeed(
  String? type, {
  String? actionType,
  String? chatId,
  String? messageId,
  String? actionUrl,
}) {
  if (isGenericVideoPublishActivityType(type)) {
    return true;
  }
  if (isMessageNotificationType(type) || isMessageNotificationType(actionType)) {
    return true;
  }
  if (shouldHideDmFromActivity(
    type: type,
    actionType: actionType,
    chatId: chatId,
    messageId: messageId,
    actionUrl: actionUrl,
  )) {
    return true;
  }
  if (!kHideContentPlanExpiredInActivity) {
    return false;
  }
  final String normalized = (type ?? '').trim().toLowerCase();
  return normalized == 'content_plan_expired' ||
      normalized == 'contentplanexpired';
}

/// Follower fan-out for video publish is feed content, not Activity.
bool isGenericVideoPublishActivityType(String? raw) {
  final String normalized = (raw ?? '').trim().toLowerCase();
  return normalized == 'newvideo' ||
      normalized == 'new_video' ||
      normalized == 'video_posted' ||
      normalized == 'video_published' ||
      normalized == 'creator_uploaded_video' ||
      normalized == 'creator_posted' ||
      normalized == 'video';
}

/// Personal DMs stay in Inbox — keep admin_broadcast in Activity Global.
bool shouldHideDmFromActivity({
  String? type,
  String? actionType,
  String? chatId,
  String? messageId,
  String? actionUrl,
}) {
  if (!isActivityMessageNotification(
    type: type,
    actionType: actionType,
    chatId: chatId,
    messageId: messageId,
    actionUrl: actionUrl,
  )) {
    return false;
  }
  final String rawType = (type ?? '').trim().toLowerCase();
  if (rawType == 'admin_broadcast' || rawType == 'adminbroadcast') {
    return false;
  }
  return true;
}

/// Website badge filters these types out of the unread count.
bool shouldHideFromActivityUnreadBadge(
  String? type, {
  String? actionType,
  String? chatId,
  String? messageId,
  String? actionUrl,
}) {
  return shouldHideFromActivityFeed(
    type,
    actionType: actionType,
    chatId: chatId,
    messageId: messageId,
    actionUrl: actionUrl,
  );
}

bool isTippyCoachNotificationType(String? type) {
  return kTippyCoachNotificationTypes.contains(
    (type ?? '').trim().toLowerCase(),
  );
}

bool isContentPlanNotificationType(String? type) {
  return kContentPlanNotificationTypes.contains(
    (type ?? '').trim().toLowerCase(),
  );
}

bool isGlobalSystemNotificationType(String? type) {
  return kGlobalSystemNotificationTypes.contains(
    (type ?? '').trim().toLowerCase(),
  );
}

/// Canonical unread check — mirrors website `isNotificationRead` inverted.
bool isActivityNotificationDocUnread(Map<String, dynamic> data) {
  if (data['isRead'] == true || data['read'] == true) {
    return false;
  }
  final Object? readAt = data['readAt'];
  if (readAt is String && readAt.trim().isNotEmpty) {
    return false;
  }
  if (readAt is Timestamp) {
    return false;
  }
  return true;
}

/// Only drop explicit seed/demo IDs — never substring-match real video ids.
bool isSyntheticTestVideoId(String? videoId) {
  if (videoId == null || videoId.isEmpty) {
    return false;
  }
  final String id = videoId.trim().toLowerCase();
  if (id.startsWith('test_video') ||
      id.startsWith('mock_video') ||
      id.startsWith('fake_video')) {
    return true;
  }
  // Short seed ids like video_1 … video_99 only.
  if (id.startsWith('video_') && id.length < 15) {
    final String suffix = id.substring('video_'.length);
    return int.tryParse(suffix) != null;
  }
  return false;
}

bool isSyntheticTestAccountId(String? accountId) {
  if (accountId == null || accountId.isEmpty) {
    return false;
  }
  final String id = accountId.trim().toLowerCase();
  return id.startsWith('test_') ||
      id.startsWith('fake_') ||
      id.startsWith('mock_') ||
      id == 'test_user_1' ||
      id == 'test_user_2' ||
      id == 'test_user_3' ||
      id == 'test_user_4' ||
      id == 'test_user_5';
}

const Set<String> kMessageNotificationTypes = <String>{
  'message',
  'new_message',
  'newmessage',
  'dm',
  'direct_message',
  'directmessage',
};

bool isMessageNotificationType(String? raw) {
  final String normalized = (raw ?? '').trim().toLowerCase();
  return kMessageNotificationTypes.contains(normalized);
}

/// DM Activity rows: typed message, open_chat, or chat-linked docs.
bool isActivityMessageNotification({
  String? type,
  String? actionType,
  String? chatId,
  String? messageId,
  String? actionUrl,
}) {
  if (isMessageNotificationType(type) || isMessageNotificationType(actionType)) {
    return true;
  }
  final String openChat = (actionType ?? '').trim().toLowerCase();
  if (openChat == 'open_chat') {
    return true;
  }
  if (isTippyCoachNotificationType(type) ||
      isContentPlanNotificationType(type) ||
      isTippyCoachNotificationType(actionType) ||
      isContentPlanNotificationType(actionType)) {
    return false;
  }
  final String normalizedType = (type ?? '').trim().toLowerCase();
  if (normalizedType == 'follow' ||
      normalizedType == 'like' ||
      normalizedType == 'comment' ||
      normalizedType == 'mention' ||
      normalizedType == 'collab_invite') {
    return false;
  }
  if ((chatId ?? '').trim().isNotEmpty) {
    return true;
  }
  if ((messageId ?? '').trim().isNotEmpty) {
    return true;
  }
  final String url = (actionUrl ?? '').toLowerCase();
  return url.contains('/messages/') ||
      url.contains('tab=messages') ||
      url.contains('chatid=');
}

DateTime? _dateFromDynamic(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    // Retention writers sometimes store epoch millis (not Timestamp).
    if (value > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
  }
  if (value is double) {
    return _dateFromDynamic(value.round());
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

DateTime readActivityTimestamp(Map<String, dynamic> data) {
  return _dateFromDynamic(data['timestamp']) ??
      _dateFromDynamic(data['createdAt']) ??
      DateTime.now();
}

/// Website Activity title/body for Tippy + planner notifications.
String activityNotificationDisplayMessage(Map<String, dynamic> data) {
  final String type = (data['type'] ?? '').toString();
  final String title = _firstNonEmpty(<Object?>[
    data['title'],
  ]);
  final String body = _firstNonEmpty(<Object?>[
    data['body'],
    data['message'],
    data['commentText'],
    data['messagePreview'],
  ]);
  if (isActivityMessageNotification(
    type: type,
    actionType: data['actionType']?.toString(),
    chatId: data['chatId']?.toString(),
    messageId: data['messageId']?.toString(),
    actionUrl: data['actionUrl']?.toString(),
  )) {
    // Keep preview only — row UI prefixes "sent you a message".
    return body;
  }
  if (isTippyCoachNotificationType(type) ||
      isContentPlanNotificationType(type) ||
      isGlobalSystemNotificationType(type)) {
    if (title.isNotEmpty && body.isNotEmpty && title != body) {
      return '$title\n$body';
    }
    if (title.isNotEmpty) {
      return title;
    }
    if (body.isNotEmpty) {
      return body;
    }
  }
  if (body.isNotEmpty) {
    return body;
  }
  return title;
}

String _firstNonEmpty(List<Object?> values) {
  for (final Object? value in values) {
    if (value == null) {
      continue;
    }
    final String text = value.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

bool activityActionUrlLooksLikeContentPlan(String? actionUrl) {
  final String url = (actionUrl ?? '').toLowerCase();
  return url.contains('content-planning') ||
      url.contains('content_planning') ||
      url.contains('contentplanner') ||
      url.contains('/planner');
}

bool activityActionUrlLooksLikeTrendDiscovery(String? actionUrl) {
  final String url = (actionUrl ?? '').toLowerCase();
  return url.contains('trending') ||
      url.contains('trend-discovery') ||
      url.contains('trend_discovery');
}

/// Resolve website Activity deep links (`/dashboard/trending`, etc.).
String resolveActivityWebsiteActionUrl(String? actionUrl) {
  final String raw = (actionUrl ?? '').trim();
  if (raw.isEmpty) {
    return siteApiPath('/dashboard/trending');
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }
  final String path = raw.startsWith('/') ? raw : '/$raw';
  return siteApiPath(path);
}

String tippyPromptFromActivityNotification({
  required String? titleAndBody,
  required String? actionUrl,
}) {
  final String text = (titleAndBody ?? '').trim();
  if (activityActionUrlLooksLikeTrendDiscovery(actionUrl)) {
    if (text.isEmpty) {
      return 'Help me act on the trend that matches my niche. '
          'Suggest a hook, caption, and posting plan.';
    }
    return 'A trend matches my niche:\n$text\n\n'
        'Help me turn this into a post — hook, caption, and next steps.';
  }
  if (text.isEmpty) {
    return 'Give me my next best creator move.';
  }
  return text;
}
