import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'creator_score.dart';

const String _creatorScoreWorkerBaseUrl = String.fromEnvironment(
  'CREATOR_SCORE_API_BASE',
  defaultValue: 'https://streamerstip-mux-api.streamerstip.workers.dev',
);

class CreatorScoreService {
  CreatorScoreService({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client();

  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;
  final http.Client _httpClient;
  static final Set<String> _requestedSyncs = <String>{};

  Stream<CreatorScore> watchCreatorScore(String uid) {
    final String safeUid = uid.trim();
    if (safeUid.isEmpty) {
      return Stream<CreatorScore>.value(CreatorScore.fallback);
    }
    return _firestore
        .collection('users')
        .doc(safeUid)
        .collection('creatorScore')
        .doc('current')
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (!snapshot.exists) {
        unawaited(requestBackendSync(safeUid));
      }
      return CreatorScore.fromFirestore(snapshot);
    }).handleError((Object _) => CreatorScore.fallback);
  }

  Future<void> requestBackendSync(String uid) async {
    final String safeUid = uid.trim();
    if (safeUid.isEmpty || !_requestedSyncs.add(safeUid)) {
      return;
    }
    try {
      final firebase_auth.User? user = _auth.currentUser;
      final String? token = await user?.getIdToken();
      if (token == null || token.isEmpty) {
        _requestedSyncs.remove(safeUid);
        return;
      }
      final Uri uri = Uri.parse(
        '${_creatorScoreWorkerBaseUrl.replaceAll(RegExp(r'/$'), '')}'
        '/creator-score/sync',
      );
      final http.Response response = await _httpClient.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'uid': safeUid}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _requestedSyncs.remove(safeUid);
      }
    } catch (_) {
      _requestedSyncs.remove(safeUid);
    }
  }
}

final Provider<CreatorScoreService> creatorScoreServiceProvider =
    Provider<CreatorScoreService>((Ref ref) => CreatorScoreService());

final StreamProviderFamily<CreatorScore, String> creatorScoreProvider =
    StreamProvider.family<CreatorScore, String>((Ref ref, String uid) {
  return ref.watch(creatorScoreServiceProvider).watchCreatorScore(uid);
});
