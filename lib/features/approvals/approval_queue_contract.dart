/// Flutter Approval Queue contract — mirror
/// `streamerstipReact/types/flutterApprovalQueue.ts`.
library;

const List<String> kApprovalDecideActions = <String>[
  'approved',
  'changes_requested',
  'rejected',
  'deny_schedule',
];

const List<({String value, String label})> kApprovalReasonChoices =
    <({String value, String label})>[
  (value: 'video_edit_needed', label: 'Video edit needed'),
  (value: 'caption_needs_changes', label: 'Caption needs changes'),
  (value: 'wrong_thumbnail', label: 'Wrong thumbnail'),
  (value: 'schedule_needs_changes', label: 'Schedule needs changes'),
  (value: 'missing_disclosure', label: 'Missing disclosure'),
  (value: 'incorrect_platform', label: 'Incorrect platform'),
  (value: 'brand_requirements_missing', label: 'Brand requirements missing'),
  (value: 'other', label: 'Other'),
];

/// Parse approval request id from Activity / web deep links.
String? parseApprovalRequestIdFromDeepLink({
  String? actionUrl,
  String? actionType,
  String? commentText,
}) {
  final List<String> candidates = <String>[
    if (actionUrl != null) actionUrl,
    if (actionType != null) actionType,
    if (commentText != null) commentText,
  ];
  for (final String raw in candidates) {
    final String text = raw.trim();
    if (text.isEmpty) {
      continue;
    }
    final RegExpMatch? query = RegExp(
      r'[?&#]approval=([^&#]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (query != null) {
      final String id = Uri.decodeComponent(query.group(1) ?? '').trim();
      if (id.isNotEmpty) {
        return id;
      }
    }
    final RegExpMatch? path = RegExp(
      r'(?:approval-review|approvals)/([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (path != null) {
      final String id = path.group(1)?.trim() ?? '';
      if (id.isNotEmpty) {
        return id;
      }
    }
  }
  return null;
}

/// Parse workspace id from Activity / web deep links.
String? parseWorkspaceIdFromDeepLink({
  String? actionUrl,
  String? actionType,
}) {
  final List<String> candidates = <String>[
    if (actionUrl != null) actionUrl,
    if (actionType != null) actionType,
  ];
  for (final String raw in candidates) {
    final String text = raw.trim();
    if (text.isEmpty) {
      continue;
    }
    final RegExpMatch? query = RegExp(
      r'[?&#]workspaceId=([^&#]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (query != null) {
      final String id = Uri.decodeComponent(query.group(1) ?? '').trim();
      if (id.isNotEmpty) {
        return id;
      }
    }
  }
  return null;
}

bool looksLikeApprovalNotification({
  String? actionUrl,
  String? actionType,
  String? typeName,
}) {
  final String blob =
      '${actionUrl ?? ''} ${actionType ?? ''} ${typeName ?? ''}'.toLowerCase();
  return blob.contains('approval') ||
      blob.contains('ready_for_review') ||
      blob.contains('pending_approval');
}
