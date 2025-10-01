import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/video_service.dart';
import '../services/notification_service.dart';
import '../services/relationship_service_advanced.dart';
import '../services/event_trigger_service.dart';
import '../services/like_service.dart';
import '../services/comments_service.dart';
import '../services/follows_service.dart';
import '../services/tag_mention_service.dart';

final globalVideoServiceProvider = Provider<VideoService>((ref) {
  return VideoService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final relationshipServiceProvider = ChangeNotifierProvider<RelationshipServiceAdvanced>((ref) {
  return RelationshipServiceAdvanced();
});

final eventTriggerServiceProvider = ChangeNotifierProvider<EventTriggerService>((ref) {
  final eventTriggerService = EventTriggerService();
  final notificationService = ref.read(notificationServiceProvider);
  eventTriggerService.setNotificationService(notificationService);
  
  // CRITICAL FIX: Configure the singleton instances that widgets will use
  final likeService = LikeService(); // This gets the singleton instance
  likeService.setEventTriggerService(eventTriggerService);
  
  final commentsService = CommentsService(); // This gets the singleton instance
  commentsService.setEventTriggerService(eventTriggerService);
  
  final followsService = FollowsService(); // This gets the singleton instance
  followsService.setEventTriggerService(eventTriggerService);
  
  final tagMentionService = TagMentionService(); // This gets the singleton instance
  tagMentionService.setEventTriggerService(eventTriggerService);
  
  debugPrint('🔧 EventTriggerService provider: Configured singleton services');
  
  return eventTriggerService;
});
