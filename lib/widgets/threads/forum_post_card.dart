import 'package:flutter/material.dart';
import '../../core/theme/support_shell_style.dart';
import '../../models/forum_post.dart';
import '../../constants/app_colors.dart';
import '../../services/discussion_author_service.dart';
import '../status_aware_avatar.dart';

/// Card widget for displaying a forum post in the grid
class ForumPostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onTap;

  const ForumPostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: shell.isLight
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
          color: shell.isLight ? shell.surfaceCard : null,
          border: Border.all(
            color: shell.surfaceCardBorder,
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shell.isLight
                  ? scheme.shadow.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient accent
            Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((post.categoryDisplayName ?? '').isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          post.categoryDisplayName!,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Title
                    Text(
                      post.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Content preview
                    Expanded(
                      child: Text(
                        post.content,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.62),
                          fontSize: 13,
                          height: 1.45,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer with author and stats
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: shell.isLight
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.65)
                    : Colors.black.withValues(alpha: 0.16),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Avatar - Always show, even if URL is missing
                  _ThreadPostAvatar(
                    userId: post.author.uid,
                    fallbackAvatarUrl: post.author.avatarUrl,
                  ),
                  const SizedBox(width: 8),
                  // Author name
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
                            color: c.onSurface.withValues(alpha: 0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
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
