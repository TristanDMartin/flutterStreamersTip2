import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/calendar_event.dart';

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
        events.map((e) => e.toMap()).toList(growable: false);
    await _users.doc(uid).update(<String, dynamic>{'calendarEvents': payload});
  }

  List<CalendarEvent> parseCalendarEvents(Map<String, dynamic> userData) {
    final List<dynamic>? raw = userData['calendarEvents'] as List<dynamic>?;
    if (raw == null) return <CalendarEvent>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CalendarEvent.fromMap)
        .toList();
  }
}
