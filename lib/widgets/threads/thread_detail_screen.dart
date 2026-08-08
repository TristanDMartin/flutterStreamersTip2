import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../models/forum_post.dart';
import '../../models/forum_comment.dart';
import '../../models/source_comment.dart';
import '../../models/creator_profile_snapshot.dart';
import '../../models/forum_author.dart';
import '../../services/forum_service.dart';
import '../../services/discussion_author_service.dart';
import '../../services/report_service.dart';
import '../status_aware_avatar.dart';
import '../../constants/app_colors.dart';
import '../../core/theme/support_shell_style.dart';
import '../../core/theme/st_theme_tokens.dart';
import '../../routing/app_navigator.dart';
import '../../features/threads/related_video.dart';
import '../../features/threads/thread_invite.dart';
import '../../features/threads/thread_visibility.dart';
import '../../services/thread_invite_service.dart';
import 'discussion_author_row.dart';
import 'thread_comment_item.dart';
import 'related_video_card.dart';
import 'thread_invite_sheet.dart';

/// Thread detail screen showing thread content and comments
/// Simplified version without video embedding to avoid build_runner issues
class ThreadDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const ThreadDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final ForumService _forumService = ForumService();
  final ReportService _reportService = ReportService();
  final DiscussionAuthorService _discussionAuthorService =
      DiscussionAuthorService();
  final FocusNode _composerFocusNode = FocusNode();
  ForumPost? _post;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _commentController = TextEditingController();
  String? _replyingToCommentId;
  String? _replyingToDisplayName;
  final Set<String> _expandedReplies = {};
  bool _isSubmittingReply = false;
  bool _isBookmarked = false;
  bool _isFollowed = false;
  String? _myInviteStatus;
  bool _respondingInvite = false;
  final ThreadInviteService _inviteService = ThreadInviteService();

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final post = await _forumService.getPost(
        widget.postId,
        currentUserId: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
      );
      if (post == null) {
        setState(() {
          _errorMessage =
              'This thread is unavailable, or it is invite-only and you do not have access.';
          _isLoading = false;
        });
        return;
      }

      // Enrich post with current user avatar data
      final enrichedPost = await _enrichPostWithAvatar(post);
      final String? uid =
          firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      String? inviteStatus;
      if (uid != null &&
          normalizeThreadVisibility(enrichedPost.visibility) ==
              kThreadVisibilityInviteOnly) {
        final ThreadInviteRecord? invite =
            await _inviteService.getThreadInvite(widget.postId, uid);
        inviteStatus = invite?.status;
      }

      if (mounted) {
        setState(() {
          _post = enrichedPost;
          _isBookmarked =
              uid != null && enrichedPost.bookmarkedBy.contains(uid);
          _isFollowed = uid != null && enrichedPost.followedBy.contains(uid);
          _myInviteStatus = inviteStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'We couldn\'t load this thread right now. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  /// Enrich post with current user avatar from users collection
  Future<ForumPost> _enrichPostWithAvatar(ForumPost post) async {
    try {
      final updatedAuthor =
          await _discussionAuthorService.loadForumAuthor(post.author.uid);
      return ForumPost(
        id: post.id,
        title: post.title,
        content: post.content,
        category: post.category,
        categoryDisplayName: post.categoryDisplayName,
        tags: post.tags,
        author: updatedAuthor,
        visibility: post.visibility,
        likes: post.likes,
        commentCount: post.commentCount,
        likedBy: post.likedBy,
        bookmarkedBy: post.bookmarkedBy,
        followedBy: post.followedBy,
        linkedVideoId: post.linkedVideoId,
        linkedCommentId: post.linkedCommentId,
        sourceComment: post.sourceComment,
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
        deleted: post.deleted,
      );
    } catch (e) {
      debugPrint('❌ Error enriching post avatar: $e');
      return post;
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _post == null) return;

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to comment')),
          );
        }
        return;
      }

      final author = await _forumService.getUserProfile(user.uid);
      await _forumService.addComment(widget.postId, text, author);
      if (mounted) {
        _commentController.clear();
        unawaited(_loadThread());
      }
    } catch (e) {
      final message = e.toString().contains('permission-denied')
          ? 'Comments are blocked by Firestore rules right now. The app-side fix is in; if this still appears after reinstall/redeploy, we should re-publish rules.'
          : 'Error: ${e.toString()}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  void _handleReply(ForumComment comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToDisplayName = comment.author.displayName;
      if (!_expandedReplies.contains(comment.id)) {
        _expandedReplies.add(comment.id);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _composerFocusNode.requestFocus();
    });
  }

  void _handleCancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToDisplayName = null;
    });
  }

  Future<void> _handleSubmitReply() async {
    final commentId = _replyingToCommentId;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (commentId == null) return;

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSubmittingReply = true;
    });

    try {
      final author = await _forumService.getUserProfile(user.uid);
      await _forumService.addComment(
        widget.postId,
        text,
        author,
        parentCommentId: commentId,
      );

      if (mounted) {
        setState(() {
          _replyingToCommentId = null;
          _replyingToDisplayName = null;
          _commentController.clear();
          if (!_expandedReplies.contains(commentId)) {
            _expandedReplies.add(commentId);
          }
        });
        unawaited(_loadThread());
      }
    } catch (e) {
      final message = e.toString().contains('permission-denied')
          ? 'Replies are blocked by Firestore rules right now. The app-side fix is in; if this still appears after reinstall/redeploy, we should re-publish rules.'
          : 'Error: ${e.toString()}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReply = false;
        });
      }
    }
  }

  Future<void> _handleLike(String commentId) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _forumService.toggleCommentLike(
        widget.postId,
        commentId,
        user.uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDislike(String commentId) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _forumService.toggleCommentDislike(
        widget.postId,
        commentId,
        user.uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDelete(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _forumService.deleteComment(widget.postId, commentId);
      if (mounted) {
        unawaited(_loadThread());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleComposerSubmit() async {
    if (_replyingToCommentId != null) {
      await _handleSubmitReply();
      return;
    }
    await _addComment();
  }

  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplies.contains(commentId)) {
        _expandedReplies.remove(commentId);
      } else {
        _expandedReplies.add(commentId);
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final author = ForumAuthor(
        uid: user.uid,
        username: user.displayName ?? 'user',
        displayName: user.displayName ?? 'User',
        avatarUrl: user.photoURL,
      );

      await _forumService.togglePostLike(widget.postId, user.uid, author);
      _loadThread(); // Refresh to update like count
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _reportThread() async {
    final post = _post;
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (post == null ||
        currentUser == null ||
        currentUser.uid == post.author.uid) {
      return;
    }

    final alreadyReported = await _reportService.hasUserReportedThread(post.id);
    if (!mounted) return;
    if (alreadyReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reported this thread.')),
      );
      return;
    }

    final selectedReason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        final reasons = _reportService.getReportReasons();
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reasons.length,
            itemBuilder: (context, index) {
              final reason = reasons[index];
              return ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.white70),
                title:
                    Text(reason, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(reason),
              );
            },
          ),
        );
      },
    );

    if (selectedReason == null) return;

    try {
      await _reportService.reportThread(
        postId: post.id,
        authorId: post.author.uid,
        reason: selectedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Thread reported. Thanks for the report.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report thread: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: shell.scaffold,
        body: Container(
          color: shell.scaffold,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _buildTopBarShell(
                    context,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: shell.onChrome),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: 'Thread',
                    subtitle: 'Loading conversation...',
                    actions: const SizedBox.shrink(),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _post == null) {
      return Scaffold(
        backgroundColor: shell.scaffold,
        body: Container(
          color: shell.scaffold,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _buildTopBarShell(
                    context,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: shell.onChrome),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: 'Thread',
                    subtitle: 'We hit a snag opening this one.',
                    actions: const SizedBox.shrink(),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: shell.surfaceCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: shell.surfaceCardBorder,
                      ),
                    ),
                    child: Text(
                      _errorMessage ?? 'Thread not found',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: shell.onChrome),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF071120) : shell.scaffold,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.05),
            radius: 1.16,
            colors: dark
                ? <Color>[
                    scheme.primary.withValues(alpha: 0.10),
                    const Color(0xFF071120),
                  ]
                : <Color>[
                    scheme.primary.withValues(alpha: 0.05),
                    shell.scaffold,
                  ],
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _buildTopBarShell(
                  context,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: shell.onChrome),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: 'Thread',
                  subtitle: '${_post!.commentCount} replies',
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (firebase_auth
                              .FirebaseAuth.instance.currentUser?.uid !=
                          _post!.author.uid)
                        _buildHeaderIconButton(
                          context,
                          icon: Icons.flag_outlined,
                          onPressed: _reportThread,
                        ),
                      const SizedBox(width: 8),
                      _buildHeaderIconButton(
                        context,
                        icon: _post!.likedBy.contains(firebase_auth
                                .FirebaseAuth.instance.currentUser?.uid)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        onPressed: _toggleLike,
                        isActive: _post!.likedBy.contains(firebase_auth
                            .FirebaseAuth.instance.currentUser?.uid),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  _replyingToCommentId != null ? 142 : 112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThreadHeroCard(),
                    const SizedBox(height: 16),
                    _buildCommentsSection(),
                  ],
                ),
              ),
            ),
            // Comment input - Fixed at bottom, outside scrollable area
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                decoration: BoxDecoration(
                  color: shell.surfaceCard.withValues(alpha: 0.78),
                  border: Border(
                    top: BorderSide(
                      color: shell.surfaceCardBorder.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToCommentId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: shell.chipUnselectedBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: shell.surfaceCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Replying to ${_replyingToDisplayName ?? 'comment'}',
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _handleCancelReply,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    scheme.onSurface.withValues(alpha: 0.55),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildComposerAvatar(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _composerFocusNode,
                            textInputAction: TextInputAction.send,
                            style: TextStyle(color: scheme.onSurface),
                            minLines: 1,
                            maxLines: 4,
                            onSubmitted: (_) => _handleComposerSubmit(),
                            decoration: InputDecoration(
                              hintText: _replyingToCommentId != null
                                  ? 'Write a reply...'
                                  : 'Jump into the conversation...',
                              hintStyle: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.45),
                              ),
                              filled: true,
                              fillColor: shell.isLight
                                  ? scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.55)
                                  : Colors.white.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: shell.surfaceCardBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: shell.surfaceCardBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: scheme.primary.withValues(alpha: 0.75),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              _isSubmittingReply ? null : _handleComposerSubmit,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(11),
                          ),
                          child: _isSubmittingReply
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      scheme.onPrimary,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  size: 20,
                                  color: scheme.onPrimary,
                                ),
                        ),
                      ],
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

  Widget _buildTopBarShell(
    BuildContext context, {
    required Widget leading,
    required String title,
    required String subtitle,
    required Widget actions,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: shell.surfaceCard.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: shell.surfaceCardBorder.withValues(alpha: 0.66),
        ),
      ),
      child: Row(
        children: [
          leading,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          actions,
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive
            ? scheme.primary.withValues(alpha: 0.16)
            : shell.onChrome.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.45)
              : shell.surfaceCardBorder,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isActive ? scheme.primary : shell.muted,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildThreadHeroCard() {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: shell.surfaceCardBorder.withValues(alpha: 0.64),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_post!.categoryDisplayName ?? '').isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                _post!.categoryDisplayName!.toUpperCase(),
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _post!.title,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          DiscussionAuthorRow(
            displayName: _post!.author.displayName,
            username: _post!.author.username,
            avatarUrl: _post!.author.avatarUrl,
            userId: _post!.author.uid,
            avatarRadius: 22,
            trailingText: _formatDate(_post!.createdAt),
            onTap: () => _openStreamerCard(
              userId: _post!.author.uid,
              initialCreator:
                  CreatorProfileSnapshot.fromForumAuthor(_post!.author),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text(
              _creatorContext(_post!.author),
              style: TextStyle(
                color: scheme.primary.withValues(alpha: 0.84),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            stripRelatedVideoMarkdown(_post!.content),
            style: TextStyle(
              color: shell.onChrome.withValues(alpha: 0.88),
              fontSize: 16,
              height: 1.45,
            ),
          ),
          if (_myInviteStatus == kThreadInviteStatusPending) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'You were invited to this thread',
                    style: TextStyle(
                      color: shell.onChrome,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: _respondingInvite
                            ? null
                            : () => _respondInvite(false),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _respondingInvite
                            ? null
                            : () => _respondInvite(true),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_myInviteStatus == kThreadInviteStatusAccepted) ...[
            const SizedBox(height: 10),
            Text(
              'Joined',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          Builder(
            builder: (BuildContext context) {
              final String? relatedId = resolveRelatedVideoId(
                linkedVideoId: _post!.linkedVideoId,
                content: _post!.content,
              );
              if (relatedId == null || relatedId.isEmpty) {
                return const SizedBox.shrink();
              }
              return RelatedVideoCard(videoId: relatedId);
            },
          ),
          if (_post!.sourceComment != null) ...[
            const SizedBox(height: 16),
            _buildSourceCommentCard(),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(
                  _isFollowed
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 18,
                ),
                label: Text(_isFollowed ? 'Following' : 'Follow'),
              ),
              OutlinedButton.icon(
                onPressed: _toggleSave,
                icon: Icon(
                  _isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 18,
                ),
                label: Text(_isBookmarked ? 'Saved' : 'Save'),
              ),
              if (canInviteToThread(
                currentUserId:
                    firebase_auth.FirebaseAuth.instance.currentUser?.uid,
                ownerId: _post!.author.uid,
                visibility: _post!.visibility,
              ))
                OutlinedButton.icon(
                  onPressed: () {
                    ThreadInviteSheet.show(
                      context,
                      postId: widget.postId,
                      postTitle: _post!.title,
                      ownerId: _post!.author.uid,
                      visibility: _post!.visibility,
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Invite'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatPill(
                icon: Icons.favorite_rounded,
                label: '${_post!.likes} likes',
              ),
              _buildStatPill(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${_post!.commentCount} replies',
              ),
              _buildStatPill(
                icon: Icons.access_time_rounded,
                label: _formatDate(_post!.createdAt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _post == null) {
      return;
    }
    final bool next = !_isFollowed;
    setState(() => _isFollowed = next);
    try {
      await _forumService.toggleThreadFollow(widget.postId, uid);
    } catch (_) {
      if (mounted) {
        setState(() => _isFollowed = !next);
      }
    }
  }

  Future<void> _toggleSave() async {
    final String? uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _post == null) {
      return;
    }
    final bool next = !_isBookmarked;
    setState(() => _isBookmarked = next);
    try {
      await _forumService.togglePostBookmark(widget.postId, uid);
    } catch (_) {
      if (mounted) {
        setState(() => _isBookmarked = !next);
      }
    }
  }

  Future<void> _respondInvite(bool accept) async {
    setState(() => _respondingInvite = true);
    try {
      await _inviteService.respondToThreadInvite(
        postId: widget.postId,
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

  Widget _buildCommentsSection() {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discussion',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Reply, react, and keep the thread moving.',
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<ForumComment>>(
            stream: _forumService.watchComments(widget.postId),
            builder: (BuildContext context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildCommentsFeedbackCard(
                  context,
                  icon: Icons.cloud_off_outlined,
                  title: 'Comments Need A Retry',
                  message:
                      'We hit a snag loading this conversation. Give it another try in a moment.',
                );
              }

              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return _buildCommentsFeedbackCard(
                  context,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Be The First To Reply',
                  message:
                      'Kick things off with the first comment and set the tone for this thread.',
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];

                  return ThreadCommentItem(
                    comment: comment,
                    postId: widget.postId,
                    onReply: _handleReply,
                    onLike: () => _handleLike(comment.id),
                    onDislike: () => _handleDislike(comment.id),
                    onDelete: () => _handleDelete(comment.id),
                    onToggleReplies: () => _toggleReplies(comment.id),
                    isExpanded: _expandedReplies.contains(comment.id),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsFeedbackCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: shell.chipUnselectedBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: shell.surfaceCardBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: shell.muted),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.62),
              fontSize: 14,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: shell.chipUnselectedBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: shell.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _creatorContext(ForumAuthor author) {
    final String username = author.username.trim();
    if (username.toLowerCase().contains('edit')) {
      return 'Editor • Creator workflow';
    }
    if (username.toLowerCase().contains('fps')) {
      return 'FPS Creator • Active today';
    }
    return 'Creator • Posted recently';
  }

  Widget _buildComposerAvatar() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return _buildComposerAvatarShell(Icon(
        Icons.person,
        color: scheme.onPrimary,
        size: 18,
      ));
    }

    return StreamBuilder(
      stream: _discussionAuthorService.watchForumAuthor(currentUser.uid),
      builder: (context, snapshot) {
        final String? liveAvatarUrl =
            snapshot.data?.avatarUrl ?? currentUser.photoURL;
        return _buildComposerAvatarShell(
          StatusAwareAvatar(
            userId: currentUser.uid,
            avatarURL: liveAvatarUrl,
            radius: 18,
            showOnlineIndicator: false,
            backgroundColor: Colors.transparent,
          ),
        );
      },
    );
  }

  Widget _buildComposerAvatarShell(Widget child) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.secondary.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _buildSourceCommentCard() {
    final SourceComment sourceComment = _post!.sourceComment!;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: shell.chipUnselectedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: shell.surfaceCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 16,
                color: StThemeColors.warningAmber,
              ),
              const SizedBox(width: 8),
              Text(
                'Started from a video comment',
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sourceComment.text,
            style: TextStyle(
              color: shell.muted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openStreamerCard(
              userId: sourceComment.authorId,
              initialCreator: CreatorProfileSnapshot(
                creatorId: sourceComment.authorId,
                displayName: sourceComment.authorName,
                username: sourceComment.authorUsername,
              ),
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Original comment by ${sourceComment.authorName} (@${sourceComment.authorUsername})',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openStreamerCard({
    required String userId,
    CreatorProfileSnapshot? initialCreator,
  }) {
    if (userId.isEmpty) return;

    AppNavigator.openStreamerCard(
      context,
      userId: userId,
      initialCreator: initialCreator,
      currentUserId: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
