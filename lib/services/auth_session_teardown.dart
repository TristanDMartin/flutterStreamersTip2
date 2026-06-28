import 'package:flutter/foundation.dart';

import 'global_playback_manager.dart';
import 'inbox_service_optimized.dart';
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
      GlobalPlaybackManager.instance.teardownForSignOut();
    } catch (e) {
      debugPrint('⚠️ AuthSessionTeardown playback teardown: $e');
    }
    debugPrint('🧹 AuthSessionTeardown: session listeners cancelled');
  }
}
