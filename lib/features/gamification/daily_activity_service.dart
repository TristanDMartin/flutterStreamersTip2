import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'create_gamification_event.dart';
import 'gamification_event_types.dart';

/// Emits at most one [GamificationEventTypes.activityDayQualified] per local day.
class DailyActivityService {
  DailyActivityService._();
  static final DailyActivityService instance = DailyActivityService._();

  static const String _prefsPrefix = 'daily_activity_qualified_';

  /// Call after any qualifying product action (social, publish, watch session).
  void maybeEmitDayQualified({String source = 'app'}) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final String dateKey = _todayKey();
    final String prefsKey = '$_prefsPrefix${user.uid}_$dateKey';
    unawaited(_emitIfNeeded(
      uid: user.uid,
      dateKey: dateKey,
      prefsKey: prefsKey,
      source: source,
    ));
  }

  static String _todayKey() {
    final DateTime now = DateTime.now();
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    return '${now.year}$m$d';
  }

  Future<void> _emitIfNeeded({
    required String uid,
    required String dateKey,
    required String prefsKey,
    required String source,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(prefsKey) == true) {
        return;
      }
      await createGamificationEvent(
        type: GamificationEventTypes.activityDayQualified,
        source: source,
        eventId: 'day_${uid}_$dateKey',
        metadata: <String, dynamic>{'dateKey': dateKey},
      );
      await prefs.setBool(prefsKey, true);
    } catch (e) {
      debugPrint('DailyActivityService: day qualified skipped: $e');
    }
  }
}
