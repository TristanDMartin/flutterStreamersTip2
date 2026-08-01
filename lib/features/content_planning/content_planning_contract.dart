/// Content Planning Contract v1 — keep in sync with
/// `streamerstipReact/contracts/content-planning.v1.json` and
/// `types/contentPlanningContract.ts`.
/// Local copy: `contracts/content-planning.v1.json`.
library;

const String kContentPlanningContractVersion = '1.0.0';

const List<String> kContentItemStatuses = <String>[
  'idea',
  'draft',
  'in_progress',
  'ready_for_review',
  'changes_requested',
  'approved',
  'scheduled',
  'publishing',
  'published',
  'missed',
  'failed',
  'archived',
  'cancelled',
];

const Map<String, String> kContentItemStatusLabels = <String, String>{
  'idea': 'Idea',
  'draft': 'Draft',
  'in_progress': 'In Progress',
  'ready_for_review': 'Ready for Review',
  'changes_requested': 'Changes Requested',
  'approved': 'Approved',
  'scheduled': 'Scheduled',
  'publishing': 'Publishing',
  'published': 'Published',
  'missed': 'Missed',
  'failed': 'Failed',
  'archived': 'Archived',
  'cancelled': 'Cancelled',
};

const Map<String, String> _legacyStatusAliases = <String, String>{
  'planned': 'draft',
  'todo': 'draft',
  'pending': 'draft',
  'recording': 'in_progress',
  'editing': 'in_progress',
  'needsreview': 'ready_for_review',
  'needs_review': 'ready_for_review',
  'posted': 'published',
  'completed': 'published',
  'done': 'published',
  'repurpose': 'archived',
  'canceled': 'cancelled',
};

