import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/discussion_author_service.dart';
import '../../services/unified_avatar_service.dart';

class DiscussionAuthorRow extends StatelessWidget {
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? userId;
  final String? trailingText;
  final double avatarRadius;
  final VoidCallback? onTap;

  const DiscussionAuthorRow({
    super.key,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.userId,
    this.trailingText,
    this.avatarRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == null || userId!.isEmpty) {
      return _buildRow(
        resolvedDisplayName: displayName,
        resolvedUsername: username,
        resolvedAvatarUrl: avatarUrl,
      );
    }

    return StreamBuilder(
      stream: DiscussionAuthorService().watchForumAuthor(userId!),
      builder: (context, snapshot) {
        final liveAuthor = snapshot.data;
        return _buildRow(
          resolvedDisplayName: liveAuthor?.displayName ?? displayName,
          resolvedUsername: liveAuthor?.username ?? username,
          resolvedAvatarUrl: liveAuthor?.avatarUrl ?? avatarUrl,
        );
      },
    );
  }

  Widget _buildRow({
    required String resolvedDisplayName,
    required String resolvedUsername,
    required String? resolvedAvatarUrl,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: _buildAuthorAvatar(resolvedAvatarUrl, avatarRadius),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Text(
                  resolvedDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      '@$resolvedUsername',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (trailingText != null && trailingText!.isNotEmpty)
                    Text(
                      trailingText!,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorAvatar(String? currentAvatarUrl, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: currentAvatarUrl != null && currentAvatarUrl.isNotEmpty
          ? ClipOval(
              child: UnifiedAvatarService().getAvatar(
                imageUrl: currentAvatarUrl,
                radius: radius,
                useProfileViewStyling: false,
                showLoadingIndicator: false,
                errorWidget: _buildPlaceholderAvatar(radius),
              ),
            )
          : _buildPlaceholderAvatar(radius),
    );
  }

  Widget _buildPlaceholderAvatar(double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
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
        size: radius * 1.2,
        color: AppColors.primary,
      ),
    );
  }
}
