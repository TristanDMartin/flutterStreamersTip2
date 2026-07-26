import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'global_playback_manager.dart';
import 'inbox_service_optimized.dart';
import 'offline_inbox_service.dart';
import 'follows_service.dart';
import 'profile_update_service.dart';
import 'relationship_service_advanced.dart';

/// Cancels user-scoped Firestore listeners before Firebase [signOut].
abstract final class AuthSessionTeardown {
  static Future<void> executeBeforeSignOut() async {
    debugPrint('🧹 AuthSessionTeardown: cancelling session listeners...');
    try {
      ProfileUpdateService().teardownUserSession();
    } catch (e) {
      debugPrint('⚠️ AuthSessionTeardown profile teardown: $e');
    }
    try {
      InboxServiceOptimized().stopRealTimeListeners();
    } catch (e) {
      debugPrint('⚠️ AuthSessionTeardown inbox teardown: $e');
    }
    try {
      RelationshipServiceAdvanced().teardownForLogout();
    } catch (e) {
      debugPrint('⚠️ AuthSessionTeardown relationship teardown: $e');
    }
    try {
      FollowsService().clearNetworkTabUsersCache(
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e) {
      debugPrint('⚠️ AuthSessionTeardown follows cache teardown: $e');
    }
    try {
      unawaited(
        OfflineInboxService().clearCache(
          userId: FirebaseAuth.instance.currentUser?.uid,
        ),
      );
      InboxServiceOptimized().clearCache();
    } catch (e) {
      debugPrint('⚠️ AuthSessionTeardown inbox cache teardown: $e');
    }
    try {
      GlobalPlaybackManager.instance.teardownForSignOut();
    } catch (e) {
      debugPrint('⚠️ AuthSessionTeardown playback teardown: $e');
    }
    debugPrint('🧹 AuthSessionTeardown: session listeners cancelled');
  }
}
