import 'package:flutter/foundation.dart';

import '../../services/post_counter_service.dart';

/// Throttles [PostCounterService.reconcilePostCount] for profile open / cold start.
class ProfilePostCountReconcile {
  ProfilePostCountReconcile._();

  static final Map<String, DateTime> _lastReconcileByUserId =
      <String, DateTime>{};

  static const Duration defaultCooldown = Duration(minutes: 5);

  /// Clears throttle so the next [reconcileIfStale] runs (e.g. after app upgrade).
  static void invalidateCooldown(String userId) {
    _lastReconcileByUserId.remove(userId);
  }

  /// Reconciles Firestore `users.postCount` when viewing own profile, with
  /// cooldown to avoid hammering Firestore on every navigation.
  static Future<void> reconcileIfStale({
    required String userId,
    required bool isCurrentUser,
    Duration cooldown = defaultCooldown,
  }) async {
    if (!isCurrentUser) {
      return;
    }
    try {
      final DateTime? last = _lastReconcileByUserId[userId];
      if (last != null && DateTime.now().difference(last) < cooldown) {
        if (kDebugMode) {
          debugPrint(
            '📊 PROFILE: Skip postCount reconcile (cooldown) for $userId',
          );
        }
        return;
      }
      if (kDebugMode) {
        debugPrint('📊 PROFILE: Reconciling postCount for $userId');
      }
      final int count = await PostCounterService().reconcilePostCount(userId);
      if (count >= 0) {
        _lastReconcileByUserId[userId] = DateTime.now();
        if (kDebugMode) {
          debugPrint('✅ PROFILE: Reconciled postCount → $count');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PROFILE: reconcileIfStale failed: $e');
      }
    }
  }

  /// Call after [VideoService.mergeProfileVideosForUser] on the owner’s
  /// profile so `users.postCount` matches the merged grid without waiting
  /// for cooldown.
  static Future<void> afterProfileVideoMerge(String userId) async {
    invalidateCooldown(userId);
    await reconcileIfStale(
      userId: userId,
      isCurrentUser: true,
    );
  }
}
