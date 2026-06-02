import 'emit_gamification_event.dart';
import 'daily_activity_service.dart';

/// Trusted engagement events + daily qualification after a real action.
void scheduleEngagementGamificationEvent({
  required String type,
  String? entityType,
  String? entityId,
  String source = 'app',
}) {
  scheduleGamificationEvent(
    type,
    entityType: entityType,
    entityId: entityId,
    metadata: <String, dynamic>{'source': source},
  );
  DailyActivityService.instance.maybeEmitDayQualified(source: source);
}
