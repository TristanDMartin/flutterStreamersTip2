/// Canonical calendar visibility — keep in sync with
/// `streamerstipReact/lib/calendar/calendarVisibility.ts`.
library;

const String kCalendarVisibilityContractVersion = '1.0.0';

const Map<String, int> kDefaultEventDurationMs = <String, int>{
  'livestream': 3 * 60 * 60 * 1000,
  'content_post': 0,
  'approval_deadline': 0,
  'editing_deadline': 0,
  'team_task': 0,
  'campaign': 24 * 60 * 60 * 1000,
  'other': 0,
};

const Map<String, int> kMissedGraceMs = <String, int>{
  'content_post': 2 * 60 * 60 * 1000,
  'livestream': 0,
  'approval_deadline': 0,
  'editing_deadline': 0,
  'team_task': 0,
  'campaign': 6 * 60 * 60 * 1000,
  'other': 2 * 60 * 60 * 1000,
};

String mapContentTypeToCalendarEventType(Object? contentType) {
  final String key = (contentType?.toString() ?? '').trim().toLowerCase();
  if (key == 'stream' || key == 'livestream' || key == 'live') {
    return 'livestream';
  }
  if (key == 'collab' || key == 'campaign') {
    return 'campaign';
  }
  return 'content_post';
}

DateTime resolveCalendarEndsAt({
  required DateTime startsAt,
  DateTime? endsAt,
  String eventType = 'content_post',
}) {
  if (endsAt != null) {
    return endsAt.toUtc();
  }
  final int duration = kDefaultEventDurationMs[eventType] ?? 0;
  return startsAt.toUtc().add(Duration(milliseconds: duration));
}

bool isActiveUpcomingCalendarEvent({
  Object? status,
  Object? deletedAt,
  required DateTime? startsAt,
  DateTime? endsAt,
  String eventType = 'content_post',
  DateTime? now,
}) {
  if (deletedAt != null) {
    return false;
  }
  final String key = (status?.toString() ?? 'scheduled').trim().toLowerCase();
  if (key == 'cancelled' ||
      key == 'canceled' ||
      key == 'archived' ||
      key == 'missed' ||
      key == 'failed' ||
      key == 'published' ||
      key == 'completed') {
    return false;
  }
  if (startsAt == null) {
    return false;
  }
  final DateTime at = (now ?? DateTime.now()).toUtc();
  final DateTime end = resolveCalendarEndsAt(
    startsAt: startsAt,
    endsAt: endsAt,
    eventType: eventType,
  );
  return !end.isBefore(at);
}

List<T> filterActiveUpcomingCalendarEvents<T>({
  required List<T> events,
  required DateTime? Function(T event) startsAtOf,
  Object? Function(T event)? statusOf,
  Object? Function(T event)? deletedAtOf,
  DateTime? Function(T event)? endsAtOf,
  String Function(T event)? eventTypeOf,
  DateTime? now,
}) {
  return events
      .where(
        (T event) => isActiveUpcomingCalendarEvent(
          status: statusOf?.call(event),
          deletedAt: deletedAtOf?.call(event),
          startsAt: startsAtOf(event),
          endsAt: endsAtOf?.call(event),
          eventType: eventTypeOf?.call(event) ?? 'content_post',
          now: now,
        ),
      )
      .toList(growable: false);
}

/// Past events remain on the public streamer page for [retention], then drop.
const Duration kStreamerPageCalendarRetention = Duration(days: 7);

bool isWithinStreamerPageCalendarWindow({
  Object? status,
  Object? deletedAt,
  required DateTime? startsAt,
  DateTime? endsAt,
  String eventType = 'content_post',
  DateTime? now,
  Duration retention = kStreamerPageCalendarRetention,
}) {
  if (deletedAt != null) {
    return false;
  }
  final String key = (status?.toString() ?? 'scheduled').trim().toLowerCase();
  if (key == 'cancelled' ||
      key == 'canceled' ||
      key == 'archived' ||
      key == 'missed' ||
      key == 'failed' ||
      key == 'published' ||
      key == 'completed') {
    return false;
  }
  if (startsAt == null) {
    return false;
  }
  final DateTime at = (now ?? DateTime.now()).toUtc();
  final DateTime end = resolveCalendarEndsAt(
    startsAt: startsAt,
    endsAt: endsAt,
    eventType: eventType,
  );
  final DateTime cutoff = at.subtract(retention);
  return !end.isBefore(cutoff);
}

List<T> filterStreamerPageCalendarEvents<T>({
  required List<T> events,
  required DateTime? Function(T event) startsAtOf,
  Object? Function(T event)? statusOf,
  Object? Function(T event)? deletedAtOf,
  DateTime? Function(T event)? endsAtOf,
  String Function(T event)? eventTypeOf,
  DateTime? now,
  Duration retention = kStreamerPageCalendarRetention,
}) {
  return events
      .where(
        (T event) => isWithinStreamerPageCalendarWindow(
          status: statusOf?.call(event),
          deletedAt: deletedAtOf?.call(event),
          startsAt: startsAtOf(event),
          endsAt: endsAtOf?.call(event),
          eventType: eventTypeOf?.call(event) ?? 'content_post',
          now: now,
          retention: retention,
        ),
      )
      .toList(growable: false);
}
