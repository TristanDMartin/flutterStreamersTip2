import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'mobile_purchase_verification_client.dart';
import 'mobile_purchase_verification_payload.dart';
import 'pending_verification_store.dart';

/// Background service that retries failed IAP verifications.
class VerificationBackgroundSync {
  VerificationBackgroundSync._();
  static final VerificationBackgroundSync instance =
      VerificationBackgroundSync._();

  final MobilePurchaseVerificationClient _client =
      MobilePurchaseVerificationClient();
  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Start periodic background sync (every 5 minutes).
  void startPeriodicSync({
    Duration interval = const Duration(minutes: 5),
    Future<void> Function()? onSuccess,
  }) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (Timer timer) {
      unawaited(syncPendingVerifications(onSuccess: onSuccess));
    });
  }

  /// Stop periodic sync.
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Manually trigger sync of pending verifications.
  Future<void> syncPendingVerifications({
    Future<void> Function()? onSuccess,
  }) async {
    if (_isSyncing) {
      return; // Prevent concurrent syncs
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return; // Can't verify without auth
    }

    _isSyncing = true;
    try {
      await PendingVerificationStore.instance.setLastSyncAttempt();
      final List<Map<String, dynamic>> pending =
          await PendingVerificationStore.instance.getPendingVerifications();

      if (pending.isEmpty) {
        return;
      }

      debugPrint(
        '🔄 IAP Background Sync: Retrying ${pending.length} pending verification(s)',
      );

      int successCount = 0;
      for (final Map<String, dynamic> entry in pending) {
        final String dedupeKey = entry['dedupeKey'] ?? '';
        final String uid = entry['uid'] ?? '';
        final int attempts = entry['attempts'] ?? 0;

        // Skip if too many attempts (max 20 across all background retries)
        if (attempts >= 20) {
          debugPrint(
            '⚠️ IAP Verification: Max attempts reached for $dedupeKey, removing',
          );
          await PendingVerificationStore.instance
              .removePendingVerification(dedupeKey);
          continue;
        }

        // Skip if not for current user
        if (uid != user.uid) {
          continue;
        }

        // Exponential backoff based on attempts: 2^min(attempts,6) minutes
        final int backoffMinutes = 1 << (attempts.clamp(0, 6));
        final String? lastAttemptStr = entry['lastAttemptAt'];
        if (lastAttemptStr != null) {
          try {
            final DateTime lastAttempt = DateTime.parse(lastAttemptStr);
            final DateTime nextAttempt =
                lastAttempt.add(Duration(minutes: backoffMinutes));
            if (DateTime.now().toUtc().isBefore(nextAttempt)) {
              continue; // Too soon to retry
            }
          } catch (_) {
            // Invalid timestamp, proceed with retry
          }
        }

        try {
          await _client.submitPurchase(
            payload: MobilePurchaseVerificationPayload(
              uid: uid,
              platform: entry['platform'] ?? 'unknown',
              productId: entry['productId'] ?? '',
              purchaseToken: entry['purchaseToken'] ?? '',
              transactionId: entry['transactionId'] ?? '',
            ),
          );

          // Success - remove from pending
          await PendingVerificationStore.instance
              .removePendingVerification(dedupeKey);
          successCount++;
          debugPrint('✅ IAP Verification: Successfully verified $dedupeKey');
        } on MobilePurchaseVerificationException catch (e) {
          if (_isRetryableVerificationMessage(e.message)) {
            // Increment attempts for next retry
            await PendingVerificationStore.instance.incrementAttempts(dedupeKey);
            debugPrint(
              '⚠️ IAP Verification: Retryable error for $dedupeKey (attempt ${attempts + 1}): ${e.message}',
            );
          } else {
            // Non-retryable error - remove
            await PendingVerificationStore.instance
                .removePendingVerification(dedupeKey);
            debugPrint(
              '❌ IAP Verification: Non-retryable error for $dedupeKey: ${e.message}',
            );
          }
        } catch (e) {
          // Generic error - increment attempts
          await PendingVerificationStore.instance.incrementAttempts(dedupeKey);
          debugPrint(
            '⚠️ IAP Verification: Error for $dedupeKey (attempt ${attempts + 1}): $e',
          );
        }
      }

      if (successCount > 0) {
        debugPrint(
          '✅ IAP Background Sync: Successfully verified $successCount purchase(s)',
        );
        if (onSuccess != null) {
          await onSuccess();
        }
      }

      // Clean up old entries (>7 days)
      await PendingVerificationStore.instance.clearOldEntries();
    } finally {
      _isSyncing = false;
    }
  }

  bool _isRetryableVerificationMessage(String message) {
    final String lower = message.toLowerCase();
    return lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('socket') ||
        lower.contains('connection reset') ||
        lower.contains('connection refused');
  }

  /// Check if there are pending verifications for the current user.
  Future<int> getPendingCount() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final List<Map<String, dynamic>> pending =
        await PendingVerificationStore.instance.getPendingVerifications();
    return pending.where((Map<String, dynamic> e) => e['uid'] == user.uid).length;
  }
}
