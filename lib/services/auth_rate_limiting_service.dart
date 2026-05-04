import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing authentication rate limiting and brute force protection
/// ✅ SECURITY FIX: Uses FlutterSecureStorage for secure data storage
class AuthRateLimitingService {
  static final AuthRateLimitingService _instance = AuthRateLimitingService._internal();
  factory AuthRateLimitingService() => _instance;
  AuthRateLimitingService._internal();

  // ✅ SECURITY FIX: Use FlutterSecureStorage instead of SharedPreferences
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _attemptsKey = 'auth_attempts';
  static const String _lastAttemptKey = 'last_auth_attempt';
  static const String _lockoutKey = 'auth_lockout_until';
  static const int _maxAttempts = 5;
  static const Duration _attemptWindow = Duration(minutes: 15);
  static const Duration _lockoutDuration = Duration(minutes: 30);

  /// Check if authentication is currently rate limited
  Future<bool> isRateLimited() async {
    try {
      final lockoutUntilStr = await _storage.read(key: _lockoutKey);
      if (lockoutUntilStr == null) return false;
      
      final lockoutUntil = int.tryParse(lockoutUntilStr) ?? 0;
      if (lockoutUntil > 0) {
        final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
        if (DateTime.now().isBefore(lockoutTime)) {
          return true;
        } else {
          // Lockout period has expired, reset
          await _resetAttempts();
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ AuthRateLimitingService: Error checking rate limit: $e');
      return false; // Fail open - don't block legitimate users
    }
  }

  /// Record an authentication attempt
  Future<void> recordAttempt() async {
    try {
      final now = DateTime.now();
      final attemptsStr = await _storage.read(key: _attemptsKey);
      final lastAttemptTimeStr = await _storage.read(key: _lastAttemptKey);
      
      final attempts = int.tryParse(attemptsStr ?? '0') ?? 0;
      final lastAttemptTime = int.tryParse(lastAttemptTimeStr ?? '0') ?? 0;
      
      // Reset attempts if outside the time window
      int newAttempts;
      if (lastAttemptTime > 0) {
        final lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptTime);
        if (now.difference(lastAttempt) > _attemptWindow) {
          newAttempts = 1;
        } else {
          newAttempts = attempts + 1;
        }
      } else {
        newAttempts = 1;
      }
      
      await _storage.write(key: _attemptsKey, value: newAttempts.toString());
      await _storage.write(key: _lastAttemptKey, value: now.millisecondsSinceEpoch.toString());
      
      // Check if we should lockout
      if (newAttempts >= _maxAttempts) {
        final lockoutUntil = now.add(_lockoutDuration);
        await _storage.write(key: _lockoutKey, value: lockoutUntil.millisecondsSinceEpoch.toString());
      }
    } catch (e) {
      debugPrint('❌ AuthRateLimitingService: Error recording attempt: $e');
      // Don't throw - rate limiting should be resilient
    }
  }

  /// Record a successful authentication (reset attempts)
  Future<void> recordSuccess() async {
    await _resetAttempts();
  }

  /// Get remaining lockout time
  Future<Duration?> getRemainingLockout() async {
    try {
      final lockoutUntilStr = await _storage.read(key: _lockoutKey);
      if (lockoutUntilStr == null) return null;
      
      final lockoutUntil = int.tryParse(lockoutUntilStr) ?? 0;
      if (lockoutUntil > 0) {
        final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
        if (DateTime.now().isBefore(lockoutTime)) {
          return lockoutTime.difference(DateTime.now());
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ AuthRateLimitingService: Error getting lockout: $e');
      return null;
    }
  }

  /// Get current attempt count
  Future<int> getAttemptCount() async {
    try {
      final attemptsStr = await _storage.read(key: _attemptsKey);
      final lastAttemptTimeStr = await _storage.read(key: _lastAttemptKey);
      
      final attempts = int.tryParse(attemptsStr ?? '0') ?? 0;
      final lastAttemptTime = int.tryParse(lastAttemptTimeStr ?? '0') ?? 0;
      
      // Reset if outside time window
      if (lastAttemptTime > 0) {
        final lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptTime);
        if (DateTime.now().difference(lastAttempt) > _attemptWindow) {
          await _resetAttempts();
          return 0;
        }
      }
      
      return attempts;
    } catch (e) {
      debugPrint('❌ AuthRateLimitingService: Error getting attempt count: $e');
      return 0;
    }
  }

  /// Check if user is approaching rate limit
  Future<bool> isApproachingLimit() async {
    final attempts = await getAttemptCount();
    return attempts >= (_maxAttempts * 0.8).round();
  }

  /// Get user-friendly rate limit message
  Future<String?> getRateLimitMessage() async {
    if (await isRateLimited()) {
      final remaining = await getRemainingLockout();
      if (remaining != null) {
        final minutes = remaining.inMinutes;
        if (minutes > 0) {
          return 'Too many failed attempts. Try again in $minutes minutes.';
        } else {
          return 'Too many failed attempts. Try again in ${remaining.inSeconds} seconds.';
        }
      }
    }
    
    final attempts = await getAttemptCount();
    if (attempts >= (_maxAttempts * 0.6).round()) {
      final remaining = _maxAttempts - attempts;
      return 'Too many failed attempts. $remaining attempts remaining.';
    }
    
    return null;
  }

  /// Reset all attempts and lockout
  Future<void> _resetAttempts() async {
    try {
      await _storage.delete(key: _attemptsKey);
      await _storage.delete(key: _lastAttemptKey);
      await _storage.delete(key: _lockoutKey);
    } catch (e) {
      debugPrint('❌ AuthRateLimitingService: Error resetting attempts: $e');
    }
  }

  /// Force reset (for admin purposes)
  Future<void> forceReset() async {
    await _resetAttempts();
  }
}
