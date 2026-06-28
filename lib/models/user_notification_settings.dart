enum NotificationDeliveryType {
  follow,
  like,
  comment,
  mention,
  tag,
  message,
  live,
}

class UserNotificationSettings {
  const UserNotificationSettings({
    this.pushNotifications = true,
    this.followNotifications = true,
    this.likeNotifications = true,
    this.commentNotifications = true,
    this.mentionNotifications = true,
    this.tagNotifications = true,
    this.messageNotifications = true,
    this.liveNotifications = true,
  });

  static const UserNotificationSettings defaults = UserNotificationSettings();

  final bool pushNotifications;
  final bool followNotifications;
  final bool likeNotifications;
  final bool commentNotifications;
  final bool mentionNotifications;
  final bool tagNotifications;
  final bool messageNotifications;
  final bool liveNotifications;

  factory UserNotificationSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return UserNotificationSettings.defaults;
    }
    return UserNotificationSettings(
      pushNotifications: data['pushNotifications'] as bool? ?? true,
      followNotifications: data['follows'] as bool? ?? true,
      likeNotifications: data['likes'] as bool? ?? true,
      commentNotifications: data['comments'] as bool? ?? true,
      mentionNotifications: data['mentions'] as bool? ?? true,
      tagNotifications: data['tags'] as bool? ?? true,
      messageNotifications: data['messages'] as bool? ?? true,
      liveNotifications: data['live'] as bool? ?? true,
    );
  }

  bool allowsInApp(NotificationDeliveryType type) {
    switch (type) {
      case NotificationDeliveryType.follow:
        return followNotifications;
      case NotificationDeliveryType.like:
        return likeNotifications;
      case NotificationDeliveryType.comment:
        return commentNotifications;
      case NotificationDeliveryType.mention:
        return mentionNotifications;
      case NotificationDeliveryType.tag:
        return tagNotifications;
      case NotificationDeliveryType.message:
        return messageNotifications;
      case NotificationDeliveryType.live:
        return liveNotifications;
    }
  }

  String storageKey(NotificationDeliveryType type) {
    switch (type) {
      case NotificationDeliveryType.follow:
        return 'follows';
      case NotificationDeliveryType.like:
        return 'likes';
      case NotificationDeliveryType.comment:
        return 'comments';
      case NotificationDeliveryType.mention:
        return 'mentions';
      case NotificationDeliveryType.tag:
        return 'tags';
      case NotificationDeliveryType.message:
        return 'messages';
      case NotificationDeliveryType.live:
        return 'live';
    }
  }
}
