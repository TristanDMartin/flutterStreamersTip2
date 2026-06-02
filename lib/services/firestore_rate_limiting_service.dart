import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service to track rate limits in Firestore for server-side rate limiting
class FirestoreRateLimitingService {
  static final FirestoreRateLimitingService _instance =
      FirestoreRateLimitingService._internal();
  factory FirestoreRateLimitingService() => _instance;
  FirestoreRateLimitingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Record an operation for rate limiting
  Future<void> recordOperation(
    String operation, {
    int maxOperations = 10,
    int timeWindowSeconds = 60,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ FirestoreRateLimitingService: No user logged in');
        return;
      }

      final userId = currentUser.uid;
      final rateLimitRef = _firestore.collection('rate_limits').doc(userId);
      final now = FieldValue.serverTimestamp();

      // Get current rate limit data
      final rateLimitDoc = await rateLimitRef.get();
      final operationCountKey = '${operation}_count';
      final operationTimeKey = '${operation}_time';

      if (!rateLimitDoc.exists) {
        // Create new rate limit document
        await rateLimitRef.set({
          operationCountKey: 1,
          operationTimeKey: now,
          'updatedAt': now,
        });
        debugPrint(
          '✅ FirestoreRateLimitingService: Created rate limit for $operation',
        );
        return;
      }

      final data = rateLimitDoc.data()!;
      final currentCount = (data[operationCountKey] as int?) ?? 0;
      final lastOperationTime = data[operationTimeKey] as Timestamp?;

      // Check if we're outside the time window
      if (lastOperationTime != null) {
        final timeSinceLastOp =
            DateTime.now().difference(lastOperationTime.toDate()).inSeconds;

        if (timeSinceLastOp > timeWindowSeconds) {
          // Reset count - outside time window
          await rateLimitRef.update({
            operationCountKey: 1,
            operationTimeKey: now,
            'updatedAt': now,
          });
          debugPrint(
            '✅ FirestoreRateLimitingService: Reset rate limit for $operation (outside window)',
          );
          return;
        }
      }

      // Increment count
      await rateLimitRef.update({
        operationCountKey: currentCount + 1,
        operationTimeKey: now,
        'updatedAt': now,
      });

      debugPrint(
        '✅ FirestoreRateLimitingService: Recorded $operation (count: ${currentCount + 1})',
      );
    } catch (e) {
      debugPrint(
        '❌ FirestoreRateLimitingService: Error recording operation: $e',
      );
      // Don't throw - rate limiting should be resilient
    }
  }

  /// Check if operation is within rate limit (client-side check)
  Future<bool> isWithinRateLimit(
    String operation, {
    int maxOperations = 10,
    int timeWindowSeconds = 60,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return true; // Allow if not logged in

      final userId = currentUser.uid;
      final rateLimitRef = _firestore.collection('rate_limits').doc(userId);
      final rateLimitDoc = await rateLimitRef.get();

      if (!rateLimitDoc.exists) return true; // No rate limit data, allow

      final data = rateLimitDoc.data()!;
      final operationCountKey = '${operation}_count';
      final operationTimeKey = '${operation}_time';

      final currentCount = (data[operationCountKey] as int?) ?? 0;
      final lastOperationTime = data[operationTimeKey] as Timestamp?;

      if (lastOperationTime == null) return true;

      // Check if we're outside the time window
      final timeSinceLastOp =
          DateTime.now().difference(lastOperationTime.toDate()).inSeconds;

      if (timeSinceLastOp > timeWindowSeconds) {
        return true; // Outside window, allow
      }

      // Check if within rate limit
      return currentCount < maxOperations;
    } catch (e) {
      debugPrint(
        '❌ FirestoreRateLimitingService: Error checking rate limit: $e',
      );
      return true; // Fail open - don't block legitimate users
    }
  }

  /// Reset rate limit for an operation
  Future<void> resetRateLimit(String operation) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final userId = currentUser.uid;
      final rateLimitRef = _firestore.collection('rate_limits').doc(userId);
      final operationCountKey = '${operation}_count';
      final operationTimeKey = '${operation}_time';

      await rateLimitRef.update({
        operationCountKey: 0,
        operationTimeKey: FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '✅ FirestoreRateLimitingService: Reset rate limit for $operation',
      );
    } catch (e) {
      debugPrint(
        '❌ FirestoreRateLimitingService: Error resetting rate limit: $e',
      );
    }
  }
}
