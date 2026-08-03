import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_status.dart';
import '../providers/status_provider.dart';
import '../utils/avatar_url_resolver.dart';

/// StatusAwareAvatar - Displays user avatar with real-time online status indicator
///
/// Features:
/// - Real-time status updates via Riverpod
/// - Green dot for online users
/// - Colored dots for other statuses (busy, dnd, streaming)
/// - Fallback to default icon when no avatar
/// - Consistent styling across the app
class StatusAwareAvatar extends ConsumerWidget {
  final String userId;
  final String? avatarURL;
  final double radius;
  final bool showOnlineIndicator;
  final Color? backgroundColor;
  final Widget? placeholder;

  const StatusAwareAvatar({
    super.key,
    required this.userId,
    this.avatarURL,
    this.radius = 20,
    this.showOnlineIndicator = true,
    this.backgroundColor,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(userId));
    final String? resolvedUrl =
        isNetworkAvatarUrl(avatarURL) ? normalizeAvatarPhotoUrl(avatarURL) : null;
    final int cachePx = (radius * 2 * 2).round().clamp(48, 256);
    final double diameter = radius * 2;
    final double indicatorSize = (radius * 0.42).clamp(8.0, 14.0);
    final double indicatorBorder = radius < 18 ? 1.5 : 2.0;
    final Widget fallback = placeholder ??
        Icon(
          Icons.person,
          color: Colors.white.withValues(alpha: 0.7),
          size: radius * 0.8,
        );

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
            ),
            child: ClipOval(
              child: resolvedUrl != null && resolvedUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: resolvedUrl,
                      fit: BoxFit.cover,
                      width: diameter,
                      height: diameter,
                      memCacheWidth: cachePx,
                      memCacheHeight: cachePx,
                      fadeInDuration: const Duration(milliseconds: 120),
                      placeholder: (BuildContext context, String url) =>
                          Center(child: fallback),
                      errorWidget:
                          (BuildContext context, String url, Object error) =>
                              Center(child: fallback),
                    )
                  : Center(child: fallback),
            ),
          ),
          if (showOnlineIndicator)
            statusAsync.when(
              data: (presence) {
                if (presence.status == UserStatus.offline) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: indicatorSize,
                    height: indicatorSize,
                    decoration: BoxDecoration(
                      color: _getStatusColor(presence.status),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: indicatorBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(presence.status)
                              .withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF10B981); // Green
      case UserStatus.busy:
        return const Color(0xFFF59E0B); // Orange
      case UserStatus.away:
        return const Color(0xFFEF4444); // Red
      case UserStatus.streaming:
        return const Color(0xFF8B5CF6); // Purple
      case UserStatus.offline:
        return const Color(0xFF6B7280); // Gray
    }
  }
}
