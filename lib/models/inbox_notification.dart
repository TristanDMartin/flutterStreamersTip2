import 'package:freezed_annotation/freezed_annotation.dart';

part 'inbox_notification.freezed.dart';
part 'inbox_notification.g.dart';

@freezed
sealed class InboxNotification with _$InboxNotification {
  const factory InboxNotification({
    required String id,
    required String text,
    required String timestamp,
    required NotificationType type,
  }) = _InboxNotification;

  factory InboxNotification.fromJson(Map<String, dynamic> json) => _$InboxNotificationFromJson(json);
}

enum NotificationType {
  like,
  comment,
  follow,
  scan;

  String get icon {
    switch (this) {
      case NotificationType.like:
        return 'heart.fill';
      case NotificationType.comment:
        return 'message.fill';
      case NotificationType.follow:
        return 'person.fill.badge.plus';
      case NotificationType.scan:
        return 'qrcode.viewfinder';
    }
  }

  String get rawValue {
    switch (this) {
      case NotificationType.like:
        return 'like';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.scan:
        return 'scan';
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'scan':
        return NotificationType.scan;
      default:
        return NotificationType.like; // Default fallback
    }
  }
}
