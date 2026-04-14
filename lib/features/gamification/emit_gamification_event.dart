import 'dart:async';

import 'package:flutter/foundation.dart';

import 'services/gamification_event_service.dart';

/// Trusted gamification events after a real product action succeeds.
/// Prefer [scheduleGamificationEvent] from services so publish flows are not blocked.
Future<void> emitGamificationEvent(
  String type, {
  String? entityType,
  String? entityId,
  Map<String, dynamic>? metadata,
}) async {
  try {
    await GamificationEventService().emitTrustedEvent(
      type: type,
      entityType: entityType,
      entityId: entityId,
      metadata: metadata,
    );
  } on StateError catch (e) {
    debugPrint('emitGamificationEvent: skipped ($e)');
  }
}

/// Fire-and-forget; logs failures inside [GamificationEventService].
void scheduleGamificationEvent(
  String type, {
  String? entityType,
  String? entityId,
  Map<String, dynamic>? metadata,
}) {
  unawaited(
    emitGamificationEvent(
      type,
      entityType: entityType,
      entityId: entityId,
      metadata: metadata,
    ),
  );
}
