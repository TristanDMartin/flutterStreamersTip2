import 'package:flutter/material.dart';
import '../../models/forum_post.dart';
import '../../constants/app_colors.dart';
import '../../services/discussion_author_service.dart';
import '../../services/unified_avatar_service.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
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
                            color: AppColors.textPrimary,
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
                          color: AppColors.textSecondary,
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
                color: Colors.black.withValues(alpha: 0.16),
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
                      builder: (context, snapshot) {
                        final liveAuthor = snapshot.data;
                        return Text(
                          liveAuthor?.displayName ?? post.author.displayName,
                          style: TextStyle(
                            color: AppColors.textSecondary,
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
        final liveAvatarUrl = snapshot.data?.avatarUrl ?? fallbackAvatarUrl;
        return _buildAvatar(liveAvatarUrl);
      },
    );
  }

  Widget _buildAvatar(String? avatarUrl) {
    const double avatarSize = 28.0;

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: UnifiedAvatarService().getAvatar(
                imageUrl: avatarUrl,
                radius: avatarSize / 2,
                useProfileViewStyling: false,
                showLoadingIndicator: false,
                errorWidget: _buildPlaceholderAvatar(avatarSize),
              ),
            )
          : _buildPlaceholderAvatar(avatarSize),
    );
  }

  Widget _buildPlaceholderAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.secondary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: AppColors.primary,
      ),
    );
  }
}
