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
import '../models/user_model.dart';

final globalVideoServiceProvider = Provider<VideoService>((ref) {
  return VideoService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class RelationshipState {
  const RelationshipState({
    required this.following,
    required this.followers,
    required this.connections,
    required this.isLoading,
  });

  final List<User> following;
  final List<User> followers;
  final List<User> connections;
  final bool isLoading;

  static RelationshipState fromService(RelationshipServiceAdvanced service) {
    return RelationshipState(
      following: List<User>.unmodifiable(service.following),
      followers: List<User>.unmodifiable(service.followers),
      connections: List<User>.unmodifiable(service.connections),
      isLoading: service.isLoading,
    );
  }
}

class RelationshipNotifier extends Notifier<RelationshipState> {
  late final RelationshipServiceAdvanced _service;
  VoidCallback? _listener;

  @override
  RelationshipState build() {
    _service = RelationshipServiceAdvanced();
    _listener = () => state = RelationshipState.fromService(_service);
    _service.addListener(_listener!);
    ref.onDispose(() {
      final VoidCallback? listener = _listener;
      if (listener != null) {
        _service.removeListener(listener);
      }
      _listener = null;
    });
    return RelationshipState.fromService(_service);
  }

  void refreshCurrentUserId() => _service.refreshCurrentUserId();
}

final NotifierProvider<RelationshipNotifier, RelationshipState>
    relationshipServiceProvider =
    NotifierProvider<RelationshipNotifier, RelationshipState>(
        RelationshipNotifier.new);

final Provider<EventTriggerService> eventTriggerServiceProvider =
    Provider<EventTriggerService>((ref) {
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
