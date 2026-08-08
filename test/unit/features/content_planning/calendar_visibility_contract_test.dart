import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/content_planning/calendar_visibility_contract.dart';

void main() {
  group('calendarVisibility contract', () {
    final DateTime now = DateTime.parse('2026-07-30T12:00:00.000Z');

    test('keeps future events on upcoming calendar', () {
      expect(
        isActiveUpcomingCalendarEvent(
          status: 'scheduled',
          startsAt: DateTime.parse('2026-07-30T18:00:00.000Z'),
          eventType: 'content_post',
          now: now,
        ),
        isTrue,
      );
    });

    test('removes past events from upcoming without deleting records', () {
      expect(
        isActiveUpcomingCalendarEvent(
          status: 'scheduled',
          startsAt: DateTime.parse('2026-07-29T18:00:00.000Z'),
          eventType: 'content_post',
          now: now,
        ),
        isFalse,
      );
    });

    test('filters list helpers consistently', () {
      final List<DateTime> dates = <DateTime>[
        DateTime.parse('2026-07-29T10:00:00.000Z'),
        DateTime.parse('2026-07-31T10:00:00.000Z'),
      ];
      final List<DateTime> upcoming = filterActiveUpcomingCalendarEvents(
        events: dates,
        startsAtOf: (DateTime d) => d,
        now: now,
      );
      expect(upcoming, <DateTime>[DateTime.parse('2026-07-31T10:00:00.000Z')]);
    });

    test('streamer page keeps past events within 7 days', () {
      expect(
        isWithinStreamerPageCalendarWindow(
          status: 'scheduled',
          startsAt: DateTime.parse('2026-07-28T12:00:00.000Z'),
          eventType: 'content_post',
          now: now,
        ),
        isTrue,
      );
    });

    test('streamer page drops events older than 7 days', () {
      expect(
        isWithinStreamerPageCalendarWindow(
          status: 'scheduled',
          startsAt: DateTime.parse('2026-07-22T12:00:00.000Z'),
          eventType: 'content_post',
          now: now,
        ),
        isFalse,
      );
    });
  });
}
