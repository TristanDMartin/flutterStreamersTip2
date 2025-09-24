import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/scheduled_post.dart';

class SchedulingNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // Handle navigation based on payload
      // This would typically involve navigating to the ManagePostsView
      print('Notification tapped: $payload');
    }
  }

  // Schedule a notification for when a post is scheduled
  static Future<void> schedulePostScheduledNotification({
    required String postId,
    required String caption,
    required DateTime scheduledAt,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'scheduled_posts',
      'Scheduled Posts',
      channelDescription: 'Notifications for scheduled posts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      postId.hashCode,
      'Post Scheduled',
      'Your post "${_truncateText(caption, 50)}" is scheduled for ${_formatDateTime(scheduledAt)}',
      details,
      payload: 'scheduled_post:$postId',
    );
  }

  // Schedule a notification 10 minutes before publishing
  static Future<void> schedulePrePublishNotification({
    required String postId,
    required String caption,
    required DateTime scheduledAt,
  }) async {
    await initialize();

    final notificationTime = scheduledAt.subtract(const Duration(minutes: 10));
    if (notificationTime.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pre_publish',
      'Pre-Publish Reminders',
      channelDescription: 'Notifications before posts are published',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      postId.hashCode + 1000, // Different ID to avoid conflicts
      'Post Publishing Soon',
      'Your post "${_truncateText(caption, 50)}" will be published in 10 minutes',
      tz.TZDateTime.from(notificationTime, tz.local),
      details,
      payload: 'pre_publish:$postId',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Schedule a notification when a post is published
  static Future<void> schedulePostPublishedNotification({
    required String postId,
    required String caption,
    required List<PlatformConfig> platforms,
  }) async {
    await initialize();

    final successfulPlatforms = platforms
        .where((p) => p.status == PlatformStatus.published)
        .map((p) => _getPlatformName(p.key))
        .join(', ');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'post_published',
      'Post Published',
      channelDescription: 'Notifications when posts are published',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      postId.hashCode + 2000, // Different ID to avoid conflicts
      'Post Published Successfully',
      'Your post "${_truncateText(caption, 30)}" was published to $successfulPlatforms',
      details,
      payload: 'post_published:$postId',
    );
  }

  // Schedule a notification when a post fails to publish
  static Future<void> schedulePostFailedNotification({
    required String postId,
    required String caption,
    required List<PlatformConfig> platforms,
  }) async {
    await initialize();

    final failedPlatforms = platforms
        .where((p) => p.status == PlatformStatus.failed)
        .map((p) => _getPlatformName(p.key))
        .join(', ');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'post_failed',
      'Post Failed',
      channelDescription: 'Notifications when posts fail to publish',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      postId.hashCode + 3000, // Different ID to avoid conflicts
      'Post Publishing Failed',
      'Your post "${_truncateText(caption, 30)}" failed to publish to $failedPlatforms',
      details,
      payload: 'post_failed:$postId',
    );
  }

  // Schedule a notification when platform needs re-authentication
  static Future<void> scheduleReauthRequiredNotification({
    required String postId,
    required String platformName,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reauth_required',
      'Re-authentication Required',
      channelDescription: 'Notifications when platform re-authentication is needed',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      postId.hashCode + 4000, // Different ID to avoid conflicts
      'Re-authentication Required',
      'Your $platformName connection needs to be renewed to continue publishing',
      details,
      payload: 'reauth_required:$postId:$platformName',
    );
  }

  // Cancel all notifications for a specific post
  static Future<void> cancelPostNotifications(String postId) async {
    await initialize();
    
    await _notifications.cancel(postId.hashCode);
    await _notifications.cancel(postId.hashCode + 1000);
    await _notifications.cancel(postId.hashCode + 2000);
    await _notifications.cancel(postId.hashCode + 3000);
    await _notifications.cancel(postId.hashCode + 4000);
  }

  // Cancel all scheduled notifications
  static Future<void> cancelAllNotifications() async {
    await initialize();
    await _notifications.cancelAll();
  }

  // Get pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await initialize();
    return await _notifications.pendingNotificationRequests();
  }

  // Schedule a custom notification
  static Future<void> scheduleCustomNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'custom',
      'Custom Notifications',
      channelDescription: 'Custom scheduled notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      details,
      payload: payload,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Helper methods
  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'now';
    }
  }

  static String _getPlatformName(String platformKey) {
    switch (platformKey) {
      case 'youtube':
        return 'YouTube';
      case 'tiktok':
        return 'TikTok';
      case 'instagram':
        return 'Instagram';
      case 'x':
        return 'X (Twitter)';
      case 'facebook':
        return 'Facebook';
      case 'linkedin':
        return 'LinkedIn';
      default:
        return platformKey;
    }
  }
}
