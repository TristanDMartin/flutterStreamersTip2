import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/follows_service.dart';
import '../services/event_trigger_service.dart';
import '../services/notification_service.dart';

/// Provider for FollowsService with proper EventTriggerService initialization
/// This ensures follow notifications are created when users follow each other
final followsServiceProvider = Provider<FollowsService>((ref) {
  final service = FollowsService();
  final eventTriggerService = EventTriggerService();
  final notificationService = NotificationService();

  // Initialize the notification chain
  eventTriggerService.setNotificationService(notificationService);
  service.setEventTriggerService(eventTriggerService);

  debugPrint(
      '✅ FollowsServiceProvider: EventTriggerService initialized for follow notifications');

  return service;
});

/// Provider for EventTriggerService (if needed elsewhere)
final eventTriggerServiceProvider = Provider<EventTriggerService>((ref) {
  final service = EventTriggerService();
  final notificationService = NotificationService();

  service.setNotificationService(notificationService);

  debugPrint('✅ EventTriggerServiceProvider: NotificationService initialized');

  return service;
});

/// Provider for NotificationService (if needed elsewhere)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
