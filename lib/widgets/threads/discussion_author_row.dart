import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class DiscussionAuthorRow extends StatelessWidget {
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? trailingText;
  final double avatarRadius;
  final VoidCallback? onTap;

  const DiscussionAuthorRow({
    super.key,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.trailingText,
    this.avatarRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: _buildAuthorAvatar(avatarUrl, avatarRadius),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Text(
                  displayName,
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
                      '@$username',
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
              child: CachedNetworkImage(
                imageUrl: currentAvatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 2 * 2).round(),
                memCacheHeight: (radius * 2 * 2).round(),
                placeholder: (context, url) => _buildPlaceholderAvatar(radius),
                errorWidget: (context, url, error) =>
                    _buildPlaceholderAvatar(radius),
                fadeInDuration: const Duration(milliseconds: 200),
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
