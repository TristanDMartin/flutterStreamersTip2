import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing rate limiting for content moderation violations
/// ✅ SECURITY FIX: Uses FlutterSecureStorage for secure data storage
class RateLimitingService {
  static final RateLimitingService _instance = RateLimitingService._internal();
  factory RateLimitingService() => _instance;
  RateLimitingService._internal();

  // ✅ SECURITY FIX: Use FlutterSecureStorage instead of SharedPreferences
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _violationsKey = 'content_violations';
  static const String _lastViolationKey = 'last_violation_time';
  static const int _maxViolations = 5;
  static const Duration _cooldownPeriod = Duration(minutes: 10);

  /// Check if user is currently rate limited
  Future<bool> isRateLimited() async {
    try {
      final violationsStr = await _storage.read(key: _violationsKey);
      final lastViolationTimeStr = await _storage.read(key: _lastViolationKey);
      
      final violations = int.tryParse(violationsStr ?? '0') ?? 0;
      final lastViolationTime = int.tryParse(lastViolationTimeStr ?? '0') ?? 0;

      if (violations >= _maxViolations) {
        final lastViolation = DateTime.fromMillisecondsSinceEpoch(lastViolationTime);
        final timeSinceLastViolation = DateTime.now().difference(lastViolation);
        
        if (timeSinceLastViolation < _cooldownPeriod) {
          return true;
        } else {
          // Reset violations if cooldown period has passed
          await _resetViolations();
          return false;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ RateLimitingService: Error checking rate limit: $e');
      return false; // Fail open - don't block legitimate users
    }
  }

  /// Record a content violation
  Future<void> recordViolation() async {
    try {
      final violationsStr = await _storage.read(key: _violationsKey);
      final violations = int.tryParse(violationsStr ?? '0') ?? 0;
      
      await _storage.write(key: _violationsKey, value: (violations + 1).toString());
      await _storage.write(key: _lastViolationKey, value: DateTime.now().millisecondsSinceEpoch.toString());
    } catch (e) {
      debugPrint('❌ RateLimitingService: Error recording violation: $e');
      // Don't throw - rate limiting should be resilient
    }
  }

  /// Reset violations (called when cooldown period expires)
  Future<void> _resetViolations() async {
    try {
      await _storage.delete(key: _violationsKey);
      await _storage.delete(key: _lastViolationKey);
    } catch (e) {
      debugPrint('❌ RateLimitingService: Error resetting violations: $e');
    }
  }

  /// Get remaining cooldown time
  Future<Duration?> getRemainingCooldown() async {
    try {
      final violationsStr = await _storage.read(key: _violationsKey);
      final lastViolationTimeStr = await _storage.read(key: _lastViolationKey);
      
      final violations = int.tryParse(violationsStr ?? '0') ?? 0;
      final lastViolationTime = int.tryParse(lastViolationTimeStr ?? '0') ?? 0;

      if (violations >= _maxViolations) {
        final lastViolation = DateTime.fromMillisecondsSinceEpoch(lastViolationTime);
        final timeSinceLastViolation = DateTime.now().difference(lastViolation);
        
        if (timeSinceLastViolation < _cooldownPeriod) {
          return _cooldownPeriod - timeSinceLastViolation;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ RateLimitingService: Error getting cooldown: $e');
      return null;
    }
  }

  /// Get current violation count
  Future<int> getViolationCount() async {
    try {
      final violationsStr = await _storage.read(key: _violationsKey);
      return int.tryParse(violationsStr ?? '0') ?? 0;
    } catch (e) {
      debugPrint('❌ RateLimitingService: Error getting violation count: $e');
      return 0;
    }
  }

  /// Check if user is approaching rate limit
  Future<bool> isApproachingLimit() async {
    final violations = await getViolationCount();
    return violations >= (_maxViolations * 0.8).round();
  }
}
