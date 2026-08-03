import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/calendar_event.dart';
import 'package:streamers_tip/widgets/streamer_mirror_calendar.dart';

void main() {
  testWidgets('StreamerMirrorCalendar shows month grid and event chip',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final CalendarEvent event = CalendarEvent(
      id: 'cp-1-2',
      title: 'Tippy Live',
      description: 'stream',
      date: DateTime(now.year, now.month, now.day, 18),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreamerMirrorCalendar(events: <CalendarEvent>[event]),
          ),
        ),
      ),
    );
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tippy Live'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
  });
}
