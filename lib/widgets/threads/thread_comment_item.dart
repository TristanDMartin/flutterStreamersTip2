import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../models/forum_comment.dart';
import '../../services/forum_service.dart';
import '../../services/report_service.dart';
import '../../constants/app_colors.dart';
import '../../core/theme/support_shell_style.dart';
import '../../routing/app_navigator.dart';
import 'discussion_author_row.dart';

/// Comment item widget for thread comments with replies support
class ThreadCommentItem extends StatefulWidget {
  final ForumComment comment;
  final String postId;
  final ValueChanged<ForumComment> onReply;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onDelete;
  final VoidCallback onToggleReplies;
  final bool isExpanded;

  const ThreadCommentItem({
    super.key,
    required this.comment,
    required this.postId,
    required this.onReply,
    required this.onLike,
    required this.onDislike,
    required this.onDelete,
    required this.onToggleReplies,
    required this.isExpanded,
  });

  @override
  State<ThreadCommentItem> createState() => _ThreadCommentItemState();
}

class _ThreadCommentItemState extends State<ThreadCommentItem> {
  final ForumService _forumService = ForumService();
  final user = firebase_auth.FirebaseAuth.instance.currentUser;

  Future<void> _reportComment() async {
    if (user == null || user!.uid == widget.comment.author.uid) return;

    final reportService = ReportService();
    final alreadyReported = await reportService.hasUserReportedThreadComment(
      postId: widget.postId,
      commentId: widget.comment.id,
    );
    if (!mounted) return;
    if (alreadyReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already reported this thread comment.'),
        ),
      );
      return;
    }

    final selectedReason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        final reasons = reportService.getReportReasons();
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
      await reportService.reportThreadComment(
        postId: widget.postId,
        commentId: widget.comment.id,
        commentAuthorId: widget.comment.author.uid,
        reason: selectedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thread comment reported. Thanks for the report.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report thread comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final isLiked = user != null && widget.comment.likedBy.contains(user!.uid);
    final isDisliked =
        user != null && widget.comment.dislikedBy.contains(user!.uid);
    final isAuthor = user != null && widget.comment.author.uid == user!.uid;
    final hasReplies = widget.comment.replyCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shell.surfaceCardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DiscussionAuthorRow(
                      displayName: widget.comment.author.displayName,
                      username: widget.comment.author.username,
                      avatarUrl: widget.comment.author.avatarUrl,
                      userId: widget.comment.author.uid,
                      avatarRadius: 16,
                      trailingText: _formatDate(widget.comment.createdAt),
                      onTap: () =>
                          _navigateToProfile(widget.comment.author.uid),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.comment.deleted
                          ? '[deleted]'
                          : widget.comment.content,
                      style: TextStyle(
                        color: widget.comment.deleted
                            ? shell.muted
                            : shell.onChrome,
                        fontSize: 14,
                        fontStyle: widget.comment.deleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Comment Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildActionButton(
                context,
                icon: Icons.favorite_outline,
                filledIcon: Icons.favorite,
                label: '${widget.comment.likes}',
                isActive: isLiked,
                onTap: widget.onLike,
                activeColor: scheme.primary,
              ),
              _buildActionButton(
                context,
                icon: Icons.thumb_down_outlined,
                filledIcon: Icons.thumb_down,
                label: '${widget.comment.dislikes}',
                isActive: isDisliked,
                onTap: widget.onDislike,
                activeColor: scheme.error,
              ),
              if (user != null && !widget.comment.deleted)
                _buildActionButton(
                  context,
                  icon: Icons.reply_outlined,
                  label: 'Reply',
                  onTap: () => widget.onReply(widget.comment),
                ),
              if (hasReplies)
                _buildActionButton(
                  context,
                  icon:
                      widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                  label: widget.isExpanded
                      ? 'Hide replies (${widget.comment.replyCount})'
                      : 'View replies (${widget.comment.replyCount})',
                  onTap: widget.onToggleReplies,
                ),
              if (user != null &&
                  user!.uid != widget.comment.author.uid &&
                  !widget.comment.deleted)
                _buildTextAction(
                  context,
                  label: 'Report',
                  color: shell.muted,
                  onTap: _reportComment,
                ),
              if (isAuthor && !widget.comment.deleted)
                _buildTextAction(
                  context,
                  label: 'Delete',
                  color: scheme.error,
                  onTap: widget.onDelete,
                ),
            ],
          ),

          // Replies Section with smooth animation
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: widget.isExpanded
                ? _buildRepliesSection()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    IconData? filledIcon,
    String? label,
    bool isActive = false,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color resolvedActive = activeColor ?? scheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: shell.chipUnselectedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: shell.surfaceCardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive && filledIcon != null ? filledIcon : icon,
              size: 16,
              color: isActive ? resolvedActive : shell.muted,
            ),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? resolvedActive : shell.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextAction(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: shell.chipUnselectedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRepliesSection() {
    return StreamBuilder<List<ForumComment>>(
      stream: _forumService.watchCommentReplies(
        widget.postId,
        widget.comment.id,
      ),
      builder: (BuildContext context, snapshot) {
        final StSupportShellStyle shell = StSupportShellStyle.of(context);
        final ColorScheme scheme = Theme.of(context).colorScheme;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: scheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error loading replies: ${snapshot.error}',
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          );
        }

        final replies = snapshot.data ?? [];

        if (replies.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, left: 12),
            child: Text(
              'No replies yet',
              style: TextStyle(
                color: shell.muted,
                fontSize: 12,
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: shell.surfaceCardBorder,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: replies.map((ForumComment reply) {
              final isReplyLiked =
                  user != null && reply.likedBy.contains(user!.uid);
              final isReplyDisliked =
                  user != null && reply.dislikedBy.contains(user!.uid);
              final isReplyAuthor =
                  user != null && reply.author.uid == user!.uid;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: shell.chipUnselectedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: shell.surfaceCardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DiscussionAuthorRow(
                            displayName: reply.author.displayName,
                            username: reply.author.username,
                            avatarUrl: reply.author.avatarUrl,
                            userId: reply.author.uid,
                            avatarRadius: 12,
                            trailingText: _formatDate(reply.createdAt),
                            onTap: () => _navigateToProfile(reply.author.uid),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reply.deleted ? '[deleted]' : reply.content,
                            style: TextStyle(
                              color: reply.deleted
                                  ? shell.muted
                                  : shell.onChrome,
                              fontSize: 13,
                              fontStyle: reply.deleted
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildActionButton(
                                context,
                                icon: Icons.favorite_outline,
                                filledIcon: Icons.favorite,
                                label: '${reply.likes}',
                                isActive: isReplyLiked,
                                onTap: () => _forumService.toggleCommentLike(
                                  widget.postId,
                                  reply.id,
                                  user!.uid,
                                ),
                                activeColor: scheme.primary,
                              ),
                              const SizedBox(width: 12),
                              _buildActionButton(
                                context,
                                icon: Icons.thumb_down_outlined,
                                filledIcon: Icons.thumb_down,
                                label: '${reply.dislikes}',
                                isActive: isReplyDisliked,
                                onTap: () => _forumService.toggleCommentDislike(
                                  widget.postId,
                                  reply.id,
                                  user!.uid,
                                ),
                                activeColor: scheme.error,
                              ),
                              const Spacer(),
                              if (isReplyAuthor && !reply.deleted)
                                TextButton(
                                  onPressed: () => _forumService.deleteComment(
                                    widget.postId,
                                    reply.id,
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: scheme.error,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  void _navigateToProfile(String userId) {
    AppNavigator.openStreamerCard(
      context,
      userId: userId,
      currentUserId: user?.uid,
    );
  }
}