String normalizeContentItemStatus(Object? raw) {
  final String key = (raw?.toString() ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_');
  if (key.isEmpty) {
    return 'draft';
  }
  if (kContentItemStatuses.contains(key)) {
    return key;
  }
  return _legacyStatusAliases[key] ?? 'draft';
}

String contentItemStatusLabel(Object? status) {
  final String normalized = normalizeContentItemStatus(status);
  return kContentItemStatusLabels[normalized] ?? 'Draft';
}

const List<String> kContentTypes = <String>[
  'stream',
  'clip',
  'video',
  'short',
  'story',
  'post',
  'collab',
  'image',
  'carousel',
  'thread',
  'other',
];

const Map<String, String> _legacyTypeAliases = <String, String>{
  'livestream': 'stream',
  'live': 'stream',
  'vod': 'video',
};

String normalizeContentItemType(Object? raw) {
  final String key = (raw?.toString() ?? '').trim().toLowerCase();
  if (key.isEmpty) {
    return 'post';
  }
  if (kContentTypes.contains(key)) {
    return key;
  }
  return _legacyTypeAliases[key] ?? 'other';
}

const List<String> kContentVisibilities = <String>[
  'private',
  'team',
  'public',
];

const List<String> kProfileCalendarVisibilities = <String>[
  'public',
  'private',
  'hidden',
];

const List<String> kStreamerCalendarVisibilities = <String>[
  'public',
  'private',
  'hidden',
  'off',
];

String normalizeProfileCalendarVisibility(Object? raw) {
  final String key = (raw?.toString() ?? '').trim().toLowerCase();
  if (key == 'public' || key == 'private' || key == 'hidden') {
    return key;
  }
  return 'public';
}

/// Map stored profileCalendar + streamerCalendar → contract visibility.
String visibilityFromProfileFields({
  Object? profileCalendar,
  Object? streamerCalendar,
}) {
  final String profile = normalizeProfileCalendarVisibility(profileCalendar);
  if (profile == 'public') {
    return 'public';
  }
  if (profile == 'hidden') {
    return 'private';
  }
  final String? streamer = streamerCalendar?.toString().trim().toLowerCase();
  if (streamer == null ||
      streamer.isEmpty ||
      streamer == 'off' ||
      streamer == 'hidden') {
    return 'team';
  }
  return 'private';
}

/// Map contract visibility → profileCalendar + streamerCalendar storage.
({String profileCalendar, String? streamerCalendar})
    profileFieldsFromVisibility(String visibility) {
  final String key = visibility.trim().toLowerCase();
  if (key == 'public') {
    return (profileCalendar: 'public', streamerCalendar: null);
  }
  if (key == 'team') {
    return (profileCalendar: 'private', streamerCalendar: 'off');
  }
  return (profileCalendar: 'private', streamerCalendar: 'off');
}

const List<String> kContentSources = <String>[
  'web',
  'flutter',
  'tippy',
  'team',
  'import',
  'system',
];

const Map<String, String> _legacySourceAliases = <String, String>{
  'app': 'flutter',
  'tippy_ai': 'tippy',
  'mobile': 'flutter',
};

String? normalizeContentSource(Object? raw) {
  final String key = (raw?.toString() ?? '').trim().toLowerCase();
  if (key.isEmpty) {
    return null;
  }
  if (kContentSources.contains(key)) {
    return key;
  }
  return _legacySourceAliases[key];
}

const List<String> kContentPlatforms = <String>[
  'streamerstip',
  'twitch',
  'youtube',
  'kick',
  'tiktok',
  'instagram',
  'twitter',
  'linkedin',
  'facebook',
  'custom',
];

const List<String> kRequiredContentItemFields = <String>[
  'id',
  'title',
  'type',
  'status',
  'platforms',
  'createdAt',
  'updatedAt',
];

bool isClosedContentItemStatus(Object? status) {
  final String normalized = normalizeContentItemStatus(status);
  return normalized == 'published' ||
      normalized == 'archived' ||
      normalized == 'cancelled' ||
      normalized == 'failed' ||
      normalized == 'missed';
}

bool isQueuedScheduleStatus(Object? status) {
  final String normalized = normalizeContentItemStatus(status);
  if (isClosedContentItemStatus(normalized)) {
    return false;
  }
  return normalized == 'scheduled' ||
      normalized == 'publishing' ||
      normalized == 'draft' ||
      normalized == 'idea' ||
      normalized == 'in_progress' ||
      normalized == 'ready_for_review' ||
      normalized == 'approved' ||
      normalized == 'changes_requested';
}

/// Status choices for Flutter pickers (canonical only — never write legacy).
const List<({String value, String label})> kContentItemStatusChoices =
    <({String value, String label})>[
  (value: 'idea', label: 'Idea'),
  (value: 'draft', label: 'Draft'),
  (value: 'in_progress', label: 'In Progress'),
  (value: 'ready_for_review', label: 'Ready for Review'),
  (value: 'changes_requested', label: 'Changes Requested'),
  (value: 'approved', label: 'Approved'),
  (value: 'scheduled', label: 'Scheduled'),
  (value: 'publishing', label: 'Publishing'),
  (value: 'published', label: 'Published'),
  (value: 'missed', label: 'Missed'),
  (value: 'failed', label: 'Failed'),
  (value: 'archived', label: 'Archived'),
  (value: 'cancelled', label: 'Cancelled'),
];

/// Phase 3 stable ids linking scheduled_posts ↔ contentItems ↔ publishJobs.
String contentItemIdForScheduledPost(String scheduledPostId) =>
    'sp_$scheduledPostId';

String publishJobIdForScheduledPost(String scheduledPostId) =>
    'pj_$scheduledPostId';

String publishIdempotencyKey(String ownerUserId, String scheduledPostId) =>
    'publish:$ownerUserId:$scheduledPostId';

/// Cutover PR2: personal workspace id equals owner uid.
String personalWorkspaceId(String ownerUserId) => ownerUserId.trim();

/// Map publishJobs.status → Flutter PostStatus name (canceled spelling).
String mapPublishJobStatusToPostStatusName(Object? raw) {
  final String key = (raw?.toString() ?? '').trim().toLowerCase();
  if (key == 'cancelled' || key == 'canceled') {
    return 'canceled';
  }
  if (key == 'pending' || key == 'draft') {
    return 'draft';
  }
  if (key == 'publishing') {
    return 'publishing';
  }
  if (key == 'published' || key == 'posted') {
    return 'published';
  }
  if (key == 'failed') {
    return 'failed';
  }
  return 'scheduled';
}

DateTime? parsePublishJobDate(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is DateTime) {
    return raw.toUtc();
  }
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }
  if (raw is Map) {
    final Object? seconds = raw['seconds'] ?? raw['_seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        seconds.toInt() * 1000,
        isUtc: true,
      );
    }
  }
  final String text = raw.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toUtc();
}
