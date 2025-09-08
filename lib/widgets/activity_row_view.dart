import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_notification.dart';
import '../models/user.dart';

class ActivityRowView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Get actual user manager
    const isFollowing = false; // userManager.isFollowing(notification.user.id)
    const isMutualFollow = false; // isFollowing && userManager.isFollowedBy(notification.user.id)

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Avatar with ring
              _buildAvatarWithRing(),
              
              const SizedBox(width: 12),
              
              // Notification text
              Expanded(
                child: _buildNotificationText(),
              ),
              
              const SizedBox(width: 12),
              
              // Action item
              _buildActionItem(isFollowing, isMutualFollow),
            ],
          ),
          
          // Processing indicator overlay
          if (notification.status == 'processing')
            const Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithRing() {
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.grey,
            size: 24,
          ),
        ),
        
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getNotificationTypeColor(notification.type),
              width: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationText() {
    return GestureDetector(
      onTap: () => onProfileTap(notification.user),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
          children: [
            TextSpan(
              text: notification.user.username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: ' ${_getNotificationMessage()} • ${_getTimestampString()}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildActionItem(bool isFollowing, bool isMutualFollow) {
    if (notification.postThumbnailUrl != null) {
      return GestureDetector(
        onTap: () => onPostTap(notification),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.network(
              notification.postThumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.withValues(alpha: 0.3),
                  child: const Icon(
                    Icons.photo,
                    color: Colors.grey,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else if (notification.type == ActivityNotificationType.follow &&
               notification.user.id != 'currentUserId') { // TODO: Get actual current user ID
      return GestureDetector(
        onTap: () {
          // TODO: Implement follow/unfollow logic
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.purple],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isMutualFollow 
                ? 'Connected' 
                : (isFollowing ? 'Following' : 'Follow back'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  String _getNotificationMessage() {
    switch (notification.type) {
      case ActivityNotificationType.like:
        return 'liked your post';
      case ActivityNotificationType.follow:
        return 'started following you';
      case ActivityNotificationType.comment:
        if (notification.commentText != null) {
          return 'commented: "${notification.commentText}"';
        } else {
          return 'commented on your post';
        }
      case ActivityNotificationType.tag:
        return 'tagged you in their video';
      case ActivityNotificationType.mention:
        if (notification.commentText != null) {
          return 'mentioned you: "${notification.commentText}"';
        } else {
          return 'mentioned you in a comment';
        }
    }
  }

  String _getTimestampString() {
    final now = DateTime.now();
    final difference = now.difference(notification.timestamp);
    
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
        return Colors.red;
      case ActivityNotificationType.follow:
        return Colors.blue;
      case ActivityNotificationType.comment:
        return Colors.green;
      case ActivityNotificationType.tag:
        return Colors.orange;
      case ActivityNotificationType.mention:
        return Colors.purple;
    }
  }
}
