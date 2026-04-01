import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/follows_service.dart';
import '../services/event_trigger_service.dart';
import '../services/notification_service.dart';

export 'service_providers.dart'
    show eventTriggerServiceProvider, notificationServiceProvider;

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
