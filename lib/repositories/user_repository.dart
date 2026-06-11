import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/calendar_event.dart';
import '../utils/user_profile_firestore.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  String? get currentUid => fa.FirebaseAuth.instance.currentUser?.uid;

  Future<Map<String, dynamic>?> fetchUser(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data();
  }

  Future<void> upsertUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> updateUserCalendarEvents(
    String uid,
    List<CalendarEvent> events,
  ) async {
    final List<Map<String, dynamic>> payload =
        UserProfileFirestore.calendarEventsToFirestore(events);
    UserProfileFirestore.logCalendarSave(
      uid: uid,
      source: 'CalendarCreate',
      count: payload.length,
    );
    await _users.doc(uid).update(<String, dynamic>{
      UserProfileFirestore.calendarEventsField: payload,
    });
  }

  List<CalendarEvent> parseCalendarEvents(
    Map<String, dynamic> userData, {
    String? uid,
  }) {
    final List<CalendarEvent> events =
        UserProfileFirestore.parseCalendarEventsFromUserData(userData);
    final String resolvedUid =
        uid ?? userData['id']?.toString() ?? userData['uid']?.toString() ?? '';
    if (resolvedUid.isNotEmpty) {
      UserProfileFirestore.logCalendarRead(
        uid: resolvedUid,
        source: 'CalendarView',
        count: events.length,
      );
    }
    return events;
  }
}
