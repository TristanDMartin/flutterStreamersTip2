import 'package:flutter/material.dart';
import '../../core/theme/support_shell_style.dart';
import '../../models/forum_post.dart';
import '../../services/discussion_author_service.dart';
import '../status_aware_avatar.dart';

/// Card widget for displaying a forum post in the grid
class ForumPostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onTap;
  final bool featured;

  const ForumPostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String category = (post.categoryDisplayName ?? '').isNotEmpty
        ? post.categoryDisplayName!
        : _threadTypeLabel(post.category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(featured ? 18 : 14),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            featured ? 16 : 14,
            featured ? 16 : 12,
            featured ? 16 : 14,
            featured ? 15 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(featured ? 18 : 14),
            color: shell.surfaceCard.withValues(alpha: featured ? 0.74 : 0.5),
            border: Border.all(
              color: shell.surfaceCardBorder.withValues(alpha: 0.58),
              width: 1,
            ),
            boxShadow: featured
                ? <BoxShadow>[
                    BoxShadow(
                      color: shell.shadowSoft.withValues(alpha: 0.65),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ThreadTypePill(label: category),
                  const Spacer(),
                  Text(
                    '${post.commentCount} replies',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.52),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: featured ? 12 : 8),
              Text(
                post.title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: featured ? 20 : 15.5,
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                  letterSpacing: featured ? -0.2 : 0,
                ),
                maxLines: featured ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 7),
              Text(
                post.content,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                  fontSize: featured ? 14 : 13,
                  height: 1.38,
                ),
                maxLines: featured ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: featured ? 14 : 12),
              Row(
                children: [
                  _ThreadPostAvatar(
                    userId: post.author.uid,
                    fallbackAvatarUrl: post.author.avatarUrl,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StreamBuilder(
                      stream: DiscussionAuthorService()
                          .watchForumAuthor(post.author.uid),
                      builder: (BuildContext ctx, snapshot) {
                        final ColorScheme c = Theme.of(ctx).colorScheme;
                        final liveAuthor = snapshot.data;
                        return Text(
                          liveAuthor?.displayName ?? post.author.displayName,
                          style: TextStyle(
                            color: c.onSurface.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 14,
                    color: scheme.onSurface.withValues(alpha: 0.44),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${post.likes}',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.52),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _relativeTime(post.createdAt),
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _threadTypeLabel(String category) {
    final String normalized = category.toLowerCase();
    if (normalized.contains('growth')) return 'Growth Advice';
    if (normalized.contains('game')) return 'Gaming Debate';
    if (normalized.contains('video') || normalized.contains('clip')) {
      return 'Video Discussion';
    }
    if (normalized.contains('setup')) return 'Stream Setup';
    return 'Creator Talk';
  }

  String _relativeTime(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }
}

class _ThreadTypePill extends StatelessWidget {
  const _ThreadTypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ThreadPostAvatar extends StatelessWidget {
  const _ThreadPostAvatar({
    required this.userId,
    required this.fallbackAvatarUrl,
  });

  final String userId;
  final String? fallbackAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: DiscussionAuthorService().watchForumAuthor(userId),
      builder: (context, snapshot) {
        final String? liveAvatarUrl =
            snapshot.data?.avatarUrl ?? fallbackAvatarUrl;
        return StatusAwareAvatar(
          userId: userId,
          avatarURL: liveAvatarUrl,
          radius: 14,
          showOnlineIndicator: true,
        );
      },
    );
  }
}
