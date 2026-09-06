import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../gamification_backend_config.dart';
import 'achievement_catalog.dart';
import 'achievement_definition.dart';

/// Read-only achievement data layer. Unlocks are Worker-owned.
class AchievementRepository {
  AchievementRepository({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    String? baseUrl,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? kGamificationEventsBaseUrl;

  final FirebaseFirestore _firestore;
  final http.Client _http;
  final String _baseUrl;

  Stream<AchievementSnapshot> watch(String uid) {
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(uid);
    final DocumentReference<Map<String, dynamic>> stateRef =
        userRef.collection('gamification').doc('state');
    final CollectionReference<Map<String, dynamic>> unlocksRef =
        userRef.collection('gamificationAchievements');
    final DocumentReference<Map<String, dynamic>> legacyFirstStepsRef =
        userRef.collection('achievements').doc('first_steps');
    DocumentSnapshot<Map<String, dynamic>>? latestState;
    QuerySnapshot<Map<String, dynamic>>? latestUnlocks;
    DocumentSnapshot<Map<String, dynamic>>? latestLegacyFirstSteps;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? stateSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? unlocksSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? legacySub;
    final StreamController<AchievementSnapshot> controller =
        StreamController<AchievementSnapshot>.broadcast();

    void emitSnapshot() {
      final List<String> pending = AchievementCatalog.canonicalizePending(
        _stringList(latestState?.data()?['pendingAchievements']),
      );
      final Map<String, AchievementUnlock> unlocked =
          <String, AchievementUnlock>{};
      if (latestUnlocks != null) {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in latestUnlocks!.docs) {
          final String key = AchievementCatalog.canonicalizeKey(doc.id);
          if (!AchievementCatalog.isLaunchKey(key) ||
              doc.data()['unlocked'] == false) {
            continue;
          }
          unlocked[key] = AchievementUnlock(
            key: key,
            unlockedAt: _readDate(doc.data()['unlockedAt']),
          );
        }
      }
      final Map<String, dynamic>? legacy = latestLegacyFirstSteps?.data();
      if (latestLegacyFirstSteps?.exists == true &&
          legacy?['unlocked'] != false) {
        unlocked.putIfAbsent(
          'onboarding_done',
          () => AchievementUnlock(
            key: 'onboarding_done',
            unlockedAt: _readDate(legacy?['unlockedAt'] ?? legacy?['seenAt']),
          ),
        );
      }
      controller.add(
        AchievementSnapshot(pendingKeys: pending, unlocked: unlocked),
      );
    }

    controller.onListen = () {
      stateSub = stateRef.snapshots().listen(
        (DocumentSnapshot<Map<String, dynamic>> snap) {
          latestState = snap;
          emitSnapshot();
        },
        onError: controller.addError,
      );
      unlocksSub = unlocksRef.snapshots().listen(
        (QuerySnapshot<Map<String, dynamic>> snap) {
          latestUnlocks = snap;
          emitSnapshot();
        },
        onError: controller.addError,
      );
      legacySub = legacyFirstStepsRef.snapshots().listen(
        (DocumentSnapshot<Map<String, dynamic>> snap) {
          latestLegacyFirstSteps = snap;
          emitSnapshot();
        },
        onError: controller.addError,
      );
    };
    controller.onCancel = () async {
      await stateSub?.cancel();
      await unlocksSub?.cancel();
      await legacySub?.cancel();
    };
    return controller.stream;
  }

  Future<void> acknowledge(String rawKey) async {
    final String key = AchievementCatalog.canonicalizeKey(rawKey);
    if (!AchievementCatalog.isLaunchKey(key)) {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final String? token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      return;
    }
    final String noSlash = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final Uri uri = Uri.parse(
      '$noSlash/gamification/achievements/${Uri.encodeComponent(key)}/acknowledge',
    );
    try {
      final http.Response res = await _http.patch(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{'key': key}),
      );
      if (res.statusCode >= 400) {
        debugPrint(
          'AchievementRepository: ack HTTP ${res.statusCode} ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('AchievementRepository: ack failed (non-fatal): $e');
    }
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw.whereType<String>().toList();
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
