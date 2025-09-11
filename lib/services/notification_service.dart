class NotificationService {
  bool _hasUnreadNotifications = false;

  bool get hasUnreadNotifications => _hasUnreadNotifications;

  Future<void> markAllNotificationsAsRead() async {
    // Mock implementation - replace with actual Firestore logic
    await Future.delayed(const Duration(milliseconds: 100));
    _hasUnreadNotifications = false;
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // Mock implementation - replace with actual notification logic
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    // Mock implementation - replace with actual Firestore logic
    await Future.delayed(const Duration(milliseconds: 100));
    
    return [
      {
        'id': 'notification_1',
        'title': 'New Follower',
        'body': 'Someone started following you!',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        'isRead': false,
        'type': 'follow',
      },
      {
        'id': 'notification_2',
        'title': 'Video Liked',
        'body': 'Your video received a like!',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'isRead': true,
        'type': 'like',
      },
    ];
  }

  // No-op handlers to satisfy EventTriggerService calls. Replace with real logic.
  Future<void> handleFollowEvent({
    required String followerId,
    required String followingId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> handleLikeEvent({
    required String likerId,
    required String videoOwnerId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> handleCommentEvent({
    required String commenterId,
    required String videoOwnerId,
    required String videoId,
    required String commentText,
    String? postThumbnailUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> handleTagEvent({
    required String taggerId,
    required String taggedUserId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> processBatchNotifications(List<Map<String, dynamic>> notifications) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
