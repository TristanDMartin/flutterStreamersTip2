import 'create_gamification_event.dart';

/// Back-compat aliases — prefer [createGamificationEvent].
Future<void> emitGamificationEvent(
  String type, {
  String? entityType,
  String? entityId,
  String? eventId,
  Map<String, dynamic>? metadata,
}) =>
    createGamificationEvent(
      type: type,
      entityType: entityType,
      entityId: entityId,
      eventId: eventId,
      metadata: metadata,
    );

void scheduleGamificationEvent(
  String type, {
  String? entityType,
  String? entityId,
  String? eventId,
  Map<String, dynamic>? metadata,
}) =>
    scheduleCreateGamificationEvent(
      type: type,
      entityType: entityType,
      entityId: entityId,
      eventId: eventId,
      metadata: metadata,
    );
