class StudioTeamMemberSummary {
  const StudioTeamMemberSummary({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String role;

  factory StudioTeamMemberSummary.fromJson(Map<String, dynamic> raw) {
    return StudioTeamMemberSummary(
      userId: _str(raw['userId'], ''),
      displayName: _str(raw['displayName'], 'Member'),
      role: _str(raw['role'], 'viewer'),
    );
  }
}

class StudioAssignmentItem {
  const StudioAssignmentItem({
    required this.id,
    required this.title,
    required this.status,
    required this.assigneeDisplayName,
  });

  final String id;
  final String title;
  final String status;
  final String? assigneeDisplayName;

  factory StudioAssignmentItem.fromJson(Map<String, dynamic> raw) {
    return StudioAssignmentItem(
      id: _str(raw['id'], ''),
      title: _str(raw['title'], 'Task'),
      status: _str(raw['status'], 'open'),
      assigneeDisplayName: raw['assigneeDisplayName'] is String
          ? raw['assigneeDisplayName'] as String
          : null,
    );
  }
}

class StudioApprovalItem {
  const StudioApprovalItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.href,
    this.status = 'pending_approval',
    this.source = 'approval_request',
    this.contentVersionId,
    this.priority,
    this.targetId,
    this.targetType,
    this.createdAt,
  });

  final String id;
  final String title;
  final String kind;
  final String href;
  final String status;
  final String source;
  final String? contentVersionId;
  final String? priority;
  final String? targetId;
  final String? targetType;
  final String? createdAt;

  bool get canOpenReview =>
      source == 'approval_request' ||
      (contentVersionId != null && contentVersionId!.isNotEmpty);

  factory StudioApprovalItem.fromJson(Map<String, dynamic> raw) {
    return StudioApprovalItem(
      id: _str(raw['id'], ''),
      title: _str(raw['title'], 'Pending approval'),
      kind: _str(raw['kind'], 'agent_plan'),
      href: _str(raw['href'], '/tippy'),
      status: _str(raw['status'], 'pending_approval'),
      source: _str(raw['source'], 'approval_request'),
      contentVersionId: raw['contentVersionId'] is String
          ? raw['contentVersionId'] as String
          : null,
      priority: raw['priority'] is String ? raw['priority'] as String : null,
      targetId: raw['targetId'] is String ? raw['targetId'] as String : null,
      targetType:
          raw['targetType'] is String ? raw['targetType'] as String : null,
      createdAt: raw['createdAt'] is String ? raw['createdAt'] as String : null,
    );
  }
}

class StudioTeamPreview {
  const StudioTeamPreview({
    required this.feature,
    required this.title,
    required this.teaser,
    required this.upgradeLabel,
  });

  final String feature;
  final String title;
  final String teaser;
  final String upgradeLabel;

  factory StudioTeamPreview.fromJson(Map<String, dynamic> raw) {
    return StudioTeamPreview(
      feature: _str(raw['feature'], 'teams'),
      title: _str(raw['title'], 'Studio feature'),
      teaser: _str(raw['teaser'], ''),
      upgradeLabel: _str(raw['upgradeLabel'], 'Unlock with Creator Studio'),
    );
  }
}

class StudioTeamControl {
  const StudioTeamControl({
    required this.entitled,
    required this.activeCount,
    required this.limit,
    required this.members,
    required this.assignments,
    required this.approvals,
    required this.myApprovals,
    required this.automationSummary,
    required this.automationActive,
    required this.exportEntitled,
    required this.exportSummary,
    required this.campaignNextFocus,
    required this.campaignNotes,
    required this.openAssignments,
    required this.pendingApprovals,
    required this.postsPublishedThisWeek,
    required this.targetPostsPerWeek,
    required this.previews,
    this.workspaceId,
  });

