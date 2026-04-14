import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? readFirestoreDate(Object? v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}
