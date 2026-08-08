import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../features/threads/thread_invite.dart';
import '../../models/user_model.dart' as user_model;
import '../../services/follows_service.dart';
import '../../services/search_api_service.dart';
import '../../services/thread_invite_service.dart';
import '../status_aware_avatar.dart';

class _InviteCandidate {
  const _InviteCandidate({
    required this.userId,
    required this.displayName,
    required this.username,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
}

/// Multi-select invite picker for invite-only threads (mirrors web ThreadInviteSheet).
class ThreadInviteSheet extends StatefulWidget {
  const ThreadInviteSheet({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.ownerId,
    required this.visibility,
  });

  final String postId;
  final String postTitle;
  final String ownerId;
  final String visibility;

  static Future<void> show(
    BuildContext context, {
    required String postId,
    required String postTitle,
    required String ownerId,
    required String visibility,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1322),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return ThreadInviteSheet(
          postId: postId,
          postTitle: postTitle,
          ownerId: ownerId,
          visibility: visibility,
        );
      },
    );
  }

  @override
  State<ThreadInviteSheet> createState() => _ThreadInviteSheetState();
}

class _ThreadInviteSheetState extends State<ThreadInviteSheet> {
  final ThreadInviteService _inviteService = ThreadInviteService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  final Map<String, String> _blockedIds = <String, String>{};
  List<_InviteCandidate> _candidates = const <_InviteCandidate>[];
  List<_InviteCandidate> _searchResults = const <_InviteCandidate>[];
  bool _loading = true;
  bool _sending = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final NetworkTabUsers tabs = await FollowsService().loadNetworkTabUsers();
      final List<ThreadInviteRecord> invites =
          await _inviteService.listThreadInvites(widget.postId);
      final Map<String, _InviteCandidate> byId = <String, _InviteCandidate>{};
      void addUsers(List<user_model.User> users) {
        for (final user_model.User u in users) {
          if (u.id.isEmpty || u.id == widget.ownerId) {
            continue;
          }
          byId.putIfAbsent(
            u.id,
            () => _InviteCandidate(
              userId: u.id,
              displayName:
                  u.displayName.isNotEmpty ? u.displayName : u.username,
              username: u.username,
              avatarUrl: u.avatarURL,
            ),
          );
        }
      }

      addUsers(tabs.connections);
      addUsers(tabs.following);
      addUsers(tabs.followers);
      final Map<String, String> blocked = <String, String>{
        widget.ownerId: 'Page owner',
      };
      for (final ThreadInviteRecord invite in invites) {
        if (invite.status == kThreadInviteStatusPending) {
          blocked[invite.invitedUserId] = 'Already invited';
        } else if (invite.status == kThreadInviteStatusAccepted) {
          blocked[invite.invitedUserId] = 'Already joined';
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = byId.values.toList(growable: false);
        _blockedIds
          ..clear()
          ..addAll(blocked);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _onSearchChanged(String raw) async {
    final String query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = const <_InviteCandidate>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final String lower = query.toLowerCase();
    final List<_InviteCandidate> local = _candidates
        .where(
          (_InviteCandidate c) =>
              c.displayName.toLowerCase().contains(lower) ||
              c.username.toLowerCase().contains(lower),
        )
        .toList(growable: false);
    try {
      final List<SearchResult> remote =
          await SearchApiService().searchUsers(query, limit: 20);
      final Map<String, _InviteCandidate> merged = <String, _InviteCandidate>{
        for (final _InviteCandidate c in local) c.userId: c,
      };
      for (final SearchResult r in remote) {
        final String userId = (r.userId ?? r.id).trim();
        if (userId.isEmpty || userId == widget.ownerId) {
          continue;
        }
        final String username = (r.username ?? '').trim();
        final String displayName = (r.displayName ?? '').trim();
        merged.putIfAbsent(
          userId,
          () => _InviteCandidate(
            userId: userId,
            displayName: displayName.isNotEmpty
                ? displayName
                : (username.isNotEmpty ? username : 'Creator'),
            username: username,
            avatarUrl: r.avatarUrl ?? r.imageURL,
          ),
        );
      }
      if (!mounted || _searchController.text.trim() != query) {
        return;
      }
      setState(() {
        _searchResults = merged.values.toList(growable: false);
        _searching = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = local;
        _searching = false;
      });
    }
  }

  void _toggle(String userId) {
    if (_blockedIds.containsKey(userId)) {
      return;
    }
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }

  Future<void> _send() async {
    if (_selectedIds.isEmpty || _sending) {
      return;
    }
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    setState(() => _sending = true);
    try {
      final result = await _inviteService.sendThreadInvites(
        postId: widget.postId,
        postTitle: widget.postTitle,
        ownerId: widget.ownerId,
        visibility: widget.visibility,
        invitedUserIds: _selectedIds.toList(growable: false),
        inviterDisplayName: user?.displayName ?? user?.email,
        inviterAvatarUrl: user?.photoURL,
      );
      if (!mounted) {
        return;
      }
      final String message = result.sent.isEmpty
          ? 'Selected users were already invited or ineligible.'
          : 'Sent ${result.sent.length} invite${result.sent.length == 1 ? '' : 's'}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if (result.sent.isNotEmpty) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_InviteCandidate> rows = _searchController.text.trim().isEmpty
        ? _candidates
        : _searchResults;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Invite creators',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Search StreamersTip users to invite',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (String value) {
                  _onSearchChanged(value);
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or @username',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF151A2B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      itemCount: rows.length,
                      itemBuilder: (BuildContext context, int index) {
                        final _InviteCandidate row = rows[index];
                        final String? blocked = _blockedIds[row.userId];
                        final bool selected = _selectedIds.contains(row.userId);
                        return ListTile(
                          enabled: blocked == null,
                          onTap: () => _toggle(row.userId),
                          leading: StatusAwareAvatar(
                            userId: row.userId,
                            avatarURL: row.avatarUrl,
                            radius: 20,
                            showOnlineIndicator: false,
                          ),
                          title: Text(
                            '${selected ? '✓ ' : ''}${row.displayName}',
                            style: TextStyle(
                              color: blocked == null
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            blocked ?? '@${row.username}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_searching)
              const LinearProgressIndicator(minHeight: 2),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _selectedIds.isEmpty || _sending
                          ? null
                          : _send,
                      child: Text(
                        _sending
                            ? 'Sending…'
                            : 'Send ${_selectedIds.length} invite${_selectedIds.length == 1 ? '' : 's'}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
