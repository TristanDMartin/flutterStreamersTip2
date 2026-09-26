// Canonical workspace team / invite shapes shared with web
// (`/api/workspace/members`, `/api/workspace/invites`).
class WorkspaceTeamMember {
  const WorkspaceTeamMember({
    required this.userId,
    required this.role,
    required this.displayLabel,
    this.displayName,
    this.username,
    this.email,
    this.avatarUrl,
  });

  final String userId;
  final String role;
  final String displayLabel;
  final String? displayName;
  final String? username;
  final String? email;
  final String? avatarUrl;

  factory WorkspaceTeamMember.fromJson(Map<String, dynamic> raw) {
    final String displayName = _str(raw['displayName'], '');
    final String username = _str(raw['username'], '');
    final String email = _str(raw['email'], '');
    final String label = _str(raw['displayLabel'], '');
    final String resolved = label.isNotEmpty
        ? label
        : (displayName.isNotEmpty
            ? displayName
            : (username.isNotEmpty
                ? '@$username'
                : (email.isNotEmpty ? email : 'Member')));
    return WorkspaceTeamMember(
      userId: _str(raw['userId'], ''),
      role: _str(raw['role'], 'viewer'),
      displayLabel: resolved,
      displayName: displayName.isEmpty ? null : displayName,
      username: username.isEmpty ? null : username,
      email: email.isEmpty ? null : email,
      avatarUrl: raw['avatarUrl'] is String ? raw['avatarUrl'] as String : null,
    );
  }
}

class WorkspaceInviteItem {
  const WorkspaceInviteItem({
    required this.id,
    required this.workspaceId,
    required this.ownerUserId,
    required this.ownerLabel,
    required this.invitedEmail,
    required this.inviteLabel,
    required this.role,
    required this.status,
    this.invitedUserId,
    this.expiresAt,
  });

  final String id;
  final String workspaceId;
  final String ownerUserId;
  final String ownerLabel;
  final String invitedEmail;
  final String inviteLabel;
  final String role;
  final String status;
  final String? invitedUserId;
  final String? expiresAt;

  factory WorkspaceInviteItem.fromJson(Map<String, dynamic> raw) {
    final String invitedEmail = _str(raw['invitedEmail'], '');
    return WorkspaceInviteItem(
      id: _str(raw['id'], ''),
      workspaceId: _str(raw['workspaceId'], ''),
      ownerUserId: _str(raw['ownerUserId'], ''),
      ownerLabel: _str(raw['ownerLabel'], 'Creator'),
      invitedEmail: invitedEmail,
      inviteLabel: _str(raw['inviteLabel'], invitedEmail),
      role: _str(raw['role'], 'viewer'),
      status: _str(raw['status'], 'pending'),
      invitedUserId:
          raw['invitedUserId'] is String ? raw['invitedUserId'] as String : null,
      expiresAt: raw['expiresAt'] is String ? raw['expiresAt'] as String : null,
    );
  }
}

class WorkspaceInviteCandidate {
  const WorkspaceInviteCandidate({
    required this.userId,
    required this.label,
    this.username,
    this.avatarUrl,
  });

  final String userId;
  final String label;
  final String? username;
  final String? avatarUrl;

  factory WorkspaceInviteCandidate.fromJson(Map<String, dynamic> raw) {
    final String username = _str(raw['username'], '');
    final String displayName = _str(raw['displayName'], '');
    final String label = displayName.isNotEmpty
        ? displayName
        : (username.isNotEmpty ? '@$username' : _str(raw['email'], 'User'));
    return WorkspaceInviteCandidate(
      userId: _str(raw['userId'], ''),
      label: label,
      username: username.isEmpty ? null : username,
      avatarUrl: raw['avatarUrl'] is String ? raw['avatarUrl'] as String : null,
    );
  }
}

class WorkspaceTeamSummary {
  const WorkspaceTeamSummary({
    required this.workspaceId,
    required this.ownerUserId,
    required this.actorRole,
    required this.members,
    required this.activeTeamCount,
    required this.pendingInviteCount,
    required this.occupiedSeats,
    required this.teamMembersLimit,
    required this.canInvite,
    required this.ownerIsStudio,
  });

  final String workspaceId;
  final String ownerUserId;
  final String actorRole;
  final List<WorkspaceTeamMember> members;
  final int activeTeamCount;
  final int pendingInviteCount;
  final int occupiedSeats;
  final int teamMembersLimit;
  final bool canInvite;
  final bool ownerIsStudio;

  bool get canManageTeam =>
      actorRole == 'owner' || actorRole == 'admin';

  bool get hasTeamSeats => teamMembersLimit > 0;

  bool get seatsFull =>
      hasTeamSeats && occupiedSeats >= teamMembersLimit;

  factory WorkspaceTeamSummary.fromJson(Map<String, dynamic> raw) {
    final Object? sub = raw['ownerSubscription'];
    final bool isStudio = sub is Map && sub['isStudio'] == true;
    return WorkspaceTeamSummary(
      workspaceId: _str(raw['workspaceId'], ''),
      ownerUserId: _str(raw['ownerUserId'], ''),
      actorRole: _str(raw['actorRole'], 'viewer'),
      members: _mapList(raw['members'], WorkspaceTeamMember.fromJson),
      activeTeamCount: _int(raw['activeTeamCount'], 0),
      pendingInviteCount: _int(raw['pendingInviteCount'], 0),
      occupiedSeats: _int(raw['occupiedSeats'], 0),
      teamMembersLimit: _int(raw['teamMembersLimit'], 0),
      canInvite: raw['canInvite'] == true,
      ownerIsStudio: isStudio,
    );
  }
}

class WorkspaceContextSnapshot {
  const WorkspaceContextSnapshot({
    required this.workspaceId,
    required this.ownerUserId,
    required this.actorRole,
    required this.isPersonalWorkspace,
  });

  final String workspaceId;
  final String ownerUserId;
  final String actorRole;
  final bool isPersonalWorkspace;

  factory WorkspaceContextSnapshot.fromJson(Map<String, dynamic> raw) {
    final Object? active = raw['active'];
    final Map<String, dynamic> map = active is Map
        ? Map<String, dynamic>.from(active)
        : raw;
    return WorkspaceContextSnapshot(
      workspaceId: _str(map['workspaceId'], ''),
      ownerUserId: _str(map['ownerUserId'], ''),
      actorRole: _str(map['actorRole'], 'viewer'),
      isPersonalWorkspace: map['isPersonalWorkspace'] == true,
    );
  }
}

const Map<String, String> kWorkspaceRoleLabels = <String, String>{
  'owner': 'Workspace Owner',
  'admin': 'Admin',
  'content_manager': 'Content Manager',
  'social_manager': 'Social Media Manager',
  'editor': 'Editor',
  'designer': 'Designer',
  'analyst': 'Analyst',
  'viewer': 'Viewer',
  'client': 'Client',
};

const List<String> kProInvitableRoles = <String>[
  'content_manager',
  'editor',
  'analyst',
  'viewer',
];

const List<String> kStudioInvitableRoles = <String>[
  'content_manager',
  'social_manager',
  'editor',
  'designer',
  'analyst',
  'viewer',
  'client',
];

String workspaceRoleLabel(String role) =>
    kWorkspaceRoleLabels[role] ?? role.replaceAll('_', ' ');

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
