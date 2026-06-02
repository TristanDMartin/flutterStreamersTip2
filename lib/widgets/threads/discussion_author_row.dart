import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/discussion_author_service.dart';
import '../../utils/avatar_url_resolver.dart';
import '../status_aware_avatar.dart';

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
        context: context,
        avatarUserId: null,
        resolvedDisplayName: displayName,
        resolvedUsername: username,
        resolvedAvatarUrl: avatarUrl,
      );
    }

    return StreamBuilder(
      stream: DiscussionAuthorService().watchForumAuthor(userId!),
      builder: (BuildContext context, snapshot) {
        final liveAuthor = snapshot.data;
        return _buildRow(
          context: context,
          avatarUserId: userId,
          resolvedDisplayName: liveAuthor?.displayName ?? displayName,
          resolvedUsername: liveAuthor?.username ?? username,
          resolvedAvatarUrl: liveAuthor?.avatarUrl ?? avatarUrl,
        );
      },
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required String? avatarUserId,
    required String resolvedDisplayName,
    required String resolvedUsername,
    required String? resolvedAvatarUrl,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: _buildLeadingAvatar(avatarUserId, resolvedAvatarUrl),
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
                  style: TextStyle(
                    color: scheme.onSurface,
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
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (trailingText != null && trailingText!.isNotEmpty)
                    Text(
                      trailingText!,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.45),
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

  Widget _buildLeadingAvatar(String? uid, String? resolvedAvatarUrl) {
    if (uid != null && uid.isNotEmpty) {
      return StatusAwareAvatar(
        userId: uid,
        avatarURL: resolvedAvatarUrl,
        radius: avatarRadius,
        showOnlineIndicator: true,
      );
    }
    final String? url = normalizeAvatarPhotoUrl(resolvedAvatarUrl);
    if (url != null && url.isNotEmpty) {
      final double d = avatarRadius * 2;
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: d,
          height: d,
          fit: BoxFit.cover,
          errorWidget: (BuildContext c, String u, Object e) =>
              _buildPlaceholderAvatar(avatarRadius),
        ),
      );
    }
    return _buildPlaceholderAvatar(avatarRadius);
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
