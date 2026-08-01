import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Display-safe profile reads after `users/{uid}` became owner-private.
///
/// Prefer [publicUsers]. Fall back to [users] only when the id is the signed-in
/// owner. Never query another user's private `users/{uid}` doc.
class PublicProfileFirestore {
  PublicProfileFirestore._();

  static final PublicProfileFirestore instance = PublicProfileFirestore._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _publicUsers =>
      _db.collection('publicUsers');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Single profile map keyed for display (username, displayName, avatar…).
  Future<Map<String, dynamic>?> getProfileMap(String userId) async {
    final String id = userId.trim();
    if (id.isEmpty) {
      return null;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> publicDoc =
          await _publicUsers.doc(id).get();
      if (publicDoc.exists) {
        return _withIds(id, publicDoc.data());
      }
      if (_currentUid == id) {
        final DocumentSnapshot<Map<String, dynamic>> ownDoc =
            await _users.doc(id).get();
        if (ownDoc.exists) {
          return _withIds(id, ownDoc.data());
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Batch fetch (Firestore `whereIn` chunks of 10).
  Future<Map<String, Map<String, dynamic>>> getProfileMaps(
    Iterable<String> userIds,
  ) async {
    final Map<String, Map<String, dynamic>> result =
        <String, Map<String, dynamic>>{};
    final List<String> ids = userIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return result;
    }
    const int batchSize = 10;
    for (int i = 0; i < ids.length; i += batchSize) {
      final List<String> batch = ids.sublist(
        i,
        (i + batchSize).clamp(0, ids.length),
      );
      try {
        final QuerySnapshot<Map<String, dynamic>> snap = await _publicUsers
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snap.docs) {
          result[doc.id] = _withIds(doc.id, doc.data())!;
        }
      } catch (_) {
        // Best-effort batch; missing ids stay absent.
      }
    }
    final String? ownUid = _currentUid;
    if (ownUid != null &&
        ids.contains(ownUid) &&
        !result.containsKey(ownUid)) {
      final Map<String, dynamic>? own = await getProfileMap(ownUid);
      if (own != null) {
        result[ownUid] = own;
      }
    }
    return result;
  }

  /// Live profile for inbox / chat peers.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(String userId) {
    final String id = userId.trim();
    if (id.isEmpty) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    if (_currentUid == id) {
      return _users.doc(id).snapshots();
    }
    return _publicUsers.doc(id).snapshots();
  }

  /// True when a public (or own private) profile doc exists.
  Future<Set<String>> filterExistingIds(Iterable<String> userIds) async {
    final Map<String, Map<String, dynamic>> maps =
        await getProfileMaps(userIds);
    return maps.keys.toSet();
  }

  Map<String, dynamic>? _withIds(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    return <String, dynamic>{
      ...data,
      'id': id,
      'uid': data['uid'] ?? id,
    };
  }
}
