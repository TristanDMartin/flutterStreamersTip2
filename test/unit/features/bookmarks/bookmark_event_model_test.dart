import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/bookmark_event.dart';

void main() {
  group('BookmarkEvent.fromMap', () {
    test('parses calendar bookmark document', () {
      final DateTime start = DateTime.now().toUtc().add(const Duration(days: 2));
      final DateTime notify = start.subtract(const Duration(minutes: 30));
      final BookmarkEvent actual = BookmarkEvent.fromMap(<String, dynamic>{
        'eventId': 'evt-1',
        'creatorId': 'creator-1',
        'creatorName': 'Creator One',
        'title': 'Stream tonight',
        'startAt': Timestamp.fromDate(start),
        'notifyAt': Timestamp.fromDate(notify),
        'notify': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 5, 30)),
        'source': 'streamerCardBackView',
      });
      expect(actual.eventId, 'evt-1');
      expect(actual.creatorName, 'Creator One');
      expect(actual.title, 'Stream tonight');
      expect(actual.notify, isTrue);
      expect(actual.status, EventStatus.upcoming);
    });
  });
}
