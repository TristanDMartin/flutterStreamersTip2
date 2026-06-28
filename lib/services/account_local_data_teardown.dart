import 'package:flutter/foundation.dart';

import 'algorithm_cache_service.dart';
import 'global_playback_manager.dart';
import 'memory_pressure_service.dart';
import 'unified_avatar_service.dart';

/// Clears device-local user data after permanent account deletion.
/// Logout intentionally does not call this — onboarding stays on the server.
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
    debugPrint('🧹 AccountLocalDataTeardown: local data cleared');
  }
}
