import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_notification.dart';
import '../models/user.dart';
import '../widgets/optimized_image.dart';
import '../services/auth_service.dart';
// import '../services/relationship_service.dart'; // Temporarily commented out

class ActivityRowView extends ConsumerStatefulWidget {
  final ActivityNotification notification;
  final ValueChanged<User> onProfileTap;
  final ValueChanged<ActivityNotification> onPostTap;

  const ActivityRowView({
    super.key,
    required this.notification,
    required this.onProfileTap,
    required this.onPostTap,
  });

  @override
  ConsumerState<ActivityRowView> createState() => _ActivityRowViewState();
}

class _ActivityRowViewState extends ConsumerState<ActivityRowView> 
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  bool _isPressed = false;

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
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  @override
  Widget build(BuildContext context) {
    // Get actual user management from Riverpod
    final auth = ref.watch(authServiceProvider);
    final currentUserId = auth.currentUser?.id;
    
    // TODO: Implement relationship service
    // For now, use mock data
    const isFollowing = false;
    const isMutualFollow = false;

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
                      ? Colors.white.withValues(alpha:0.25)
                      : Colors.white.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isPressed
                        ? Colors.white.withValues(alpha:0.5)
                        : Colors.white.withValues(alpha:0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha:0.1),
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
                        _buildActionItem(isFollowing, isMutualFollow, currentUserId),
                      ],
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
                              color: Colors.black.withValues(alpha:0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onProfileTap(widget.notification.user);
      },
      child: Stack(
        children: [
          OptimizedAvatar(
            imageUrl: widget.notification.user.avatarURL,
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha:0.2),
            child: Icon(
              Icons.person,
              color: Colors.white.withValues(alpha:0.7),
              size: 24,
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
                    color: Colors.white.withValues(alpha:0.9),
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
                  color: Colors.white.withValues(alpha:0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getTimestampString(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.6),
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

  Widget _buildActionItem(bool isFollowing, bool isMutualFollow, String? currentUserId) {
    if (widget.notification.postThumbnailUrl != null) {
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
              color: Colors.white.withValues(alpha:0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: OptimizedImage(
              imageUrl: widget.notification.postThumbnailUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: Container(
                color: Colors.white.withValues(alpha:0.1),
                child: Icon(
                  Icons.photo,
                  color: Colors.white.withValues(alpha:0.6),
                  size: 20,
                ),
              ),
              errorWidget: Container(
                color: Colors.white.withValues(alpha:0.1),
                child: Icon(
                  Icons.photo,
                  color: Colors.white.withValues(alpha:0.6),
                  size: 20,
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
                color: const Color(0xFF9248D2).withValues(alpha:0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
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
    }
  }

  void _handleFollowAction(bool isFollowing, bool isMutualFollow) async {
    try {
      // TODO: Implement actual follow/unfollow logic with relationship service
      // For now, show a snackbar indicating the action
      final action = isFollowing ? 'unfollow' : 'follow';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$action action will be implemented soon'),
          backgroundColor: const Color(0xFF9248D2),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
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
