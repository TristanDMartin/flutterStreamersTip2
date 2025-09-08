import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing rate limiting for content moderation violations
class RateLimitingService {
  static final RateLimitingService _instance = RateLimitingService._internal();
  factory RateLimitingService() => _instance;
  RateLimitingService._internal();

  static const String _violationsKey = 'content_violations';
  static const String _lastViolationKey = 'last_violation_time';
  static const int _maxViolations = 5;
  static const Duration _cooldownPeriod = Duration(minutes: 10);

  /// Check if user is currently rate limited
  Future<bool> isRateLimited() async {
    final prefs = await SharedPreferences.getInstance();
    final violations = prefs.getInt(_violationsKey) ?? 0;
    final lastViolationTime = prefs.getInt(_lastViolationKey) ?? 0;

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
  }

  /// Record a content violation
  Future<void> recordViolation() async {
    final prefs = await SharedPreferences.getInstance();
    final violations = prefs.getInt(_violationsKey) ?? 0;
    
    await prefs.setInt(_violationsKey, violations + 1);
    await prefs.setInt(_lastViolationKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Reset violations (called when cooldown period expires)
  Future<void> _resetViolations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_violationsKey);
    await prefs.remove(_lastViolationKey);
  }

  /// Get remaining cooldown time
  Future<Duration?> getRemainingCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final violations = prefs.getInt(_violationsKey) ?? 0;
    final lastViolationTime = prefs.getInt(_lastViolationKey) ?? 0;

    if (violations >= _maxViolations) {
      final lastViolation = DateTime.fromMillisecondsSinceEpoch(lastViolationTime);
      final timeSinceLastViolation = DateTime.now().difference(lastViolation);
      
      if (timeSinceLastViolation < _cooldownPeriod) {
        return _cooldownPeriod - timeSinceLastViolation;
      }
    }

    return null;
  }

  /// Get current violation count
  Future<int> getViolationCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_violationsKey) ?? 0;
  }

  /// Check if user is approaching rate limit
  Future<bool> isApproachingLimit() async {
    final violations = await getViolationCount();
    return violations >= (_maxViolations * 0.8).round();
  }
}
