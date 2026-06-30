import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_user_doc_fields.dart';

/// Emits user doc data only when non-ignored profile fields change.
Stream<Map<String, dynamic>?> userDocSnapshotsRelevantOnly(
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots, {
  required String uid,
}) async* {
  Map<String, dynamic>? lastData;
  await for (final DocumentSnapshot<Map<String, dynamic>> snapshot
      in snapshots) {
    if (!snapshot.exists) {
      lastData = null;
      yield null;
      continue;
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      snapshot.data() ?? <String, dynamic>{},
    );
    if (lastData != null &&
        ProfileUserDocFields.hasOnlyIgnoredChanges(
          before: lastData,
          after: data,
        )) {
      continue;
    }
    lastData = data;
    yield data;
  }
}
