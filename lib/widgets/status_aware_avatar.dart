import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';

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
    // Watch user's online status
    final statusAsync = ref.watch(userStatusProvider(userId));

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar
          CircleAvatar(
            radius: radius,
            backgroundColor:
                backgroundColor ?? Colors.white.withValues(alpha: 0.2),
            backgroundImage: avatarURL != null && avatarURL!.isNotEmpty
                ? NetworkImage(avatarURL!)
                : null,
            child: avatarURL == null || avatarURL!.isEmpty
                ? (placeholder ??
                    Icon(
                      Icons.person,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: radius * 0.8,
                    ))
                : null,
          ),

          // Online Status Indicator
          if (showOnlineIndicator)
            statusAsync.when(
              data: (presence) {
                // Only show indicator for non-offline statuses
                if (presence.status == UserStatus.offline) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: radius * 0.35,
                    height: radius * 0.35,
                    decoration: BoxDecoration(
                      color: _getStatusColor(presence.status),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: 2,
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
      case UserStatus.dnd:
        return const Color(0xFFEF4444); // Red
      case UserStatus.streaming:
        return const Color(0xFF8B5CF6); // Purple
      case UserStatus.offline:
        return const Color(0xFF6B7280); // Gray
    }
  }
}