  final bool entitled;
  final String? workspaceId;
  final int activeCount;
  final int limit;
  final List<StudioTeamMemberSummary> members;
  final List<StudioAssignmentItem> assignments;
  final List<StudioApprovalItem> approvals;
  final List<StudioApprovalItem> myApprovals;
  final String automationSummary;
  final bool automationActive;
  final bool exportEntitled;
  final String exportSummary;
  final String campaignNextFocus;
  final List<String> campaignNotes;
  final int openAssignments;
  final int pendingApprovals;
  final int postsPublishedThisWeek;
  final int? targetPostsPerWeek;
  final List<StudioTeamPreview> previews;

  /// Prefer actor inbox; fall back to workspace approvals list.
  List<StudioApprovalItem> get reviewQueue {
    if (myApprovals.isNotEmpty) {
      return myApprovals;
    }
    return approvals;
  }

  factory StudioTeamControl.fromJson(Map<String, dynamic> raw) {
    final Map<String, dynamic> team =
        raw['team'] is Map<String, dynamic>
            ? raw['team'] as Map<String, dynamic>
            : <String, dynamic>{};
    final Map<String, dynamic> automation =
        raw['automation'] is Map<String, dynamic>
            ? raw['automation'] as Map<String, dynamic>
            : <String, dynamic>{};
    final Map<String, dynamic> exports =
        raw['exports'] is Map<String, dynamic>
            ? raw['exports'] as Map<String, dynamic>
            : <String, dynamic>{};
    final Map<String, dynamic> campaign =
        raw['campaign'] is Map<String, dynamic>
            ? raw['campaign'] as Map<String, dynamic>
            : <String, dynamic>{};
    final List<StudioApprovalItem> approvals =
        _mapList(raw['approvals'], StudioApprovalItem.fromJson);
    final List<StudioApprovalItem> myApprovals =
        _mapList(raw['myApprovals'], StudioApprovalItem.fromJson);

    return StudioTeamControl(
      entitled: raw['entitled'] == true,
      workspaceId: raw['workspaceId'] is String
          ? raw['workspaceId'] as String
          : null,
      activeCount: _int(team['activeCount'], 0),
      limit: _int(team['limit'], 0),
      members: _mapList(team['members'], StudioTeamMemberSummary.fromJson),
      assignments: _mapList(raw['assignments'], StudioAssignmentItem.fromJson),
      approvals: approvals,
      myApprovals: myApprovals,
      automationSummary: _str(
        automation['summary'],
        'Automation status unavailable.',
      ),
      automationActive: automation['active'] == true,
      exportEntitled: exports['entitled'] == true,
      exportSummary: _str(exports['summary'], ''),
      campaignNextFocus: _str(campaign['nextFocus'], ''),
      campaignNotes: _stringList(campaign['notes']),
      openAssignments: _int(campaign['openAssignments'], 0),
      pendingApprovals: _int(campaign['pendingApprovals'], 0),
      postsPublishedThisWeek: _int(campaign['postsPublishedThisWeek'], 0),
      targetPostsPerWeek: campaign['targetPostsPerWeek'] is num
          ? (campaign['targetPostsPerWeek'] as num).round()
          : null,
      previews: _mapList(raw['previews'], StudioTeamPreview.fromJson),
    );
  }
}

class StudioTeamControlResponse {
  const StudioTeamControlResponse({required this.control});

  final StudioTeamControl control;

  factory StudioTeamControlResponse.fromJson(Map<String, dynamic> raw) {
    final Map<String, dynamic> control =
        raw['control'] is Map<String, dynamic>
            ? raw['control'] as Map<String, dynamic>
            : raw;
    return StudioTeamControlResponse(
      control: StudioTeamControl.fromJson(control),
    );
  }
}

int _int(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return fallback;
}

String _str(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

List<T> _mapList<T>(
  Object? value,
  T Function(Map<String, dynamic> raw) map,
) {
  if (value is! List) {
    return <T>[];
  }
  final List<T> out = <T>[];
  for (final Object? item in value) {
    if (item is Map<String, dynamic>) {
      out.add(map(item));
    } else if (item is Map) {
      out.add(map(Map<String, dynamic>.from(item)));
    }
  }
  return out;
}
