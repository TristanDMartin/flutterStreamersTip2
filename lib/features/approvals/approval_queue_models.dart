class ApprovalQueueSnapshot {
  const ApprovalQueueSnapshot({
    required this.title,
    this.caption,
    this.thumbnailUrl,
    this.status,
    this.platforms = const <String>[],
    this.proposedScheduledAt,
  });

  final String title;
  final String? caption;
  final String? thumbnailUrl;
  final String? status;
  final List<String> platforms;
  final String? proposedScheduledAt;

  factory ApprovalQueueSnapshot.fromJson(Map<String, dynamic>? raw) {
    if (raw == null) {
      return const ApprovalQueueSnapshot(title: 'Untitled');
    }
    final Object? platformsRaw = raw['platforms'];
    final List<String> platforms = platformsRaw is List
        ? platformsRaw.map((Object? e) => e.toString()).toList(growable: false)
        : const <String>[];
    return ApprovalQueueSnapshot(
      title: _str(raw['title'], 'Untitled'),
      caption: _nullableStr(raw['caption']),
      thumbnailUrl: _nullableStr(raw['thumbnailUrl']),
      status: _nullableStr(raw['status']),
      platforms: platforms,
      proposedScheduledAt: _nullableStr(raw['proposedScheduledAt']),
    );
  }
}

class ApprovalQueueRequest {
  const ApprovalQueueRequest({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.status,
    required this.contentVersionId,
    required this.targetType,
    required this.targetId,
    required this.snapshot,
    this.priority,
    this.deadlineAt,
    this.videoId,
    this.contentItemId,
    this.planId,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String status;
  final String contentVersionId;
  final String targetType;
  final String targetId;
  final ApprovalQueueSnapshot snapshot;
  final String? priority;
  final String? deadlineAt;
  final String? videoId;
  final String? contentItemId;
  final String? planId;

  bool get isPending =>
      status == 'pending_approval' || status == 'partially_approved';

  factory ApprovalQueueRequest.fromJson(Map<String, dynamic> raw) {
    final Map<String, dynamic>? snap = raw['snapshot'] is Map<String, dynamic>
        ? raw['snapshot'] as Map<String, dynamic>
        : raw['snapshot'] is Map
            ? Map<String, dynamic>.from(raw['snapshot'] as Map)
            : null;
    return ApprovalQueueRequest(
      id: _str(raw['id'], ''),
      workspaceId: _str(raw['workspaceId'], ''),
      title: _str(raw['title'], 'Pending approval'),
      status: _str(raw['status'], 'pending_approval'),
      contentVersionId: _str(raw['contentVersionId'], ''),
      targetType: _str(raw['targetType'], 'content_item'),
      targetId: _str(raw['targetId'], ''),
      snapshot: ApprovalQueueSnapshot.fromJson(snap),
      priority: _nullableStr(raw['priority']),
      deadlineAt: _nullableStr(raw['deadlineAt']),
      videoId: _nullableStr(raw['videoId']),
      contentItemId: _nullableStr(raw['contentItemId']),
      planId: _nullableStr(raw['planId']),
    );
  }
}

class ApprovalDecideResult {
  const ApprovalDecideResult({
    required this.requestId,
    required this.status,
    required this.remainingApprovals,
  });

  final String requestId;
  final String status;
  final int remainingApprovals;

  factory ApprovalDecideResult.fromJson(Map<String, dynamic> raw) {
    final Map<String, dynamic> request = raw['request'] is Map<String, dynamic>
        ? raw['request'] as Map<String, dynamic>
        : <String, dynamic>{};
    return ApprovalDecideResult(
      requestId: _str(request['id'], ''),
      status: _str(request['status'], ''),
      remainingApprovals: raw['remainingApprovals'] is num
          ? (raw['remainingApprovals'] as num).round()
          : 0,
    );
  }
}

String _str(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

String? _nullableStr(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
