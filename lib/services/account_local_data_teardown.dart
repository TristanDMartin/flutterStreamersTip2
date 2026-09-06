import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/onboarding/email_verification_intent_store.dart';
import '../features/onboarding_tippy/tippy_onboarding_contract.dart';
import '../features/onboarding_tippy/tippy_onboarding_session.dart';
import 'algorithm_cache_service.dart';
import 'app_session_cache.dart';
import 'global_playback_manager.dart';
import 'memory_pressure_service.dart';
import 'unified_avatar_service.dart';

/// Clears device-local user data after permanent account deletion.
/// Logout intentionally does not call this — onboarding stays on the server.
///
/// Hard rule: deleted accounts must never resume Tippy/onboarding state.
abstract final class AccountLocalDataTeardown {
  static Future<void> executeAfterAccountDeletion({
    required String userId,
  }) async {
    debugPrint(
      '🧹 AccountLocalDataTeardown: clearing local data for $userId',
    );
    try {
      GlobalPlaybackManager.instance.disposeAll();
    } catch (e) {
      debugPrint('⚠️ AccountLocalDataTeardown playback: $e');
    }
    try {
      await TippyOnboardingSessionStore().invalidateAfterAccountDeletion();
    } catch (e) {
      debugPrint('⚠️ AccountLocalDataTeardown tippy session: $e');
    }
    try {
      AppSessionCache.instance.clearUser(userId);
      AppSessionCache.instance.clearAll();
    } catch (e) {
      debugPrint('⚠️ AccountLocalDataTeardown app session cache: $e');
    }
    try {
      await AlgorithmCacheService().clearUserCache(userId);
      await AlgorithmCacheService().clearAllCache();
    } catch (e) {
      debugPrint('⚠️ AccountLocalDataTeardown algorithm cache: $e');
    }
    try {
      await UnifiedAvatarService().clearCache();
    } catch (e) {
      debugPrint('⚠️ AccountLocalDataTeardown avatar cache: $e');
    }
    try {
      MemoryPressureService.clearAllCaches();
    } catch (e) {
      debugPrint('⚠️ AccountLocalDataTeardown memory cache: $e');
    }
    try {
      await EmailVerificationIntentStore.clear();
    } catch (e) {
      debugPrint('⚠️ AccountLocalDataTeardown verification intent: $e');
    }
    try {
      await _clearAccountBoundPreferences(userId);
    } catch (e) {
      debugPrint('⚠️ AccountLocalDataTeardown prefs: $e');
    }
    debugPrint('🧹 AccountLocalDataTeardown: local data cleared');
  }

  static Future<void> _clearAccountBoundPreferences(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> keys = prefs.getKeys().toList(growable: false);
    for (final String key in keys) {
      final bool isAccountBound = key.contains(userId) ||
          key.startsWith('onboarding_') ||
          key.startsWith('user_profile_') ||
          key.startsWith('cached_user_') ||
          key.startsWith('gamification_') ||
          key.startsWith('creator_score_') ||
          key.startsWith('growth_') ||
          key == kTippyForceFreshAfterAccountDeletionKey ||
          key == kTippyStartedFromWelcomeAfterDeletionKey ||
          key == kTippyOnboardingSessionStorageKey ||
          key == kTippyOnboardingV1SessionStorageKey ||
          key == kEmailVerificationIntentStorageKey;
      // Keep the force-fresh / started-from-welcome flags — they must survive
      // so the next Get Started opens at Meet Tippy.
      if (key == kTippyForceFreshAfterAccountDeletionKey ||
          key == kTippyStartedFromWelcomeAfterDeletionKey) {
        continue;
      }
      if (isAccountBound) {
        await prefs.remove(key);
      }
    }
    await prefs.setBool(kTippyForceFreshAfterAccountDeletionKey, true);
    await prefs.setBool(kTippyStartedFromWelcomeAfterDeletionKey, true);
  }
}
