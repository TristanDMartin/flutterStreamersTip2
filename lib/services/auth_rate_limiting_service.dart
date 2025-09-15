import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing authentication rate limiting and brute force protection
class AuthRateLimitingService {
  static final AuthRateLimitingService _instance = AuthRateLimitingService._internal();
  factory AuthRateLimitingService() => _instance;
  AuthRateLimitingService._internal();

  static const String _attemptsKey = 'auth_attempts';
  static const String _lastAttemptKey = 'last_auth_attempt';
  static const String _lockoutKey = 'auth_lockout_until';
  static const int _maxAttempts = 5;
  static const Duration _attemptWindow = Duration(minutes: 15);
  static const Duration _lockoutDuration = Duration(minutes: 30);

  /// Check if authentication is currently rate limited
  Future<bool> isRateLimited() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(_lockoutKey) ?? 0;
    
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
  }

  /// Record an authentication attempt
  Future<void> recordAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final attempts = prefs.getInt(_attemptsKey) ?? 0;
    final lastAttemptTime = prefs.getInt(_lastAttemptKey) ?? 0;
    
    // Reset attempts if outside the time window
    if (lastAttemptTime > 0) {
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptTime);
      if (now.difference(lastAttempt) > _attemptWindow) {
        await prefs.setInt(_attemptsKey, 1);
      } else {
        await prefs.setInt(_attemptsKey, attempts + 1);
      }
    } else {
      await prefs.setInt(_attemptsKey, 1);
    }
    
    await prefs.setInt(_lastAttemptKey, now.millisecondsSinceEpoch);
    
    // Check if we should lockout
    final currentAttempts = prefs.getInt(_attemptsKey) ?? 0;
    if (currentAttempts >= _maxAttempts) {
      final lockoutUntil = now.add(_lockoutDuration);
      await prefs.setInt(_lockoutKey, lockoutUntil.millisecondsSinceEpoch);
    }
  }

  /// Record a successful authentication (reset attempts)
  Future<void> recordSuccess() async {
    await _resetAttempts();
  }

  /// Get remaining lockout time
  Future<Duration?> getRemainingLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(_lockoutKey) ?? 0;
    
    if (lockoutUntil > 0) {
      final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
      if (DateTime.now().isBefore(lockoutTime)) {
        return lockoutTime.difference(DateTime.now());
      }
    }
    
    return null;
  }

  /// Get current attempt count
  Future<int> getAttemptCount() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_attemptsKey) ?? 0;
    final lastAttemptTime = prefs.getInt(_lastAttemptKey) ?? 0;
    
    // Reset if outside time window
    if (lastAttemptTime > 0) {
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptTime);
      if (DateTime.now().difference(lastAttempt) > _attemptWindow) {
        await _resetAttempts();
        return 0;
      }
    }
    
    return attempts;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptsKey);
    await prefs.remove(_lastAttemptKey);
    await prefs.remove(_lockoutKey);
  }

  /// Force reset (for admin purposes)
  Future<void> forceReset() async {
    await _resetAttempts();
  }
}
