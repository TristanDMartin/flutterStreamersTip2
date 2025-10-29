import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_notification.dart';
import '../models/user.dart';
import '../widgets/optimized_image.dart';
import '../services/auth_service.dart';
import '../services/follows_service.dart';
// import '../services/relationship_service.dart'; // Temporarily commented out

class ActivityRowView extends ConsumerStatefulWidget {
  final ActivityNotification notification;
  final ValueChanged<User> onProfileTap;
  final ValueChanged<ActivityNotification> onPostTap;
  final ValueChanged<User>? onFollowAction;
  final ValueChanged<ActivityNotification>? onCardTap;

  const ActivityRowView({
    super.key,
    required this.notification,
    required this.onProfileTap,
    required this.onPostTap,
    this.onFollowAction,
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

  @override
  Widget build(BuildContext context) {
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
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isPressed
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isPressed
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        // Avatar with ring
                        _buildAvatarWithRing(),

                        const SizedBox(width: 16),

                        // Notification text
                        Expanded(
                          child: _buildNotificationText(),
                        ),

                        const SizedBox(width: 16),

                        // Action item
                        _buildActionItem(
                            isFollowing, isMutualFollow, currentUserId),
                      ],
                    ),

                    // Unread indicator
                    if (widget.notification.status == 'pending')
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF9248D2),
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
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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

  Widget _buildAvatarWithRing() {
    final user = widget.notification.user;
    final avatarURL = user.avatarURL ?? '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onProfileTap(widget.notification.user);
      },
      child: Stack(
        children: [
          // User avatar - Always show user's avatar using UnifiedAvatarService
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              // No background color - let the avatar show through
            ),
            child: ClipOval(
              child: avatarURL.isNotEmpty
                  ? Image.network(
                      avatarURL,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.grey[600],
                        size: 20,
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
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationText() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onProfileTap(widget.notification.user);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: widget.notification.user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ' ${_getNotificationMessage()}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
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
              Text(
                '@${widget.notification.user.username}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getTimestampString(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
      bool isFollowing, bool isMutualFollow, String? currentUserId) {
    if (widget.notification.postThumbnailUrl != null &&
        widget.notification.postThumbnailUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPostTap(widget.notification);
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: OptimizedImage(
              imageUrl: widget.notification.postThumbnailUrl!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: Container(
                color: Colors.white.withValues(alpha: 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.photo,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 12,
                    ),
                  ],
                ),
              ),
              errorWidget: Container(
                color: Colors.white.withValues(alpha: 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.photo,
                      color: Colors.white.withValues(alpha: 0.4),
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
          if (widget.onFollowAction != null) {
            widget.onFollowAction!(widget.notification.user);
          } else {
            _handleFollowAction(isFollowing, isMutualFollow);
          }
        },
        child: AbsorbPointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMutualFollow
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF9248D2), // Primary purple
                        Color(0xFF7768DF), // Secondary purple
                        Color(0xFF1670DE), // Blue
                        Color(0xFF3C8BD6), // Lighter blue
                        Color(0xFF4897D2), // Lightest blue
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFF9248D2), // Primary purple
                        Color(0xFF7768DF), // Secondary purple
                        Color(0xFF1670DE), // Blue
                        Color(0xFF3C8BD6), // Lighter blue
                        Color(0xFF4897D2), // Lightest blue
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9248D2).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoadingFollowStatus
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isMutualFollow
                        ? 'Connected'
                        : (isFollowing ? 'Following' : 'Follow back'),
                    style: const TextStyle(
                      color: Colors.white,
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
        return const Color(0xFF9248D2); // StreamersTip Purple
      case ActivityNotificationType.milestone:
        return const Color(0xFFFFC107); // Amber/Gold
      case ActivityNotificationType.liveStream:
        return const Color(0xFFF44336); // Red (live)
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

  void _handleFollowAction(bool isFollowing, bool isMutualFollow) async {
    try {
      setState(() {
        _isLoadingFollowStatus = true;
      });

      bool success;
      final action = isFollowing ? 'Unfollowed' : 'Followed';

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action @${widget.notification.user.username}'),
            backgroundColor:
                success ? Colors.green.shade700 : Colors.red.shade700,
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
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
