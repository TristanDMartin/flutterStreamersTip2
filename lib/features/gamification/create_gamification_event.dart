import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gamification_source.dart';
import 'services/gamification_event_service.dart';

/// Shared entry point for trusted gamification events (mobile + web contract).
///
/// Maps alignment-doc action names to canonical types:
/// - `UPLOAD_CLIP` → [GamificationEventTypes.contentPublished]
/// - `COMPLETE_PROFILE` → [GamificationEventTypes.profileCompleted]
/// - `CONNECT_TWITCH` → [GamificationEventTypes.platformConnected]
Future<void> createGamificationEvent({
  required String type,
  String? source,
  String? entityType,
  String? entityId,
  String? eventId,
  Map<String, dynamic>? metadata,
}) async {
  try {
    await GamificationEventService().emitTrustedEvent(
      type: type,
      source: source ?? GamificationEventSource.currentPlatform,
      entityType: entityType,
      entityId: entityId,
      eventId: eventId,
      metadata: metadata,
    );
  } on StateError catch (e) {
    debugPrint('createGamificationEvent: skipped ($e)');
  }
}

/// Fire-and-forget; does not block publish flows.
void scheduleCreateGamificationEvent({
  required String type,
  String? source,
  String? entityType,
  String? entityId,
  String? eventId,
  Map<String, dynamic>? metadata,
}) {
  unawaited(
    createGamificationEvent(
      type: type,
      source: source,
      entityType: entityType,
      entityId: entityId,
      eventId: eventId,
      metadata: metadata,
    ),
  );
}
