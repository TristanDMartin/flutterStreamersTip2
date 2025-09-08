import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_service.dart';
import '../services/notification_service.dart';

final globalVideoServiceProvider = Provider<VideoService>((ref) {
  return VideoService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
