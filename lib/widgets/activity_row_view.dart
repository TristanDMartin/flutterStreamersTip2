import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';
import '../models/activity_notification.dart';
import '../models/user.dart';
import '../widgets/optimized_image.dart';
import '../services/auth_service.dart';
import '../services/follows_service.dart';
import '../providers/follow_refresh_provider.dart';

class ActivityRowView extends ConsumerStatefulWidget {
  final ActivityNotification notification;
  final ValueChanged<User> onProfileTap;
  final ValueChanged<ActivityNotification> onPostTap;
  final ValueChanged<ActivityNotification>? onCardTap;

  const ActivityRowView({
    super.key,
    required this.notification,
    required this.onProfileTap,
    required this.onPostTap,
    this.onCardTap,
  });

  @override
  ConsumerState<ActivityRowView> createState() => _ActivityRowViewState();
}

class _ActivityRowViewState extends ConsumerState<ActivityRowView>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  bool _isPressed = false;

  // Follow status state
  bool _isFollowing = false;
  bool _isFollowedBy = false;
  bool _isLoadingFollowStatus = true;

  final FollowsService _followsService = FollowsService();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController.forward();
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    final auth = ref.read(authServiceProvider);
    final currentUserId = auth.currentUser?.id;

    if (currentUserId == null || widget.notification.user.id == currentUserId) {
      setState(() {
        _isLoadingFollowStatus = false;
      });
      return;
    }

    try {
      // Load all follow status in parallel for efficiency
      final results = await Future.wait([
        _followsService.isFollowing(widget.notification.user.id),
        _followsService.isFollowedBy(widget.notification.user.id),
      ]);

      if (mounted) {
        setState(() {
          _isFollowing = results[0];
          _isFollowedBy = results[1];
          _isLoadingFollowStatus = false;
        });

        debugPrint(
            '✅ ActivityRowView: Follow status loaded - following: ${results[0]}, followedBy: ${results[1]}');
      }
    } catch (e) {
      debugPrint('❌ ActivityRowView: Error loading follow status: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollowStatus = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool get _canOpenActorProfile {
    final id = widget.notification.user.id.toLowerCase().trim();
    final username = widget.notification.user.username.toLowerCase().trim();
    return id.isNotEmpty &&
        !id.contains('system') &&
        username != 'streamerstip' &&
        username != 'system';
  }

  void _handleActorTap() {
    HapticFeedback.lightImpact();
    if (_canOpenActorProfile) {
      widget.onProfileTap(widget.notification.user);
    } else {
      widget.onCardTap?.call(widget.notification);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    // Get actual user management from Riverpod
    final auth = ref.watch(authServiceProvider);
    final currentUserId = auth.currentUser?.id;

    // Calculate follow status
    final isFollowing = _isFollowing;
    final isMutualFollow = _isFollowing && _isFollowedBy;

    return FadeTransition(
      opacity: _fadeController,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _isPressed = true;
          });
          _scaleController.forward();
        },
        onTapUp: (_) {
          setState(() {
            _isPressed = false;
          });
          _scaleController.reverse();
          // Handle card tap
          if (widget.onCardTap != null) {
            widget.onCardTap!(widget.notification);
          }
        },
        onTapCancel: () {
          setState(() {
            _isPressed = false;
          });
          _scaleController.reverse();
        },
        child: AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 - (_scaleController.value * 0.02),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _isPressed
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : shell.surfaceCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _isPressed
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : shell.surfaceCardBorder,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shell.shadowSoft,
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar with ring
                        _buildAvatarWithRing(context, shell),

                        const SizedBox(width: 12),

                        // Notification text
                        Expanded(
                          child: _buildNotificationText(shell),
                        ),

                        const SizedBox(width: 10),

                        // Action item
                        Flexible(
                          flex: 0,
                          child: _buildActionItem(
                            context,
                            shell,
                            isFollowing,
                            isMutualFollow,
                            currentUserId,
                          ),
                        ),
                      ],
                    ),

                    // Unread indicator
                    if (widget.notification.status == 'pending')
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                    // Processing indicator overlay
                    if (widget.notification.status == 'processing')
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  shell.onChrome,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarWithRing(
    BuildContext context,
    StSupportShellStyle shell,
  ) {
    final user = widget.notification.user;
    final avatarURL = user.avatarURL ?? '';
    final Color ringOuter = Theme.of(context).colorScheme.surface;

    return GestureDetector(
      onTap: _handleActorTap,
      child: Stack(
        children: [
          // User avatar - Always show user's avatar using UnifiedAvatarService
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: shell.surfaceCardBorder.withValues(alpha: 0.8),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarURL.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarURL,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 180),
                      placeholder: (_, __) => Container(
                        width: 40,
                        height: 40,
                        color: shell.skeletonFill,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: shell.skeletonLineDim,
                        child: Icon(
                          Icons.person_rounded,
                          color: shell.iconDim,
                          size: 22,
                        ),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: shell.skeletonLineDim,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: shell.iconDim,
                        size: 22,
                      ),
                    ),
            ),
          ),

          // Notification type ring
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _getNotificationTypeColor(widget.notification.type),
                width: 2,
              ),
            ),
          ),

          // Online status indicator
          if (widget.notification.user.onlineStatus == 'online')
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringOuter,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationText(StSupportShellStyle shell) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 15,
              color: shell.onChrome.withValues(alpha: 0.96),
              height: 1.32,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleActorTap,
                  child: Text(
                    widget.notification.user.displayName,
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.32,
                    ),
                  ),
                ),
              ),
              TextSpan(
                text: ' ${_getNotificationMessage()}',
                style: TextStyle(
                  color: shell.muted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleActorTap,
                child: Text(
                  '@${widget.notification.user.username}',
                  style: TextStyle(
                    color: shell.mutedStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: shell.iconDim,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getTimestampString(),
              style: TextStyle(
                color: shell.mutedStrong,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    StSupportShellStyle shell,
    bool isFollowing,
    bool isMutualFollow,
    String? currentUserId,
  ) {
    if (widget.notification.postThumbnailUrl != null &&
        widget.notification.postThumbnailUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPostTap(widget.notification);
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: shell.surfaceCardBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: OptimizedImage(
              imageUrl: widget.notification.postThumbnailUrl!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: Container(
                color: shell.skeletonFill,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: shell.muted,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.photo,
                      color: shell.iconDim,
                      size: 12,
                    ),
                  ],
                ),
              ),
              errorWidget: Container(
                color: shell.skeletonFill,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: shell.muted,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.photo,
                      color: shell.iconDim,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else if (widget.notification.type == ActivityNotificationType.follow &&
        widget.notification.user.id != currentUserId) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _handleFollowAction(isFollowing, isMutualFollow);
        },
        child: AbsorbPointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoadingFollowStatus
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    _getFollowButtonText(
                      isFollowing: isFollowing,
                      isMutualFollow: isMutualFollow,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _getNotificationMessage() {
    switch (widget.notification.type) {
      case ActivityNotificationType.like:
        return 'liked your post';
      case ActivityNotificationType.follow:
        return 'started following you';
      case ActivityNotificationType.comment:
        if (widget.notification.commentText != null) {
          return 'commented: "${widget.notification.commentText}"';
        } else {
          return 'commented on your post';
        }
      case ActivityNotificationType.tag:
        return 'tagged you in their video';
      case ActivityNotificationType.mention:
        if (widget.notification.commentText != null) {
          return 'mentioned you: "${widget.notification.commentText}"';
        } else {
          return 'mentioned you in a comment';
        }
      case ActivityNotificationType.commentReply:
        if (widget.notification.commentText != null) {
          return 'replied to your comment: "${widget.notification.commentText}"';
        } else {
          return 'replied to your comment';
        }
      case ActivityNotificationType.newVideo:
        return 'posted a new video';
      case ActivityNotificationType.milestone:
        if (widget.notification.milestoneType != null &&
            widget.notification.milestoneValue != null) {
          final formattedValue = _formatMilestone(
            widget.notification.milestoneValue!,
          );
          return 'Your video reached $formattedValue ${widget.notification.milestoneType}! 🎉';
        } else {
          return 'reached a milestone! 🎉';
        }
      case ActivityNotificationType.liveStream:
        if (widget.notification.commentText != null) {
          return widget.notification.commentText!;
        } else {
          return 'is live now! 🔴';
        }
      case ActivityNotificationType.adminBroadcast:
        if (widget.notification.commentText != null) {
          return widget.notification.commentText!;
        } else {
          return 'Admin announcement';
        }
    }
  }

  String _getTimestampString() {
    final now = DateTime.now();
    final difference = now.difference(widget.notification.timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  Color _getNotificationTypeColor(ActivityNotificationType type) {
    switch (type) {
      case ActivityNotificationType.like:
        return const Color(0xFFE91E63); // Pink
      case ActivityNotificationType.follow:
        return const Color(0xFF2196F3); // Blue
      case ActivityNotificationType.comment:
        return const Color(0xFF4CAF50); // Green
      case ActivityNotificationType.tag:
        return const Color(0xFFFF9800); // Orange
      case ActivityNotificationType.mention:
        return const Color(0xFF9C27B0); // Purple
      case ActivityNotificationType.commentReply:
        return const Color(0xFF00BCD4); // Cyan
      case ActivityNotificationType.newVideo:
        return AppColors.primary;
      case ActivityNotificationType.milestone:
        return const Color(0xFFFFC107); // Amber/Gold
      case ActivityNotificationType.liveStream:
        return const Color(0xFFF44336); // Red (live)
      case ActivityNotificationType.adminBroadcast:
        return const Color(0xFF607D8B); // Blue grey
    }
  }

  String _formatMilestone(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toString();
    }
  }

  String _getFollowButtonText({
    required bool isFollowing,
    required bool isMutualFollow,
  }) {
    if (isMutualFollow) {
      return 'Connected';
    }
    if (isFollowing) {
      return 'Following';
    }
    return 'Follow';
  }

  void _handleFollowAction(bool isFollowing, bool isMutualFollow) async {
    try {
      setState(() {
        _isLoadingFollowStatus = true;
      });

      bool success;

      if (isFollowing) {
        // Unfollow the user
        success =
            await _followsService.unfollowUser(widget.notification.user.id);
        if (success) {
          setState(() {
            _isFollowing = false;
            _isLoadingFollowStatus = false;
          });
        }
      } else {
        // Follow the user
        success = await _followsService.followUser(widget.notification.user.id);
        if (success) {
          setState(() {
            _isFollowing = true;
            _isLoadingFollowStatus = false;
          });
          // Reload follow status to check if they now follow you back
          await _loadFollowStatus();
        }
      }

      if (success) {
        ref.read(followRefreshProvider.notifier).state++;
      }

      if (mounted) {
        final username = widget.notification.user.username;
        final message = success
            ? (isFollowing
                ? 'Unfollowed @$username'
                : (isMutualFollow
                    ? 'Stayed connected with @$username'
                    : 'Following @$username'))
            : 'Unable to update follow status for @$username';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ ActivityRowView: Error handling follow action: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollowStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
