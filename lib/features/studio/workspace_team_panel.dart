import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/support_shell_style.dart';
import '../../routing/app_routes.dart';
import '../../widgets/optimized_avatar_image.dart';
import 'models/workspace_team_models.dart';
import 'workspace_team_service.dart';

/// Invite / seat management MVP for Creator Studio teams.
class WorkspaceTeamPanel extends StatefulWidget {
  const WorkspaceTeamPanel({
    super.key,
    required this.shell,
    this.initialWorkspaceId,
    this.onChanged,
  });

  final StSupportShellStyle shell;
  final String? initialWorkspaceId;
  final VoidCallback? onChanged;

  @override
  State<WorkspaceTeamPanel> createState() => _WorkspaceTeamPanelState();
}

class _WorkspaceTeamPanelState extends State<WorkspaceTeamPanel> {
  final WorkspaceTeamService _service = WorkspaceTeamService();
  final TextEditingController _queryController = TextEditingController();
  Timer? _searchDebounce;

  WorkspaceTeamSummary? _summary;
  List<WorkspaceInviteItem> _incoming = <WorkspaceInviteItem>[];
  List<WorkspaceInviteItem> _outgoing = <WorkspaceInviteItem>[];
  List<WorkspaceInviteCandidate> _candidates = <WorkspaceInviteCandidate>[];
  WorkspaceInviteCandidate? _selected;
  String _role = 'viewer';
  String? _workspaceId;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _workspaceId = widget.initialWorkspaceId;
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String workspaceId = (_workspaceId ?? '').trim();
      if (workspaceId.isEmpty) {
        final WorkspaceContextSnapshot ctx = await _service.fetchContext();
        workspaceId = ctx.workspaceId;
        _workspaceId = workspaceId;
      }
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        _service.fetchTeamSummary(workspaceId: workspaceId),
        _service.fetchIncomingInvites(),
        _service.fetchOutgoingInvites(workspaceId: workspaceId),
      ]);
      if (!mounted) {
        return;
      }
      final WorkspaceTeamSummary summary = results[0] as WorkspaceTeamSummary;
      final List<String> roles = summary.ownerIsStudio
          ? kStudioInvitableRoles
          : kProInvitableRoles;
      setState(() {
        _summary = summary;
        _incoming = results[1] as List<WorkspaceInviteItem>;
        _outgoing = results[2] as List<WorkspaceInviteItem>;
        if (!roles.contains(_role)) {
          _role = roles.first;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    final String trimmed = value.trim();
    if (trimmed.startsWith('@') ||
        (!trimmed.contains('@') && trimmed.length >= 2)) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        _runSearch(trimmed.replaceFirst(RegExp(r'^@'), ''));
      });
    } else {
      setState(() {
        _candidates = <WorkspaceInviteCandidate>[];
        _selected = null;
      });
    }
  }

  Future<void> _runSearch(String query) async {
    final String? workspaceId = _workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) {
      return;
    }
    setState(() => _searching = true);
    try {
      final List<WorkspaceInviteCandidate> found =
          await _service.searchCandidates(
        workspaceId: workspaceId,
        query: query,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = found;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = <WorkspaceInviteCandidate>[];
        _searching = false;
      });
    }
  }

  Future<void> _invite() async {
    final WorkspaceTeamSummary? summary = _summary;
    final String? workspaceId = _workspaceId;
    if (summary == null || workspaceId == null) {
      return;
    }
    if (summary.seatsFull) {
      _toast('Team is full — revoke an invite or remove a member.');
      return;
    }
    final String query = _queryController.text.trim();
    final String? email = _selected == null && query.contains('@')
        ? query
        : null;
    final String? targetUserId = _selected?.userId;
    if ((email == null || email.isEmpty) &&
        (targetUserId == null || targetUserId.isEmpty)) {
      _toast('Enter an email or pick a @username.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.inviteMember(
        workspaceId: workspaceId,
        role: _role,
        email: email,
        targetUserId: targetUserId,
      );
      _queryController.clear();
      _selected = null;
      _candidates = <WorkspaceInviteCandidate>[];
      await _load();
      widget.onChanged?.call();
      _toast('Invite sent.');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revoke(String inviteId) async {
    final String? workspaceId = _workspaceId;
    if (workspaceId == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.revokeInvite(
        workspaceId: workspaceId,
        inviteId: inviteId,
      );
      await _load();
      widget.onChanged?.call();
      _toast('Invite revoked.');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _accept(String inviteId) async {
    setState(() => _busy = true);
    try {
      final String? joined = await _service.acceptInvite(inviteId);
      if (joined != null && joined.isNotEmpty) {
        _workspaceId = joined;
      }
      await _load();
      widget.onChanged?.call();
      _toast('Joined workspace.');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _decline(String inviteId) async {
    setState(() => _busy = true);
    try {
      await _service.declineInvite(inviteId);
      await _load();
      widget.onChanged?.call();
      _toast('Invite declined.');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changeRole(WorkspaceTeamMember member, String role) async {
    final String? workspaceId = _workspaceId;
    if (workspaceId == null || role == member.role) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.changeMemberRole(
        workspaceId: workspaceId,
        memberId: member.userId,
        role: role,
      );
      await _load();
      widget.onChanged?.call();
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove(WorkspaceTeamMember member) async {
    final String? workspaceId = _workspaceId;
    if (workspaceId == null) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove teammate?'),
          content: Text(
            'Revoke ${member.displayLabel} from this workspace immediately.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.removeMember(
        workspaceId: workspaceId,
        memberId: member.userId,
      );
      await _load();
      widget.onChanged?.call();
      _toast('Member removed.');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = widget.shell;
    if (_loading && _summary == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _summary == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_error!, style: TextStyle(color: shell.mutedStrong)),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    final WorkspaceTeamSummary summary = _summary!;
    final List<String> roles = summary.ownerIsStudio
        ? kStudioInvitableRoles
        : kProInvitableRoles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_incoming.isNotEmpty) ...<Widget>[
          _sectionTitle(shell, 'Pending invites for you'),
          ..._incoming.map(
            (WorkspaceInviteItem invite) => _incomingTile(shell, invite),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          summary.hasTeamSeats
              ? 'Seats ${summary.occupiedSeats}/'
                  '${summary.teamMembersLimit}'
                  ' · ${summary.activeTeamCount} active'
                  '${summary.pendingInviteCount > 0 ? ', ${summary.pendingInviteCount} pending' : ''}'
              : 'Team seats require Creator Pro (3) or Studio (5).',
          style: TextStyle(color: shell.mutedStrong, fontSize: 13),
        ),
        if (!summary.hasTeamSeats && summary.canManageTeam) ...<Widget>[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.upgrade);
            },
            child: const Text('Upgrade to invite teammates'),
          ),
        ],
        if (summary.canManageTeam && summary.hasTeamSeats) ...<Widget>[
          const SizedBox(height: 14),
          _sectionTitle(shell, 'Invite a teammate'),
          if (summary.seatsFull)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Team is full — revoke an invite or remove a member.',
                style: TextStyle(color: shell.mutedStrong, fontSize: 13),
              ),
            ),
          TextField(
            controller: _queryController,
            enabled: !_busy && !summary.seatsFull,
            onChanged: _onQueryChanged,
            style: TextStyle(color: shell.onChrome),
            decoration: InputDecoration(
              hintText: 'Email or @username',
              hintStyle: TextStyle(color: shell.muted),
              filled: true,
              fillColor: shell.panelSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: shell.panelBorder),
              ),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          if (_candidates.isNotEmpty)
            ..._candidates.map(
              (WorkspaceInviteCandidate c) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: OptimizedAvatarImage(
                  imageUrl: c.avatarUrl,
                  size: 32,
                  displayName: c.label,
                ),
                title: Text(
                  c.label,
                  style: TextStyle(color: shell.onChrome),
                ),
                subtitle: c.username == null
                    ? null
                    : Text(
                        '@${c.username}',
                        style: TextStyle(color: shell.muted),
                      ),
                onTap: () {
                  setState(() {
                    _selected = c;
                    _queryController.text =
                        c.username != null ? '@${c.username}' : c.label;
                    _candidates = <WorkspaceInviteCandidate>[];
                  });
                },
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: roles.contains(_role) ? _role : roles.first,
                  dropdownColor: shell.surfaceCard,
                  style: TextStyle(color: shell.onChrome),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: shell.panelSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: roles
                      .map(
                        (String role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(workspaceRoleLabel(role)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _busy || summary.seatsFull
                      ? null
                      : (String? value) {
                          if (value != null) {
                            setState(() => _role = value);
                          }
                        },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy || summary.seatsFull ? null : _invite,
                child: Text(_busy ? '…' : 'Invite'),
              ),
            ],
          ),
        ],
        if (summary.canManageTeam && _outgoing.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _sectionTitle(shell, 'Pending invites'),
          ..._outgoing.map(
            (WorkspaceInviteItem invite) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                invite.inviteLabel.isNotEmpty
                    ? invite.inviteLabel
                    : invite.invitedEmail,
                style: TextStyle(color: shell.onChrome),
              ),
              subtitle: Text(
                '${workspaceRoleLabel(invite.role)} · Awaiting response',
                style: TextStyle(color: shell.muted),
              ),
              trailing: TextButton(
                onPressed: _busy ? null : () => _revoke(invite.id),
                child: const Text('Revoke'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _sectionTitle(shell, 'Workspace members'),
        if (summary.members.isEmpty)
          Text(
            'No members loaded.',
            style: TextStyle(color: shell.mutedStrong),
          )
        else
          ...summary.members.map(
            (WorkspaceTeamMember member) => _memberTile(
              shell,
              member,
              roles: roles,
              canManage: summary.canManageTeam,
            ),
          ),
      ],
    );
  }

  Widget _incomingTile(StSupportShellStyle shell, WorkspaceInviteItem invite) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shell.panelSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            invite.ownerLabel,
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Invited as ${workspaceRoleLabel(invite.role)}',
            style: TextStyle(color: shell.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: _busy ? null : () => _decline(invite.id),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : () => _accept(invite.id),
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memberTile(
    StSupportShellStyle shell,
    WorkspaceTeamMember member, {
    required List<String> roles,
    required bool canManage,
  }) {
    final bool isOwner = member.role == 'owner';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: OptimizedAvatarImage(
        imageUrl: member.avatarUrl,
        size: 36,
        displayName: member.displayLabel,
      ),
      title: Text(
        member.displayLabel,
        style: TextStyle(color: shell.onChrome),
      ),
      subtitle: Text(
        workspaceRoleLabel(member.role),
        style: TextStyle(color: shell.muted),
      ),
      trailing: !canManage || isOwner
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButton<String>(
                  value: roles.contains(member.role) ? member.role : null,
                  hint: Text(
                    workspaceRoleLabel(member.role),
                    style: TextStyle(color: shell.muted, fontSize: 12),
                  ),
                  dropdownColor: shell.surfaceCard,
                  underline: const SizedBox.shrink(),
                  items: roles
                      .map(
                        (String role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(
                            workspaceRoleLabel(role),
                            style: TextStyle(color: shell.onChrome),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _busy
                      ? null
                      : (String? role) {
                          if (role != null) {
                            _changeRole(member, role);
                          }
                        },
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: _busy ? null : () => _remove(member),
                  icon: Icon(Icons.person_remove_outlined, color: shell.muted),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(StSupportShellStyle shell, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: shell.onChrome,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
