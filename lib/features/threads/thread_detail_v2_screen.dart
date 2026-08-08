import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../models/forum_author.dart';
import '../../services/discussion_author_service.dart';
import '../../services/thread_invite_service.dart';
import '../../utils/avatar_url_resolver.dart';
import '../../widgets/status_aware_avatar.dart';
import '../../widgets/threads/related_video_card.dart';
import '../../widgets/threads/thread_invite_sheet.dart';
import 'conversation_pulse_card.dart';
import 'related_video.dart';
import 'thread_invite.dart';
import 'thread_visibility.dart';
import 'thread_workspace_header.dart';
import 'threads_contract.dart';
import 'threads_models.dart';
import 'threads_repository.dart';


/// Threads v2 detail — header, nested replies, typed reactions, resolve.
class ThreadDetailV2Screen extends StatefulWidget {
  const ThreadDetailV2Screen({
    super.key,
    required this.threadId,
    required this.repository,
    this.initialThread,
  });

  final String threadId;
  final ThreadsRepository repository;
  final ThreadDto? initialThread;

  @override
  State<ThreadDetailV2Screen> createState() => _ThreadDetailV2ScreenState();
}

class _ThreadDetailV2ScreenState extends State<ThreadDetailV2Screen> {
  ThreadDto? _thread;
  List<ThreadReplyDto> _replies = const <ThreadReplyDto>[];
  Map<String, int> _threadReactionCounts = const <String, int>{};
  Set<String> _myThreadReactions = const <String>{};
  Map<String, Map<String, int>> _replyReactionCounts =
      const <String, Map<String, int>>{};
  Map<String, Set<String>> _myReplyReactions =
      const <String, Set<String>>{};
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isFollowing = false;
  bool _isSaved = false;
  String? _myInviteStatus;
  bool _respondingInvite = false;
  final ThreadInviteService _inviteService = ThreadInviteService();
  String? _errorMessage;
  String? _selectedReplyId;
  String? _replyingToReplyId;
  String? _replyingToUsername;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _thread = widget.initialThread;
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final ThreadDto? thread =
          await widget.repository.getThread(widget.threadId);
      final List<ThreadReplyDto> replies =
          await widget.repository.listReplies(threadId: widget.threadId);
      final List<ThreadReactionDto> reactions =
          await widget.repository.listReactions(threadId: widget.threadId);
      final String? uid =
          firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && thread != null) {
        await widget.repository.markViewed(
          threadId: widget.threadId,
          userId: uid,
        );
      }
      if (!mounted) {
        return;
      }
      final _ReactionProjection projected = _projectReactions(
        reactions: reactions,
        thread: thread,
        uid: uid,
      );
      String? inviteStatus;
      if (uid != null &&
          thread != null &&
          normalizeThreadVisibility(thread.visibility) ==
              kThreadVisibilityInviteOnly) {
        final ThreadInviteRecord? invite =
            await _inviteService.getThreadInvite(widget.threadId, uid);
        inviteStatus = invite?.status;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _thread = thread;
        _replies = replies;
        _threadReactionCounts = projected.threadCounts;
        _myThreadReactions = projected.myThread;
        _replyReactionCounts = projected.replyCounts;
        _myReplyReactions = projected.myReply;
        _isFollowing = thread?.legacyFollowedBy.contains(uid ?? '') ?? false;
        _isSaved = thread?.legacyBookmarkedBy.contains(uid ?? '') ?? false;
        _myInviteStatus = inviteStatus;
        _isLoading = false;
        if (thread == null) {
          _errorMessage =
              'This thread is unavailable, or it is invite-only and you do not have access.';
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  _ReactionProjection _projectReactions({
    required List<ThreadReactionDto> reactions,
    required ThreadDto? thread,
    required String? uid,
  }) {
    final Map<String, int> threadCounts = <String, int>{};
    final Set<String> myThread = <String>{};
    final Map<String, Map<String, int>> replyCounts =
        <String, Map<String, int>>{};
    final Map<String, Set<String>> myReply = <String, Set<String>>{};
    for (final ThreadReactionDto row in reactions) {
      final String type = row.reactionType;
      if (type.isEmpty) {
        continue;
      }
      if (row.targetType == 'reply') {
        final Map<String, int> counts =
            replyCounts.putIfAbsent(row.targetId, () => <String, int>{});
        counts[type] = (counts[type] ?? 0) + 1;
        if (uid != null && row.userId == uid) {
          myReply.putIfAbsent(row.targetId, () => <String>{}).add(type);
        }
      } else {
        threadCounts[type] = (threadCounts[type] ?? 0) + 1;
        if (uid != null && row.userId == uid) {
          myThread.add(type);
        }
      }
    }
    final int helpfulFromLikes = thread?.helpfulCount ?? 0;
    if (helpfulFromLikes > (threadCounts['helpful'] ?? 0)) {
      threadCounts['helpful'] = helpfulFromLikes;
    }
    if (uid != null && (thread?.legacyLikedBy.contains(uid) ?? false)) {
      myThread.add('helpful');
    }
    return _ReactionProjection(
      threadCounts: threadCounts,
      myThread: myThread,
      replyCounts: replyCounts,
      myReply: myReply,
    );
  }

  void _startReplyTo(ThreadReplyDto reply, String username) {
    setState(() {
      _replyingToReplyId = reply.id;
      _replyingToUsername = username;
    });
    _replyFocus.requestFocus();
  }

  void _clearReplyTarget() {
    setState(() {
      _replyingToReplyId = null;
      _replyingToUsername = null;
    });
  }

  Future<void> _submitReply() async {
    final String body = _replyController.text.trim();
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to reply.');
      return;
    }
    if (body.isEmpty || _isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.createReply(
        CreateReplyRequest(
          threadId: widget.threadId,
          authorId: user.uid,
          body: body,
          parentReplyId: _replyingToReplyId,
          authorDisplayName: user.displayName,
          authorUsername: user.displayName,
          authorAvatarUrl: user.photoURL,
        ),
      );
      _replyController.clear();
      _clearReplyTarget();
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _reactThread(String reactionType) async {
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _errorMessage = 'Please sign in to react.');
      return;
    }
    try {
      await widget.repository.react(
        threadId: widget.threadId,
        userId: uid,
        reactionType: reactionType,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _reactReply(ThreadReplyDto reply, String reactionType) async {
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _errorMessage = 'Please sign in to react.');
      return;
    }
    try {
      await widget.repository.react(
        threadId: widget.threadId,
        userId: uid,
        reactionType: reactionType,
        targetType: 'reply',
        targetId: reply.id,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _deleteReply(ThreadReplyDto reply) async {
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _errorMessage = 'Please sign in to delete.');
      return;
    }
    if (uid != reply.authorId) {
      setState(() => _errorMessage = 'You can only delete your own replies.');
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete reply?'),
          content: const Text('This can’t be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.repository.deleteReply(
        threadId: widget.threadId,
        replyId: reply.id,
        userId: uid,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _toggleFollow() async {
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _errorMessage = 'Please sign in to follow.');
      return;
    }
    final bool next = !_isFollowing;
    try {
      await widget.repository.followThread(
        threadId: widget.threadId,
        userId: uid,
        follow: next,
      );
      if (mounted) {
        setState(() => _isFollowing = next);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _toggleSave() async {
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _errorMessage = 'Please sign in to save.');
      return;
    }
    final bool next = !_isSaved;
    try {
      await widget.repository.saveThread(
        threadId: widget.threadId,
        userId: uid,
        save: next,
      );
      if (mounted) {
        setState(() => _isSaved = next);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _respondInvite(bool accept) async {
    setState(() => _respondingInvite = true);
    try {
      await _inviteService.respondToThreadInvite(
        postId: widget.threadId,
        status: accept
            ? kThreadInviteStatusAccepted
            : kThreadInviteStatusDeclined,
      );
      if (mounted) {
        setState(() {
          _myInviteStatus = accept
              ? kThreadInviteStatusAccepted
              : kThreadInviteStatusDeclined;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update invite')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _respondingInvite = false);
      }
    }
  }

  Future<void> _resolve() async {
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    final ThreadDto? thread = _thread;
    if (uid == null || thread == null || thread.authorId != uid) {
      return;
    }
    await widget.repository.resolveThread(
      threadId: widget.threadId,
      resolvedBy: uid,
      selectedReplyIds: _selectedReplyId == null
          ? const <String>[]
          : <String>[_selectedReplyId!],
    );
    await _load();
  }

  List<_ReplyNode> _buildReplyTree(List<ThreadReplyDto> flat) {
    final Set<String> ids =
        flat.map((ThreadReplyDto r) => r.id).toSet();
    final Map<String, List<ThreadReplyDto>> children =
        <String, List<ThreadReplyDto>>{};
    for (final ThreadReplyDto reply in flat) {
      final String? parent = reply.parentReplyId;
      if (parent == null || parent.isEmpty || !ids.contains(parent)) {
        continue;
      }
      children.putIfAbsent(parent, () => <ThreadReplyDto>[]).add(reply);
    }
    List<_ReplyNode> walk(ThreadReplyDto reply) {
      final List<ThreadReplyDto> kids =
          children[reply.id] ?? const <ThreadReplyDto>[];
      return <_ReplyNode>[
        _ReplyNode(
          reply: reply,
          children: kids.expand(walk).toList(growable: false),
        ),
      ];
    }

    return flat
        .where((ThreadReplyDto r) {
          final String? parent = r.parentReplyId;
          return parent == null ||
              parent.isEmpty ||
              !ids.contains(parent);
        })
        .expand(walk)
        .toList(growable: false);
  }

  List<Widget> _buildReplyWidgets({
    required List<_ReplyNode> nodes,
    required ThreadDto thread,
    required String? uid,
    int depth = 0,
  }) {
    final List<Widget> out = <Widget>[];
    for (final _ReplyNode node in nodes) {
      out.add(
        _ReplyTile(
          reply: node.reply,
          depth: depth,
          threadType: thread.type,
          isSelected: _selectedReplyId == node.reply.id,
          canSelect: uid == thread.authorId && thread.status != 'resolved',
          canDelete: uid != null && uid == node.reply.authorId,
          reactionCounts:
              _replyReactionCounts[node.reply.id] ?? const <String, int>{},
          activeTypes:
              _myReplyReactions[node.reply.id] ?? const <String>{},
          onSelect: () {
            setState(() {
              _selectedReplyId = _selectedReplyId == node.reply.id
                  ? null
                  : node.reply.id;
            });
          },
          onReply: (String username) => _startReplyTo(node.reply, username),
          onReact: (String type) => _reactReply(node.reply, type),
          onDelete: () => _deleteReply(node.reply),
        ),
      );
      out.addAll(
        _buildReplyWidgets(
          nodes: node.children,
          thread: thread,
          uid: uid,
          depth: depth + 1,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ThreadDto? thread = _thread;
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF071120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071120),
        elevation: 0,
        title: const Text('Discussion'),
        actions: <Widget>[
          IconButton(
            tooltip: _isSaved ? 'Unsave' : 'Save',
            onPressed: _toggleSave,
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            ),
          ),
          if (_thread != null &&
              canInviteToThread(
                currentUserId: uid,
                ownerId: _thread!.authorId,
                visibility: _thread!.visibility,
              ))
            IconButton(
              tooltip: 'Invite',
              onPressed: () {
                ThreadInviteSheet.show(
                  context,
                  postId: widget.threadId,
                  postTitle: _thread!.title,
                  ownerId: _thread!.authorId,
                  visibility: _thread!.visibility,
                );
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
        ],
      ),
      body: _isLoading && thread == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && thread == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText.rich(
                      TextSpan(
                        text: _errorMessage,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                )
              : thread == null
                  ? const Center(child: Text('Thread not found'))
                  : Column(
                      children: <Widget>[
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.only(bottom: 28),
                              children: <Widget>[
                                ThreadWorkspaceHeader(
                                  thread: thread,
                                  isFollowing: _isFollowing,
                                  onFollow: _toggleFollow,
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    0,
                                  ),
                                  child: Text(
                                    stripRelatedVideoMarkdown(thread.body),
                                    style: TextStyle(
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.88),
                                      fontSize: 16,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                                if (_myInviteStatus ==
                                    kThreadInviteStatusPending)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      0,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: scheme.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          const Text(
                                            'You were invited to this thread',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: <Widget>[
                                              OutlinedButton(
                                                onPressed: _respondingInvite
                                                    ? null
                                                    : () =>
                                                        _respondInvite(false),
                                                child: const Text('Decline'),
                                              ),
                                              const SizedBox(width: 8),
                                              FilledButton(
                                                onPressed: _respondingInvite
                                                    ? null
                                                    : () =>
                                                        _respondInvite(true),
                                                child: const Text('Accept'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                Builder(
                                  builder: (BuildContext context) {
                                    final String? relatedId =
                                        resolveRelatedVideoId(
                                      sourceVideoId: thread.sourceVideoId,
                                      content: thread.body,
                                    );
                                    if (relatedId == null ||
                                        relatedId.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: RelatedVideoCard(
                                        videoId: relatedId,
                                      ),
                                    );
                                  },
                                ),
                                ConversationPulseCard(thread: thread),
                                const SizedBox(height: 14),
                                _ReactionRow(
                                  threadType: thread.type,
                                  counts: _threadReactionCounts,
                                  activeTypes: _myThreadReactions,
                                  onReact: _reactThread,
                                ),
                                if (uid == thread.authorId &&
                                    thread.status != 'resolved')
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      0,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: _resolve,
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                        ),
                                        label: const Text('Mark as resolved'),
                                      ),
                                    ),
                                  ),
                                if (_errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: SelectableText.rich(
                                      TextSpan(
                                        text: _errorMessage,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    28,
                                    16,
                                    10,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Text(
                                        'Replies',
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${_replies.length}',
                                          style: TextStyle(
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.7),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_replies.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      0,
                                    ),
                                    child: Text(
                                      'Be the first to add a helpful reply.',
                                      style: TextStyle(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.5),
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                else
                                  ..._buildReplyWidgets(
                                    nodes: _buildReplyTree(_replies),
                                    thread: thread,
                                    uid: uid,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF071120),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (_replyingToReplyId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            'Replying to '
                                            '${_replyingToUsername ?? 'comment'}',
                                            style: TextStyle(
                                              color: scheme.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _clearReplyTarget,
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: _replyController,
                                        focusNode: _replyFocus,
                                        minLines: 1,
                                        maxLines: 4,
                                        style:
                                            TextStyle(color: scheme.onSurface),
                                        decoration: InputDecoration(
                                          hintText: _replyingToReplyId != null
                                              ? 'Write your reply…'
                                              : 'Write a helpful reply…',
                                          hintStyle: TextStyle(
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white
                                              .withValues(alpha: 0.06),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filled(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _submitReply,
                                      icon: _isSubmitting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.send_rounded),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ReplyNode {
  const _ReplyNode({
    required this.reply,
    required this.children,
  });

  final ThreadReplyDto reply;
  final List<_ReplyNode> children;
}

class _ReactionProjection {
  const _ReactionProjection({
    required this.threadCounts,
    required this.myThread,
    required this.replyCounts,
    required this.myReply,
  });

  final Map<String, int> threadCounts;
  final Set<String> myThread;
  final Map<String, Map<String, int>> replyCounts;
  final Map<String, Set<String>> myReply;
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.threadType,
    required this.counts,
    required this.activeTypes,
    required this.onReact,
    this.compact = false,
  });

  final String threadType;
  final Map<String, int> counts;
  final Set<String> activeTypes;
  final ValueChanged<String> onReact;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> allowed = allowedReactionsForType(threadType);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: allowed.map((String type) {
          final String label = kReactionLabels[type] ?? type;
          final int count = counts[type] ?? 0;
          final String suffix = count > 0 ? ' $count' : '';
          final bool isActive = activeTypes.contains(type);
          return Material(
            color: isActive
                ? scheme.primary.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: compact ? 0.04 : 0.06),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onReact(type),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isActive
                        ? scheme.primary.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 6 : 8,
                ),
                child: Text(
                  '$label$suffix',
                  style: TextStyle(
                    color: isActive
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.reply,
    required this.depth,
    required this.threadType,
    required this.isSelected,
    required this.canSelect,
    required this.canDelete,
    required this.reactionCounts,
    required this.activeTypes,
    required this.onSelect,
    required this.onReply,
    required this.onReact,
    required this.onDelete,
  });

  final ThreadReplyDto reply;
  final int depth;
  final String threadType;
  final bool isSelected;
  final bool canSelect;
  final bool canDelete;
  final Map<String, int> reactionCounts;
  final Set<String> activeTypes;
  final VoidCallback onSelect;
  final ValueChanged<String> onReply;
  final ValueChanged<String> onReact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String authorId = reply.authorId.trim();
    final double indent = 16 + (depth.clamp(0, 3) * 18);
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 6, 16, 6),
      child: Material(
        color: isSelected
            ? scheme.primary.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: canSelect ? onSelect : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (authorId.isNotEmpty)
                  StreamBuilder<ForumAuthor?>(
                    stream: DiscussionAuthorService()
                        .watchForumAuthor(authorId),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<ForumAuthor?> snapshot,
                    ) {
                      final ForumAuthor? live = snapshot.data;
                      return StatusAwareAvatar(
                        userId: authorId,
                        avatarURL: pickBestAvatarUrl(
                          live?.avatarUrl,
                          reply.authorAvatarUrl,
                        ),
                        radius: 18,
                        showOnlineIndicator: false,
                      );
                    },
                  )
                else
                  const SizedBox(width: 36, height: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<ForumAuthor?>(
                    stream: authorId.isEmpty
                        ? null
                        : DiscussionAuthorService()
                            .watchForumAuthor(authorId),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<ForumAuthor?> snapshot,
                    ) {
                      final ForumAuthor? live = snapshot.data;
                      final String username = safeThreadHandle(
                        liveUsername: live?.username,
                        fallbackUsername: reply.authorUsername,
                        fallbackDisplayName:
                            live?.displayName ?? reply.authorDisplayName,
                        authorId: authorId,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reply.body,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.84),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ReactionRow(
                            threadType: threadType,
                            counts: reactionCounts,
                            activeTypes: activeTypes,
                            onReact: onReact,
                            compact: true,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              TextButton(
                                onPressed: () => onReply(username),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Reply'),
                              ),
                              if (canDelete) ...<Widget>[
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: onDelete,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ],
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Selected for resolution',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
