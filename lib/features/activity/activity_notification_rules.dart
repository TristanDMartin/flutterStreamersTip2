import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/backend/site_api_base.dart';

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
  'newevent',
  'new_event',
};

/// Website hides these from the Activity feed and unread badge.
bool shouldHideFromActivityFeed(String? type) {
  if (!kHideContentPlanExpiredInActivity) {
    return false;
  }
  final String normalized = (type ?? '').trim().toLowerCase();
  return normalized == 'content_plan_expired' ||
      normalized == 'contentplanexpired';
}

/// Website badge filters these types out of the unread count.
bool shouldHideFromActivityUnreadBadge(String? type) {
  return shouldHideFromActivityFeed(type);
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
  if (isTippyCoachNotificationType(type) ||
      isContentPlanNotificationType(type)) {
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
