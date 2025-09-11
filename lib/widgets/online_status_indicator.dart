import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_status.dart';
import '../providers/status_provider.dart';

/// A reusable online status indicator widget
class OnlineStatusIndicator extends ConsumerWidget {
  final String userId;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final bool showShadow;
  final EdgeInsets? position;

  const OnlineStatusIndicator({
    super.key,
    required this.userId,
    this.size = 12.0,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = 2.0,
    this.showShadow = true,
    this.position,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(userId));
    
    return statusAsync.when(
      data: (presence) {
        if (presence.status == UserStatus.offline) {
          return const SizedBox.shrink();
        }
        
        return _buildIndicator(presence.status);
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildIndicator(UserStatus status) {
    final indicator = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: borderColor ?? Colors.white,
                width: borderWidth,
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: _getStatusColor(status).withValues(alpha:0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );

    if (position != null) {
      return Positioned(
        top: position!.top,
        right: position!.right,
        bottom: position!.bottom,
        left: position!.left,
        child: indicator,
      );
    }

    return indicator;
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }
}

/// A positioned online status indicator for avatars
class AvatarOnlineIndicator extends StatelessWidget {
  final String userId;
  final double avatarSize;
  final double indicatorSize;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final bool showShadow;

  const AvatarOnlineIndicator({
    super.key,
    required this.userId,
    this.avatarSize = 50.0,
    this.indicatorSize = 12.0,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = 2.0,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return OnlineStatusIndicator(
      userId: userId,
      size: indicatorSize,
      showBorder: showBorder,
      borderColor: borderColor,
      borderWidth: borderWidth,
      showShadow: showShadow,
      position: EdgeInsets.only(
        top: avatarSize - indicatorSize - 2,
        right: 0,
      ),
    );
  }
}

/// A simple online status dot
class OnlineStatusDot extends ConsumerWidget {
  final String userId;
  final double size;
  final Color? backgroundColor;

  const OnlineStatusDot({
    super.key,
    required this.userId,
    this.size = 8.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(userId));
    
    return statusAsync.when(
      data: (presence) {
        if (presence.status == UserStatus.offline) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? _getStatusColor(presence.status),
            shape: BoxShape.circle,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }
}
